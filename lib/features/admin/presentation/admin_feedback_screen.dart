import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/time_ago.dart';
import '../../../models/feedback_item.dart';
import '../../feedback/data/feedback_repository.dart';

/// Admin → Feedback triage. Filter by status, read submissions, reply and
/// update status. Every write goes through the is_admin()-gated RPC.
class AdminFeedbackScreen extends ConsumerStatefulWidget {
  const AdminFeedbackScreen({super.key});

  @override
  ConsumerState<AdminFeedbackScreen> createState() =>
      _AdminFeedbackScreenState();
}

class _AdminFeedbackScreenState extends ConsumerState<AdminFeedbackScreen> {
  String? _filter; // null = all

  @override
  Widget build(BuildContext context) {
    final list = ref.watch(adminFeedbackProvider(_filter));
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Feedback'),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              children: [
                _chip('All', null),
                for (final s in feedbackStatuses) _chip(feedbackStatusLabel(s), s),
              ],
            ),
          ),
          Expanded(
            child: RefreshIndicator(
              onRefresh: () async => ref.invalidate(adminFeedbackProvider(_filter)),
              child: list.when(
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (e, _) => Center(
                    child: Text(e.toString().contains('42501')
                        ? 'Admins only'
                        : 'Could not load')),
                data: (items) => items.isEmpty
                    ? ListView(children: [
                        const SizedBox(height: 120),
                        Center(child: Text('No feedback here', style: AppText.headlineSm)),
                      ])
                    : ListView.builder(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                        itemCount: items.length,
                        itemBuilder: (_, i) => _AdminCard(
                          item: items[i],
                          onManage: () => _manage(items[i]),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _chip(String label, String? value) {
    final selected = _filter == value;
    return Padding(
      padding: const EdgeInsets.only(right: 8),
      child: ChoiceChip(
        label: Text(label),
        selected: selected,
        onSelected: (_) => setState(() => _filter = value),
      ),
    );
  }

  Future<void> _manage(FeedbackItem item) async {
    final changed = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (_) => _ManageSheet(item: item),
    );
    if (changed == true) ref.invalidate(adminFeedbackProvider(_filter));
  }
}

class _AdminCard extends StatelessWidget {
  const _AdminCard({required this.item, required this.onManage});
  final FeedbackItem item;
  final VoidCallback onManage;

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
            Text(feedbackStatusLabel(item.status),
                style: AppText.labelSm.copyWith(color: AppColors.primary)),
          ]),
          const SizedBox(height: 4),
          Text(
              '${feedbackCategoryLabel(item.category)} · '
              '${item.userName ?? item.userEmail ?? 'User'} · '
              '${timeAgo(item.createdAt)}',
              style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
          const SizedBox(height: 8),
          Text(item.message, style: AppText.bodyMd),
          if (item.hasResponse) ...[
            const SizedBox(height: 8),
            Text('Reply: ${item.adminResponse}',
                style: AppText.labelSm.copyWith(color: AppColors.tertiary)),
          ],
          const SizedBox(height: 8),
          Align(
            alignment: Alignment.centerRight,
            child: OutlinedButton.icon(
              onPressed: onManage,
              icon: const Icon(Symbols.reply, size: 18),
              label: const Text('Respond'),
            ),
          ),
        ],
      ),
    );
  }
}

class _ManageSheet extends ConsumerStatefulWidget {
  const _ManageSheet({required this.item});
  final FeedbackItem item;

  @override
  ConsumerState<_ManageSheet> createState() => _ManageSheetState();
}

class _ManageSheetState extends ConsumerState<_ManageSheet> {
  late String _status = widget.item.status;
  late final _response =
      TextEditingController(text: widget.item.adminResponse ?? '');
  bool _saving = false;

  @override
  void dispose() {
    _response.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ref.read(feedbackRepositoryProvider).respond(
            id: widget.item.id,
            status: _status,
            response: _response.text.trim(),
          );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _saving = false);
      if (mounted) {
        ScaffoldMessenger.of(context)
            .showSnackBar(SnackBar(content: Text('Failed: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
          left: 16, right: 16, bottom: MediaQuery.of(context).viewInsets.bottom + 16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(widget.item.subject, style: AppText.headlineSm),
          const SizedBox(height: 12),
          Text('Status', style: AppText.labelSm),
          const SizedBox(height: 6),
          Wrap(
            spacing: 8,
            children: [
              for (final s in feedbackStatuses)
                ChoiceChip(
                  label: Text(feedbackStatusLabel(s)),
                  selected: _status == s,
                  onSelected: (_) => setState(() => _status = s),
                ),
            ],
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _response,
            minLines: 2,
            maxLines: 5,
            decoration: const InputDecoration(
                labelText: 'Reply (optional)', border: OutlineInputBorder()),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: _saving ? null : _save,
            style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(50)),
            child: Text(_saving ? 'Saving…' : 'Save'),
          ),
        ],
      ),
    );
  }
}
