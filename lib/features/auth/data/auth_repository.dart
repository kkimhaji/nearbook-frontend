import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../core/storage/secure_storage.dart';

class AuthRepository {
  final Dio _dio = DioClient.instance;

  Future<void> register({
    required String username,
    required String nickname,
    required String email,
    required String password,
  }) async {
    final response = await _dio.post('/auth/register', data: {
      'username': username,
      'nickname': nickname,
      'email': email,
      'password': password,
    });
    await _saveTokens(response.data as Map<String, dynamic>);
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    await _saveTokens(response.data as Map<String, dynamic>);
  }

  Future<void> logout() async {
    try {
      await _dio.post('/auth/logout');
    } catch (_) {
      // 서버 요청이 실패해도 로컬 토큰은 반드시 제거
    }
    await SecureStorage.clearAll();
  }

  Future<void> forgotPassword(String email) async {
    await _dio.post('/auth/forgot-password', data: {'email': email});
  }

  Future<void> _saveTokens(Map<String, dynamic> data) async {
    await SecureStorage.saveToken(data['accessToken'] as String);
    await SecureStorage.saveRefreshToken(data['refreshToken'] as String);
  }
}
