import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_store.dart';
import '../../../core/offline/outbox.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/crop.dart';

final dashboardRepositoryProvider = Provider<DashboardRepository>((ref) {
  return DashboardRepository(ref.watch(supabaseClientProvider));
});

/// Aggregates a farm's live figures for the Dashboard: revenue (sum of sales),
/// expenses (sum of expense costs), profit, the active crops, and a merged
/// recent-activity feed. RLS scopes every query to farms the user can see.
class DashboardRepository {
  DashboardRepository(this._client);

  final SupabaseClient _client;

  /// Offline-first: the figures are computed from the local mirror (which
  /// already includes offline-created expenses/sales/harvests), after refreshing
  /// that mirror from the server when a connection is available.
  Future<FarmSummary> getSummary(String farmId) async {
    await _refresh(farmId);
    return _computeLocal(farmId);
  }

  Future<void> _refresh(String farmId) async {
    try {
      final r = await Future.wait([
        _client
            .from('expenses')
            .select('*, category:expense_categories(name_en)')
            .eq('farm_id', farmId),
        _client.from('sales').select('*, crop:crops(name)').eq('farm_id', farmId),
        _client
            .from('harvests')
            .select('*, crop:crops(name)')
            .eq('farm_id', farmId),
        _client.from('crops').select().eq('farm_id', farmId),
      ]);
      if (!LocalStore.isReady) return;
      await _cache('expenses', r[0]);
      await _cache('sales', r[1]);
      await _cache('harvests', r[2]);
      await _cache('crops', r[3]);
    } catch (_) {
      // Offline / server unreachable — the cached rows still answer.
    }
  }

  /// Mirror [rows] locally, but never clobber a row that still has a pending
  /// offline write queued for it (its local copy is newer than the server's).
  Future<void> _cache(String table, List<Map<String, dynamic>> rows) async {
    final pending = Outbox.instance.pendingIds(table);
    await LocalStore.instance.putAll(
      table,
      rows
          .map((r) => Map<String, dynamic>.from(r))
          .where((r) => !pending.contains(r['id']))
          .toList(),
    );
  }

  FarmSummary _computeLocal(String farmId) {
    final store = LocalStore.instance;
    final expenses = store.list('expenses', farmId: farmId);
    final sales = store.list('sales', farmId: farmId);
    final harvests = store.list('harvests', farmId: farmId);
    final crops = store.list('crops', farmId: farmId);

    final activeCrops = (crops
            .where((c) => (c['stage'] as String?) != 'completed')
            .toList()
          ..sort((a, b) => (b['created_at'] ?? '')
              .toString()
              .compareTo((a['created_at'] ?? '').toString())))
        .map(Crop.fromMap)
        .toList();

    DateTime d(Object? v) =>
        DateTime.tryParse(v?.toString() ?? '') ?? DateTime(1970);

    final activity = <ActivityItem>[
      for (final e in expenses)
        ActivityItem(
          type: ActivityType.expense,
          title: (e['category'] as Map?)?['name_en'] as String? ??
              (e['description'] as String?) ??
              'Expense',
          date: d(e['date']),
          amount: (e['total_cost'] as num?)?.toDouble() ?? 0,
        ),
      for (final h in harvests)
        ActivityItem(
          type: ActivityType.harvest,
          title:
              'Harvested ${(h['crop'] as Map?)?['name'] as String? ?? 'crop'}',
          date: d(h['date']),
          quantity: (h['quantity'] as num?)?.toDouble(),
          unit: h['unit'] as String?,
        ),
      for (final s in sales)
        ActivityItem(
          type: ActivityType.sale,
          title:
              'Sold ${(s['crop'] as Map?)?['name'] as String? ?? 'produce'}',
          date: d(s['date']),
          amount: (s['total_price'] as num?)?.toDouble() ?? 0,
        ),
    ]..sort((a, b) => b.date.compareTo(a.date));

    return FarmSummary(
      revenue: _sum(sales, 'total_price'),
      expenses: _sum(expenses, 'total_cost'),
      activeCrops: activeCrops,
      recentActivity: activity.take(5).toList(),
    );
  }

  static double _sum(List<Map<String, dynamic>> rows, String key) {
    var total = 0.0;
    for (final r in rows) {
      total += (r[key] as num?)?.toDouble() ?? 0;
    }
    return total;
  }
}

/// Live Dashboard figures for one farm.
class FarmSummary {
  const FarmSummary({
    required this.revenue,
    required this.expenses,
    required this.activeCrops,
    required this.recentActivity,
  });

  final double revenue;
  final double expenses;
  final List<Crop> activeCrops;
  final List<ActivityItem> recentActivity;

  double get profit => revenue - expenses;

  /// Profit as a share of revenue, or null when there is no revenue yet.
  double? get margin => revenue > 0 ? (profit / revenue) * 100 : null;

  Map<String, dynamic> toMap() => {
        'revenue': revenue,
        'expenses': expenses,
        'activeCrops': [for (final c in activeCrops) c.toMap()],
        'recentActivity': [for (final a in recentActivity) a.toMap()],
      };

  factory FarmSummary.fromMap(Map<String, dynamic> m) => FarmSummary(
        revenue: (m['revenue'] as num?)?.toDouble() ?? 0,
        expenses: (m['expenses'] as num?)?.toDouble() ?? 0,
        activeCrops: [
          for (final c in (m['activeCrops'] as List? ?? []))
            Crop.fromMap(Map<String, dynamic>.from(c as Map)),
        ],
        recentActivity: [
          for (final a in (m['recentActivity'] as List? ?? []))
            ActivityItem.fromMap(Map<String, dynamic>.from(a as Map)),
        ],
      );
}

enum ActivityType { expense, harvest, sale }

class ActivityItem {
  const ActivityItem({
    required this.type,
    required this.title,
    required this.date,
    this.amount,
    this.quantity,
    this.unit,
  });

  final ActivityType type;
  final String title;
  final DateTime date;
  final double? amount;
  final double? quantity;
  final String? unit;

  Map<String, dynamic> toMap() => {
        'type': type.name,
        'title': title,
        'date': date.toIso8601String(),
        'amount': amount,
        'quantity': quantity,
        'unit': unit,
      };

  factory ActivityItem.fromMap(Map<String, dynamic> m) => ActivityItem(
        type: ActivityType.values.firstWhere(
          (t) => t.name == m['type'],
          orElse: () => ActivityType.expense,
        ),
        title: (m['title'] as String?) ?? '',
        date: DateTime.tryParse(m['date'] as String? ?? '') ?? DateTime.now(),
        amount: (m['amount'] as num?)?.toDouble(),
        quantity: (m['quantity'] as num?)?.toDouble(),
        unit: m['unit'] as String?,
      );
}

/// Live summary for [farmId]; invalidated after any expense/harvest/sale write.
final farmSummaryProvider =
    FutureProvider.family<FarmSummary, String>((ref, farmId) {
  return ref.watch(dashboardRepositoryProvider).getSummary(farmId);
});
