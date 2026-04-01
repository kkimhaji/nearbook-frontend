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
    await SecureStorage.saveToken(response.data['accessToken'] as String);
  }

  Future<void> login({
    required String username,
    required String password,
  }) async {
    final response = await _dio.post('/auth/login', data: {
      'username': username,
      'password': password,
    });
    await SecureStorage.saveToken(response.data['accessToken'] as String);
  }

  Future<void> logout() async {
    await SecureStorage.deleteToken();
  }
}
