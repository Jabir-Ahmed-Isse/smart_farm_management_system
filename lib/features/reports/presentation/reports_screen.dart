import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:material_symbols_icons/symbols.dart';

import '../../../core/format.dart';
import '../../../core/l10n/l10n.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../models/farm_report.dart';
import '../../profile/data/profile_repository.dart';
import '../data/report_export.dart';
import '../data/reports_repository.dart';

enum _Preset { thisMonth, last3, thisYear, allTime }

extension on _Preset {
  String get label => switch (this) {
        _Preset.thisMonth => 'This month',
        _Preset.last3 => 'Last 3 months',
        _Preset.thisYear => 'This year',
        _Preset.allTime => 'All time',
      };

  (DateTime, DateTime) range() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day);
    return switch (this) {
      _Preset.thisMonth => (DateTime(now.year, now.month), end),
      _Preset.last3 => (DateTime(now.year, now.month - 2), end),
      _Preset.thisYear => (DateTime(now.year), end),
      _Preset.allTime => (DateTime(2015), end),
    };
  }
}

/// Reports & analytics — charts over a chosen period, with PDF/Excel export.
class ReportsScreen extends ConsumerStatefulWidget {
  const ReportsScreen({super.key});

  @override
  ConsumerState<ReportsScreen> createState() => _ReportsScreenState();
}

class _ReportsScreenState extends ConsumerState<ReportsScreen> {
  _Preset _preset = _Preset.thisYear;
  bool _exporting = false;

  @override
  Widget build(BuildContext context) {
    final farm = ref.watch(activeFarmProvider);

    if (farm == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: Text(ref.watch(stringsProvider).reports)),
        body: const Center(child: Text('Create a farm to see reports.')),
      );
    }

    final (start, end) = _preset.range();
    final report = ref.watch(
        farmReportProvider((farmId: farm.id, start: start, end: end)));

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Reports'),
        backgroundColor: AppColors.background,
      ),
      body: Column(
        children: [
          _presetBar(),
          Expanded(
            child: report.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text('Could not build the report.\n$e',
                      textAlign: TextAlign.center, style: AppText.labelSm),
                ),
              ),
              data: (r) => r.isEmpty ? _empty() : _Report(report: r),
            ),
          ),
        ],
      ),
      bottomNavigationBar: report.valueOrNull == null ||
              report.value!.isEmpty
          ? null
          : _exportBar(report.value!),
    );
  }

  Widget _presetBar() {
    return SizedBox(
      height: 52,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        children: [
          for (final p in _Preset.values)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: ChoiceChip(
                label: Text(p.label),
                selected: _preset == p,
                onSelected: (_) => setState(() => _preset = p),
              ),
            ),
        ],
      ),
    );
  }

  Widget _empty() => Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Symbols.bar_chart, size: 56, color: AppColors.outline),
              const SizedBox(height: 12),
              Text('No data in this period', style: AppText.headlineSm),
              const SizedBox(height: 6),
              Text('Record expenses, harvests or sales to see reports.',
                  textAlign: TextAlign.center,
                  style: AppText.bodyMd
                      .copyWith(color: AppColors.onSurfaceVariant)),
            ],
          ),
        ),
      );

  Widget _exportBar(FarmReport r) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
        child: Row(
          children: [
            Expanded(
              child: OutlinedButton.icon(
                onPressed: _exporting ? null : () => _export(() => ReportExporter.exportPdf(r), 'PDF'),
                icon: const Icon(Symbols.picture_as_pdf),
                label: Text(ref.watch(stringsProvider).exportPdf),
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: FilledButton.icon(
                onPressed: _exporting ? null : () => _export(() => ReportExporter.exportExcel(r), 'Excel'),
                icon: _exporting
                    ? const SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Icon(Symbols.table_view),
                label: Text(ref.watch(stringsProvider).exportExcel),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _export(Future<void> Function() run, String kind) async {
    setState(() => _exporting = true);
    try {
      await run();
      if (mounted) _snack('$kind report exported.');
    } catch (e) {
      if (mounted) _snack('Could not export $kind: $e');
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _snack(String m) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
}

// ============================================================ report body

class _Report extends StatelessWidget {
  const _Report({required this.report});
  final FarmReport report;

  static const _palette = [
    AppColors.primary,
    AppColors.tertiary,
    AppColors.secondary,
    Color(0xFF2E7D32),
    Color(0xFFB45000),
    Color(0xFF7A5649),
    AppColors.outline,
  ];

  @override
  Widget build(BuildContext context) {
    final r = report;
    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
      children: [
        _summaryTiles(r),
        const SizedBox(height: 20),
        if (r.monthly.length > 1) ...[
          _card('Revenue vs expenses', _monthlyChart(r)),
          const SizedBox(height: 16),
        ],
        if (r.byCategory.isNotEmpty) ...[
          _card('Expenses by category', _categorySection(r)),
          const SizedBox(height: 16),
        ],
        if (r.crops.isNotEmpty) ...[
          _card('Crop performance', _cropSection(r)),
          const SizedBox(height: 16),
        ],
        if (r.harvests.isNotEmpty)
          _card('Harvest summary', _harvestSection(r)),
      ],
    );
  }

  Widget _summaryTiles(FarmReport r) {
    return Column(
      children: [
        Row(
          children: [
            Expanded(
                child: _tile('Revenue', formatMoney(r.revenue),
                    AppColors.primary, Symbols.trending_up)),
            const SizedBox(width: 12),
            Expanded(
                child: _tile('Expenses', formatMoney(r.expenses),
                    AppColors.error, Symbols.trending_down)),
          ],
        ),
        const SizedBox(height: 12),
        Row(
          children: [
            Expanded(
                child: _tile(
                    'Net profit',
                    formatMoney(r.profit),
                    r.profit >= 0 ? AppColors.primary : AppColors.error,
                    Symbols.payments)),
            const SizedBox(width: 12),
            Expanded(
                child: _tile('Margin', '${(r.margin * 100).toStringAsFixed(1)}%',
                    AppColors.tertiary, Symbols.percent)),
          ],
        ),
      ],
    );
  }

  Widget _tile(String label, String value, Color color, IconData icon) {
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
          Icon(icon, color: color, size: 22),
          const SizedBox(height: 8),
          Text(value,
              style: AppText.headlineSm.copyWith(color: color),
              maxLines: 1,
              overflow: TextOverflow.ellipsis),
          Text(label, style: AppText.labelSm),
        ],
      ),
    );
  }

  Widget _card(String title, Widget child) {
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
          Text(title, style: AppText.labelMd),
          const SizedBox(height: 16),
          child,
        ],
      ),
    );
  }

  Widget _monthlyChart(FarmReport r) {
    final maxY = r.monthly.fold<double>(1, (m, p) {
      final hi = (p.revenue > p.expenses ? p.revenue : p.expenses).toDouble();
      return hi > m ? hi : m;
    });
    return Column(
      children: [
        SizedBox(
          height: 200,
          child: BarChart(
            BarChartData(
              maxY: maxY * 1.2,
              barTouchData: BarTouchData(enabled: false),
              gridData: const FlGridData(show: true, drawVerticalLine: false),
              borderData: FlBorderData(show: false),
              titlesData: FlTitlesData(
                topTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                rightTitles:
                    const AxisTitles(sideTitles: SideTitles(showTitles: false)),
                leftTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    reservedSize: 40,
                    getTitlesWidget: (v, _) => Text(
                        formatMoneyCompact(v),
                        style: AppText.labelSm.copyWith(fontSize: 9)),
                  ),
                ),
                bottomTitles: AxisTitles(
                  sideTitles: SideTitles(
                    showTitles: true,
                    getTitlesWidget: (v, _) {
                      final i = v.toInt();
                      if (i < 0 || i >= r.monthly.length) {
                        return const SizedBox.shrink();
                      }
                      return Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(r.monthly[i].label,
                            style: AppText.labelSm.copyWith(fontSize: 9)),
                      );
                    },
                  ),
                ),
              ),
              barGroups: [
                for (var i = 0; i < r.monthly.length; i++)
                  BarChartGroupData(x: i, barRods: [
                    BarChartRodData(
                        toY: r.monthly[i].revenue.toDouble(),
                        color: AppColors.primary,
                        width: 7,
                        borderRadius: BorderRadius.circular(2)),
                    BarChartRodData(
                        toY: r.monthly[i].expenses.toDouble(),
                        color: AppColors.error,
                        width: 7,
                        borderRadius: BorderRadius.circular(2)),
                  ]),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            _legend(AppColors.primary, 'Revenue'),
            const SizedBox(width: 20),
            _legend(AppColors.error, 'Expenses'),
          ],
        ),
      ],
    );
  }

  Widget _categorySection(FarmReport r) {
    final total = r.byCategory.fold<num>(0, (a, c) => a + c.amount);
    return Row(
      children: [
        SizedBox(
          width: 130,
          height: 130,
          child: PieChart(
            PieChartData(
              sectionsSpace: 2,
              centerSpaceRadius: 30,
              sections: [
                for (var i = 0; i < r.byCategory.length; i++)
                  PieChartSectionData(
                    value: r.byCategory[i].amount.toDouble(),
                    color: _palette[i % _palette.length],
                    radius: 32,
                    showTitle: false,
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 16),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              for (var i = 0; i < r.byCategory.length && i < 6; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Row(
                    children: [
                      _legend(_palette[i % _palette.length], ''),
                      const SizedBox(width: 8),
                      Expanded(
                          child: Text(r.byCategory[i].name,
                              style: AppText.labelSm,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis)),
                      Text(
                        total == 0
                            ? ''
                            : '${(r.byCategory[i].amount / total * 100).round()}%',
                        style: AppText.labelSm,
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _cropSection(FarmReport r) {
    final maxAbs = r.crops.fold<double>(
        1, (m, c) => c.profit.abs() > m ? c.profit.abs().toDouble() : m);
    return Column(
      children: [
        for (final c in r.crops)
          Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(c.crop, style: AppText.labelMd)),
                    Text(formatMoney(c.profit),
                        style: AppText.labelMd.copyWith(
                            color: c.profit >= 0
                                ? AppColors.primary
                                : AppColors.error)),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: (c.profit.abs() / maxAbs).clamp(0, 1).toDouble(),
                    minHeight: 6,
                    backgroundColor: AppColors.surfaceContainerHigh,
                    valueColor: AlwaysStoppedAnimation(
                        c.profit >= 0 ? AppColors.primary : AppColors.error),
                  ),
                ),
                Text('Rev ${formatMoney(c.revenue)} · Exp ${formatMoney(c.expenses)}',
                    style: AppText.labelSm),
              ],
            ),
          ),
      ],
    );
  }

  Widget _harvestSection(FarmReport r) {
    return Column(
      children: [
        for (final h in r.harvests)
          Padding(
            padding: const EdgeInsets.symmetric(vertical: 4),
            child: Row(
              children: [
                const Icon(Symbols.eco, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(child: Text(h.crop, style: AppText.bodyMd)),
                Text('${h.quantity} ${h.unit}', style: AppText.labelMd),
              ],
            ),
          ),
      ],
    );
  }

  Widget _legend(Color color, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 12,
          height: 12,
          decoration:
              BoxDecoration(color: color, borderRadius: BorderRadius.circular(3)),
        ),
        if (label.isNotEmpty) ...[
          const SizedBox(width: 6),
          Text(label, style: AppText.labelSm),
        ],
      ],
    );
  }
}
