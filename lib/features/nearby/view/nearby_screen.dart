import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/nearby_provider.dart';
import '../../guestbook/data/guestbook_repository.dart';
import '../../../core/network/dio_exception_handler.dart';

class NearbyScreen extends ConsumerStatefulWidget {
  const NearbyScreen({super.key});

  @override
  ConsumerState<NearbyScreen> createState() => _NearbyScreenState();
}

class _NearbyScreenState extends ConsumerState<NearbyScreen> {
  @override
  void initState() {
    super.initState();
    final notifier = ref.read(nearbyProvider.notifier);
    notifier.initBleToken();
    notifier.listenBleResult();
    notifier.startScan();
  }

  @override
  void dispose() {
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
          // 스캔 상태 표시
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
