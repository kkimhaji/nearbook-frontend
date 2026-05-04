import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'notification_model.dart';
import 'notification_provider.dart';
import '../../features/friend/provider/friend_provider.dart';
import '../../features/guestbook/provider/guestbook_provider.dart';
import '../../features/guestbook/view/write_screen.dart';
import '../widgets/profile_avatar.dart';

class NotificationOverlay extends ConsumerWidget {
  const NotificationOverlay({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final notifications = ref.watch(notificationProvider);
    if (notifications.isEmpty) return const SizedBox.shrink();

    return Positioned(
      top: MediaQuery.of(context).padding.top + 8,
      left: 16,
      right: 16,
      child: Column(
        children: notifications.map((n) {
          return _NotificationBanner(
            key: ValueKey(n.id),
            notification: n,
          );
        }).toList(),
      ),
    );
  }
}

class _NotificationBanner extends ConsumerStatefulWidget {
  final AppNotification notification;

  const _NotificationBanner({
    super.key,
    required this.notification,
  });

  @override
  ConsumerState<_NotificationBanner> createState() =>
      _NotificationBannerState();
}

class _NotificationBannerState extends ConsumerState<_NotificationBanner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller;
  late final Animation<Offset> _slideAnimation;
  late final Animation<double> _fadeAnimation;

  // 자동 닫힘이 필요 없는 타입 (액션 버튼이 있는 알림)
  static const _persistentTypes = {
    NotificationType.friendRequestReceived,
    NotificationType.guestbookRequestReceived,
    NotificationType.guestbookTyping,
  };

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 300),
    );
    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, -1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOut));
    _fadeAnimation =
        CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    _controller.forward();

    // 자동 닫힘 (액션 없는 알림만)
    if (!_persistentTypes.contains(widget.notification.type)) {
      Future.delayed(const Duration(seconds: 4), () {
        if (mounted) _dismiss();
      });
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _dismiss() async {
    if (!mounted) return;
    await _controller.reverse();
    if (mounted) {
      ref.read(notificationProvider.notifier).dismiss(widget.notification.id);
    }
  }

  @override
  Widget build(BuildContext context) {
    return SlideTransition(
      position: _slideAnimation,
      child: FadeTransition(
        opacity: _fadeAnimation,
        child: Padding(
          padding: const EdgeInsets.only(bottom: 8),
          child: _buildCard(context),
        ),
      ),
    );
  }

  Widget _buildCard(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final n = widget.notification;

    switch (n.type) {
      case NotificationType.friendRequestReceived:
        return _buildFriendRequestCard(context, colorScheme, n);
      case NotificationType.friendRequestAccepted:
        return _buildSimpleCard(
          context,
          colorScheme,
          icon: Icons.people,
          color: Colors.green,
          message:
              '${(n.data['accepter'] as Map?)?['nickname'] ?? ''}님이 친구 요청을 수락했습니다.',
        );
      case NotificationType.guestbookRequestReceived:
        return _buildGuestbookRequestCard(context, colorScheme, n);
      case NotificationType.guestbookRequestRejected:
        return _buildSimpleCard(
          context,
          colorScheme,
          icon: Icons.close,
          color: Colors.orange,
          message: '방명록 요청이 거절되었습니다.',
        );
      case NotificationType.guestbookCompleted:
        final writer = n.data['writer'] as Map?;
        return _buildSimpleCard(
          context,
          colorScheme,
          icon: Icons.book,
          color: colorScheme.primary,
          message: '${writer?['nickname'] ?? ''}님이 방명록을 작성했습니다.',
        );
      case NotificationType.guestbookTyping:
        final writer = n.data['writer'] as Map?;
        return _buildTypingCard(context, colorScheme, writer);
    }
  }

  // 친구 요청 수신 카드
  Widget _buildFriendRequestCard(
    BuildContext context,
    ColorScheme colorScheme,
    AppNotification n,
  ) {
    final requester = n.data['requester'] as Map<String, dynamic>?;
    final nickname = requester?['nickname'] as String? ?? '';
    final friendshipId = n.data['friendshipId'] as int?;

    return _BannerCard(
      color: colorScheme.primaryContainer,
      child: Row(
        children: [
          ProfileAvatar(
            nickname: nickname,
            imageUrl: requester?['profileImageUrl'] as String?,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$nickname님이 친구 요청을 보냈습니다.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                label: '수락',
                onTap: () async {
                  if (friendshipId != null) {
                    await ref
                        .read(friendProvider.notifier)
                        .acceptRequest(friendshipId);
                  }
                  _dismiss();
                },
              ),
              _ActionButton(
                label: '거절',
                onTap: () async {
                  if (friendshipId != null) {
                    await ref
                        .read(friendProvider.notifier)
                        .rejectRequest(friendshipId);
                  }
                  _dismiss();
                },
              ),
            ],
          ),
          _CloseButton(onTap: _dismiss),
        ],
      ),
    );
  }

  // 방명록 요청 수신 카드
  Widget _buildGuestbookRequestCard(
    BuildContext context,
    ColorScheme colorScheme,
    AppNotification n,
  ) {
    final owner = n.data['owner'] as Map<String, dynamic>?;
    final nickname = owner?['nickname'] as String? ?? '';
    final requestId = n.data['requestId'] as int?;

    return _BannerCard(
      color: colorScheme.secondaryContainer,
      child: Row(
        children: [
          ProfileAvatar(
            nickname: nickname,
            imageUrl: owner?['profileImageUrl'] as String?,
            radius: 18,
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              '$nickname님이 방명록을 요청했습니다.',
              style: TextStyle(
                fontSize: 13,
                color: colorScheme.onSecondaryContainer,
              ),
            ),
          ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              _ActionButton(
                label: '작성',
                onTap: () async {
                  _dismiss();
                  if (requestId != null && owner != null) {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => WriteScreen(
                          requestId: requestId,
                          owner: Map<String, dynamic>.from(owner),
                        ),
                      ),
                    );
                  }
                },
              ),
              _ActionButton(
                label: '거절',
                onTap: () async {
                  if (requestId != null) {
                    await ref
                        .read(guestbookProvider.notifier)
                        .rejectRequest(requestId);
                  }
                  _dismiss();
                },
              ),
            ],
          ),
          _CloseButton(onTap: _dismiss),
        ],
      ),
    );
  }

  // 타이핑 인디케이터 카드
  Widget _buildTypingCard(
    BuildContext context,
    ColorScheme colorScheme,
    Map? writer,
  ) {
    final nickname = writer?['nickname'] as String? ?? '';
    return _BannerCard(
      color: Colors.black87,
      child: Row(
        children: [
          ProfileAvatar(
            nickname: nickname,
            imageUrl: writer?['profileImageUrl'] as String?,
            radius: 14,
          ),
          const SizedBox(width: 8),
          Text(
            '$nickname님이 방명록을 작성 중...',
            style: const TextStyle(color: Colors.white, fontSize: 13),
          ),
          const Spacer(),
          const SizedBox(
            width: 16,
            height: 16,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  // 단순 정보 카드 (자동 닫힘)
  Widget _buildSimpleCard(
    BuildContext context,
    ColorScheme colorScheme, {
    required IconData icon,
    required Color color,
    required String message,
  }) {
    return _BannerCard(
      color: colorScheme.surfaceVariant,
      child: Row(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(width: 10),
          Expanded(
            child: Text(message, style: const TextStyle(fontSize: 13)),
          ),
          _CloseButton(onTap: _dismiss),
        ],
      ),
    );
  }
}

// ─── 공통 컴포넌트 ─────────────────────────────────────────────

class _BannerCard extends StatelessWidget {
  final Color color;
  final Widget child;

  const _BannerCard({required this.color, required this.child});

  @override
  Widget build(BuildContext context) {
    return Material(
      elevation: 4,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          color: color,
          borderRadius: BorderRadius.circular(12),
        ),
        child: child,
      ),
    );
  }
}

class _ActionButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _ActionButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return TextButton(
      onPressed: onTap,
      style: TextButton.styleFrom(
        padding: const EdgeInsets.symmetric(horizontal: 8),
        minimumSize: const Size(0, 32),
        tapTargetSize: MaterialTapTargetSize.shrinkWrap,
      ),
      child: Text(label, style: const TextStyle(fontSize: 13)),
    );
  }
}

class _CloseButton extends StatelessWidget {
  final VoidCallback onTap;

  const _CloseButton({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: const Padding(
        padding: EdgeInsets.only(left: 4),
        child: Icon(Icons.close, size: 16),
      ),
    );
  }
}
