import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';
import 'notification_model.dart';
import '../socket/socket_client.dart';
import '../socket/socket_events.dart';

// uuid 대신 DateTime 기반 id 사용 (별도 패키지 불필요)
String _generateId() => DateTime.now().microsecondsSinceEpoch.toString();

class NotificationNotifier extends StateNotifier<List<AppNotification>> {
  NotificationNotifier() : super([]);

  void _add(AppNotification notification) {
    state = [...state, notification];
  }

  void dismiss(String id) {
    state = state.where((n) => n.id != id).toList();
  }

  void dismissType(NotificationType type) {
    state = state.where((n) => n.type != type).toList();
  }

  void listenSocketEvents() {
    SocketClient.instance
      ?..on(SocketEvents.friendRequestReceived, (data) {
        _add(AppNotification(
          id: _generateId(),
          type: NotificationType.friendRequestReceived,
          data: Map<String, dynamic>.from(data as Map),
        ));
      })
      ..on(SocketEvents.friendRequestAccepted, (data) {
        _add(AppNotification(
          id: _generateId(),
          type: NotificationType.friendRequestAccepted,
          data: Map<String, dynamic>.from(data as Map),
        ));
      })
      ..on(SocketEvents.guestbookRequestReceived, (data) {
        // 기존 guestbook 요청 알림이 있으면 교체
        dismissType(NotificationType.guestbookRequestReceived);
        _add(AppNotification(
          id: _generateId(),
          type: NotificationType.guestbookRequestReceived,
          data: Map<String, dynamic>.from(data as Map),
        ));
      })
      ..on(SocketEvents.guestbookRequestRejected, (data) {
        _add(AppNotification(
          id: _generateId(),
          type: NotificationType.guestbookRequestRejected,
          data: Map<String, dynamic>.from(data as Map),
        ));
      })
      ..on(SocketEvents.guestbookCompleted, (data) {
        _add(AppNotification(
          id: _generateId(),
          type: NotificationType.guestbookCompleted,
          data: Map<String, dynamic>.from(data as Map),
        ));
      })
      ..on(SocketEvents.guestbookTypingStart, (data) {
        dismissType(NotificationType.guestbookTyping);
        _add(AppNotification(
          id: _generateId(),
          type: NotificationType.guestbookTyping,
          data: Map<String, dynamic>.from(data as Map),
        ));
      })
      ..on(SocketEvents.guestbookTypingStop, (_) {
        dismissType(NotificationType.guestbookTyping);
      });
  }
}

final notificationProvider =
    StateNotifierProvider<NotificationNotifier, List<AppNotification>>(
  (ref) => NotificationNotifier(),
);
