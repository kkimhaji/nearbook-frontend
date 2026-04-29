import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/friend_provider.dart';
import '../../../core/network/dio_exception_handler.dart';
import '../../../shared/widgets/profile_avatar.dart';

class FriendScreen extends ConsumerStatefulWidget {
  const FriendScreen({super.key});

  @override
  ConsumerState<FriendScreen> createState() => _FriendScreenState();
}

class _FriendScreenState extends ConsumerState<FriendScreen> {
  final _searchController = TextEditingController();

  @override
  void initState() {
    super.initState();
    ref.read(friendProvider.notifier).fetchFriends();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _showSearchDialog() async {
    await showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('친구 검색'),
        content: TextField(
          controller: _searchController,
          decoration: const InputDecoration(labelText: '아이디 입력'),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('취소'),
          ),
          TextButton(
            onPressed: () async {
              Navigator.pop(context);
              await _sendFriendRequest(_searchController.text.trim());
              _searchController.clear();
            },
            child: const Text('요청'),
          ),
        ],
      ),
    );
  }

  Future<void> _sendFriendRequest(String username) async {
    try {
      await ref.read(friendProvider.notifier).sendRequest(username);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구 요청을 보냈습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DioExceptionHandler.getMessage(e))),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final friends = ref.watch(friendProvider);
    final receivedRequests = ref.watch(receivedRequestsProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구'),
        actions: [
          IconButton(
            icon: const Icon(Icons.person_add),
            onPressed: _showSearchDialog,
          ),
        ],
      ),
      body: Column(
        children: [
          // 받은 친구 요청
          receivedRequests.when(
            data: (requests) {
              if (requests.isEmpty) return const SizedBox.shrink();
              return Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Padding(
                    padding: EdgeInsets.fromLTRB(16, 12, 16, 4),
                    child: Text(
                      '받은 친구 요청',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  ...requests.map((req) {
                    final requester = req['requester'] as Map<String, dynamic>;
                    return ListTile(
                      leading: ProfileAvatar(
                        nickname: requester['nickname'] as String,
                        imageUrl: requester['profileImageUrl'] as String?,
                        radius: 22,
                      ),
                      title: Text(requester['nickname'] as String),
                      subtitle: Text('@${requester['username']}'),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          TextButton(
                            onPressed: () => ref
                                .read(friendProvider.notifier)
                                .acceptRequest(req['id'] as int),
                            child: const Text('수락'),
                          ),
                          TextButton(
                            onPressed: () => ref
                                .read(friendProvider.notifier)
                                .rejectRequest(req['id'] as int),
                            child: const Text('거절'),
                          ),
                        ],
                      ),
                    );
                  }),
                  const Divider(),
                ],
              );
            },
            loading: () => const SizedBox.shrink(),
            error: (_, __) => const SizedBox.shrink(),
          ),

          // 친구 목록
          Expanded(
            child: friends.isEmpty
                ? const Center(child: Text('친구가 없습니다.'))
                : ListView.builder(
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      return ListTile(
                        leading: ProfileAvatar(
                          nickname: friend.nickname,
                          imageUrl: friend.profileImageUrl,
                          radius: 22,
                        ),
                        title: Text(friend.nickname),
                        subtitle: Text('@${friend.username}'),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
