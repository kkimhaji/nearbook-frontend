import 'package:flutter/foundation.dart';
import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';
import 'socket_events.dart';

class SocketClient {
  static io.Socket? _socket;

  static io.Socket? get instance => _socket; // nullable로 변경

  static Future<void> connect() async {
    final token = await SecureStorage.getToken();
    if (token == null) return;

    _socket = io.io(
      ApiConstants.socketUrl,
      io.OptionBuilder()
          .setTransports(['websocket'])
          .setAuth({'token': token})
          .disableAutoConnect()
          .build(),
    );

    // 연결 이벤트 로그
    _socket!.onConnect((_) {
      debugPrint('[Socket] 연결 성공 ✅ id: ${_socket?.id}');
    });

    _socket!.onDisconnect((_) {
      debugPrint('[Socket] 연결 해제');
    });

    _socket!.onConnectError((e) {
      debugPrint('[Socket] 연결 오류 ❌: $e');
    });

    _socket!.connect();
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  static bool get isConnected => _socket?.connected ?? false;
}
