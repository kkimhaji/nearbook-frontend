import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../provider/guestbook_provider.dart';

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

  void _onTextChanged() {
    final ownerId = widget.owner['id'] as String;

    if (_contentController.text.isNotEmpty && !_isTyping) {
      _isTyping = true;
      ref
          .read(guestbookProvider.notifier)
          .sendTypingStart(ownerId, widget.requestId);
    } else if (_contentController.text.isEmpty && _isTyping) {
      _isTyping = false;
      ref
          .read(guestbookProvider.notifier)
          .sendTypingStop(ownerId, widget.requestId);
    }
  }

  Future<void> _submit() async {
    final content = _contentController.text.trim();
    if (content.isEmpty) return;

    final ownerId = widget.owner['id'] as String;
    ref
        .read(guestbookProvider.notifier)
        .sendTypingStop(ownerId, widget.requestId);

    await ref
        .read(guestbookProvider.notifier)
        .submitGuestbook(widget.requestId, content);

    if (!mounted) return;
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final ownerNickname = widget.owner['nickname'] as String;

    return Scaffold(
      appBar: AppBar(
        title: Text('$ownerNickname님께 방명록 쓰기'),
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
            hintText: '$ownerNickname님에게 남길 말을 작성하세요...',
            border: InputBorder.none,
          ),
        ),
      ),
    );
  }
}
