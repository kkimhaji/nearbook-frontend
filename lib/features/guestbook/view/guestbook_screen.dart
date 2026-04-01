import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearbook_frontend/features/guestbook/view/write_screen.dart';
import '../provider/guestbook_provider.dart';

class GuestbookScreen extends ConsumerStatefulWidget {
  const GuestbookScreen({super.key});

  @override
  ConsumerState<GuestbookScreen> createState() => _GuestbookScreenState();
}

class _GuestbookScreenState extends ConsumerState<GuestbookScreen> {
  String _groupBy = 'date';

  @override
  Widget build(BuildContext context) {
    final guestbookState = ref.watch(guestbookProvider);
    final myGuestbook = ref.watch(myGuestbookProvider(_groupBy));

    return Scaffold(
      appBar: AppBar(
        title: const Text('내 방명록'),
        actions: [
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(value: 'date', label: Text('날짜')),
              ButtonSegment(value: 'writer', label: Text('작성자')),
            ],
            selected: {_groupBy},
            onSelectionChanged: (value) =>
                setState(() => _groupBy = value.first),
          ),
        ],
      ),
      body: Stack(
        children: [
          myGuestbook.when(
            data: (groups) {
              if (groups.isEmpty) {
                return const Center(child: Text('아직 방명록이 없습니다.'));
              }
              return ListView.builder(
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index] as Map<String, dynamic>;
                  final entries = group['entries'] as List;
                  final groupTitle = _groupBy == 'date'
                      ? group['date'] as String
                      : (group['writer'] as Map<String, dynamic>)['nickname']
                          as String;

                  return ExpansionTile(
                    title: Text(groupTitle),
                    children: entries.map((e) {
                      final entry = e as Map<String, dynamic>;
                      return ListTile(
                        title: Text(entry['content'] as String),
                        subtitle: Text(entry['createdAt'] as String),
                      );
                    }).toList(),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          ),

          // 타이핑 인디케이터
          if (guestbookState.isTyping)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black87,
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Text(
                    '${guestbookState.typingNickname}님이 작성 중...',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),

      // 방명록 요청 알림
      bottomSheet: guestbookState.requestId != null
          ? _buildRequestBanner(context, guestbookState)
          : null,
    );
  }

  Widget _buildRequestBanner(
    BuildContext context,
    GuestbookRequestState state,
  ) {
    final ownerNickname = state.owner?['nickname'] as String? ?? '알 수 없음';

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Expanded(
            child: Text('$ownerNickname님이 방명록을 요청했습니다.'),
          ),
          TextButton(
            onPressed: () {
              if (state.requestId == null) return;
              ref
                  .read(guestbookProvider.notifier)
                  .rejectRequest(state.requestId!);
            },
            child: const Text('거절'),
          ),
          TextButton(
            onPressed: () {
              if (state.requestId == null) return;
              _navigateToWrite(state);
            },
            child: const Text('작성'),
          ),
        ],
      ),
    );
  }

  void _navigateToWrite(GuestbookRequestState state) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => WriteScreen(
          requestId: state.requestId!,
          owner: state.owner!,
        ),
      ),
    );
  }
}
