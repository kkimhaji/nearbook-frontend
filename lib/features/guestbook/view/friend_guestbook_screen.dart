import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/guestbook_repository.dart';
import '../../../core/network/dio_exception_handler.dart';
import '../../../shared/widgets/profile_avatar.dart';

final friendGuestbookProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, username) {
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
            itemCount: entries.length,
            itemBuilder: (context, index) {
              final entry = entries[index] as Map<String, dynamic>;
              final writer = entry['writer'] as Map<String, dynamic>;

              return ListTile(
                leading: ProfileAvatar(
                  nickname: writer['nickname'] as String,
                  imageUrl: writer['profileImageUrl'] as String?,
                  radius: 20,
                ),
                title: Text(entry['content'] as String),
                subtitle: Text(
                  '${writer['nickname']} · ${entry['createdAt']}',
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
