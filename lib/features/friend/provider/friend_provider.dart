import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/friend_repository.dart';
import '../../../shared/models/friend.dart';
import '../../../shared/socket/socket_client.dart';
import '../../../shared/socket/socket_events.dart';

class FriendState {
  final List<FriendModel> friends;
  final List<Map<String, dynamic>> receivedRequests;
  final bool isLoading;

  const FriendState({
    this.friends = const [],
    this.receivedRequests = const [],
    this.isLoading = false,
  });

  FriendState copyWith({
    List<FriendModel>? friends,
    List<Map<String, dynamic>>? receivedRequests,
    bool? isLoading,
  }) {
    return FriendState(
      friends: friends ?? this.friends,
      receivedRequests: receivedRequests ?? this.receivedRequests,
      isLoading: isLoading ?? this.isLoading,
    );
  }
}

class FriendNotifier extends StateNotifier<FriendState> {
  final FriendRepository _repository;

  FriendNotifier(this._repository) : super(const FriendState());

  void _listenSocketEvents() {
    SocketClient.instance
      ?..on(SocketEvents.friendRequestReceived, (_) => refresh())
      ..on(SocketEvents.friendRequestAccepted, (_) => refresh());
  }

  void initSocketListeners() {
    _listenSocketEvents();
  }

  // 친구 목록 + 받은 요청 동시 갱신
  Future<void> refresh() async {
    state = state.copyWith(isLoading: true);
    try {
      final results = await Future.wait([
        _repository.getFriends(),
        _repository.getReceivedRequests(),
      ]);

      state = state.copyWith(
        friends: (results[0] as List<Map<String, dynamic>>)
            .map((f) => FriendModel.fromJson(f))
            .toList(),
        receivedRequests: results[1] as List<Map<String, dynamic>>,
        isLoading: false,
      );
    } catch (_) {
      state = state.copyWith(isLoading: false);
    }
  }

  // 하위 호환 유지
  Future<void> fetchFriends() => refresh();

  Future<void> sendRequest(String username) async {
    await _repository.sendRequest(username);
  }

  Future<void> acceptRequest(int friendshipId) async {
    await _repository.acceptRequest(friendshipId);
    await refresh();
  }

  Future<void> rejectRequest(int friendshipId) async {
    await _repository.rejectRequest(friendshipId);
    await refresh();
  }

  Future<void> deleteFriend(int friendshipId) async {
    await _repository.deleteFriend(friendshipId);
    await refresh();
  }
}

final friendRepositoryProvider = Provider((ref) => FriendRepository());

final friendProvider = StateNotifierProvider<FriendNotifier, FriendState>(
  (ref) => FriendNotifier(ref.watch(friendRepositoryProvider)),
);
