import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../data/admin_system_repository.dart';

/// Admin → a read-only trail of privileged actions (role/plan/suspension
/// changes, broadcasts, settings edits), newest first.
class AdminAuditLogsScreen extends ConsumerWidget {
  const AdminAuditLogsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final logs = ref.watch(adminAuditLogsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Audit Logs')),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminAuditLogsProvider),
        child: logs.when(
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (e, _) => ListView(children: [
            const SizedBox(height: 120),
            const Icon(Symbols.error, size: 56, color: AppColors.outline),
            const SizedBox(height: 12),
            Center(child: Text('Could not load', style: AppText.headlineSm)),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Text('$e',
                  textAlign: TextAlign.center, style: AppText.labelSm),
            ),
          ]),
          data: (list) {
            if (list.isEmpty) {
              return ListView(children: [
                const SizedBox(height: 120),
                const Icon(Symbols.history, size: 56, color: AppColors.outline),
                const SizedBox(height: 12),
                Center(
                    child:
                        Text('Nothing logged yet', style: AppText.headlineSm)),
                const SizedBox(height: 6),
                Center(
                  child: Text('Admin actions will appear here.',
                      style: AppText.bodyMd
                          .copyWith(color: AppColors.onSurfaceVariant)),
                ),
              ]);
            }
            return ListView.separated(
              padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
              itemCount: list.length,
              separatorBuilder: (_, __) => const SizedBox(height: 8),
              itemBuilder: (_, i) => _LogTile(log: list[i]),
            );
          },
        ),
      ),
    );
  }
}

class _LogTile extends StatelessWidget {
  const _LogTile({required this.log});
  final AuditLog log;

  @override
  Widget build(BuildContext context) {
    final meta = _meta(log.action);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor: meta.$2.withValues(alpha: 0.15),
            child: Icon(meta.$1, size: 18, color: meta.$2),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(_describe(log),
                    style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                const SizedBox(height: 2),
                Text(
                  '${log.actorName ?? 'System'} · '
                  '${DateFormat('d MMM yyyy, HH:mm').format(log.createdAt.toLocal())}',
                  style: AppText.labelSm
                      .copyWith(color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// A human sentence from the action + detail JSON.
  String _describe(AuditLog log) {
    final d = log.detail ?? const {};
    final who = d['user'] ?? d['title'] ?? log.targetId ?? '';
    switch (log.action) {
      case 'role_changed':
        return 'Changed $who\'s role ${d['from']} → ${d['to']}';
      case 'plan_changed':
        return 'Changed $who\'s plan ${d['from']} → ${d['to']}';
      case 'user_suspended':
        return 'Suspended $who';
      case 'user_unsuspended':
        return 'Un-suspended $who';
      case 'broadcast_sent':
        return 'Sent announcement "${d['title']}" to ${d['audience']}';
      case 'broadcast_deleted':
        return 'Deleted an announcement';
      case 'setting_changed':
        return 'Set ${log.targetId} = ${d['value']}';
      default:
        return log.action.replaceAll('_', ' ');
    }
  }

  (IconData, Color) _meta(String action) {
    if (action.startsWith('role')) return (Symbols.badge, AppColors.primary);
    if (action.startsWith('plan')) {
      return (Symbols.workspace_premium, AppColors.tertiary);
    }
    if (action.contains('suspend')) return (Symbols.block, AppColors.error);
    if (action.startsWith('broadcast')) {
      return (Symbols.campaign, AppColors.secondary);
    }
    if (action.startsWith('setting')) return (Symbols.settings, AppColors.primary);
    return (Symbols.history, AppColors.onSurfaceVariant);
  }
}
