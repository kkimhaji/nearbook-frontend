import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/nearby_provider.dart';
import '../../guestbook/data/guestbook_repository.dart';
import '../../../core/network/dio_exception_handler.dart';
import '../../../shared/socket/socket_client.dart';
import '../../../shared/socket/socket_events.dart';
import '../../../shared/models/user.dart';

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  @override
  void initState() {
    super.initState();
    debugPrint('[NearbyScreen] initState 호출');
    _init();
  }

  Future<void> _init() async {
    debugPrint('[NearbyScreen] _init 시작');

    // 소켓 연결 완료 대기 (최대 5초)
    int retryCount = 0;
    while (!SocketClient.isConnected && retryCount < 10) {
      debugPrint('[NearbyScreen] 소켓 연결 대기 중... ($retryCount)');
      await Future.delayed(const Duration(milliseconds: 500));
      retryCount++;
    }

    debugPrint('[NearbyScreen] 소켓 연결 상태: ${SocketClient.isConnected}');

    // 리스너 등록
    _registerSocketListener();

    // BLE 초기화 및 스캔
    final notifier = ref.read(nearbyProvider.notifier);
    await notifier.initBleToken();
    debugPrint('[NearbyScreen] initBleToken 완료');
    await notifier.startScan();
  }

  void _registerSocketListener() {
    debugPrint('[NearbyScreen] 소켓 리스너 등록 시도');
    debugPrint('[NearbyScreen] 소켓 연결 상태: ${SocketClient.isConnected}');
    debugPrint('[NearbyScreen] 소켓 인스턴스: ${SocketClient.instance}');

    if (SocketClient.instance == null) {
      debugPrint('[NearbyScreen] 소켓 인스턴스가 null ❌ → 1초 후 재시도');
      Future.delayed(const Duration(seconds: 1), _registerSocketListener);
      return;
    }

    SocketClient.instance?.off(SocketEvents.bleDetectedResult);
    SocketClient.instance?.on(SocketEvents.bleDetectedResult, (data) {
      debugPrint('[NearbyScreen][Socket] ble:detected:result 수신 ✅: $data');
      if (!mounted) return;
      try {
        final users = (data['detectedUsers'] as List)
            .map((u) => UserModel.fromJson(u as Map<String, dynamic>))
            .toList();
        debugPrint(
            '[NearbyScreen][Socket] 감지된 유저: ${users.map((u) => u.username).toList()}');
        ref.read(nearbyProvider.notifier).updateNearbyUsers(users);
      } catch (e) {
        debugPrint('[NearbyScreen][Socket] 파싱 오류: $e');
      }
    });

    // 등록 확인용: 테스트 이벤트 수신 여부
    SocketClient.instance?.on('connect', (_) {
      debugPrint('[NearbyScreen][Socket] 소켓 connect 이벤트 수신');
    });

    debugPrint('[NearbyScreen] 소켓 리스너 등록 완료');
  }

  @override
  void dispose() {
    SocketClient.instance?.off(SocketEvents.bleDetectedResult);
    ref.read(nearbyProvider.notifier).stopScan();
    super.dispose();
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

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(nearbyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('주변'),
        actions: [
          if (state.isScanning)
            const Padding(
              padding: EdgeInsets.symmetric(horizontal: 16.0),
              child: Center(
                child: SizedBox(
                  width: 20,
                  height: 20,
                  child: CircularProgressIndicator(strokeWidth: 2),
                ),
              ),
            )
          else
            IconButton(
              icon: const Icon(Icons.refresh),
              onPressed: () => ref.read(nearbyProvider.notifier).startScan(),
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
                ],
              ),
            )
          : ListView.builder(
              itemCount: state.nearbyUsers.length,
              itemBuilder: (context, index) {
                final user = state.nearbyUsers[index];
                return ListTile(
                  leading: CircleAvatar(
                    child: Text(user.nickname[0]),
                  ),
                  title: Text(user.nickname),
                  subtitle: Text('@${user.username}'),
                  trailing: ElevatedButton(
                    onPressed: () => _requestGuestbook(user.username),
                    child: const Text('방명록 요청'),
                  ),
                );
              },
            ),
    );
  }
}
