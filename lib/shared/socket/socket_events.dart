class SocketEvents {
  // 클라이언트 → 서버
  static const String typingStart = 'typing:start';
  static const String typingStop = 'typing:stop';
  static const String bleDetected = 'ble:detected';

  // 서버 → 클라이언트
  static const String authenticated = 'authenticated';
  static const String friendRequestReceived = 'friend:request:received';
  static const String friendRequestAccepted = 'friend:request:accepted';
  static const String guestbookRequestReceived = 'guestbook:request:received';
  static const String guestbookRequestRejected = 'guestbook:request:rejected';
  static const String guestbookCompleted = 'guestbook:completed';
  static const String guestbookTypingStart = 'guestbook:typing:start';
  static const String guestbookTypingStop = 'guestbook:typing:stop';
  static const String bleDetectedResult = 'ble:detected:result';
}
