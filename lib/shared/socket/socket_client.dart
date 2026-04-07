import 'package:socket_io_client/socket_io_client.dart' as io;
import '../../../core/constants/api_constants.dart';
import '../../../core/storage/secure_storage.dart';

class SocketClient {
  static io.Socket? _socket;

  static io.Socket get instance {
    assert(_socket != null, 'SocketClient가 초기화되지 않았습니다. connect()를 먼저 호출하세요.');
    return _socket!;
  }

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

    _socket!.connect();
  }

  static void disconnect() {
    _socket?.disconnect();
    _socket = null;
  }

  static bool get isConnected => _socket?.connected ?? false;
}
