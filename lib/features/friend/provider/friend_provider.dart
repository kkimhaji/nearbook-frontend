import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/friend_repository.dart';
import '../../../shared/models/user.dart';
import '../../../shared/socket/socket_client.dart';
import '../../../shared/socket/socket_events.dart';

class FriendNotifier extends StateNotifier<List<UserModel>> {
  final FriendRepository _repository;

  FriendNotifier(this._repository) : super([]) {
    _listenSocketEvents();
  }

  void _listenSocketEvents() {
    SocketClient.instance
      ?..on(SocketEvents.friendRequestReceived, (_) => fetchFriends())
      ..on(SocketEvents.friendRequestAccepted, (_) => fetchFriends());
  }

// 소켓 연결 후 외부에서 호출할 수 있도록 public 메서드 추가
  void initSocketListeners() {
    _listenSocketEvents();
  }

  Future<void> fetchFriends() async {
    final data = await _repository.getFriends();
    state = data
        .map((f) => UserModel.fromJson(f['friend'] as Map<String, dynamic>))
        .toList();
  }

  Future<void> sendRequest(String username) async {
    await _repository.sendRequest(username);
  }

  Future<void> acceptRequest(int friendshipId) async {
    await _repository.acceptRequest(friendshipId);
    await fetchFriends();
  }

  Future<void> rejectRequest(int friendshipId) async {
    await _repository.rejectRequest(friendshipId);
  }
}

final friendRepositoryProvider = Provider((ref) => FriendRepository());

final friendProvider = StateNotifierProvider<FriendNotifier, List<UserModel>>(
  (ref) => FriendNotifier(ref.watch(friendRepositoryProvider)),
);

final receivedRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(friendRepositoryProvider).getReceivedRequests();
});
