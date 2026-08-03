import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/expense.dart';
import '../../../models/farm_report.dart';
import '../../../models/harvest.dart';
import '../../../models/sale.dart';

final reportsRepositoryProvider = Provider<ReportsRepository>((ref) {
  return ReportsRepository(ref.watch(supabaseClientProvider));
});

/// The parameters that define a report: which farm, over which dates.
typedef ReportRange = ({String farmId, DateTime start, DateTime end});

class ReportsRepository {
  ReportsRepository(this._client);

  final SupabaseClient _client;

  static String _d(DateTime d) => DateFormat('yyyy-MM-dd').format(d);

  Future<FarmReport> build(ReportRange r) async {
    final startStr = _d(r.start);
    final endStr = _d(r.end);

    final farmRow = await _client
        .from('farms')
        .select('name')
        .eq('id', r.farmId)
        .maybeSingle();

    final expenseRows = await _client
        .from('expenses')
        .select('*, category:expense_categories(name_en)')
        .eq('farm_id', r.farmId)
        .gte('date', startStr)
        .lte('date', endStr);
    final saleRows = await _client
        .from('sales')
        .select('*, crop:crops(name)')
        .eq('farm_id', r.farmId)
        .gte('date', startStr)
        .lte('date', endStr);
    final harvestRows = await _client
        .from('harvests')
        .select('*, crop:crops(name)')
        .eq('farm_id', r.farmId)
        .gte('date', startStr)
        .lte('date', endStr);

    final expenses = expenseRows.map(Expense.fromMap).toList();
    final sales = saleRows.map(Sale.fromMap).toList();
    final harvests = harvestRows.map(Harvest.fromMap).toList();

    final revenue = sales.fold<num>(0, (a, s) => a + s.totalPrice);
    final expenseTotal = expenses.fold<num>(0, (a, e) => a + e.totalCost);

    return FarmReport(
      farmName: (farmRow?['name'] as String?) ?? 'Farm',
      start: r.start,
      end: r.end,
      revenue: revenue,
      expenses: expenseTotal,
      monthly: _monthly(r.start, r.end, sales, expenses),
      byCategory: _byCategory(expenses),
      crops: _cropPerformance(sales, expenses),
      harvests: _harvestRows(harvests),
      salesCount: sales.length,
      expenseCount: expenses.length,
      harvestCount: harvests.length,
    );
  }

  List<MonthlyPoint> _monthly(
      DateTime start, DateTime end, List<Sale> sales, List<Expense> expenses) {
    // Build a bucket per calendar month in the range (capped at 12 for a
    // readable chart), then fold rows into it.
    final buckets = <String, MonthlyPoint>{};
    final order = <String>[];
    var cursor = DateTime(start.year, start.month);
    final last = DateTime(end.year, end.month);
    while (!cursor.isAfter(last) && order.length < 12) {
      final key = DateFormat('yyyy-MM').format(cursor);
      order.add(key);
      buckets[key] = MonthlyPoint(
        label: DateFormat('MMM').format(cursor),
        month: cursor,
        revenue: 0,
        expenses: 0,
      );
      cursor = DateTime(cursor.year, cursor.month + 1);
    }

    num rev(String k) => buckets[k]?.revenue ?? 0;
    num exp(String k) => buckets[k]?.expenses ?? 0;

    for (final s in sales) {
      final k = DateFormat('yyyy-MM').format(s.date);
      final b = buckets[k];
      if (b != null) {
        buckets[k] = MonthlyPoint(
            label: b.label,
            month: b.month,
            revenue: rev(k) + s.totalPrice,
            expenses: exp(k));
      }
    }
    for (final e in expenses) {
      final k = DateFormat('yyyy-MM').format(e.date);
      final b = buckets[k];
      if (b != null) {
        buckets[k] = MonthlyPoint(
            label: b.label,
            month: b.month,
            revenue: rev(k),
            expenses: exp(k) + e.totalCost);
      }
    }
    return [for (final k in order) buckets[k]!];
  }

  List<CategoryAmount> _byCategory(List<Expense> expenses) {
    final map = <String, num>{};
    for (final e in expenses) {
      final name = e.categoryName ?? 'Other';
      map[name] = (map[name] ?? 0) + e.totalCost;
    }
    final list = map.entries.map((e) => CategoryAmount(e.key, e.value)).toList()
      ..sort((a, b) => b.amount.compareTo(a.amount));
    return list;
  }

  List<CropPerformance> _cropPerformance(
      List<Sale> sales, List<Expense> expenses) {
    final names = <String, String>{}; // cropId -> name
    final rev = <String, num>{};
    final exp = <String, num>{};

    for (final s in sales) {
      final id = s.cropId;
      if (id == null) continue;
      names[id] = s.cropName ?? 'Crop';
      rev[id] = (rev[id] ?? 0) + s.totalPrice;
    }
    for (final e in expenses) {
      final id = e.cropId;
      if (id == null) continue;
      names.putIfAbsent(id, () => 'Crop');
      exp[id] = (exp[id] ?? 0) + e.totalCost;
    }

    final ids = {...rev.keys, ...exp.keys};
    final list = ids
        .map((id) => CropPerformance(
              crop: names[id] ?? 'Crop',
              revenue: rev[id] ?? 0,
              expenses: exp[id] ?? 0,
            ))
        .toList()
      ..sort((a, b) => b.profit.compareTo(a.profit));
    return list;
  }

  List<HarvestRow> _harvestRows(List<Harvest> harvests) {
    final map = <String, num>{}; // "crop|unit" -> qty
    for (final h in harvests) {
      final key = '${h.cropName ?? 'Crop'}|${h.unit}';
      map[key] = (map[key] ?? 0) + h.quantity;
    }
    final list = map.entries.map((e) {
      final parts = e.key.split('|');
      return HarvestRow(parts[0], e.value, parts.length > 1 ? parts[1] : '');
    }).toList()
      ..sort((a, b) => b.quantity.compareTo(a.quantity));
    return list;
  }
}

/// The report for a given farm + date range.
final farmReportProvider =
    FutureProvider.family<FarmReport, ReportRange>((ref, range) {
  return ref.watch(reportsRepositoryProvider).build(range);
});
