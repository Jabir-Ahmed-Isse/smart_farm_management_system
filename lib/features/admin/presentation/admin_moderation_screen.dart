import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/time_ago.dart';
import '../data/moderation_repository.dart';

/// Admin → Community Moderation: review reported posts and expert applications.
class AdminModerationScreen extends ConsumerWidget {
  const AdminModerationScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return DefaultTabController(
      length: 2,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Moderation'),
          backgroundColor: AppColors.background,
          bottom: const TabBar(tabs: [
            Tab(text: 'Reports'),
            Tab(text: 'Expert Requests'),
          ]),
        ),
        body: const TabBarView(children: [_ReportsTab(), _ExpertAppsTab()]),
      ),
    );
  }
}

class _ReportsTab extends ConsumerWidget {
  const _ReportsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final reports = ref.watch(adminReportsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminReportsProvider),
      child: reports.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _err(e),
        data: (list) => list.isEmpty
            ? _empty(Symbols.flag, 'No reports', 'Reported posts show up here.')
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) => _ReportCard(report: list[i]),
              ),
      ),
    );
  }
}

class _ReportCard extends ConsumerStatefulWidget {
  const _ReportCard({required this.report});
  final Map<String, dynamic> report;

  @override
  ConsumerState<_ReportCard> createState() => _ReportCardState();
}

class _ReportCardState extends ConsumerState<_ReportCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final r = widget.report;
    final open = (r['status'] as String?) == 'open';
    final (color, label) = switch (r['status'] as String?) {
      'resolved' => (AppColors.primary, 'Resolved'),
      'dismissed' => (AppColors.outline, 'Dismissed'),
      _ => (AppColors.error, 'Open'),
    };
    return Card(
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              _pill(label, color),
              const Spacer(),
              Text(timeAgo(DateTime.tryParse(r['created_at'] as String? ?? '') ?? DateTime.now()),
                  style: AppText.labelSm),
            ]),
            const SizedBox(height: 8),
            Text('"${r['post_body'] ?? ''}"',
                style: AppText.bodyMd, maxLines: 4, overflow: TextOverflow.ellipsis),
            const SizedBox(height: 6),
            Text('By ${r['post_author'] ?? 'Farmer'} · reported by ${r['reporter'] ?? 'Someone'}',
                style: AppText.labelSm),
            if ((r['reason'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 4),
              Text('Reason: ${r['reason']}', style: AppText.labelSm.copyWith(color: AppColors.error)),
            ],
            if (open) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _resolve('delete'),
                    style: FilledButton.styleFrom(backgroundColor: AppColors.error),
                    icon: const Icon(Symbols.delete, size: 18),
                    label: const Text('Delete post'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _resolve('dismiss'),
                    icon: const Icon(Symbols.check, size: 18),
                    label: const Text('Dismiss'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _resolve(String action) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(moderationRepositoryProvider)
          .resolveReport(widget.report['id'] as String, action);
      ref.invalidate(adminReportsProvider);
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
      if (mounted) setState(() => _busy = false);
    }
  }

  Widget _pill(String t, Color c) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
        decoration: BoxDecoration(color: c.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(20)),
        child: Text(t, style: AppText.labelSm.copyWith(color: c, fontWeight: FontWeight.w600)),
      );
}

class _ExpertAppsTab extends ConsumerWidget {
  const _ExpertAppsTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final apps = ref.watch(adminExpertAppsProvider);
    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(adminExpertAppsProvider),
      child: apps.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => _err(e),
        data: (list) => list.isEmpty
            ? _empty(Symbols.verified, 'No requests', 'Expert applications show up here.')
            : ListView.builder(
                padding: const EdgeInsets.all(12),
                itemCount: list.length,
                itemBuilder: (_, i) => _ExpertAppCard(app: list[i]),
              ),
      ),
    );
  }
}

class _ExpertAppCard extends ConsumerStatefulWidget {
  const _ExpertAppCard({required this.app});
  final Map<String, dynamic> app;

  @override
  ConsumerState<_ExpertAppCard> createState() => _ExpertAppCardState();
}

class _ExpertAppCardState extends ConsumerState<_ExpertAppCard> {
  bool _busy = false;

  @override
  Widget build(BuildContext context) {
    final a = widget.app;
    final pending = (a['status'] as String?) == 'pending';
    return Card(
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(14),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(children: [
              const CircleAvatar(
                  radius: 18,
                  backgroundColor: AppColors.primaryContainer,
                  child: Icon(Symbols.person, color: Colors.white)),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${a['user_name'] ?? 'Farmer'}', style: AppText.labelMd),
                    Text('${a['user_email'] ?? ''}', style: AppText.labelSm),
                  ],
                ),
              ),
              if (!pending)
                Text((a['status'] as String?) ?? '',
                    style: AppText.labelSm.copyWith(
                        color: (a['status'] == 'approved') ? AppColors.primary : AppColors.error)),
            ]),
            if ((a['message'] as String?)?.isNotEmpty == true) ...[
              const SizedBox(height: 10),
              Text(a['message'] as String, style: AppText.bodyMd),
            ],
            if (pending) ...[
              const SizedBox(height: 12),
              Row(children: [
                Expanded(
                  child: FilledButton.icon(
                    onPressed: _busy ? null : () => _review(true),
                    icon: const Icon(Symbols.verified, size: 18),
                    label: const Text('Approve'),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _busy ? null : () => _review(false),
                    style: OutlinedButton.styleFrom(foregroundColor: AppColors.error),
                    icon: const Icon(Symbols.close, size: 18),
                    label: const Text('Reject'),
                  ),
                ),
              ]),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _review(bool approve) async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      await ref.read(moderationRepositoryProvider)
          .reviewExpert(widget.app['id'] as String, approve);
      ref.invalidate(adminExpertAppsProvider);
      messenger.showSnackBar(SnackBar(
          content: Text(approve ? 'Approved as expert' : 'Application rejected')));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
      if (mounted) setState(() => _busy = false);
    }
  }
}

Widget _err(Object e) => Center(
    child: Text(e.toString().contains('42501') ? 'Admins only' : 'Could not load',
        style: AppText.headlineSm));

Widget _empty(IconData icon, String title, String sub) => ListView(children: [
      const SizedBox(height: 120),
      Icon(icon, size: 52, color: AppColors.outline),
      const SizedBox(height: 12),
      Center(child: Text(title, style: AppText.labelMd)),
      const SizedBox(height: 4),
      Center(child: Text(sub, style: AppText.labelSm)),
    ]);
