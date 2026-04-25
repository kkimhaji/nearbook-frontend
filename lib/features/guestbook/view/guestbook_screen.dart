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

  // 날짜 포맷 헬퍼
  String _formatDate(DateTime dt) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final target = DateTime(dt.year, dt.month, dt.day);
    final diff = today.difference(target).inDays;

    if (diff == 0) return '오늘';
    if (diff == 1) return '어제';
    return '${dt.year}.${dt.month.toString().padLeft(2, '0')}.${dt.day.toString().padLeft(2, '0')}';
  }

  String _formatDateTime(DateTime dt) {
    final date = _formatDate(dt);
    final time =
        '${dt.hour.toString().padLeft(2, '0')}:${dt.minute.toString().padLeft(2, '0')}';
    return '$date $time';
  }

  @override
  Widget build(BuildContext context) {
    final guestbookState = ref.watch(guestbookProvider);
    final myGuestbook = ref.watch(myGuestbookProvider(_groupBy));
    final colorScheme = Theme.of(context).colorScheme;

    ref.listen(guestbookProvider, (previous, next) {
      if (next.shouldRefresh && !(previous?.shouldRefresh ?? false)) {
        ref.invalidate(myGuestbookProvider(_groupBy));
        ref.read(guestbookProvider.notifier).clearRefreshSignal();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Row(
              children: [
                Icon(Icons.auto_awesome, color: Colors.white, size: 18),
                SizedBox(width: 8),
                Text('새 방명록이 도착했습니다!'),
              ],
            ),
            backgroundColor: colorScheme.primary,
            behavior: SnackBarBehavior.floating,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: const Color(0xFFF5F5F7),
      appBar: AppBar(
        backgroundColor: Colors.white,
        elevation: 0,
        title: const Text(
          '내 방명록',
          style: TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 18,
            color: Color(0xFF1A1A1A),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: SegmentedButton<String>(
              style: SegmentedButton.styleFrom(
                backgroundColor: const Color(0xFFF0F0F0),
                selectedBackgroundColor: colorScheme.primary,
                selectedForegroundColor: Colors.white,
                foregroundColor: const Color(0xFF666666),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
                padding: const EdgeInsets.symmetric(horizontal: 12),
                textStyle: const TextStyle(fontSize: 12),
              ),
              segments: const [
                ButtonSegment(
                  value: 'date',
                  icon: Icon(Icons.calendar_today, size: 14),
                  label: Text('날짜'),
                ),
                ButtonSegment(
                  value: 'writer',
                  icon: Icon(Icons.person, size: 14),
                  label: Text('작성자'),
                ),
              ],
              selected: {_groupBy},
              onSelectionChanged: (value) =>
                  setState(() => _groupBy = value.first),
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          myGuestbook.when(
            data: (groups) {
              if (groups.isEmpty) {
                return RefreshIndicator(
                  onRefresh: () async {
                    ref.invalidate(myGuestbookProvider(_groupBy));
                    await ref.read(myGuestbookProvider(_groupBy).future);
                  },
                  child: ListView(
                    physics: const AlwaysScrollableScrollPhysics(),
                    children: [
                      SizedBox(
                        height: MediaQuery.of(context).size.height * 0.5,
                        child: const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.book_outlined,
                              size: 64,
                              color: Color(0xFFCCCCCC),
                            ),
                            SizedBox(height: 16),
                            Text(
                              '아직 방명록이 없습니다',
                              style: TextStyle(
                                color: Color(0xFF999999),
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            SizedBox(height: 8),
                            Text(
                              '주변 탭에서 친구에게 방명록을 요청해보세요',
                              style: TextStyle(
                                color: Color(0xFFBBBBBB),
                                fontSize: 13,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                );
              }

              return RefreshIndicator(
                onRefresh: () async {
                  ref.invalidate(myGuestbookProvider(_groupBy));
                  await ref.read(myGuestbookProvider(_groupBy).future);
                },
                child: ListView.builder(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding:
                      const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
                  itemCount: groups.length,
                  itemBuilder: (context, index) {
                    final group = groups[index] as Map<String, dynamic>;
                    final entries = group['entries'] as List;

                    if (_groupBy == 'date') {
                      return _buildDateGroup(group['date'] as String, entries);
                    } else {
                      return _buildWriterGroup(
                        group['writer'] as Map<String, dynamic>,
                        entries,
                      );
                    }
                  },
                ),
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => RefreshIndicator(
              onRefresh: () async {
                ref.invalidate(myGuestbookProvider(_groupBy));
              },
              child: ListView(
                physics: const AlwaysScrollableScrollPhysics(),
                children: const [
                  SizedBox(height: 200),
                  Center(
                    child: Text(
                      '오류가 발생했습니다.\n당겨서 새로고침하세요.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Color(0xFF999999)),
                    ),
                  ),
                ],
              ),
            ),
          ),

          // 타이핑 인디케이터
          if (guestbookState.isTyping)
            Positioned(
              bottom: 16,
              left: 16,
              right: 16,
              child: Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                decoration: BoxDecoration(
                  color: const Color(0xFF1A1A1A),
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withOpacity(0.2),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const _TypingDots(),
                    const SizedBox(width: 10),
                    Text(
                      '${guestbookState.typingNickname}님이 작성 중...',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
      bottomSheet: guestbookState.requestId != null
          ? _buildRequestBanner(context, guestbookState)
          : null,
    );
  }

  // 날짜별 그룹
  Widget _buildDateGroup(String date, List entries) {
    final dateTime = DateTime.tryParse('${date}T00:00:00');
    final displayDate = dateTime != null ? _formatDate(dateTime) : date;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(top: 8, bottom: 8, left: 4),
          child: Row(
            children: [
              Container(
                width: 3,
                height: 14,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.primary,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              const SizedBox(width: 8),
              Text(
                displayDate,
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: Color(0xFF444444),
                  letterSpacing: 0.3,
                ),
              ),
              const SizedBox(width: 6),
              Text(
                '${entries.length}개',
                style: const TextStyle(
                  fontSize: 12,
                  color: Color(0xFFAAAAAA),
                ),
              ),
            ],
          ),
        ),
        ...entries.map((e) {
          final entry = e as Map<String, dynamic>;
          final writer = entry['writer'] as Map<String, dynamic>;
          return _buildEntryCard(
            content: entry['content'] as String,
            createdAt: entry['createdAt'] as String,
            writerNickname: writer['nickname'] as String,
            writerUsername: writer['username'] as String,
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }

  // 작성자별 그룹
  Widget _buildWriterGroup(Map<String, dynamic> writer, List entries) {
    final nickname = writer['nickname'] as String;
    final username = writer['username'] as String;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.05),
            blurRadius: 10,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Theme(
        data: Theme.of(context).copyWith(
          dividerColor: Colors.transparent,
        ),
        child: ExpansionTile(
          leading: CircleAvatar(
            radius: 20,
            backgroundColor: Theme.of(context).colorScheme.primaryContainer,
            child: Text(
              nickname[0].toUpperCase(),
              style: TextStyle(
                fontWeight: FontWeight.w700,
                color: Theme.of(context).colorScheme.primary,
              ),
            ),
          ),
          title: Text(
            nickname,
            style: const TextStyle(
              fontWeight: FontWeight.w700,
              fontSize: 15,
              color: Color(0xFF1A1A1A),
            ),
          ),
          subtitle: Text(
            '@$username',
            style: const TextStyle(
              color: Color(0xFF999999),
              fontSize: 12,
            ),
          ),
          trailing: Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
            decoration: BoxDecoration(
              color: const Color(0xFFF0F0F0),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              '${entries.length}개',
              style: const TextStyle(
                fontSize: 12,
                color: Color(0xFF666666),
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          children: entries.map((e) {
            final entry = e as Map<String, dynamic>;
            return _buildEntryCard(
              content: entry['content'] as String,
              createdAt: entry['createdAt'] as String,
              showWriter: false,
              isInExpansion: true,
            );
          }).toList(),
        ),
      ),
    );
  }

  // 방명록 카드
  Widget _buildEntryCard({
    required String content,
    required String createdAt,
    String? writerNickname,
    String? writerUsername,
    bool showWriter = true,
    bool isInExpansion = false,
  }) {
    final dateTime = DateTime.tryParse(createdAt);

    // 날짜 + 시간 모두 표시
    final formattedDateTime =
        dateTime != null ? _formatDateTime(dateTime) : createdAt;

    return Container(
      margin: isInExpansion
          ? const EdgeInsets.symmetric(horizontal: 12, vertical: 4)
          : const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        boxShadow: isInExpansion
            ? []
            : [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 10,
                  offset: const Offset(0, 2),
                ),
              ],
      ),
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 작성자 정보 (날짜별 그룹에서만)
            if (showWriter &&
                writerNickname != null &&
                writerUsername != null) ...[
              Row(
                children: [
                  CircleAvatar(
                    radius: 14,
                    backgroundColor:
                        Theme.of(context).colorScheme.primaryContainer,
                    child: Text(
                      writerNickname[0].toUpperCase(),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        color: Theme.of(context).colorScheme.primary,
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Text(
                    writerNickname,
                    style: const TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    '@$writerUsername',
                    style: const TextStyle(
                      color: Color(0xFF999999),
                      fontSize: 12,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              const Divider(height: 1, color: Color(0xFFF0F0F0)),
              const SizedBox(height: 10),
            ],

            // 방명록 내용
            Text(
              content,
              style: const TextStyle(
                fontSize: 15,
                color: Color(0xFF2A2A2A),
                height: 1.6,
              ),
            ),

            const SizedBox(height: 10),

            // 날짜 + 시간 (수정된 부분)
            Row(
              mainAxisAlignment: MainAxisAlignment.end,
              children: [
                Icon(
                  Icons.access_time,
                  size: 12,
                  color: Colors.grey[400],
                ),
                const SizedBox(width: 4),
                Text(
                  formattedDateTime, // 날짜 + 시간 모두 표시
                  style: TextStyle(
                    color: Colors.grey[400],
                    fontSize: 11,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildRequestBanner(
    BuildContext context,
    GuestbookRequestState state,
  ) {
    final ownerNickname = state.owner?['nickname'] as String? ?? '알 수 없음';
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            CircleAvatar(
              radius: 18,
              backgroundColor: colorScheme.primaryContainer,
              child: Text(
                ownerNickname[0].toUpperCase(),
                style: TextStyle(
                  color: colorScheme.primary,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '$ownerNickname님의 방명록 요청',
                    style: const TextStyle(
                      fontWeight: FontWeight.w700,
                      fontSize: 14,
                      color: Color(0xFF1A1A1A),
                    ),
                  ),
                  const Text(
                    '지금 방명록을 작성해보세요',
                    style: TextStyle(
                      fontSize: 12,
                      color: Color(0xFF999999),
                    ),
                  ),
                ],
              ),
            ),
            TextButton(
              style: TextButton.styleFrom(
                foregroundColor: Colors.red[400],
                padding: const EdgeInsets.symmetric(horizontal: 8),
              ),
              onPressed: () {
                if (state.requestId == null) return;
                ref
                    .read(guestbookProvider.notifier)
                    .rejectRequest(state.requestId!);
              },
              child: const Text('거절'),
            ),
            const SizedBox(width: 4),
            FilledButton(
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(horizontal: 16),
              ),
              onPressed: () {
                if (state.requestId == null) return;
                _navigateToWrite(state);
              },
              child: const Text('작성'),
            ),
          ],
        ),
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

// 타이핑 인디케이터 점 애니메이션
class _TypingDots extends StatefulWidget {
  const _TypingDots();

  @override
  State<_TypingDots> createState() => _TypingDotsState();
}

class _TypingDotsState extends State<_TypingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (_, __) {
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: List.generate(3, (i) {
            final delay = i * 0.3;
            final value = (_controller.value - delay).clamp(0.0, 1.0);
            final opacity = (value < 0.5) ? value * 2 : (1.0 - value) * 2;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color: Colors.white.withOpacity(0.3 + opacity * 0.7),
                shape: BoxShape.circle,
              ),
            );
          }),
        );
      },
    );
  }
}
