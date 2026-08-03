import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../data/admin_system_repository.dart';

const _audiences = <(String, String)>[
  ('all', 'Everyone'),
  ('farmers', 'Farmers'),
  ('experts', 'Experts'),
  ('premium', 'Premium users'),
];

String _audienceLabel(String key) =>
    _audiences.firstWhere((a) => a.$1 == key, orElse: () => (key, key)).$2;

/// Admin → compose and manage in-app announcements sent to users.
class AdminNotificationsScreen extends ConsumerWidget {
  const AdminNotificationsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final broadcasts = ref.watch(adminBroadcastsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Notifications')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _compose(context, ref),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimary,
        icon: const Icon(Symbols.campaign),
        label: const Text('New announcement'),
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminBroadcastsProvider),
        child: broadcasts.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => _error('$e'),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 120),
                const Icon(Symbols.campaign, size: 56, color: AppColors.outline),
                const SizedBox(height: 12),
                Center(child: Text('No announcements yet', style: AppText.headlineSm)),
                const SizedBox(height: 6),
                Center(
                  child: Text('Send a message to your farmers.',
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ),
              ]);
            }
            return ListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
              itemCount: list.length,
              itemBuilder: (_, i) => _BroadcastCard(
                b: list[i],
                onDelete: () => _delete(context, ref, list[i]),
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _error(String e) => ListView(children: [
        const SizedBox(height: 120),
        const Icon(Symbols.error, size: 56, color: AppColors.outline),
        const SizedBox(height: 12),
        Center(child: Text('Could not load', style: AppText.headlineSm)),
        Padding(
          padding: const EdgeInsets.all(24),
          child: Text(e, textAlign: TextAlign.center, style: AppText.labelSm),
        ),
      ]);

  Future<void> _delete(
      BuildContext context, WidgetRef ref, Broadcast b) async {
    final ok = await confirmDelete(context,
        title: 'Delete announcement?', message: 'Remove "${b.title}"?');
    if (ok != true) return;
    try {
      await ref.read(adminSystemRepositoryProvider).deleteBroadcast(b.id);
      ref.invalidate(adminBroadcastsProvider);
    } catch (_) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not delete.')));
      }
    }
  }

  Future<void> _compose(BuildContext context, WidgetRef ref) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => const _ComposeSheet(),
    );
  }
}

class _BroadcastCard extends StatelessWidget {
  const _BroadcastCard({required this.b, required this.onDelete});
  final Broadcast b;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(b.title,
                    style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w700)),
                if (b.body.isNotEmpty) ...[
                  const SizedBox(height: 4),
                  Text(b.body,
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ],
                const SizedBox(height: 8),
                Row(
                  children: [
                    _pill(Symbols.group, _audienceLabel(b.audience)),
                    const SizedBox(width: 8),
                    Text(DateFormat('d MMM yyyy').format(b.createdAt),
                        style: AppText.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                  ],
                ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Symbols.delete, size: 20),
            color: AppColors.onSurfaceVariant,
            onPressed: onDelete,
          ),
        ],
      ),
    );
  }

  Widget _pill(IconData icon, String label) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(
          color: AppColors.primaryContainer.withValues(alpha: 0.18),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(mainAxisSize: MainAxisSize.min, children: [
          Icon(icon, size: 13, color: AppColors.primary),
          const SizedBox(width: 4),
          Text(label,
              style: AppText.labelSm.copyWith(color: AppColors.primary)),
        ]),
      );
}

class _ComposeSheet extends ConsumerStatefulWidget {
  const _ComposeSheet();

  @override
  ConsumerState<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends ConsumerState<_ComposeSheet> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  String _audience = 'all';
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text('New announcement', style: AppText.headlineSm),
          const SizedBox(height: 16),
          TextField(
            controller: _titleCtrl,
            autofocus: true,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Title'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _bodyCtrl,
            maxLines: 3,
            textCapitalization: TextCapitalization.sentences,
            decoration: const InputDecoration(labelText: 'Message'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _audience,
            decoration: const InputDecoration(labelText: 'Send to'),
            items: [
              for (final a in _audiences)
                DropdownMenuItem(value: a.$1, child: Text(a.$2)),
            ],
            onChanged: (v) => setState(() => _audience = v ?? 'all'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!,
                style: AppText.labelMd.copyWith(color: AppColors.error)),
          ],
          const SizedBox(height: 20),
          FilledButton.icon(
            onPressed: _saving ? null : _send,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Symbols.send, size: 18),
            label: Text(_saving ? 'Sending…' : 'Send announcement'),
          ),
        ],
      ),
    );
  }

  Future<void> _send() async {
    if (_titleCtrl.text.trim().isEmpty) {
      setState(() => _error = 'A title is required.');
      return;
    }
    final nav = Navigator.of(context);
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ref.read(adminSystemRepositoryProvider).createBroadcast(
            title: _titleCtrl.text,
            body: _bodyCtrl.text,
            audience: _audience,
          );
      ref.invalidate(adminBroadcastsProvider);
      nav.pop();
    } catch (_) {
      if (mounted) {
        setState(() {
          _saving = false;
          _error = 'Could not send the announcement.';
        });
      }
    }
  }
}
