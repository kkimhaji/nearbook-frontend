import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nearbook_frontend/features/guestbook/view/write_screen.dart';
import '../provider/guestbook_provider.dart';

class GuestbookScreen extends ConsumerStatefulWidget {
  const GuestbookScreen({super.key});

  @override
  ConsumerState<GuestbookScreen> createState() => _GuestbookScreenState();
}

class _GuestbookScreenState extends ConsumerState<GuestbookScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  String _receivedGroupBy = 'date';
  String _writtenGroupBy = 'date';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final guestbookState = ref.watch(guestbookProvider);
    final receivedGuestbook = ref.watch(myGuestbookProvider(_receivedGroupBy));
    final writtenGuestbook =
        ref.watch(writtenGuestbookProvider(_writtenGroupBy));

    return Scaffold(
      appBar: AppBar(
        title: const Text('방명록'),
        bottom: TabBar(
          controller: _tabController,
          tabs: const [
            Tab(text: '받은 방명록'),
            Tab(text: '내가 쓴 방명록'),
          ],
        ),
      ),
      body: Stack(
        children: [
          TabBarView(
            controller: _tabController,
            children: [
              _ReceivedGuestbookTab(
                guestbook: receivedGuestbook,
                groupBy: _receivedGroupBy,
                onGroupByChanged: (v) => setState(() => _receivedGroupBy = v),
              ),
              _WrittenGuestbookTab(
                guestbook: writtenGuestbook,
                groupBy: _writtenGroupBy,
                onGroupByChanged: (v) => setState(() => _writtenGroupBy = v),
              ),
            ],
          ),
          if (guestbookState.isTyping)
            Positioned(
              bottom: 16,
              left: 0,
              right: 0,
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
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
      bottomSheet: guestbookState.requestId != null
          ? _RequestBanner(state: guestbookState)
          : null,
    );
  }
}

// 받은 방명록 탭

class _ReceivedGuestbookTab extends ConsumerWidget {
  final AsyncValue<List<dynamic>> guestbook;
  final String groupBy;
  final ValueChanged<String> onGroupByChanged;

  const _ReceivedGuestbookTab({
    required this.guestbook,
    required this.groupBy,
    required this.onGroupByChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _GroupBySelector(
          options: const {'date': '날짜', 'writer': '작성자'},
          selected: groupBy,
          onChanged: onGroupByChanged,
        ),
        Expanded(
          child: guestbook.when(
            data: (groups) {
              if (groups.isEmpty) {
                return const _EmptyState(message: '아직 받은 방명록이 없습니다.');
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index] as Map<String, dynamic>;
                  final entries = group['entries'] as List;
                  final groupTitle = group['date'] as String? ??
                      (group['writer'] as Map<String, dynamic>?)?['nickname']
                          as String? ??
                      '-';
                  final writerMap = group['writer'] as Map<String, dynamic>?;
                  final avatarLabel = groupBy == 'writer'
                      ? (writerMap?['nickname'] as String? ?? '?')
                      : groupTitle;

                  return _GroupSection(
                    title: groupTitle,
                    avatarLabel: groupBy == 'writer' ? avatarLabel : null,
                    entryCount: entries.length,
                    children: entries.map((e) {
                      final entry = e as Map<String, dynamic>;
                      final writer = entry['writer'] as Map<String, dynamic>?;
                      return _ReceivedEntryCard(
                        content: entry['content'] as String,
                        writerNickname: writer?['nickname'] as String?,
                        createdAt: entry['createdAt'] as String,
                        showWriter: groupBy == 'date',
                      );
                    }).toList(),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          ),
        ),
      ],
    );
  }
}

// 내가 쓴 방명록 탭

class _WrittenGuestbookTab extends ConsumerWidget {
  final AsyncValue<List<dynamic>> guestbook;
  final String groupBy;
  final ValueChanged<String> onGroupByChanged;

  const _WrittenGuestbookTab({
    required this.guestbook,
    required this.groupBy,
    required this.onGroupByChanged,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        _GroupBySelector(
          options: const {'date': '날짜', 'owner': '받은 사람'},
          selected: groupBy,
          onChanged: onGroupByChanged,
        ),
        Expanded(
          child: guestbook.when(
            data: (groups) {
              if (groups.isEmpty) {
                return const _EmptyState(message: '아직 쓴 방명록이 없습니다.');
              }
              return ListView.builder(
                padding: const EdgeInsets.only(bottom: 80),
                itemCount: groups.length,
                itemBuilder: (context, index) {
                  final group = groups[index] as Map<String, dynamic>;
                  final entries = group['entries'] as List;
                  final owner = group['owner'] as Map<String, dynamic>?;
                  final ownerNickname = owner?['nickname'] as String?;
                  final groupTitle = group['date'] as String? ??
                      owner?['nickname'] as String? ??
                      '-';

                  return _GroupSection(
                    title: groupTitle,
                    avatarLabel: groupBy == 'owner' ? ownerNickname : null,
                    entryCount: entries.length,
                    children: entries.map((e) {
                      final entry = e as Map<String, dynamic>;
                      final entryOwner =
                          (entry['owner'] as Map<String, dynamic>?) ?? owner;
                      return _WrittenEntryCard(
                        content: entry['content'] as String,
                        ownerNickname: entryOwner?['nickname'] as String?,
                        ownerUsername: entryOwner?['username'] as String?,
                        createdAt: entry['createdAt'] as String,
                        showOwner: groupBy == 'date',
                      );
                    }).toList(),
                  );
                },
              );
            },
            loading: () => const Center(child: CircularProgressIndicator()),
            error: (e, _) => Center(child: Text('오류: $e')),
          ),
        ),
      ],
    );
  }
}

// 공통 위젯

class _GroupBySelector extends StatelessWidget {
  final Map<String, String> options;
  final String selected;
  final ValueChanged<String> onChanged;

  const _GroupBySelector({
    required this.options,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          SegmentedButton<String>(
            segments: options.entries
                .map((e) => ButtonSegment(value: e.key, label: Text(e.value)))
                .toList(),
            selected: {selected},
            onSelectionChanged: (v) => onChanged(v.first),
          ),
        ],
      ),
    );
  }
}

class _GroupSection extends StatelessWidget {
  final String title;
  final String? avatarLabel;
  final int entryCount;
  final List<Widget> children;

  const _GroupSection({
    required this.title,
    required this.entryCount,
    required this.children,
    this.avatarLabel,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (avatarLabel != null) ...[
                CircleAvatar(
                  radius: 14,
                  backgroundColor: colorScheme.primaryContainer,
                  child: Text(
                    avatarLabel![0],
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
              ],
              Text(
                title,
                style: Theme.of(context).textTheme.titleSmall?.copyWith(
                      fontWeight: FontWeight.w600,
                    ),
              ),
              const SizedBox(width: 6),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 1),
                decoration: BoxDecoration(
                  color: colorScheme.secondaryContainer,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text(
                  '$entryCount',
                  style: TextStyle(
                    fontSize: 11,
                    color: colorScheme.onSecondaryContainer,
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          ...children,
          const SizedBox(height: 4),
        ],
      ),
    );
  }
}

// 받은 방명록 카드
class _ReceivedEntryCard extends StatelessWidget {
  final String content;
  final String? writerNickname;
  final String createdAt;
  final bool showWriter;

  const _ReceivedEntryCard({
    required this.content,
    required this.createdAt,
    this.writerNickname,
    this.showWriter = false,
  });

  @override
  Widget build(BuildContext context) {
    final dateStr =
        createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
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
              content,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                if (showWriter && writerNickname != null) ...[
                  Icon(
                    Icons.person_outline,
                    size: 13,
                    color: Theme.of(context).colorScheme.outline,
                  ),
                  const SizedBox(width: 3),
                  Text(
                    writerNickname!,
                    style: TextStyle(
                      fontSize: 12,
                      color: Theme.of(context).colorScheme.outline,
                    ),
                  ),
                  const SizedBox(width: 8),
                ],
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
  }
}

// 내가 쓴 방명록 카드
class _WrittenEntryCard extends StatelessWidget {
  final String content;
  final String? ownerNickname;
  final String? ownerUsername;
  final String createdAt;
  final bool showOwner;

  const _WrittenEntryCard({
    required this.content,
    required this.createdAt,
    this.ownerNickname,
    this.ownerUsername,
    this.showOwner = false,
  });

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final dateStr =
        createdAt.length >= 10 ? createdAt.substring(0, 10) : createdAt;

    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
          color: colorScheme.outlineVariant,
          width: 0.5,
        ),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // 항상 수신자 표시 (그룹 기준에 무관하게)
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: colorScheme.primaryContainer,
                borderRadius: BorderRadius.circular(6),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    Icons.send_outlined,
                    size: 12,
                    color: colorScheme.onPrimaryContainer,
                  ),
                  const SizedBox(width: 4),
                  Text(
                    ownerNickname != null
                        ? '$ownerNickname${ownerUsername != null ? ' (@$ownerUsername)' : ''}'
                        : '-',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                      color: colorScheme.onPrimaryContainer,
                    ),
                  ),
                ],
              ),
            ),
            Text(
              content,
              style: const TextStyle(fontSize: 15, height: 1.5),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(Icons.schedule, size: 13, color: colorScheme.outline),
                const SizedBox(width: 3),
                Text(
                  dateStr,
                  style: TextStyle(fontSize: 12, color: colorScheme.outline),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;
  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.book_outlined, size: 48, color: Colors.grey.shade400),
          const SizedBox(height: 12),
          Text(message, style: const TextStyle(color: Colors.grey)),
        ],
      ),
    );
  }
}

class _RequestBanner extends ConsumerWidget {
  final GuestbookRequestState state;
  const _RequestBanner({required this.state});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final ownerNickname = state.owner?['nickname'] as String? ?? '알 수 없음';

    return Container(
      padding: const EdgeInsets.all(16),
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Row(
        children: [
          Expanded(child: Text('$ownerNickname님이 방명록을 요청했습니다.')),
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
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) => WriteScreen(
                    requestId: state.requestId!,
                    owner: state.owner!,
                  ),
                ),
              );
            },
            child: const Text('작성'),
          ),
        ],
      ),
    );
  }
}
