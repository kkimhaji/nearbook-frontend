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
  bool _submitted = false;
  bool _leavingHandled = false;

  String get _ownerId => widget.owner['id'] as String;
  String get _ownerNickname => widget.owner['nickname'] as String? ?? '';

  @override
  void initState() {
    super.initState();
    ref.read(guestbookRepositoryProvider).markAsWriting(widget.requestId);
    _contentController.addListener(_onTextChanged);
  }

  @override
  void dispose() {
    _contentController.removeListener(_onTextChanged);
    _contentController.dispose();
    super.dispose();
  }

  Future<void> _handleExit() async {
    if (_leavingHandled) return;
    _leavingHandled = true;

    if (_isTyping) {
      _isTyping = false;
      ref.read(guestbookProvider.notifier).sendTypingStop(
            _ownerId,
            widget.requestId,
          );
    }

    try {
      await ref
          .read(guestbookRepositoryProvider)
          .cancelWriting(widget.requestId);
    } catch (_) {}
  }

  void _onTextChanged() {
    if (_contentController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      ref.read(guestbookProvider.notifier).sendTypingStart(
            _ownerId,
            widget.requestId,
          );
    } else if (_contentController.text.isEmpty && _isTyping) {
      _isTyping = false;
      ref.read(guestbookProvider.notifier).sendTypingStop(
            _ownerId,
            widget.requestId,
          );
    }
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    if (_isTyping) {
      ref.read(guestbookProvider.notifier).sendTypingStop(
            _ownerId,
            widget.requestId,
          );
      _isTyping = false;
    }

    await ref
        .read(guestbookProvider.notifier)
        .submitGuestbook(widget.requestId, content);

    _submitted = true;
    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (didPop, result) async {
        if (didPop) return;
        if (_submitted) return;

        await _handleExit();
        if (mounted) {
          Navigator.pop(context);
        }
      },
      child: Scaffold(
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
      ),
    );
  }
}
