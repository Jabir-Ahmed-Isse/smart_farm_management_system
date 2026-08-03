import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/util/time_ago.dart';
import '../data/admin_users_repository.dart';
import '../data/subscription_repository.dart';
import 'admin_users_screen.dart' show roleMeta, adminRoleOptions;

const _planOptions = <(String, String)>[
  ('free', 'Free'),
  ('premium', 'Premium'),
  ('enterprise', 'Enterprise'),
  ('ngo', 'NGO'),
];

/// Admin view of one user: profile, activity, farms, and management actions.
class AdminUserDetailScreen extends ConsumerWidget {
  const AdminUserDetailScreen({super.key, required this.userId});
  final String userId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final detail = ref.watch(adminUserDetailProvider(userId));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('User'),
        backgroundColor: AppColors.background,
      ),
      body: detail.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Text('Could not load user.\n$e',
                textAlign: TextAlign.center, style: AppText.labelSm),
          ),
        ),
        data: (d) => _body(context, ref, d),
      ),
    );
  }

  Widget _body(BuildContext context, WidgetRef ref, Map<String, dynamic> d) {
    final profile = Map<String, dynamic>.from(d['profile'] as Map? ?? {});
    final farms = (d['farms'] as List? ?? []);
    final activity = Map<String, dynamic>.from(d['activity'] as Map? ?? {});
    final role = (profile['role'] as String?) ?? 'farmer';
    final suspended = (profile['suspended'] as bool?) ?? false;
    final name = (profile['full_name'] as String?)?.trim();
    final email = profile['email'] as String?;
    final (color, label) = roleMeta(role);
    final display = (name?.isNotEmpty == true) ? name! : (email?.split('@').first ?? 'User');

    int act(String k) => (activity[k] as num?)?.toInt() ?? 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
      children: [
        // header
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            children: [
              CircleAvatar(
                radius: 34,
                backgroundColor: color.withValues(alpha: 0.15),
                child: Text(display[0].toUpperCase(),
                    style: AppText.headlineMd.copyWith(color: color)),
              ),
              const SizedBox(height: 12),
              Text(display, style: AppText.headlineSm),
              if (email != null)
                Text(email,
                    style: AppText.bodyMd
                        .copyWith(color: AppColors.onSurfaceVariant)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 8,
                alignment: WrapAlignment.center,
                children: [
                  _pill(label, color),
                  _pill((profile['ai_plan'] as String?) == 'premium' ? 'Premium' : 'Free',
                      AppColors.tertiary),
                  if (suspended) _pill('Suspended', AppColors.error),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        Text('Activity', style: AppText.labelMd),
        const SizedBox(height: 8),
        Row(children: [
          Expanded(child: _stat('Diagnoses', '${act('diagnoses')}')),
          const SizedBox(width: 10),
          Expanded(child: _stat('Diag. (mo)', '${act('diagnoses_month')}')),
          const SizedBox(width: 10),
          Expanded(child: _stat('Chats (mo)', '${act('chats_month')}')),
          const SizedBox(width: 10),
          Expanded(child: _stat('Posts', '${act('posts')}')),
        ]),
        const SizedBox(height: 16),
        Text('Farms (${farms.length})', style: AppText.labelMd),
        const SizedBox(height: 8),
        if (farms.isEmpty)
          Text('No farms', style: AppText.labelSm)
        else
          for (final f in farms)
            Card(
              elevation: 0,
              color: AppColors.surfaceContainerLowest,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
                side: const BorderSide(color: AppColors.outlineVariant),
              ),
              child: ListTile(
                leading: const Icon(Symbols.agriculture, color: AppColors.primary),
                title: Text((f as Map)['name']?.toString() ?? 'Farm',
                    style: AppText.labelMd),
                subtitle: Text(f['region']?.toString() ?? '',
                    style: AppText.labelSm),
              ),
            ),
        const SizedBox(height: 24),
        Text('Actions', style: AppText.labelMd),
        const SizedBox(height: 8),
        _action(Symbols.badge, 'Change role', label,
            () => _changeRole(context, ref, role)),
        _action(Symbols.workspace_premium, 'Change plan',
            (profile['ai_plan'] as String?) ?? 'free',
            () => _changePlan(context, ref, (profile['ai_plan'] as String?) ?? 'free')),
        _action(Symbols.bolt, 'Reset AI credits', 'This month',
            () => _resetCredits(context, ref)),
        _action(Symbols.history, 'Credit history', 'Recent AI usage',
            () => _creditHistory(context, ref)),
        _action(
          suspended ? Symbols.lock_open : Symbols.block,
          suspended ? 'Restore account' : 'Suspend account',
          suspended ? 'Re-enable access' : 'Block app access',
          () => _toggleSuspend(context, ref, !suspended),
          danger: !suspended,
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- actions

  Future<void> _run(BuildContext context, WidgetRef ref,
      Future<void> Function() op, String ok) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      await op();
      ref.invalidate(adminUserDetailProvider(userId));
      ref.invalidate(adminUsersProvider);
      messenger.showSnackBar(SnackBar(content: Text(ok)));
    } catch (e) {
      messenger.showSnackBar(SnackBar(content: Text('Failed: $e')));
    }
  }

  Future<void> _changeRole(
      BuildContext context, WidgetRef ref, String current) async {
    final repo = ref.read(adminUsersRepositoryProvider);
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Assign role', style: AppText.headlineSm),
            ),
            for (final r in adminRoleOptions)
              ListTile(
                leading: Icon(r.$1 == current ? Symbols.check_circle : Symbols.circle,
                    color: r.$1 == current ? AppColors.primary : AppColors.outline),
                title: Text(r.$2),
                onTap: () => Navigator.pop(ctx, r.$1),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current) return;
    if (!context.mounted) return;
    await _run(context, ref, () => repo.setRole(userId, picked),
        'Role updated to $picked');
  }

  Future<void> _changePlan(
      BuildContext context, WidgetRef ref, String current) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: Text('Assign plan', style: AppText.headlineSm),
            ),
            for (final p in _planOptions)
              ListTile(
                leading: Icon(
                    p.$1 == current ? Symbols.check_circle : Symbols.circle,
                    color: p.$1 == current ? AppColors.primary : AppColors.outline),
                title: Text(p.$2),
                onTap: () => Navigator.pop(ctx, p.$1),
              ),
          ],
        ),
      ),
    );
    if (picked == null || picked == current || !context.mounted) return;
    await _run(context, ref,
        () => ref.read(subscriptionRepositoryProvider).setUserPlan(userId, picked),
        'Plan set to $picked');
  }

  Future<void> _creditHistory(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(subscriptionRepositoryProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (ctx) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: 0.6,
        builder: (ctx, scroll) => FutureBuilder<List<Map<String, dynamic>>>(
          future: repo.creditHistory(userId),
          builder: (ctx, snap) {
            if (!snap.hasData) {
              return const Center(child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator()));
            }
            final rows = snap.data!;
            return ListView(
              controller: scroll,
              padding: const EdgeInsets.all(16),
              children: [
                Text('Credit history', style: AppText.headlineSm),
                const SizedBox(height: 12),
                if (rows.isEmpty)
                  Text('No AI usage recorded.', style: AppText.labelSm)
                else
                  for (final r in rows)
                    ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: Icon(_kindIcon(r['kind'] as String?),
                          color: AppColors.primary, size: 20),
                      title: Text(_kindLabel(r['kind'] as String?),
                          style: AppText.labelMd),
                      trailing: Text(
                          timeAgo(DateTime.tryParse(r['created_at'] as String? ?? '') ??
                              DateTime.now()),
                          style: AppText.labelSm),
                    ),
              ],
            );
          },
        ),
      ),
    );
  }

  IconData _kindIcon(String? k) => switch (k) {
        'diagnosis' => Symbols.psychiatry,
        'chat' => Symbols.smart_toy,
        _ => Symbols.auto_awesome,
      };
  String _kindLabel(String? k) => switch (k) {
        'diagnosis' => 'Plant diagnosis',
        'chat' => 'Assistant chat',
        'insight' => 'AI insights',
        _ => k ?? 'AI',
      };

  Future<void> _resetCredits(BuildContext context, WidgetRef ref) async {
    final repo = ref.read(adminUsersRepositoryProvider);
    final ok = await _confirm(context, 'Reset AI credits?',
        "This clears the user's AI usage for the current month, giving them a fresh allowance.");
    if (ok != true || !context.mounted) return;
    await _run(context, ref, () => repo.resetCredits(userId),
        'AI credits reset for this month');
  }

  Future<void> _toggleSuspend(
      BuildContext context, WidgetRef ref, bool suspend) async {
    final repo = ref.read(adminUsersRepositoryProvider);
    if (suspend) {
      final ok = await _confirm(context, 'Suspend account?',
          'The user will be blocked from using the app until restored.');
      if (ok != true || !context.mounted) return;
    }
    await _run(context, ref, () => repo.setSuspended(userId, suspend),
        suspend ? 'Account suspended' : 'Account restored');
  }

  Future<bool?> _confirm(BuildContext context, String title, String msg) =>
      showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text(title),
          content: Text(msg),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Cancel')),
            FilledButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text('Confirm')),
          ],
        ),
      );

  // ---------------------------------------------------------------- widgets

  Widget _stat(String label, String value) => Container(
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 8),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerLow,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          children: [
            Text(value, style: AppText.labelMd.copyWith(color: AppColors.primary)),
            const SizedBox(height: 2),
            Text(label,
                style: AppText.labelSm, textAlign: TextAlign.center, maxLines: 1),
          ],
        ),
      );

  Widget _action(IconData icon, String label, String sub, VoidCallback onTap,
      {bool danger = false}) {
    final color = danger ? AppColors.error : AppColors.onSurface;
    return Card(
      elevation: 0,
      color: AppColors.surfaceContainerLowest,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: const BorderSide(color: AppColors.outlineVariant),
      ),
      child: ListTile(
        leading: Icon(icon, color: danger ? AppColors.error : AppColors.primary),
        title: Text(label, style: AppText.labelMd.copyWith(color: color)),
        subtitle: Text(sub, style: AppText.labelSm),
        trailing: const Icon(Symbols.chevron_right),
        onTap: onTap,
      ),
    );
  }

  Widget _pill(String text, Color color) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Text(text,
            style: AppText.labelSm
                .copyWith(color: color, fontWeight: FontWeight.w600)),
      );
}
