import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../core/format.dart';
import '../../core/l10n/l10n.dart';
import '../../core/theme/app_colors.dart';
import '../../core/theme/app_text_styles.dart';
import '../../models/crop.dart';
import '../../models/farm.dart';
import '../journey/presentation/crop_journey_screen.dart';
import '../notifications/data/notifications_repository.dart';
import '../profile/data/profile_repository.dart';
import '../records/presentation/records_screen.dart';
import 'data/dashboard_repository.dart';

/// Home dashboard — implements the Stitch "Farm Dashboard" design.
/// Greeting, farm, financials, active crops and recent activity are all live
/// from Supabase for the user's first farm.
class DashboardScreen extends ConsumerWidget {
  const DashboardScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profile = ref.watch(myProfileProvider);

    final name = profile.valueOrNull?.fullName?.split(' ').first ?? 'Farmer';
    final farm = ref.watch(activeFarmProvider);

    final summary =
        farm == null ? null : ref.watch(farmSummaryProvider(farm.id));
    final t = ref.watch(stringsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () async {
            ref.invalidate(myProfileProvider);
            ref.invalidate(myFarmsProvider);
            if (farm != null) ref.invalidate(farmSummaryProvider(farm.id));
          },
          child: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _Header(name: name, greeting: t.welcomeBack),
              const SizedBox(height: 24),
              _FinancialCard(summary: summary),
              const SizedBox(height: 24),
              Text(t.quickActions, style: AppText.headlineSm),
              const SizedBox(height: 16),
              const _QuickActions(),
              const SizedBox(height: 24),
              Text(t.activeCrops, style: AppText.headlineSm),
              const SizedBox(height: 16),
              _ActiveCrops(summary: summary),
              const SizedBox(height: 24),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(t.recentActivity, style: AppText.headlineSm),
                  if (farm != null)
                    InkWell(
                      onTap: () => Navigator.of(context).push(
                        MaterialPageRoute(
                            builder: (_) => const RecordsScreen()),
                      ),
                      child: Text(t.viewAll,
                          style: AppText.labelMd
                              .copyWith(color: AppColors.primary)),
                    ),
                ],
              ),
              const SizedBox(height: 16),
              _RecentActivity(summary: summary),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends ConsumerWidget {
  const _Header({required this.name, required this.greeting});
  final String name;
  final String greeting;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farms = ref.watch(myFarmsProvider).valueOrNull ?? const <Farm>[];
    final active = ref.watch(activeFarmProvider);
    final farmName = active?.name ?? 'Your Farm';
    // Only a farmer with more than one farm needs the switcher.
    final canSwitch = farms.length > 1;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(greeting,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
              Text(name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppText.headlineLgMobile),
            ],
          ),
        ),
        const _NotificationBell(),
        const SizedBox(width: 2),
        Flexible(
          child: InkWell(
            borderRadius: BorderRadius.circular(999),
            onTap: canSwitch ? () => _pickFarm(context, ref, farms, active) : null,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainerLow,
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Flexible(
                    child: Text(farmName,
                        overflow: TextOverflow.ellipsis,
                        style:
                            AppText.labelMd.copyWith(color: AppColors.primary)),
                  ),
                  if (canSwitch)
                    const Icon(Symbols.expand_more,
                        size: 20, color: AppColors.primary),
                ],
              ),
            ),
          ),
        ),
      ],
    );
  }

  void _pickFarm(
      BuildContext context, WidgetRef ref, List<Farm> farms, Farm? active) {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: AppColors.surfaceContainerLowest,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text('Choose farm', style: AppText.headlineSm),
            ),
            for (final f in farms)
              ListTile(
                leading: Icon(
                  f.id == active?.id
                      ? Symbols.check_circle
                      : Symbols.agriculture,
                  color:
                      f.id == active?.id ? AppColors.primary : AppColors.outline,
                ),
                title: Text(f.name, style: AppText.bodyMd),
                subtitle: (f.region ?? '').isEmpty
                    ? null
                    : Text(f.region!, style: AppText.labelSm),
                onTap: () {
                  ref.read(selectedFarmIdProvider.notifier).state = f.id;
                  Navigator.pop(context);
                },
              ),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }
}

/// Bell in the dashboard header — opens the announcements inbox and shows a
/// badge with the count of unseen announcements.
class _NotificationBell extends ConsumerWidget {
  const _NotificationBell();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final unread = ref.watch(unreadNotificationsProvider).valueOrNull ?? 0;
    return IconButton(
      onPressed: () => context.push('/notifications'),
      padding: EdgeInsets.zero,
      visualDensity: VisualDensity.compact,
      constraints: const BoxConstraints.tightFor(width: 40, height: 40),
      icon: Badge(
        isLabelVisible: unread > 0,
        label: Text('$unread'),
        child: const Icon(Symbols.notifications),
      ),
      tooltip: 'Announcements',
    );
  }
}

class _FinancialCard extends ConsumerWidget {
  const _FinancialCard({required this.summary});

  /// null when the user has no farm yet.
  final AsyncValue<FarmSummary>? summary;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final t = ref.watch(stringsProvider);
    final s = summary?.valueOrNull;
    final loading = summary?.isLoading ?? false;
    final margin = s?.margin;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
        boxShadow: const [
          BoxShadow(
              color: Color(0x14000000), blurRadius: 12, offset: Offset(0, 4)),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(t.netProfit,
                        style: AppText.labelMd.copyWith(
                            color: AppColors.onSurfaceVariant,
                            letterSpacing: 0.5)),
                    const SizedBox(height: 4),
                    if (loading && s == null)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 6),
                        child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2)),
                      )
                    else
                      Text(
                        formatMoney(s?.profit ?? 0),
                        style: AppText.headlineLgMobile.copyWith(
                            color: (s?.profit ?? 0) < 0
                                ? AppColors.error
                                : AppColors.primary),
                      ),
                  ],
                ),
              ),
              if (margin != null) _MarginBadge(margin: margin),
            ],
          ),
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Divider(),
          ),
          Row(
            children: [
              Expanded(
                child: _Metric(
                    label: t.totalRevenue,
                    value: formatMoney(s?.revenue ?? 0),
                    color: AppColors.onSurface),
              ),
              Expanded(
                child: _Metric(
                    label: t.totalExpenses,
                    value: formatMoney(s?.expenses ?? 0),
                    color: AppColors.error),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MarginBadge extends StatelessWidget {
  const _MarginBadge({required this.margin});
  final double margin;

  @override
  Widget build(BuildContext context) {
    final positive = margin >= 0;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        color: positive ? AppColors.primaryFixed : AppColors.errorContainer,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        children: [
          Icon(positive ? Symbols.trending_up : Symbols.trending_down,
              size: 16,
              color: positive
                  ? AppColors.onPrimaryFixed
                  : AppColors.onErrorContainer),
          const SizedBox(width: 4),
          Text('${positive ? '+' : ''}${margin.toStringAsFixed(0)}%',
              style: AppText.labelSm.copyWith(
                  color: positive
                      ? AppColors.onPrimaryFixed
                      : AppColors.onErrorContainer)),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  const _Metric({required this.label, required this.value, required this.color});
  final String label;
  final String value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label,
            style: AppText.labelSm.copyWith(color: AppColors.onSurfaceVariant)),
        const SizedBox(height: 4),
        Text(value, style: AppText.headlineSm.copyWith(color: color)),
      ],
    );
  }
}

class _QuickActions extends ConsumerStatefulWidget {
  const _QuickActions();

  @override
  ConsumerState<_QuickActions> createState() => _QuickActionsState();
}

class _QuickActionsState extends ConsumerState<_QuickActions> {
  bool _expanded = false;

  // Featured on the home screen by default, in this display order. Everything
  // else is hidden behind "Show more".
  static const _featured = <String>[
    '/add-expense',
    '/add-harvest',
    '/add-sale',
    '/reports',
    '/assistant',
  ];

  @override
  Widget build(BuildContext context) {
    final t = ref.watch(stringsProvider);
    // (icon, label, bg, fg, route) — a null route means "not built yet".
    final actions = <(IconData, String, Color, Color, String?)>[
      (Symbols.receipt_long, t.addExpense, AppColors.errorContainer,
          AppColors.onErrorContainer, '/add-expense'),
      (Symbols.eco, t.addHarvest, AppColors.tertiaryContainer,
          AppColors.onTertiaryContainer, '/add-harvest'),
      (Symbols.sell, t.recordSale, AppColors.primaryContainer,
          AppColors.onPrimaryContainer, '/add-sale'),
      (Symbols.task_alt, t.tasks, AppColors.secondaryContainer,
          AppColors.onSecondaryContainer, '/tasks'),
      (Symbols.groups, t.workers, AppColors.secondaryContainer,
          AppColors.onSecondaryContainer, '/workers'),
      (Symbols.agriculture, t.equipment, AppColors.secondaryContainer,
          AppColors.onSecondaryContainer, '/equipment'),
      (Symbols.water_drop, t.water, AppColors.secondaryContainer,
          AppColors.onSecondaryContainer, '/water'),
      (Symbols.partly_cloudy_day, t.weather, AppColors.tertiaryContainer,
          AppColors.onTertiaryContainer, '/weather'),
      (Symbols.potted_plant, t.nursery, AppColors.secondaryContainer,
          AppColors.onSecondaryContainer, '/nursery'),
      (Symbols.pets, t.livestock, AppColors.secondaryContainer,
          AppColors.onSecondaryContainer, '/livestock'),
      (Symbols.pest_control, t.pests, AppColors.errorContainer,
          AppColors.onErrorContainer, '/pests'),
      (Symbols.map, t.farmMap, AppColors.secondaryContainer,
          AppColors.onSecondaryContainer, '/map'),
      (Symbols.inventory_2, t.inventory, AppColors.secondaryContainer,
          AppColors.onSecondaryContainer, '/inventory'),
      (Symbols.receipt, t.records, AppColors.surfaceContainerHigh,
          AppColors.onSurface, '/records'),
      (Symbols.bar_chart, t.reports, AppColors.tertiaryContainer,
          AppColors.onTertiaryContainer, '/reports'),
      (Symbols.psychiatry, t.aiPlantDoctor, AppColors.primaryContainer,
          AppColors.onPrimaryContainer, '/plant-doctor'),
      (Symbols.smart_toy, t.aiAssistant, AppColors.primaryContainer,
          AppColors.onPrimaryContainer, '/assistant'),
      (Symbols.auto_awesome, t.aiInsights, AppColors.primaryContainer,
          AppColors.onPrimaryContainer, '/insights'),
      (Symbols.monitoring, t.aiAnalytics, AppColors.primaryContainer,
          AppColors.onPrimaryContainer, '/ai-analytics'),
      (Symbols.menu_book, t.knowledge, AppColors.primaryContainer,
          AppColors.onPrimaryContainer, '/knowledge'),
      (Symbols.school, 'Learn', AppColors.primaryContainer,
          AppColors.onPrimaryContainer, '/knowledge-hub'),
    ];

    // Split into the featured actions (in the requested order) and the rest,
    // so the home screen stays focused until the user taps "Show more".
    final byRoute = {for (final a in actions) a.$5: a};
    final featured = [
      for (final r in _featured)
        if (byRoute[r] != null) byRoute[r]!,
    ];
    final rest = [
      for (final a in actions)
        if (!_featured.contains(a.$5)) a,
    ];
    final shown = _expanded
        ? <(IconData, String, Color, Color, String?)>[...featured, ...rest]
        : featured;

    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 16,
      crossAxisSpacing: 16,
      childAspectRatio: 1.6,
      children: [
        for (final a in shown)
          _tile(a.$1, a.$2, a.$3, a.$4, () {
            if (a.$5 != null) {
              context.push(a.$5!);
            } else {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(content: Text('${a.$2} — coming soon')),
              );
            }
          }),
        // Trailing toggle: reveal / hide the remaining features.
        _tile(
          _expanded ? Symbols.expand_less : Symbols.apps,
          _expanded ? (t.isSo ? 'Muuji wax yar' : 'Show less')
                    : (t.isSo ? 'Muuji dheeraad' : 'Show more'),
          AppColors.primaryContainer,
          AppColors.onPrimaryContainer,
          () => setState(() => _expanded = !_expanded),
        ),
      ],
    );
  }

  Widget _tile(IconData icon, String label, Color bg, Color fg,
      VoidCallback onTap) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.outlineVariant),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
                child: Icon(icon, color: fg),
              ),
              const SizedBox(height: 8),
              Text(label, style: AppText.labelMd, textAlign: TextAlign.center),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveCrops extends StatelessWidget {
  const _ActiveCrops({required this.summary});
  final AsyncValue<FarmSummary>? summary;

  @override
  Widget build(BuildContext context) {
    if (summary?.isLoading ?? false) {
      return const SizedBox(
          height: 120, child: Center(child: CircularProgressIndicator()));
    }
    final crops = summary?.valueOrNull?.activeCrops ?? const <Crop>[];
    if (crops.isEmpty) {
      return const _EmptyCard(
        icon: Symbols.eco,
        message: 'No active crops yet.',
      );
    }

    return SizedBox(
      height: 128,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        itemCount: crops.length,
        separatorBuilder: (_, __) => const SizedBox(width: 16),
        itemBuilder: (_, i) {
          final c = crops[i];
          final progress = cropStageProgress(c.stage);
          return Material(
            color: Colors.transparent,
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: () => Navigator.of(context).push(MaterialPageRoute(
                  builder: (_) => CropJourneyScreen(cropId: c.id))),
              child: Container(
            width: 260,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.outlineVariant),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(c.name,
                              style: AppText.headlineSm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
                          if (c.variety != null && c.variety!.isNotEmpty)
                            Text(c.variety!,
                                style: AppText.labelSm.copyWith(
                                    color: AppColors.onSurfaceVariant)),
                        ],
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: AppColors.primaryFixed,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(c.stage.toUpperCase(),
                          style: AppText.labelSm.copyWith(
                              color: AppColors.onPrimaryFixed,
                              fontWeight: FontWeight.w700)),
                    ),
                  ],
                ),
                const Spacer(),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text('Growth Progress',
                        style: AppText.labelSm
                            .copyWith(color: AppColors.onSurfaceVariant)),
                    Text('${(progress * 100).round()}%',
                        style: AppText.labelSm
                            .copyWith(fontWeight: FontWeight.w600)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(999),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 8,
                    backgroundColor: AppColors.surfaceVariant,
                    valueColor:
                        const AlwaysStoppedAnimation(AppColors.primary),
                  ),
                ),
              ],
            ),
          )));
        },
      ),
    );
  }
}

class _RecentActivity extends StatelessWidget {
  const _RecentActivity({required this.summary});
  final AsyncValue<FarmSummary>? summary;

  @override
  Widget build(BuildContext context) {
    if (summary?.isLoading ?? false) {
      return const SizedBox(
          height: 80, child: Center(child: CircularProgressIndicator()));
    }
    final items = summary?.valueOrNull?.recentActivity ?? const <ActivityItem>[];
    if (items.isEmpty) {
      return const _EmptyCard(
        icon: Symbols.history,
        message: 'No activity yet. Log an expense or harvest to get started.',
      );
    }

    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          for (var i = 0; i < items.length; i++) ...[
            if (i > 0) const Divider(height: 1),
            _ActivityRow(items[i]),
          ],
        ],
      ),
    );
  }
}

class _ActivityRow extends StatelessWidget {
  const _ActivityRow(this.item);
  final ActivityItem item;

  @override
  Widget build(BuildContext context) {
    final (icon, bg, fg) = switch (item.type) {
      ActivityType.expense => (
          Symbols.shopping_cart,
          AppColors.errorContainer,
          AppColors.onErrorContainer
        ),
      ActivityType.harvest => (
          Symbols.agriculture,
          AppColors.primaryFixed,
          AppColors.onPrimaryFixed
        ),
      ActivityType.sale => (
          Symbols.sell,
          AppColors.secondaryContainer,
          AppColors.onSecondaryContainer
        ),
    };

    final (trailing, trailingColor) = switch (item.type) {
      ActivityType.expense => (
          '-${formatMoney(item.amount ?? 0)}',
          AppColors.error
        ),
      ActivityType.harvest => (
          '+${_qty(item.quantity)} ${item.unit ?? ''}'.trim(),
          AppColors.primary
        ),
      ActivityType.sale => (
          '+${formatMoney(item.amount ?? 0)}',
          AppColors.primary
        ),
    };

    return Padding(
      padding: const EdgeInsets.all(16),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: bg, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: fg),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style:
                        AppText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                Text(DateFormat('EEE, d MMM').format(item.date),
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          Text(trailing,
              style: AppText.labelMd
                  .copyWith(color: trailingColor, fontWeight: FontWeight.w700)),
        ],
      ),
    );
  }

  static String _qty(double? q) {
    if (q == null) return '0';
    return q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();
  }
}

class _EmptyCard extends StatelessWidget {
  const _EmptyCard({required this.icon, required this.message});
  final IconData icon;
  final String message;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 28, horizontal: 16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Column(
        children: [
          Icon(icon, color: AppColors.outline),
          const SizedBox(height: 8),
          Text(message,
              textAlign: TextAlign.center,
              style: AppText.labelMd
                  .copyWith(color: AppColors.onSurfaceVariant)),
        ],
      ),
    );
  }
}
