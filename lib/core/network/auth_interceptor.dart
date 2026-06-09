import 'package:dio/dio.dart';
import '../storage/secure_storage.dart';

class AuthInterceptor extends Interceptor {
  // 401 발생 시 호출할 콜백 — app_router.dart에서 주입
  static Future<void> Function()? onUnauthorized;

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
  void onError(DioException err, ErrorInterceptorHandler handler) {
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
    SecureStorage.deleteToken();
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