import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/friend_repository.dart';
import '../../../shared/models/friend.dart';
import '../../../shared/socket/socket_client.dart';
import '../../../shared/socket/socket_events.dart';

class FriendNotifier extends StateNotifier<List<FriendModel>> {
  final FriendRepository _repository;

  FriendNotifier(this._repository) : super([]) {
    _listenSocketEvents();
  }

  void _listenSocketEvents() {
    SocketClient.instance
      ?..on(SocketEvents.friendRequestReceived, (_) => fetchFriends())
      ..on(SocketEvents.friendRequestAccepted, (_) => fetchFriends());
  }

  void initSocketListeners() {
    _listenSocketEvents();
  }

  Future<void> fetchFriends() async {
    final data = await _repository.getFriends();
    state = data.map((f) => FriendModel.fromJson(f)).toList();
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

  Future<void> deleteFriend(int friendshipId) async {
    await _repository.deleteFriend(friendshipId);
    await fetchFriends();
  }
}

final friendRepositoryProvider = Provider((ref) => FriendRepository());

final friendProvider = StateNotifierProvider<FriendNotifier, List<FriendModel>>(
  (ref) => FriendNotifier(ref.watch(friendRepositoryProvider)),
);

final receivedRequestsProvider =
    FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(friendRepositoryProvider).getReceivedRequests();
});
