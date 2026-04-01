import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';
import '../../../shared/models/user.dart';

class FriendRepository {
  final Dio _dio = DioClient.instance;

  Future<List<Map<String, dynamic>>> getFriends() async {
    final response = await _dio.get('/friends');
    return List<Map<String, dynamic>>.from(response.data as List);
  }

  Future<List<Map<String, dynamic>>> getReceivedRequests() async {
    final response = await _dio.get('/friends/requests/received');
    return List<Map<String, dynamic>>.from(response.data as List);
  }

  Future<void> sendRequest(String receiverUsername) async {
    await _dio.post('/friends/request', data: {
      'receiverUsername': receiverUsername,
    });
  }

  Future<void> acceptRequest(int friendshipId) async {
    await _dio.patch('/friends/request/$friendshipId/accept');
  }

  Future<void> rejectRequest(int friendshipId) async {
    await _dio.patch('/friends/request/$friendshipId/reject');
  }

  Future<Map<String, dynamic>> searchUser(String username) async {
    final response = await _dio
        .get('/users/search', queryParameters: {'username': username});
    return Map<String, dynamic>.from(response.data as Map);
  }
}
