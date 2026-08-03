import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/widgets/confirm_dialog.dart';
import '../../../models/farm.dart';
import '../../dashboard/data/dashboard_repository.dart';
import '../../expenses/data/expense_repository.dart';
import '../../expenses/presentation/add_expense_screen.dart';
import '../../harvests/data/harvest_repository.dart';
import '../../harvests/presentation/add_harvest_screen.dart';
import '../../profile/data/profile_repository.dart';
import '../../sales/data/sales_repository.dart';
import '../../sales/presentation/add_sale_screen.dart';

/// History of all records for the user's farm, grouped into tabs, each with
/// per-item edit and delete.
class RecordsScreen extends ConsumerWidget {
  const RecordsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final farm = ref.watch(activeFarmProvider);
    final t = ref.watch(stringsProvider);

    return DefaultTabController(
      length: 3,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: Text(t.records),
          bottom: TabBar(
            tabs: [
              Tab(text: t.tabExpenses),
              Tab(text: t.tabHarvests),
              Tab(text: t.tabSales),
            ],
          ),
        ),
        body: farm == null
            ? Center(child: Text(t.createFarmToSeeRecords))
            : TabBarView(
                children: [
                  _ExpensesTab(farm: farm),
                  _HarvestsTab(farm: farm),
                  _SalesTab(farm: farm),
                ],
              ),
      ),
    );
  }
}

class _ExpensesTab extends ConsumerWidget {
  const _ExpensesTab({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final expenses = ref.watch(expensesForFarmProvider(farm.id));
    final t = ref.watch(stringsProvider);
    return expenses.when(
      loading: () => const _Loading(),
      error: (e, _) => _ErrorState('$e'),
      data: (list) => list.isEmpty
          ? _EmptyState(t.noExpenses)
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(expensesForFarmProvider(farm.id)),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final e = list[i];
                  return _RecordTile(
                    icon: Symbols.shopping_cart,
                    iconBg: AppColors.errorContainer,
                    iconFg: AppColors.onErrorContainer,
                    title: e.title,
                    subtitle: _sub(e.date, e.supplier),
                    trailing: '-${formatMoney(e.totalCost)}',
                    trailingColor: AppColors.error,
                    onEdit: () => _push(context, AddExpenseScreen(existing: e)),
                    onDelete: () => _delete(
                      context,
                      ref,
                      onConfirm: () async {
                        await ref
                            .read(expenseRepositoryProvider)
                            .deleteExpense(e.id);
                        ref.invalidate(expensesForFarmProvider(farm.id));
                        ref.invalidate(farmSummaryProvider);
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _HarvestsTab extends ConsumerWidget {
  const _HarvestsTab({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final harvests = ref.watch(harvestsForFarmProvider(farm.id));
    final t = ref.watch(stringsProvider);
    return harvests.when(
      loading: () => const _Loading(),
      error: (e, _) => _ErrorState('$e'),
      data: (list) => list.isEmpty
          ? _EmptyState(t.noHarvests)
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(harvestsForFarmProvider(farm.id)),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final h = list[i];
                  return _RecordTile(
                    icon: Symbols.agriculture,
                    iconBg: AppColors.primaryFixed,
                    iconFg: AppColors.onPrimaryFixed,
                    title: h.title,
                    subtitle: _sub(
                        h.date, h.grade == null ? null : '${t.grade} ${h.grade}'),
                    trailing: '${_qty(h.quantity)} ${h.unit}',
                    trailingColor: AppColors.primary,
                    onEdit: () => _push(context, AddHarvestScreen(existing: h)),
                    onDelete: () => _delete(
                      context,
                      ref,
                      onConfirm: () async {
                        await ref
                            .read(harvestRepositoryProvider)
                            .deleteHarvest(h.id);
                        ref.invalidate(harvestsForFarmProvider(farm.id));
                        ref.invalidate(farmSummaryProvider);
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

class _SalesTab extends ConsumerWidget {
  const _SalesTab({required this.farm});
  final Farm farm;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final sales = ref.watch(salesForFarmProvider(farm.id));
    final t = ref.watch(stringsProvider);
    return sales.when(
      loading: () => const _Loading(),
      error: (e, _) => _ErrorState('$e'),
      data: (list) => list.isEmpty
          ? _EmptyState(t.noSales)
          : RefreshIndicator(
              onRefresh: () async =>
                  ref.invalidate(salesForFarmProvider(farm.id)),
              child: ListView.builder(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 32),
                itemCount: list.length,
                itemBuilder: (_, i) {
                  final s = list[i];
                  return _RecordTile(
                    icon: Symbols.sell,
                    iconBg: AppColors.secondaryContainer,
                    iconFg: AppColors.onSecondaryContainer,
                    title: s.title,
                    subtitle: _sub(s.date, s.customer),
                    trailing: '+${formatMoney(s.totalPrice)}',
                    trailingColor: AppColors.primary,
                    onEdit: () => _push(context, AddSaleScreen(existing: s)),
                    onDelete: () => _delete(
                      context,
                      ref,
                      onConfirm: () async {
                        await ref.read(salesRepositoryProvider).deleteSale(s.id);
                        ref.invalidate(salesForFarmProvider(farm.id));
                        ref.invalidate(farmSummaryProvider);
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}

String _sub(DateTime date, String? extra) {
  final d = DateFormat('EEE, d MMM yyyy').format(date);
  return (extra != null && extra.isNotEmpty) ? '$d · $extra' : d;
}

String _qty(num q) =>
    q == q.roundToDouble() ? q.toStringAsFixed(0) : q.toString();

void _push(BuildContext context, Widget screen) {
  Navigator.of(context).push(MaterialPageRoute(builder: (_) => screen));
}

Future<void> _delete(
  BuildContext context,
  WidgetRef ref, {
  required Future<void> Function() onConfirm,
}) async {
  final t = ref.read(stringsProvider);
  final ok = await confirmDelete(context,
      title: t.deleteRecordQ, message: t.deleteRecordBody);
  if (ok != true) return;
  try {
    await onConfirm();
  } catch (_) {
    if (context.mounted) {
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text(t.couldNotDelete)));
    }
  }
}

class _RecordTile extends StatelessWidget {
  const _RecordTile({
    required this.icon,
    required this.iconBg,
    required this.iconFg,
    required this.title,
    required this.subtitle,
    required this.trailing,
    required this.trailingColor,
    required this.onEdit,
    required this.onDelete,
  });

  final IconData icon;
  final Color iconBg;
  final Color iconFg;
  final String title;
  final String subtitle;
  final String trailing;
  final Color trailingColor;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.fromLTRB(16, 8, 4, 8),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.outlineVariant),
      ),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(color: iconBg, shape: BoxShape.circle),
            child: Icon(icon, size: 20, color: iconFg),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.bodyMd.copyWith(fontWeight: FontWeight.w600)),
                Text(subtitle,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppText.labelSm
                        .copyWith(color: AppColors.onSurfaceVariant)),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Text(trailing,
              style: AppText.labelMd
                  .copyWith(color: trailingColor, fontWeight: FontWeight.w700)),
          PopupMenuButton<String>(
            icon: const Icon(Symbols.more_vert, color: AppColors.onSurfaceVariant),
            onSelected: (v) => v == 'edit' ? onEdit() : onDelete(),
            itemBuilder: (_) => const [
              PopupMenuItem(value: 'edit', child: Text('Edit')),
              PopupMenuItem(value: 'delete', child: Text('Delete')),
            ],
          ),
        ],
      ),
    );
  }
}

class _Loading extends StatelessWidget {
  const _Loading();
  @override
  Widget build(BuildContext context) =>
      const Center(child: CircularProgressIndicator());
}

class _EmptyState extends StatelessWidget {
  const _EmptyState(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(message,
              textAlign: TextAlign.center,
              style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
        ),
      );
}

class _ErrorState extends StatelessWidget {
  const _ErrorState(this.message);
  final String message;
  @override
  Widget build(BuildContext context) => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text('Could not load records.\n$message',
              textAlign: TextAlign.center,
              style: AppText.bodyMd.copyWith(color: AppColors.onSurfaceVariant)),
        ),
      );
}
