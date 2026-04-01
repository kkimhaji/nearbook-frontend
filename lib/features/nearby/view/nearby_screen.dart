import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/nearby_provider.dart';
import '../../guestbook/data/guestbook_repository.dart';

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
        SnackBar(content: Text('오류: $e')),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final nearbyUsers = ref.watch(nearbyProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('주변'),
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: () => ref.read(nearbyProvider.notifier).startScan(),
          ),
        ],
      ),
      body: nearbyUsers.isEmpty
          ? const Center(child: Text('주변에 친구가 없습니다.'))
          : ListView.builder(
              itemCount: nearbyUsers.length,
              itemBuilder: (context, index) {
                final user = nearbyUsers[index];
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
