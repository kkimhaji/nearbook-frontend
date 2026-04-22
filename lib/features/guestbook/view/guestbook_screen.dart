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

                  if (_groupBy == 'date') {
                    // 날짜별 그룹: 날짜 헤더 + 각 항목에 작성자 표시
                    final date = group['date'] as String;
                    return _buildDateGroup(date, entries);
                  } else {
                    // 작성자별 그룹: 작성자 헤더 + 항목 목록
                    final writer = group['writer'] as Map<String, dynamic>;
                    return _buildWriterGroup(writer, entries);
                  }
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

  // 날짜별 그룹 위젯
  Widget _buildDateGroup(String date, List entries) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // 날짜 헤더
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
          child: Text(
            date,
            style: const TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.bold,
              color: Colors.grey,
            ),
          ),
        ),
        const Divider(height: 1),
        ...entries.map((e) {
          final entry = e as Map<String, dynamic>;
          final writer = entry['writer'] as Map<String, dynamic>;
          return _buildEntryTile(
            content: entry['content'] as String,
            createdAt: entry['createdAt'] as String,
            writerNickname: writer['nickname'] as String,
            writerUsername: writer['username'] as String,
          );
        }),
      ],
    );
  }

  // 작성자별 그룹 위젯
  Widget _buildWriterGroup(Map<String, dynamic> writer, List entries) {
    final nickname = writer['nickname'] as String;
    final username = writer['username'] as String;

    return ExpansionTile(
      // 작성자 헤더: 닉네임 + 아이디
      leading: CircleAvatar(
        child: Text(nickname[0]),
      ),
      title: Text(
        nickname,
        style: const TextStyle(fontWeight: FontWeight.bold),
      ),
      subtitle: Text(
        '@$username',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      trailing: Text(
        '${entries.length}개',
        style: const TextStyle(color: Colors.grey, fontSize: 12),
      ),
      children: entries.map((e) {
        final entry = e as Map<String, dynamic>;
        return _buildEntryTile(
          content: entry['content'] as String,
          createdAt: entry['createdAt'] as String,
          showWriter: false, // 작성자별 그룹에서는 작성자 중복 표시 불필요
        );
      }).toList(),
    );
  }

  // 개별 방명록 항목
  Widget _buildEntryTile({
    required String content,
    required String createdAt,
    String? writerNickname,
    String? writerUsername,
    bool showWriter = true,
  }) {
    // ISO 날짜 → 읽기 좋은 형식으로 변환
    final dateTime = DateTime.tryParse(createdAt);
    final formattedTime = dateTime != null
        ? '${dateTime.hour.toString().padLeft(2, '0')}:'
            '${dateTime.minute.toString().padLeft(2, '0')}'
        : createdAt;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: const BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Color(0xFFEEEEEE)),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // 작성자 정보 (날짜별 그룹에서만 표시)
          if (showWriter && writerNickname != null && writerUsername != null)
            Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 12,
                    child: Text(
                      writerNickname[0],
                      style: const TextStyle(fontSize: 11),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    writerNickname,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '@$writerUsername',
                    style: const TextStyle(
                      color: Colors.grey,
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
            ),

          // 방명록 내용
          Text(
            content,
            style: const TextStyle(fontSize: 15),
          ),

          // 작성 시간
          const SizedBox(height: 4),
          Text(
            formattedTime,
            style: const TextStyle(
              color: Colors.grey,
              fontSize: 11,
            ),
          ),
        ],
      ),
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
