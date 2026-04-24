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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final guestbookState = ref.watch(guestbookProvider);
    final myGuestbook = ref.watch(myGuestbookProvider(_groupBy));

    ref.listen(guestbookProvider, (previous, next) {
      if (next.shouldRefresh && !(previous?.shouldRefresh ?? false)) {
        ref.invalidate(myGuestbookProvider(_groupBy));
        ref.read(guestbookProvider.notifier).clearRefreshSignal();

        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            behavior: SnackBarBehavior.floating,
            content: const Text('새 방명록이 도착했습니다! 🎉'),
            duration: const Duration(seconds: 2),
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
            ),
          ),
        );
      }
    });

    return Scaffold(
      backgroundColor: colorScheme.surface,
      appBar: AppBar(
        title: const Text('내 방명록'),
        centerTitle: false,
        elevation: 0,
      ),
      body: Stack(
        children: [
          Column(
            children: [
              _buildTopSection(context),
              Expanded(
                child: myGuestbook.when(
                  data: (groups) {
                    if (groups.isEmpty) {
                      return RefreshIndicator(
                        onRefresh: () async {
                          ref.invalidate(myGuestbookProvider(_groupBy));
                          await ref.read(myGuestbookProvider(_groupBy).future);
                        },
                        child: ListView(
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                          children: [
                            const SizedBox(height: 60),
                            _buildEmptyState(context),
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
                        padding: const EdgeInsets.fromLTRB(16, 8, 16, 120),
                        itemCount: groups.length,
                        itemBuilder: (context, index) {
                          final group = groups[index] as Map<String, dynamic>;
                          final entries = group['entries'] as List;

                          if (_groupBy == 'date') {
                            final date = group['date'] as String;
                            return _buildDateGroup(context, date, entries);
                          } else {
                            final writer =
                                group['writer'] as Map<String, dynamic>;
                            return _buildWriterGroup(context, writer, entries);
                          }
                        },
                      ),
                    );
                  },
                  loading: () => const Center(
                    child: CircularProgressIndicator(),
                  ),
                  error: (e, _) => RefreshIndicator(
                    onRefresh: () async {
                      ref.invalidate(myGuestbookProvider(_groupBy));
                    },
                    child: ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(16, 24, 16, 120),
                      children: [
                        const SizedBox(height: 80),
                        _buildErrorState(context),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (guestbookState.isTyping)
            Positioned(
              left: 16,
              right: 16,
              bottom: guestbookState.requestId != null ? 96 : 20,
              child: _buildTypingIndicator(context, guestbookState),
            ),
        ],
      ),
      bottomSheet: guestbookState.requestId != null
          ? _buildRequestBanner(context, guestbookState)
          : null,
    );
  }

  Widget _buildTopSection(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.03),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '친구들이 남긴 흔적을 모아보세요',
            style: theme.textTheme.bodyMedium?.copyWith(
              color: colorScheme.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: 14),
          SegmentedButton<String>(
            segments: const [
              ButtonSegment(
                value: 'date',
                icon: Icon(Icons.calendar_today_rounded, size: 18),
                label: Text('날짜'),
              ),
              ButtonSegment(
                value: 'writer',
                icon: Icon(Icons.person_rounded, size: 18),
                label: Text('작성자'),
              ),
            ],
            selected: {_groupBy},
            showSelectedIcon: false,
            onSelectionChanged: (value) {
              setState(() => _groupBy = value.first);
            },
            style: ButtonStyle(
              visualDensity: VisualDensity.compact,
              padding: WidgetStateProperty.all(
                const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildDateGroup(BuildContext context, String date, List entries) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
            child: Row(
              children: [
                Icon(
                  Icons.event_note_rounded,
                  size: 16,
                  color: colorScheme.primary,
                ),
                const SizedBox(width: 6),
                Text(
                  date,
                  style: theme.textTheme.labelLarge?.copyWith(
                    color: colorScheme.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Card(
            elevation: 0,
            color: colorScheme.surfaceContainerLowest,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
              side: BorderSide(
                color: colorScheme.outlineVariant.withValues(alpha: 0.5),
              ),
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(vertical: 6),
              child: Column(
                children: [
                  ...entries.asMap().entries.map((item) {
                    final index = item.key;
                    final entry = item.value as Map<String, dynamic>;
                    final writer = entry['writer'] as Map<String, dynamic>;

                    return Column(
                      children: [
                        _buildEntryTile(
                          context: context,
                          content: entry['content'] as String,
                          createdAt: entry['createdAt'] as String,
                          writerNickname: writer['nickname'] as String,
                          writerUsername: writer['username'] as String,
                        ),
                        if (index != entries.length - 1)
                          Divider(
                            height: 1,
                            indent: 20,
                            endIndent: 20,
                            color: colorScheme.outlineVariant
                                .withValues(alpha: 0.5),
                          ),
                      ],
                    );
                  }),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWriterGroup(
    BuildContext context,
    Map<String, dynamic> writer,
    List entries,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final nickname = writer['nickname'] as String;
    final username = writer['username'] as String;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Card(
        elevation: 0,
        color: colorScheme.surfaceContainerLowest,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(24),
          side: BorderSide(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Theme(
          data: theme.copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            tilePadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            childrenPadding: const EdgeInsets.fromLTRB(10, 0, 10, 12),
            leading: CircleAvatar(
              radius: 24,
              backgroundColor: colorScheme.primaryContainer,
              foregroundColor: colorScheme.onPrimaryContainer,
              child: Text(
                nickname[0],
                style: const TextStyle(fontWeight: FontWeight.bold),
              ),
            ),
            title: Text(
              nickname,
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            subtitle: Padding(
              padding: const EdgeInsets.only(top: 2),
              child: Text(
                '@$username',
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colorScheme.onSurfaceVariant,
                ),
              ),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
              decoration: BoxDecoration(
                color: colorScheme.secondaryContainer,
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text(
                '${entries.length}개',
                style: theme.textTheme.labelMedium?.copyWith(
                  color: colorScheme.onSecondaryContainer,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
            children: entries.map((e) {
              final entry = e as Map<String, dynamic>;
              return Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: _buildEntryTile(
                  context: context,
                  content: entry['content'] as String,
                  createdAt: entry['createdAt'] as String,
                  showWriter: false,
                  compact: true,
                ),
              );
            }).toList(),
          ),
        ),
      ),
    );
  }

  Widget _buildEntryTile({
    required BuildContext context,
    required String content,
    required String createdAt,
    String? writerNickname,
    String? writerUsername,
    bool showWriter = true,
    bool compact = false,
  }) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    final dateTime = DateTime.tryParse(createdAt);
    final formattedTime = dateTime != null
        ? '${dateTime.hour.toString().padLeft(2, '0')}:'
            '${dateTime.minute.toString().padLeft(2, '0')}'
        : createdAt;

    return Padding(
      padding: EdgeInsets.fromLTRB(
        compact ? 6 : 16,
        compact ? 6 : 12,
        compact ? 6 : 16,
        compact ? 6 : 12,
      ),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: compact
              ? colorScheme.surfaceContainerHigh
              : colorScheme.surfaceContainer,
          borderRadius: BorderRadius.circular(18),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showWriter && writerNickname != null && writerUsername != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Row(
                  children: [
                    CircleAvatar(
                      radius: 16,
                      backgroundColor: colorScheme.primaryContainer,
                      foregroundColor: colorScheme.onPrimaryContainer,
                      child: Text(
                        writerNickname[0],
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            writerNickname,
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          Text(
                            '@$writerUsername',
                            style: theme.textTheme.bodySmall?.copyWith(
                              color: colorScheme.onSurfaceVariant,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: colorScheme.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        formattedTime,
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            Text(
              content,
              style: theme.textTheme.bodyLarge?.copyWith(
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
            if (!showWriter) ...[
              const SizedBox(height: 10),
              Align(
                alignment: Alignment.centerRight,
                child: Text(
                  formattedTime,
                  style: theme.textTheme.labelSmall?.copyWith(
                    color: colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildTypingIndicator(
    BuildContext context,
    GuestbookRequestState state,
  ) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: colorScheme.inverseSurface.withValues(alpha: 0.92),
          borderRadius: BorderRadius.circular(999),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.12),
              blurRadius: 16,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: colorScheme.onInverseSurface,
              ),
            ),
            const SizedBox(width: 10),
            Flexible(
              child: Text(
                '${state.typingNickname}님이 작성 중...',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: colorScheme.onInverseSurface,
                  fontWeight: FontWeight.w600,
                ),
              ),
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
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;
    final ownerNickname = state.owner?['nickname'] as String? ?? '알 수 없음';

    return SafeArea(
      top: false,
      child: Material(
        elevation: 12,
        color: colorScheme.surfaceContainerHigh,
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: colorScheme.primaryContainer,
                foregroundColor: colorScheme.onPrimaryContainer,
                child: const Icon(Icons.edit_note_rounded),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  '$ownerNickname님이 방명록을 요청했습니다.',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              TextButton(
                onPressed: () {
                  if (state.requestId == null) return;
                  ref
                      .read(guestbookProvider.notifier)
                      .rejectRequest(state.requestId!);
                },
                child: const Text('거절'),
              ),
              FilledButton(
                onPressed: () {
                  if (state.requestId == null) return;
                  _navigateToWrite(state);
                },
                style: FilledButton.styleFrom(
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                child: const Text('작성'),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.surfaceContainerLowest,
          borderRadius: BorderRadius.circular(28),
          border: Border.all(
            color: colorScheme.outlineVariant.withValues(alpha: 0.5),
          ),
        ),
        child: Column(
          children: [
            CircleAvatar(
              radius: 28,
              backgroundColor: colorScheme.primaryContainer,
              child: Icon(
                Icons.menu_book_rounded,
                color: colorScheme.onPrimaryContainer,
              ),
            ),
            const SizedBox(height: 14),
            Text(
              '아직 방명록이 없습니다',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '가까운 친구와 만나면 첫 방명록이 여기에 쌓여요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Center(
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: colorScheme.errorContainer.withValues(alpha: 0.35),
          borderRadius: BorderRadius.circular(24),
        ),
        child: Column(
          children: [
            Icon(
              Icons.cloud_off_rounded,
              size: 36,
              color: colorScheme.error,
            ),
            const SizedBox(height: 12),
            Text(
              '오류가 발생했습니다',
              style: theme.textTheme.titleMedium?.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              '당겨서 새로고침해 다시 불러와 주세요.',
              textAlign: TextAlign.center,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: colorScheme.onSurfaceVariant,
              ),
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
