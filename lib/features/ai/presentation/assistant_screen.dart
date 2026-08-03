import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/ai_conversation.dart';
import '../../../models/ai_message.dart';
import '../../../models/farm.dart';
import '../../profile/data/profile_repository.dart';
import '../data/ai_service.dart';
import '../data/assistant_repository.dart';

const _suggestions = [
  'How much did I spend this month?',
  'Which crop made the highest profit?',
  'What diseases have affected my crops?',
  'What should I plant next month?',
  'Suggest an irrigation schedule.',
];

/// AI Farm Assistant — bilingual chat grounded in the farm's real data.
class AssistantScreen extends ConsumerStatefulWidget {
  const AssistantScreen({super.key});

  @override
  ConsumerState<AssistantScreen> createState() => _AssistantScreenState();
}

class _AssistantScreenState extends ConsumerState<AssistantScreen> {
  final _controller = TextEditingController();
  final _scroll = ScrollController();
  final List<AiMessage> _messages = [];
  String? _conversationId;
  String? _animateMessageId;
  bool _sending = false;

  String get _language =>
      ui.PlatformDispatcher.instance.locale.languageCode == 'so' ? 'so' : 'en';

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final farms = ref.watch(myFarmsProvider);
    final farm =
        farms.valueOrNull?.isNotEmpty == true ? farms.value!.first : null;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        title: const Text('AI Assistant'),
        actions: [
          IconButton(
            tooltip: 'Chat history',
            icon: const Icon(Symbols.history),
            onPressed: farm == null ? null : () => _openHistory(farm),
          ),
          IconButton(
            tooltip: 'New chat',
            icon: const Icon(Symbols.add_comment),
            onPressed: _messages.isEmpty ? null : _newChat,
          ),
        ],
      ),
      body: farm == null
          ? const Center(child: Text('Create a farm to use the assistant.'))
          : Column(
              children: [
                Expanded(
                  child: _messages.isEmpty && !_sending
                      ? _Welcome(onPick: (q) => _send(farm, q))
                      : _transcript(),
                ),
                _InputBar(
                  controller: _controller,
                  sending: _sending,
                  onSend: () => _send(farm, _controller.text),
                  onMic: () => _snack('Voice input is coming soon.'),
                ),
              ],
            ),
    );
  }

  Widget _transcript() {
    return ListView.builder(
      controller: _scroll,
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
      itemCount: _messages.length + (_sending ? 1 : 0),
      itemBuilder: (context, i) {
        if (i >= _messages.length) return const _TypingBubble();
        final m = _messages[i];
        return _Bubble(
          message: m,
          animate: m.id == _animateMessageId,
        );
      },
    );
  }

  Future<void> _send(Farm farm, String raw) async {
    final text = raw.trim();
    if (text.isEmpty || _sending) return;
    _controller.clear();
    setState(() {
      _messages.add(AiMessage.local('user', text));
      _sending = true;
    });
    _scrollToEnd();

    final outcome = await ref.read(assistantRepositoryProvider).ask(
          farmId: farm.id,
          conversationId: _conversationId,
          question: text,
          language: _language,
        );
    if (!mounted) return;

    switch (outcome) {
      case ChatOk(:final conversationId, :final answer):
        final msg = AiMessage.local('assistant', answer);
        setState(() {
          _conversationId = conversationId;
          _messages.add(msg);
          _animateMessageId = msg.id;
          _sending = false;
        });
        ref.invalidate(chatCreditProvider);
        ref.invalidate(conversationsForFarmProvider(farm.id));
      case ChatCreditLimit():
        setState(() => _sending = false);
        _creditLimitSheet();
      case ChatError(:final message, :final code):
        setState(() => _sending = false);
        _snack(code == 'no_key'
            ? 'The AI is not switched on yet.'
            : message);
    }
    _scrollToEnd();
  }

  void _newChat() {
    setState(() {
      _messages.clear();
      _conversationId = null;
      _animateMessageId = null;
    });
  }

  Future<void> _openHistory(Farm farm) async {
    final selected = await showModalBottomSheet<AiConversation>(
      context: context,
      showDragHandle: true,
      builder: (_) => _HistorySheet(farmId: farm.id),
    );
    if (selected == null || !mounted) return;
    final messages =
        await ref.read(assistantRepositoryProvider).getMessages(selected.id);
    if (!mounted) return;
    setState(() {
      _conversationId = selected.id;
      _messages
        ..clear()
        ..addAll(messages);
      _animateMessageId = null;
    });
    _scrollToEnd();
  }

  void _scrollToEnd() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) {
        _scroll.animateTo(
          _scroll.position.maxScrollExtent + 120,
          duration: const Duration(milliseconds: 250),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _creditLimitSheet() => showModalBottomSheet<void>(
        context: context,
        showDragHandle: true,
        builder: (ctx) => Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.bolt, size: 44, color: AppColors.tertiary),
              const SizedBox(height: 12),
              Text('Monthly limit reached', style: AppText.headlineSm),
              const SizedBox(height: 8),
              Text(
                "You've used all $kFreeChatLimit free assistant questions this "
                'month. They reset on the 1st. Upgrade to Premium for unlimited '
                'questions.',
                textAlign: TextAlign.center,
                style:
                    AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () {
                    Navigator.pop(ctx);
                    _snack('Premium plans are coming soon.');
                  },
                  icon: const Icon(Symbols.workspace_premium),
                  label: const Text('Upgrade to Premium'),
                ),
              ),
            ],
          ),
        ),
      );

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
}

// ============================================================ welcome

class _Welcome extends ConsumerWidget {
  const _Welcome({required this.onPick});
  final void Function(String) onPick;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final credit = ref.watch(chatCreditProvider).valueOrNull;
    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 32, 20, 20),
      children: [
        Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.primaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(Symbols.smart_toy, color: Colors.white, size: 32),
          ),
        ),
        const SizedBox(height: 16),
        Text('Ask Somali Farm', style: AppText.headlineMd, textAlign: TextAlign.center),
        const SizedBox(height: 6),
        Text(
          'Your farm assistant. Ask about your money, crops, harvests, '
          'inventory, or diseases — it knows your farm.',
          textAlign: TextAlign.center,
          style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant),
        ),
        const SizedBox(height: 24),
        Text('Try asking', style: AppText.labelMd),
        const SizedBox(height: 10),
        for (final s in _suggestions)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: InkWell(
              borderRadius: BorderRadius.circular(12),
              onTap: () => onPick(s),
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerLowest,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    const Icon(Symbols.chat_bubble,
                        size: 18, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(child: Text(s, style: AppText.bodyMd)),
                    const Icon(Symbols.arrow_outward,
                        size: 16, color: AppColors.outline),
                  ],
                ),
              ),
            ),
          ),
        if (credit != null && !credit.isPremium) ...[
          const SizedBox(height: 8),
          Center(
            child: Text('${credit.remaining} of ${credit.limit} questions left this month',
                style: AppText.labelSm),
          ),
        ],
      ],
    );
  }
}

// ============================================================ bubbles

class _Bubble extends StatelessWidget {
  const _Bubble({required this.message, this.animate = false});
  final AiMessage message;
  final bool animate;

  @override
  Widget build(BuildContext context) {
    final isUser = message.isUser;
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        mainAxisAlignment:
            isUser ? MainAxisAlignment.end : MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (!isUser) ...[
            const CircleAvatar(
              radius: 14,
              backgroundColor: AppColors.primaryContainer,
              child: Icon(Symbols.smart_toy, size: 16, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isUser
                    ? AppColors.primary
                    : AppColors.surfaceContainerLowest,
                borderRadius: BorderRadius.only(
                  topLeft: const Radius.circular(16),
                  topRight: const Radius.circular(16),
                  bottomLeft: Radius.circular(isUser ? 16 : 4),
                  bottomRight: Radius.circular(isUser ? 4 : 16),
                ),
                border: isUser
                    ? null
                    : Border.all(color: AppColors.outlineVariant),
              ),
              child: animate
                  ? _Typewriter(text: message.content)
                  : Text(
                      message.content,
                      style: AppText.bodyMd.copyWith(
                          color: isUser ? Colors.white : AppColors.onSurface),
                    ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Reveals assistant text progressively for a "streaming" feel.
class _Typewriter extends StatefulWidget {
  const _Typewriter({required this.text});
  final String text;

  @override
  State<_Typewriter> createState() => _TypewriterState();
}

class _TypewriterState extends State<_Typewriter> {
  int _shown = 0;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 12), (t) {
      if (!mounted) return;
      if (_shown >= widget.text.length) {
        t.cancel();
      } else {
        setState(() => _shown = (_shown + 2).clamp(0, widget.text.length));
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Text(widget.text.substring(0, _shown), style: AppText.bodyMd);
  }
}

class _TypingBubble extends StatelessWidget {
  const _TypingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primaryContainer,
            child: Icon(Symbols.smart_toy, size: 16, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLowest,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: const SizedBox(
              width: 20,
              height: 12,
              child: _Dots(),
            ),
          ),
        ],
      ),
    );
  }
}

class _Dots extends StatefulWidget {
  const _Dots();
  @override
  State<_Dots> createState() => _DotsState();
}

class _DotsState extends State<_Dots> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 900))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (context, _) {
        return Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: List.generate(3, (i) {
            final t = ((_c.value + i * 0.2) % 1.0);
            final o = 0.3 + 0.7 * (t < 0.5 ? t * 2 : (1 - t) * 2);
            return Container(
              width: 5,
              height: 5,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppColors.primary.withValues(alpha: o),
              ),
            );
          }),
        );
      },
    );
  }
}

// ============================================================ input

class _InputBar extends StatelessWidget {
  const _InputBar({
    required this.controller,
    required this.sending,
    required this.onSend,
    required this.onMic,
  });

  final TextEditingController controller;
  final bool sending;
  final VoidCallback onSend;
  final VoidCallback onMic;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
        decoration: const BoxDecoration(
          color: AppColors.surfaceContainerLowest,
          border: Border(top: BorderSide(color: AppColors.outlineVariant)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            IconButton(
              onPressed: onMic,
              icon: const Icon(Symbols.mic),
              color: AppColors.onSurfaceVariant,
              tooltip: 'Voice input',
            ),
            Expanded(
              child: TextField(
                controller: controller,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: (_) => onSend(),
                decoration: InputDecoration(
                  hintText: 'Ask about your farm…',
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
            _SendButton(sending: sending, onSend: onSend),
          ],
        ),
      ),
    );
  }
}

class _SendButton extends StatelessWidget {
  const _SendButton({required this.sending, required this.onSend});
  final bool sending;
  final VoidCallback onSend;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 46,
      height: 46,
      child: FilledButton(
        onPressed: sending ? null : onSend,
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primary,
          padding: EdgeInsets.zero,
          shape: const CircleBorder(),
        ),
        child: sending
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                    strokeWidth: 2, color: Colors.white),
              )
            : const Icon(Symbols.send, size: 20),
      ),
    );
  }
}

// ============================================================ history

class _HistorySheet extends ConsumerWidget {
  const _HistorySheet({required this.farmId});
  final String farmId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final convos = ref.watch(conversationsForFarmProvider(farmId));
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Past chats', style: AppText.headlineSm),
            const SizedBox(height: 12),
            convos.when(
              loading: () => const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Could not load chats.', style: AppText.labelSm),
              ),
              data: (list) => list.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                          child: Text('No past chats yet.',
                              style: AppText.labelSm)),
                    )
                  : Flexible(
                      child: ListView.builder(
                        shrinkWrap: true,
                        itemCount: list.length,
                        itemBuilder: (context, i) {
                          final c = list[i];
                          return ListTile(
                            leading: const Icon(Symbols.forum),
                            title: Text(c.title,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppText.labelMd),
                            trailing: IconButton(
                              icon: const Icon(Symbols.delete, size: 20),
                              onPressed: () async {
                                await ref
                                    .read(assistantRepositoryProvider)
                                    .deleteConversation(c.id);
                                ref.invalidate(
                                    conversationsForFarmProvider(farmId));
                              },
                            ),
                            onTap: () => Navigator.pop(context, c),
                          );
                        },
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
