import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearbook_frontend/shared/models/friend.dart';
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
    Future.microtask(
      () => ref.read(friendProvider.notifier).refresh(),
    );
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
    final state = ref.watch(friendProvider);
    final friends = state.friends;
    final receivedRequests = state.receivedRequests;

    return Scaffold(
      appBar: AppBar(
        title: const Text('친구'),
        actions: [
          // 수동 새로고침 버튼
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: '새로고침',
            onPressed: state.isLoading
                ? null
                : () => ref.read(friendProvider.notifier).refresh(),
          ),
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
      // 당겨서 새로고침
      body: RefreshIndicator(
        onRefresh: () => ref.read(friendProvider.notifier).refresh(),
        child: state.isLoading && friends.isEmpty && receivedRequests.isEmpty
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // 받은 친구 요청 섹션
                  if (receivedRequests.isNotEmpty) ...[
                    SliverToBoxAdapter(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
                        child: Text(
                          '받은 친구 요청',
                          style: TextStyle(
                            fontWeight: FontWeight.bold,
                            color: Theme.of(context).colorScheme.primary,
                          ),
                        ),
                      ),
                    ),
                    SliverList(
                      delegate: SliverChildBuilderDelegate(
                        (context, index) {
                          final req = receivedRequests[index];
                          final requester =
                              req['requester'] as Map<String, dynamic>;
                          return _RequestCard(
                            requester: requester,
                            onAccept: () => ref
                                .read(friendProvider.notifier)
                                .acceptRequest(req['id'] as int),
                            onReject: () => ref
                                .read(friendProvider.notifier)
                                .rejectRequest(req['id'] as int),
                          );
                        },
                        childCount: receivedRequests.length,
                      ),
                    ),
                    const SliverToBoxAdapter(child: Divider()),
                  ],

                  // 친구 목록 섹션
                  if (friends.isEmpty)
                    const SliverFillRemaining(
                      child: Center(child: Text('친구가 없습니다.')),
                    )
                  else
                    SliverPadding(
                      padding: const EdgeInsets.only(top: 8),
                      sliver: SliverList(
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final friend = friends[index];
                            return _FriendCard(
                              friend: friend,
                              onDelete: () => _confirmDeleteFriend(
                                friend.friendshipId,
                                friend.user.nickname,
                              ),
                            );
                          },
                          childCount: friends.length,
                        ),
                      ),
                    ),
                ],
              ),
      ),
    );
  }
}

// ─── 받은 친구 요청 카드 ───────────────────────────────────────

class _RequestCard extends StatelessWidget {
  final Map<String, dynamic> requester;
  final VoidCallback onAccept;
  final VoidCallback onReject;

  const _RequestCard({
    required this.requester,
    required this.onAccept,
    required this.onReject,
  });

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextButton(
                  onPressed: onAccept,
                  child: const Text('수락'),
                ),
                TextButton(
                  onPressed: onReject,
                  child: const Text('거절'),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ─── 친구 카드 ────────────────────────────────────────────────

class _FriendCard extends StatelessWidget {
  final FriendModel friend;
  final VoidCallback onDelete;

  const _FriendCard({
    required this.friend,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
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
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
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
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              color: Theme.of(context).colorScheme.outline,
              tooltip: '친구 삭제',
              onPressed: onDelete,
            ),
          ],
        ),
      ),
    );
  }
}
