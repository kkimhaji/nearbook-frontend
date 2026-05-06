import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/nearby_provider.dart';
import '../../guestbook/data/guestbook_repository.dart';
import '../../friend/data/friend_repository.dart'; // 추가
import '../../../core/network/dio_exception_handler.dart';
import '../../../shared/socket/socket_client.dart';
import '../../../shared/socket/socket_events.dart';
import '../../../shared/models/user.dart';
import '../../../shared/widgets/profile_avatar.dart';

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  bool _isActive = true;
  late NearbyNotifier _notifier;

  @override
  void initState() {
    super.initState();
    _isActive = true;
    _notifier = ref.read(nearbyProvider.notifier);
    debugPrint('[NearbyScreen] initState 호출');
    _init();
  }

  @override
  void dispose() {
    _isActive = false;
    SocketClient.instance?.off(SocketEvents.bleDetectedResult);
    _notifier.stopScan();
    super.dispose();
  }

  Future<void> _init() async {
    debugPrint('[NearbyScreen] _init 시작');

    int retryCount = 0;
    while (!SocketClient.isConnected && retryCount < 10) {
      if (!_isActive) return;
      debugPrint('[NearbyScreen] 소켓 연결 대기 중... ($retryCount)');
      await Future.delayed(const Duration(milliseconds: 500));
      retryCount++;
    }

    if (!_isActive) return;

    debugPrint('[NearbyScreen] 소켓 연결 상태: ${SocketClient.isConnected}');
    _registerSocketListener();

    await _notifier.initBleToken();

    if (!_isActive) return;
    await _notifier.startScan();
  }

  void _registerSocketListener() {
    debugPrint('[NearbyScreen] 소켓 리스너 등록 시도');

    if (SocketClient.instance == null) {
      debugPrint('[NearbyScreen] 소켓 인스턴스가 null ❌ → 1초 후 재시도');
      Future.delayed(const Duration(seconds: 1), () {
        if (_isActive) _registerSocketListener();
      });
      return;
    }

    SocketClient.instance?.off(SocketEvents.bleDetectedResult);
    SocketClient.instance?.on(SocketEvents.bleDetectedResult, (data) {
      debugPrint('[NearbyScreen][Socket] ble:detected:result 수신 ✅: $data');

      if (!_isActive || !mounted) return;

      try {
        final users = (data['detectedUsers'] as List)
            .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
            .toList();
        debugPrint(
            '[NearbyScreen][Socket] 감지된 유저: ${users.map((u) => u.username).toList()}');
        _notifier.updateNearbyUsers(users);
      } catch (e) {
        debugPrint('[NearbyScreen][Socket] 파싱 오류: $e');
      }
    });

    debugPrint('[NearbyScreen] 소켓 리스너 등록 완료');
  }

  Future<void> _requestGuestbook(String writerUsername) async {
    try {
      await GuestbookRepository().requestGuestbook(writerUsername);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('방명록 요청을 보냈습니다.')),
      );
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(DioExceptionHandler.getMessage(e))),
      );
    }
  }

  // 추가
  Future<void> _sendFriendRequest(String receiverUsername) async {
    try {
      await FriendRepository().sendRequest(receiverUsername);
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
    final state = ref.watch(nearbyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('주변'),
        actions: [
          IconButton(
            icon: state.isScanning
                ? const Icon(Icons.stop_circle_outlined)
                : const Icon(Icons.refresh),
            tooltip: state.isScanning ? '스캔 중지' : '스캔 시작',
            onPressed: () {
              if (state.isScanning) {
                _notifier.stopScan();
              } else {
                _notifier.startScan();
              }
            },
          ),
        ],
      ),
      body: state.nearbyUsers.isEmpty
          ? Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.radar, size: 64, color: Colors.grey),
                  const SizedBox(height: 16),
                  Text(
                    state.isScanning ? '주변을 탐색 중...' : '주변에 친구가 없습니다.',
                    style: const TextStyle(color: Colors.grey),
                  ),
                  if (!state.isScanning) ...[
                    const SizedBox(height: 12),
                    TextButton.icon(
                      onPressed: () => _notifier.startScan(),
                      icon: const Icon(Icons.refresh),
                      label: const Text('다시 탐색'),
                    ),
                  ],
                ],
              ),
            )
          : ListView.builder(
              padding: const EdgeInsets.symmetric(vertical: 8),
              itemCount: state.nearbyUsers.length,
              itemBuilder: (context, index) {
                final user = state.nearbyUsers[index];
                return _NearbyUserCard(
                  user: user,
                  onGuestbookRequest: () => _requestGuestbook(user.username),
                  onFriendRequest: () => _sendFriendRequest(user.username),
                );
              },
            ),
    );
  }
}

class _NearbyUserCard extends StatelessWidget {
  final UserModel user;
  final VoidCallback onGuestbookRequest;
  final VoidCallback onFriendRequest;

  const _NearbyUserCard({
    required this.user,
    required this.onGuestbookRequest,
    required this.onFriendRequest,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                ProfileAvatar(
                  nickname: user.nickname,
                  imageUrl: user.profileImageUrl,
                  radius: 24,
                ),
                const SizedBox(width: 12),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      user.nickname,
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    Text(
                      '@${user.username}',
                      style: theme.textTheme.bodySmall?.copyWith(
                        color: theme.colorScheme.outline,
                      ),
                    ),
                  ],
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: user.isFriend
                  ? [
                      ElevatedButton(
                        onPressed: onGuestbookRequest,
                        child: const Text('방명록 요청'),
                      ),
                    ]
                  : [
                      OutlinedButton(
                        onPressed: onFriendRequest,
                        child: const Text('친구 신청'),
                      ),
                      const SizedBox(width: 8),
                      ElevatedButton(
                        onPressed: onGuestbookRequest,
                        child: const Text('방명록 요청'),
                      ),
                    ],
            ),
          ],
        ),
      ),
    );
  }
}
