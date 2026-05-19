import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/guestbook_repository.dart';
import '../../../core/network/dio_exception_handler.dart';
import '../../../shared/widgets/profile_avatar.dart';

final friendGuestbookProvider = FutureProvider.autoDispose
    .family<Map<String, dynamic>, String>((ref, username) {
  return GuestbookRepository().getFriendGuestbook(username);
});

class FriendGuestbookScreen extends ConsumerWidget {
  final String username;
  final String nickname;

  const FriendGuestbookScreen({
    super.key,
    required this.username,
    required this.nickname,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncData = ref.watch(friendGuestbookProvider(username));

    return Scaffold(
      appBar: AppBar(title: Text('$nickname님의 방명록')),
      body: asyncData.when(
        data: (data) {
          final entries = data['entries'] as List;

          if (entries.isEmpty) {
            return const Center(child: Text('공개된 방명록이 없습니다.'));
          }

          return ListView.builder(
            padding: const EdgeInsets.symmetric(vertical: 8),
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index] as Map<String, dynamic>;
              final writer = entry['writer'] as Map<String, dynamic>;
              final createdAt = entry['createdAt'] as String;
              final dateStr = createdAt.length >= 10
                  ? createdAt.substring(0, 10)
                  : createdAt;

              return Card(
                margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
                elevation: 0,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                  side: BorderSide(
                    color: Theme.of(context).colorScheme.outlineVariant,
                    width: 0.5,
                  ),
                ),
                child: Padding(
                  padding: const EdgeInsets.all(14),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        entry['content'] as String,
                        style: const TextStyle(fontSize: 15, height: 1.5),
                      ),
                      const SizedBox(height: 10),
                      Row(
                        children: [
                          ProfileAvatar(
                            nickname: writer['nickname'] as String,
                            imageUrl: writer['profileImageUrl'] as String?,
                            radius: 10,
                          ),
                          const SizedBox(width: 5),
                          Text(
                            writer['nickname'] as String,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Icon(
                            Icons.schedule,
                            size: 13,
                            color: Theme.of(context).colorScheme.outline,
                          ),
                          const SizedBox(width: 3),
                          Text(
                            dateStr,
                            style: TextStyle(
                              fontSize: 12,
                              color: Theme.of(context).colorScheme.outline,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Text(DioExceptionHandler.getMessage(e)),
        ),
      ),
    );
  }
}
