import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/time_ago.dart';
import '../../../models/feedback_item.dart';
import '../data/feedback_repository.dart';

/// Farmer-facing feedback: submit a report/request and see past submissions
/// with any admin response.
class FeedbackScreen extends ConsumerStatefulWidget {
  const FeedbackScreen({super.key});

  @override
  ConsumerState<FeedbackScreen> createState() => _FeedbackScreenState();
}

class _FeedbackScreenState extends ConsumerState<FeedbackScreen> {
  final _subject = TextEditingController();
  final _message = TextEditingController();
  String _category = 'general';
  bool _sending = false;

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (_subject.text.trim().isEmpty || _message.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Please add a subject and a message.')));
      return;
    }
    setState(() => _sending = true);
    try {
      await ref.read(feedbackRepositoryProvider).submit(
            category: _category,
            subject: _subject.text,
            message: _message.text,
          );
      _subject.clear();
      _message.clear();
      setState(() => _category = 'general');
      ref.invalidate(myFeedbackProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Thanks! Your feedback was submitted.')));
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Could not submit: $e')));
      }
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final mine = ref.watch(myFeedbackProvider);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: AppColors.background,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text('Report a problem, request a feature, or ask a question. '
              'An admin will follow up here.',
              style: AppText.labelSm),
          const SizedBox(height: 16),
          Wrap(
            spacing: 8,
            children: [
              for (final c in feedbackCategories)
                ChoiceChip(
                  label: Text(c.$2),
                  selected: _category == c.$1,
                  onSelected: (_) => setState(() => _category = c.$1),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _subject,
            decoration: const InputDecoration(
                labelText: 'Subject', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _message,
            minLines: 3,
            maxLines: 6,
            decoration: const InputDecoration(
                labelText: 'Message', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 12),
          FilledButton.icon(
            onPressed: _sending ? null : _submit,
            icon: _sending
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppColors.onPrimary))
                : const Icon(Symbols.send),
            label: Text(_sending ? 'Sending…' : 'Submit feedback'),
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
          ),
          const SizedBox(height: 24),
          Text('Your submissions',
              style: AppText.labelMd.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          mine.when(
            loading: () => const Padding(
              padding: EdgeInsets.all(24),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (_, __) => Text('Could not load your feedback.',
                style: AppText.labelSm),
            data: (list) => list.isEmpty
                ? Text('Nothing submitted yet.', style: AppText.labelSm)
                : Column(
                    children: [for (final f in list) _FeedbackCard(item: f)]),
          ),
        ],
      ),
    );
  }
}

class _FeedbackCard extends StatelessWidget {
  const _FeedbackCard({required this.item});
  final FeedbackItem item;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Expanded(child: Text(item.subject, style: AppText.labelMd)),
            _StatusPill(status: item.status),
          ]),
          const SizedBox(height: 4),
          Text('${feedbackCategoryLabel(item.category)} · ${timeAgo(item.createdAt)}',
              style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(item.message, style: AppText.bodyMd),
          if (item.hasResponse) ...[
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.primaryContainer.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    const Icon(Symbols.support_agent,
                        size: 16, color: AppColors.primary),
                    const SizedBox(width: 6),
                    Text('Admin response', style: AppText.labelSm),
                  ]),
                  const SizedBox(height: 4),
                  Text(item.adminResponse!, style: AppText.bodyMd),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({required this.status});
  final String status;

  @override
  Widget build(BuildContext context) {
    final color = switch (status) {
      'resolved' => AppColors.tertiary,
      'closed' => AppColors.outline,
      'in_review' => AppColors.primary,
      _ => AppColors.secondary,
    };
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(feedbackStatusLabel(status),
          style: AppText.labelSm.copyWith(color: color)),
    );
  }
}
