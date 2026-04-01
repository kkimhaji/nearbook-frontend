import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/guestbook_repository.dart';
import '../../../shared/socket/socket_client.dart';
import '../../../shared/socket/socket_events.dart';

// 받은 방명록 요청 상태
class GuestbookRequestState {
  final int? requestId;
  final Map<String, dynamic>? owner;
  final bool isTyping;
  final String? typingNickname;

  const GuestbookRequestState({
    this.requestId,
    this.owner,
    this.isTyping = false,
    this.typingNickname,
  });

  GuestbookRequestState copyWith({
    int? requestId,
    Map<String, dynamic>? owner,
    bool? isTyping,
    String? typingNickname,
  }) {
    return GuestbookRequestState(
      requestId: requestId ?? this.requestId,
      owner: owner ?? this.owner,
      isTyping: isTyping ?? this.isTyping,
      typingNickname: typingNickname ?? this.typingNickname,
    );
  }

  GuestbookRequestState clear() => const GuestbookRequestState();
}

class GuestbookNotifier extends StateNotifier<GuestbookRequestState> {
  final GuestbookRepository _repository;

  GuestbookNotifier(this._repository) : super(const GuestbookRequestState()) {
    _listenSocketEvents();
  }

  void _listenSocketEvents() {
    // 방명록 요청 수신
    SocketClient.instance.on(SocketEvents.guestbookRequestReceived, (data) {
      final map = data as Map<String, dynamic>;
      state = state.copyWith(
        requestId: map['requestId'] as int,
        owner: map['owner'] as Map<String, dynamic>,
      );
    });

    // 타이핑 인디케이터 시작
    SocketClient.instance.on(SocketEvents.guestbookTypingStart, (data) {
      final map = data as Map<String, dynamic>;
      final writer = map['writer'] as Map<String, dynamic>;
      state = state.copyWith(
        isTyping: true,
        typingNickname: writer['nickname'] as String,
      );
    });

    // 타이핑 인디케이터 종료
    SocketClient.instance.on(SocketEvents.guestbookTypingStop, (_) {
      state = state.copyWith(isTyping: false, typingNickname: null);
    });

    // 작성 완료
    SocketClient.instance.on(SocketEvents.guestbookCompleted, (_) {
      state = state.copyWith(isTyping: false, typingNickname: null);
    });
  }

  Future<void> submitGuestbook(int requestId, String content) async {
    await _repository.submitGuestbook(requestId, content);
    state = state.clear();
  }

  Future<void> rejectRequest(int requestId) async {
    await _repository.rejectRequest(requestId);
    state = state.clear();
  }

  void sendTypingStart(String targetUserId, int requestId) {
    SocketClient.instance.emit(SocketEvents.typingStart, {
      'targetUserId': targetUserId,
      'requestId': requestId,
    });
  }

  void sendTypingStop(String targetUserId, int requestId) {
    SocketClient.instance.emit(SocketEvents.typingStop, {
      'targetUserId': targetUserId,
      'requestId': requestId,
    });
  }
}

final guestbookRepositoryProvider = Provider((ref) => GuestbookRepository());

final guestbookProvider =
    StateNotifierProvider<GuestbookNotifier, GuestbookRequestState>(
  (ref) => GuestbookNotifier(ref.watch(guestbookRepositoryProvider)),
);

final myGuestbookProvider =
    FutureProvider.family<List<dynamic>, String>((ref, groupBy) {
  return ref.watch(guestbookRepositoryProvider).getMyGuestbook(groupBy);
});
