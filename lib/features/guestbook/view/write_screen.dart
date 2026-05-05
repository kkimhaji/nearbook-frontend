import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/guestbook_provider.dart';
import '../../../shared/widgets/profile_avatar.dart';

class WriteScreen extends ConsumerStatefulWidget {
  final int requestId;
  final Map<String, dynamic> owner;

  const WriteScreen({
    super.key,
    required this.requestId,
    required this.owner,
  });

  @override
  ConsumerState<WriteScreen> createState() => _WriteScreenState();
}

class _WriteScreenState extends ConsumerState<WriteScreen> {
  final _contentController = TextEditingController();
  bool _isTyping = false;
  bool _submitted = false; // 정상 제출 여부 추적

  String get _ownerId => widget.owner['id'] as String;
  String get _ownerNickname => widget.owner['nickname'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    // 작성 시작 상태로 변경
    ref.read(guestbookRepositoryProvider).markAsWriting(widget.requestId);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _contentController.removeListener(_onTextChanged);
    _contentController.dispose();

    // 제출 없이 이탈한 경우 처리
    if (!_submitted) {
      _handleAbandon();
    }

    super.dispose();
  }

  // dispose는 async 불가 → fire-and-forget으로 처리
  void _handleAbandon() {
    // 타이핑 중이었다면 stop 전송
    if (_isTyping) {
      ref.read(guestbookProvider.notifier).sendTypingStop(
            _ownerId,
            widget.requestId,
          );
    }

    // writing → pending 으로 복구
    ref
        .read(guestbookRepositoryProvider)
        .cancelWriting(widget.requestId)
        .catchError((_) {});
    // 오류가 발생해도 UI에는 영향 없으므로 무시
  }

  void _onTextChanged() {
    if (_contentController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      ref
          .read(guestbookProvider.notifier)
          .sendTypingStart(_ownerId, widget.requestId);
    } else if (_contentController.text.isEmpty && _isTyping) {
      _isTyping = false;
      ref
          .read(guestbookProvider.notifier)
          .sendTypingStop(_ownerId, widget.requestId);
    }
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    // 타이핑 종료 알림
    if (_isTyping) {
      ref
          .read(guestbookProvider.notifier)
          .sendTypingStop(_ownerId, widget.requestId);
      _isTyping = false;
    }

    await ref
        .read(guestbookProvider.notifier)
        .submitGuestbook(widget.requestId, content);

    _submitted = true; // 정상 제출 마킹

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileAvatar(
              nickname: _ownerNickname,
              imageUrl: widget.owner['profileImageUrl'] as String?,
              radius: 16,
            ),
            const SizedBox(width: 8),
            Text('$_ownerNickname님께'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text('제출'),
          ),
        ],
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: TextField(
          controller: _contentController,
          maxLines: null,
          expands: true,
          autofocus: true,
          decoration: InputDecoration(
            hintText: '$_ownerNickname님에게 남길 말을 작성하세요...',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
