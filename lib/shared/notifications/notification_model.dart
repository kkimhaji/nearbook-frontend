enum NotificationType {
  friendRequestReceived,
  friendRequestAccepted,
  guestbookRequestReceived,
  guestbookRequestRejected,
  guestbookCompleted,
  guestbookTyping,
}

class AppNotification {
  final String id;
  final NotificationType type;
  final Map<String, dynamic> data;

  AppNotification({
    required this.id,
    required this.type,
    required this.data,
  });
}
