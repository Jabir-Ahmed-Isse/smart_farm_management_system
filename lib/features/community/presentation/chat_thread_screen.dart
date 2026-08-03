import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/chat.dart';
import '../data/chat_repository.dart';

/// A live 1:1 conversation. Messages stream in over Realtime; sending goes
/// through the send_chat_message RPC.
class ChatThreadScreen extends ConsumerStatefulWidget {
  const ChatThreadScreen({
    super.key,
    required this.threadId,
    required this.otherName,
    this.otherAvatar,
  });

  final String threadId;
  final String otherName;
  final String? otherAvatar;

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  bool _sending = false;

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final myId = ref.watch(currentUserProvider)?.id;
    final messages = ref.watch(chatMessagesProvider(widget.threadId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Row(
          children: [
            _avatar(),
            const SizedBox(width: 10),
            Text(widget.otherName, style: AppText.headlineSm),
          ],
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: messages.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not load messages.\n$e',
                      textAlign: TextAlign.center, style: AppText.labelSm),
                ),
              ),
              data: (list) {
                WidgetsBinding.instance
                    .addPostFrameCallback((_) => _scrollToEnd());
                if (list.isEmpty) {
                  return Center(
                    child: Text('Say hello to ${widget.otherName} 👋',
                        style: AppText.bodyMd
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  );
                }
                return ListView.builder(
                  controller: _scroll,
                  padding: const EdgeInsets.fromLTRB(12, 12, 12, 12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _bubble(list[i], list[i].senderId == myId),
                );
              },
            ),
          ),
          _input(),
        ],
      ),
    );
  }

  Widget _avatar() {
    final url = widget.otherAvatar;
    if (url != null && url.startsWith('http')) {
      return CircleAvatar(radius: 16, backgroundImage: NetworkImage(url));
    }
    final initials = widget.otherName.trim().isEmpty
        ? '?'
        : widget.otherName.trim().split(RegExp(r'\s+')).take(2).map((w) => w[0]).join();
    return CircleAvatar(
      radius: 16,
      backgroundColor: AppColors.primaryContainer,
      child: Text(initials.toUpperCase(),
          style: AppText.labelSm.copyWith(color: Colors.white)),
    );
  }

  Widget _bubble(ChatMessage m, bool mine) {
    return Align(
      alignment: mine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.75),
        decoration: BoxDecoration(
          color: mine ? AppColors.primary : AppColors.surfaceContainerLowest,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(mine ? 16 : 4),
            bottomRight: Radius.circular(mine ? 4 : 16),
          ),
          border: mine ? null : Border.all(color: AppColors.outlineVariant),
        ),
        child: Text(m.body,
            style: AppText.bodyMd
                .copyWith(color: mine ? Colors.white : AppColors.onSurface)),
      ),
    );
  }

  Widget _input() {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(top: BorderSide(color: AppColors.outlineVariant)),
        ),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: _controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => _send(),
                decoration: InputDecoration(
                  hintText: 'Message…',
                  filled: true,
                  fillColor: AppColors.surfaceContainerLow,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            IconButton.filled(
              onPressed: _sending ? null : _send,
              style: IconButton.styleFrom(backgroundColor: AppColors.primary),
              icon: _sending
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                          strokeWidth: 2, color: Colors.white))
                  : const Icon(Symbols.send, color: Colors.white),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _send() async {
    final text = _controller.text.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() => _sending = true);
    try {
      await ref
          .read(chatRepositoryProvider)
          .sendMessage(widget.threadId, text);
      // The message arrives back through the realtime stream.
    } catch (e) {
      if (mounted) {
        _controller.text = text;
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not send: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  void _scrollToEnd() {
    if (_scroll.hasClients) {
      _scroll.jumpTo(_scroll.position.maxScrollExtent);
    }
  }
}
