import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/guestbook_repository.dart';
import '../../../shared/socket/socket_client.dart';
import '../../../shared/socket/socket_events.dart';

class GuestbookRequestState {
  final int? requestId;
  final Map<String, dynamic>? owner;
  final bool isTyping;
  final String? typingNickname;
  final bool shouldRefresh;

  const GuestbookRequestState({
    this.requestId,
    this.owner,
    this.isTyping = false,
    this.typingNickname,
    this.shouldRefresh = false,
  });

  GuestbookRequestState copyWith({
    int? requestId,
    Map<String, dynamic>? owner,
    bool? isTyping,
    String? typingNickname,
    bool? shouldRefresh,
  }) {
    return GuestbookRequestState(
      requestId: requestId ?? this.requestId,
      owner: owner ?? this.owner,
      isTyping: isTyping ?? this.isTyping,
      typingNickname: typingNickname ?? this.typingNickname,
      shouldRefresh: shouldRefresh ?? this.shouldRefresh,
    );
  }

  GuestbookRequestState clear() => const GuestbookRequestState();
}

class GuestbookNotifier extends StateNotifier<GuestbookRequestState> {
  final GuestbookRepository _repository;

  GuestbookNotifier(this._repository) : super(const GuestbookRequestState());

  void _listenSocketEvents() {
    SocketClient.instance
      ?..on(SocketEvents.guestbookRequestReceived, (data) {
        final map = data as Map<String, dynamic>;
        state = state.copyWith(
          requestId: map['requestId'] as int,
          owner: map['owner'] as Map<String, dynamic>,
        );
      })
      ..on(SocketEvents.guestbookTypingStart, (data) {
        final map = data as Map<String, dynamic>;
        final writer = map['writer'] as Map<String, dynamic>;
        state = state.copyWith(
          isTyping: true,
          typingNickname: writer['nickname'] as String,
        );
      })
      ..on(SocketEvents.guestbookTypingStop, (_) {
        state = state.copyWith(isTyping: false, typingNickname: null);
      })
      ..on(SocketEvents.guestbookCompleted, (_) {
        // 타이핑 인디케이터 초기화 + 목록 갱신 신호
        state = state.copyWith(
          isTyping: false,
          typingNickname: null,
          shouldRefresh: true, // 갱신 트리거
        );
      });
  }

  void initSocketListeners() {
    _listenSocketEvents();
  }

  // 갱신 완료 후 신호 초기화
  void clearRefreshSignal() {
    state = state.copyWith(shouldRefresh: false);
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
    SocketClient.instance?.emit(SocketEvents.typingStart, {
      'targetUserId': targetUserId,
      'requestId': requestId,
    });
  }

  void sendTypingStop(String targetUserId, int requestId) {
    SocketClient.instance?.emit(SocketEvents.typingStop, {
      'targetUserId': targetUserId,
      'requestId': requestId,
    });
  }
}

final writtenGuestbookProvider =
    FutureProvider.family<List<dynamic>, String>((ref, groupBy) {
  return ref.watch(guestbookRepositoryProvider).getWrittenGuestbook(groupBy);
});

final guestbookRepositoryProvider = Provider((ref) => GuestbookRepository());

final guestbookProvider =
    StateNotifierProvider<GuestbookNotifier, GuestbookRequestState>(
  (ref) => GuestbookNotifier(ref.watch(guestbookRepositoryProvider)),
);

final myGuestbookProvider =
    FutureProvider.family<List<dynamic>, String>((ref, groupBy) {
  return ref.watch(guestbookRepositoryProvider).getMyGuestbook(groupBy);
});
