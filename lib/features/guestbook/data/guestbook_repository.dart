import 'package:dio/dio.dart';
import '../../../core/network/dio_client.dart';

class GuestbookRepository {
  final Dio _dio = DioClient.instance;

  Future<Map<String, dynamic>> requestGuestbook(String writerUsername) async {
    final response = await _dio.post('/guestbook/request', data: {
      'writerUsername': writerUsername,
    });
    return Map<String, dynamic>.from(response.data as Map);
  }

  Future<void> markAsWriting(int requestId) async {
    await _dio.patch('/guestbook/request/$requestId/writing');
  }

  Future<void> submitGuestbook(int requestId, String content) async {
    await _dio.post('/guestbook/request/$requestId/submit', data: {
      'content': content,
    });
  }

  Future<void> rejectRequest(int requestId) async {
    await _dio.patch('/guestbook/request/$requestId/reject');
  }

  Future<List<dynamic>> getMyGuestbook(String groupBy) async {
    final response = await _dio.get(
      '/guestbook/mine',
      queryParameters: {'groupBy': groupBy},
    );
    return response.data as List;
  }

  Future<List<dynamic>> getWrittenGuestbook(String groupBy) async {
    final response = await _dio.get(
      '/guestbook/written',
      queryParameters: {'groupBy': groupBy},
    );
    return response.data as List;
  }
}
