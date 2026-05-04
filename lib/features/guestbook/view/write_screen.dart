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
        title: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            ProfileAvatar(
              nickname: ownerNickname,
              imageUrl: widget.owner['profileImageUrl'] as String?,
              radius: 16,
            ),
            const SizedBox(width: 8),
            Text('$ownerNickname님께'),
          ],
        ),
        actions: [
          TextButton(
            onPressed: _submit,
            child: const Text('제출'),
          ),
        ],
      ),
      body: Column(
        children: [
          const Divider(height: 1),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(20),
              child: TextField(
                controller: _contentController,
                maxLines: null,
                expands: true,
                autofocus: true,
                style: const TextStyle(fontSize: 16, height: 1.7),
                decoration: InputDecoration(
                  hintText: '$ownerNickname님에게 남길 말을 작성하세요...',
                  hintStyle: const TextStyle(
                    color: Color(0xFFCCCCCC),
                    fontSize: 15,
                  ),
                  border: InputBorder.none,
                ),
              ),
            ),
          ),
          // 글자 수 표시
          ValueListenableBuilder(
            valueListenable: _contentController,
            builder: (_, value, __) => Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
              color: const Color(0xFFF5F5F7),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    '${value.text.length} / 1000',
                    style: TextStyle(
                      fontSize: 12,
                      color: value.text.length > 900
                          ? Colors.red
                          : const Color(0xFFAAAAAA),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
