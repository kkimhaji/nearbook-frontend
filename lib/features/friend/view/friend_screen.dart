import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/friend_provider.dart';
import '../view/qr_scanner_screen.dart';
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

  Future<void> _scanQrCode() async {
    final username = await Navigator.push<String>(
      context,
      MaterialPageRoute(builder: (_) => const QrScannerScreen()),
    );
    if (!mounted || username == null) return;
    await _showScannedUserDialog(username);
  }

  Future<void> _showScannedUserDialog(String username) async {
    try {
      final user =
          await ref.read(friendRepositoryProvider).searchUser(username);
      if (!mounted) return;

      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('친구 요청'),
          content: Text(
            '${user['nickname']}(@${user['username']})님께\n친구 요청을 보내시겠습니까?',
            textAlign: TextAlign.center,
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('취소'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('요청'),
            ),
          ],
        ),
      );

      if (confirmed != true || !mounted) return;
      await _sendFriendRequest(username);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DioExceptionHandler.getMessage(e))),
      );
    }
  }

  Future<void> _confirmDeleteFriend(int friendshipId, String nickname) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('친구 삭제'),
        content: Text('$nickname님을 친구 목록에서 삭제하시겠습니까?\n상대방의 친구 목록에서도 삭제됩니다.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('취소'),
          ),
          TextButton(
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('삭제'),
          ),
        ],
      ),
    );

    if (confirmed != true || !mounted) return;

    try {
      await ref.read(friendProvider.notifier).deleteFriend(friendshipId);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('친구가 삭제되었습니다.')),
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
            icon: const Icon(Icons.qr_code_scanner),
            tooltip: 'QR 스캔',
            onPressed: _scanQrCode,
          ),
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
                    return Card(
                      margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                        side: BorderSide(
                          color: Theme.of(context).colorScheme.outlineVariant,
                          width: 0.5,
                        ),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 12),
                        child: Row(
                          children: [
                            ProfileAvatar(
                              nickname: requester['nickname'] as String,
                              imageUrl: requester['profileImageUrl'] as String?,
                              radius: 24,
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    requester['nickname'] as String,
                                    style: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    '@${requester['username']}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      color:
                                          Theme.of(context).colorScheme.outline,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Row(
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
                          ],
                        ),
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
                    padding: const EdgeInsets.only(top: 8),
                    itemCount: friends.length,
                    itemBuilder: (context, index) {
                      final friend = friends[index];
                      return Card(
                        margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                          side: BorderSide(
                            color: Theme.of(context).colorScheme.outlineVariant,
                            width: 0.5,
                          ),
                        ),
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 12),
                          child: Row(
                            children: [
                              ProfileAvatar(
                                nickname: friend.user.nickname,
                                imageUrl: friend.user.profileImageUrl,
                                radius: 24,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      friend.user.nickname,
                                      style: const TextStyle(
                                        fontWeight: FontWeight.w600,
                                        fontSize: 15,
                                      ),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '@${friend.user.username}',
                                      style: TextStyle(
                                        fontSize: 13,
                                        color: Theme.of(context)
                                            .colorScheme
                                            .outline,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              IconButton(
                                icon: const Icon(Icons.person_remove_outlined),
                                color: Theme.of(context).colorScheme.outline,
                                tooltip: '친구 삭제',
                                onPressed: () => _confirmDeleteFriend(
                                  friend.friendshipId,
                                  friend.user.nickname,
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }
}
