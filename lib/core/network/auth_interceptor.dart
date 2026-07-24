import 'dart:async';
import 'package:dio/dio.dart';
import '../constants/api_constants.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  static Future<void> Function()? onUnauthorized;

  static Completer<bool>? _refreshCompleter;

  static final Dio _refreshDio = Dio(
    BaseOptions(
      baseUrl: ApiConstants.baseUrl,
      headers: {'Content-Type': 'application/json'},
    ),
  );

  @override
  Future<void> onRequest(
    RequestOptions options,
    RequestInterceptorHandler handler,
  ) async {
    final token = await SecureStorage.getToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  Future<void> onError(
    DioException err,
    ErrorInterceptorHandler handler,
  ) async {
    final response = err.response;

    if (response == null) {
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          error: '서버에 연결할 수 없습니다.',
        ),
      );
      return;
    }

    final path = err.requestOptions.path;
    final isAuthEndpoint = path.contains('/auth/');

    if (response.statusCode == 401 && !isAuthEndpoint) {
      final refreshed = await _refreshAccessToken();

      if (refreshed) {
        try {
          final retryResponse = await _retry(err.requestOptions);
          handler.resolve(retryResponse);
          return;
        } catch (_) {
          // 재시도 자체가 실패하면 아래 401 처리로 진행
        }
      }

      await SecureStorage.clearAll();
      onUnauthorized?.call();
      handler.reject(
        DioException(
          requestOptions: err.requestOptions,
          response: response,
          error: '로그인이 필요합니다.',
        ),
      );
      return;
    }

    // 인증 엔드포인트 401 포함 일반 에러 — 서버 메시지 그대로 전달
    final message = response.data is Map
        ? response.data['message'] as String? ?? '알 수 없는 오류가 발생했습니다.'
        : '알 수 없는 오류가 발생했습니다.';

    handler.reject(
      DioException(
        requestOptions: err.requestOptions,
        response: response,
        error: message,
      ),
    );
  }

  Future<bool> _refreshAccessToken() async {
    if (_refreshCompleter != null) {
      return _refreshCompleter!.future;
    }

    _refreshCompleter = Completer<bool>();

    try {
      final refreshToken = await SecureStorage.getRefreshToken();
      if (refreshToken == null) {
        _refreshCompleter!.complete(false);
        return false;
      }

      final response = await _refreshDio.post(
        '/auth/refresh',
        data: {'refreshToken': refreshToken},
      );

      final data = response.data as Map<String, dynamic>;
      await SecureStorage.saveToken(data['accessToken'] as String);
      await SecureStorage.saveRefreshToken(data['refreshToken'] as String);

      _refreshCompleter!.complete(true);
      return true;
    } catch (_) {
      _refreshCompleter!.complete(false);
      return false;
    } finally {
      _refreshCompleter = null;
    }
  }

  Future<Response<dynamic>> _retry(RequestOptions requestOptions) async {
    final token = await SecureStorage.getToken();
    final retryOptions = requestOptions.copyWith(
      headers: {
        ...requestOptions.headers,
        'Authorization': 'Bearer $token',
      },
    );
    return _refreshDio.fetch(retryOptions);
  }
}
