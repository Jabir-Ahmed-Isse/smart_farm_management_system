import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../knowledge_hub/presentation/articles_screen.dart';
import '../data/admin_repository.dart';
import 'admin_audit_logs_screen.dart';
import 'admin_diseases_screen.dart';
import 'admin_feedback_screen.dart';
import 'admin_medicines_screen.dart';
import 'admin_moderation_screen.dart';
import 'admin_notifications_screen.dart';
import 'admin_settings_screen.dart';
import 'admin_subscriptions_screen.dart';
import 'admin_users_screen.dart';

/// Super Admin dashboard — platform-wide overview plus entry points into the
/// management modules. Only reachable by admins (gated in the Profile screen
/// and defended server-side by is_admin() in every admin RPC).
class AdminDashboardScreen extends ConsumerWidget {
  const AdminDashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final overview = ref.watch(adminOverviewProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Admin Dashboard'),
        backgroundColor: AppColors.background,
      ),
      body: RefreshIndicator(
        onRefresh: () async => ref.invalidate(adminOverviewProvider),
        child: overview.when(
          loading: () => const _LoadingSkeleton(),
          error: (e, _) => _ErrorState(error: e.toString()),
          data: (o) => ListView(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
            children: [
              _sectionTitle('Overview'),
              const SizedBox(height: 12),
              _statGrid(o),
              const SizedBox(height: 24),
              if (o.topCrops.isNotEmpty) ...[
                _Leaderboard(
                    title: 'Most common crops',
                    icon: Symbols.potted_plant,
                    rows: o.topCrops),
                const SizedBox(height: 16),
              ],
              if (o.topDiseases.isNotEmpty) ...[
                _Leaderboard(
                    title: 'Most common diseases',
                    icon: Symbols.coronavirus,
                    rows: o.topDiseases),
                const SizedBox(height: 24),
              ],
              _sectionTitle('Management'),
              const SizedBox(height: 12),
              const _ManagementGrid(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionTitle(String t) => Text(t, style: AppText.headlineSm);

  Widget _statGrid(AdminOverview o) {
    final stats = <(IconData, String, String, Color)>[
      (Symbols.group, 'Total users', '${o.totalUsers}', AppColors.primary),
      (Symbols.person_add, 'New this month', '${o.newUsersMonth}', AppColors.tertiary),
      (Symbols.workspace_premium, 'Premium', '${o.premiumUsers}', AppColors.tertiary),
      (Symbols.verified, 'Experts', '${o.experts}', AppColors.primary),
      (Symbols.agriculture, 'Farms', '${o.totalFarms}', AppColors.secondary),
      (Symbols.psychiatry, 'Diagnoses', '${o.totalDiagnoses}', AppColors.primary),
      (Symbols.today, 'Diagnoses (mo)', '${o.diagnosesMonth}', AppColors.primary),
      (Symbols.bolt, 'AI calls (mo)', '${o.aiCallsMonth}', AppColors.tertiary),
      (Symbols.forum, 'Posts', '${o.totalPosts}', AppColors.secondary),
      (Symbols.chat, 'Comments', '${o.totalComments}', AppColors.secondary),
      (Symbols.coronavirus, 'Active diseases', '${o.activeDiseases}', AppColors.error),
      (Symbols.chat_bubble, 'Chat calls', '${o.totalChats}', AppColors.primary),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 1.5,
      children: [for (final s in stats) _StatCard(icon: s.$1, label: s.$2, value: s.$3, color: s.$4)],
    );
  }
}

class _StatCard extends StatelessWidget {
  const _StatCard(
      {required this.icon, required this.label, required this.value, required this.color});
  final IconData icon;
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Icon(icon, color: color, size: 22),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(value,
                  style: AppText.headlineSm.copyWith(color: color),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis),
              Text(label, style: AppText.labelSm, maxLines: 1, overflow: TextOverflow.ellipsis),
            ],
          ),
        ],
      ),
    );
  }
}

class _Leaderboard extends StatelessWidget {
  const _Leaderboard({required this.title, required this.icon, required this.rows});
  final String title;
  final IconData icon;
  final List<NamedCount> rows;

  @override
  Widget build(BuildContext context) {
    final max = rows.fold<int>(1, (m, r) => r.count > m ? r.count : m);
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerLowest,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, size: 20, color: AppColors.primary),
            const SizedBox(width: 8),
            Text(title, style: AppText.labelMd),
          ]),
          const SizedBox(height: 12),
          for (final r in rows)
            Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(children: [
                    Expanded(child: Text(r.name, style: AppText.bodyMd, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    Text('${r.count}', style: AppText.labelMd),
                  ]),
                  const SizedBox(height: 4),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: r.count / max,
                      minHeight: 6,
                      backgroundColor: AppColors.surfaceContainerHigh,
                      valueColor: const AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _ManagementGrid extends StatelessWidget {
  const _ManagementGrid();

  @override
  Widget build(BuildContext context) {
    // Modules are wired in as each is built; a null destination = upcoming.
    final modules = <(IconData, String, Widget?)>[
      (Symbols.manage_accounts, 'Users & Roles', const AdminUsersScreen()),
      (Symbols.medication, 'Medicines', const AdminMedicinesScreen()),
      (Symbols.coronavirus, 'Disease Database', const AdminDiseasesScreen()),
      (Symbols.menu_book, 'Knowledge Base', const ArticlesScreen(mode: KbMode.admin)),
      (Symbols.shield_person, 'Moderation', const AdminModerationScreen()),
      (Symbols.workspace_premium, 'Subscriptions', const AdminSubscriptionsScreen()),
      (Symbols.bolt, 'AI Credits', const AdminSubscriptionsScreen()),
      (Symbols.campaign, 'Notifications', const AdminNotificationsScreen()),
      (Symbols.receipt_long, 'Audit Logs', const AdminAuditLogsScreen()),
      (Symbols.feedback, 'Feedback', const AdminFeedbackScreen()),
      (Symbols.settings, 'System Settings', const AdminSettingsScreen()),
    ];
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.4,
      children: [
        for (final m in modules)
          Material(
            color: AppColors.surfaceContainerLowest,
            borderRadius: BorderRadius.circular(14),
            child: InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                if (m.$3 != null) {
                  Navigator.of(context)
                      .push(MaterialPageRoute(builder: (_) => m.$3!));
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('${m.$2} — coming next')));
                }
              },
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.outlineVariant),
                ),
                child: Row(
                  children: [
                    Icon(m.$1, size: 22, color: AppColors.primary),
                    const SizedBox(width: 10),
                    Expanded(
                        child: Text(m.$2,
                            style: AppText.labelMd,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis)),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

class _LoadingSkeleton extends StatelessWidget {
  const _LoadingSkeleton();
  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        for (var i = 0; i < 6; i++)
          Container(
            height: 70,
            margin: const EdgeInsets.only(bottom: 12),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(16),
            ),
          ),
      ],
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.error});
  final String error;
  @override
  Widget build(BuildContext context) {
    final denied = error.contains('42501') || error.toLowerCase().contains('authorized');
    return ListView(
      children: [
        const SizedBox(height: 120),
        Icon(denied ? Symbols.lock : Symbols.error, size: 56, color: AppColors.outline),
        const SizedBox(height: 12),
        Center(
            child: Text(denied ? 'Admins only' : 'Could not load the dashboard',
                style: AppText.headlineSm)),
        const SizedBox(height: 8),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Text(
            denied
                ? 'Your account does not have admin access.'
                : error,
            textAlign: TextAlign.center,
            style: AppText.labelSm,
          ),
        ),
      ],
    );
  }
}
