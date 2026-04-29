import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class UserRepository {
  final Dio _dio = DioClient.instance;

  Future<Map<String, dynamic>> getMyProfile() async {
    final response = await _dio.get('/users/me');
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> updateNickname(String nickname) async {
    await _dio.patch('/users/nickname', data: {'nickname': nickname});
  }

  Future<void> changePassword({
    required String currentPassword,
    required String newPassword,
  }) async {
    await _dio.patch('/users/password', data: {
      'currentPassword': currentPassword,
      'newPassword': newPassword,
    });
  }

  Future<void> updateBleVisibility(String bleVisibility) async {
    await _dio.patch('/users/ble-visibility', data: {
      'bleVisibility': bleVisibility,
    });
  }

  Future<String> uploadProfileImage(String filePath) async {
    final formData = FormData.fromMap({
      'image': await MultipartFile.fromFile(
        filePath,
        filename: filePath.split('/').last,
      ),
    });
    final response = await _dio.post(
      '/users/profile-image',
      data: formData,
    );
    return response.data['profileImageUrl'] as String;
  }

  Future<void> deleteProfileImage() async {
    await _dio.delete('/users/profile-image');
  }

  Future<void> deleteAccount() async {
    await _dio.delete('/users/me');
  }
}
