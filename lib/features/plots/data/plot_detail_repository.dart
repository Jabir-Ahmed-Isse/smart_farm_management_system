import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/disease_log.dart';
import '../../../models/plot_comment.dart';

final plotDetailRepositoryProvider = Provider<PlotDetailRepository>((ref) {
  return PlotDetailRepository(ref.watch(supabaseClientProvider));
});

/// Per-plot rollup: expenses/harvests/sales attributed to the plot, plus the
/// plot's disease log and comments.
class PlotDetailRepository {
  PlotDetailRepository(this._client);

  final SupabaseClient _client;

  /// Expenses and harvests carry plot_id directly; sales are attributed to the
  /// plot through their crop (crop.plot_id).
  Future<PlotSummary> getSummary(String plotId) async {
    final results = await Future.wait([
      _client.from('expenses').select('total_cost').eq('plot_id', plotId),
      _client.from('harvests').select('quantity, unit').eq('plot_id', plotId),
      _client.from('crops').select('id').eq('plot_id', plotId),
    ]);

    final expenseRows = results[0];
    final harvestRows = results[1];
    final cropRows = results[2];

    final expenseTotal = _sum(expenseRows, 'total_cost');
    final expenseCount = expenseRows.length;

    final harvestCount = harvestRows.length;
    final harvestQty = _sum(harvestRows, 'quantity');
    final harvestUnit = harvestRows.isEmpty
        ? ''
        : (harvestRows.first['unit'] as String? ?? '');
    final harvestUnitMixed =
        harvestRows.any((r) => (r['unit'] as String? ?? '') != harvestUnit);

    var salesTotal = 0.0;
    var salesCount = 0;
    final cropIds =
        cropRows.map((r) => r['id'] as String).toList(growable: false);
    if (cropIds.isNotEmpty) {
      final salesRows = await _client
          .from('sales')
          .select('total_price')
          .inFilter('crop_id', cropIds);
      salesTotal = _sum(salesRows, 'total_price');
      salesCount = salesRows.length;
    }

    return PlotSummary(
      expenseTotal: expenseTotal,
      expenseCount: expenseCount,
      harvestCount: harvestCount,
      harvestQty: harvestQty,
      harvestUnit: harvestUnitMixed ? 'units' : harvestUnit,
      salesTotal: salesTotal,
      salesCount: salesCount,
    );
  }

  Future<List<DiseaseLog>> getDiseaseLogs(String plotId) async {
    final rows = await _client
        .from('disease_logs')
        .select()
        .eq('plot_id', plotId)
        .order('observed_date', ascending: false);
    return rows.map(DiseaseLog.fromMap).toList();
  }

  Future<void> addDiseaseLog({
    required String farmId,
    required String plotId,
    required String name,
    required String kind,
    required String severity,
    required String status,
    required DateTime observedDate,
    String? cropId,
    String? treatment,
    String? notes,
  }) async {
    final user = _client.auth.currentUser;
    await _client.from('disease_logs').insert({
      'farm_id': farmId,
      'plot_id': plotId,
      'name': name,
      'kind': kind,
      'severity': severity,
      'status': status,
      'observed_date': _dateOnly(observedDate),
      'created_by': user?.id,
      if (cropId != null) 'crop_id': cropId,
      if (treatment != null && treatment.trim().isNotEmpty)
        'treatment': treatment.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  Future<void> updateDiseaseLog({
    required String id,
    required String name,
    required String kind,
    required String severity,
    required String status,
    required DateTime observedDate,
    String? treatment,
    String? notes,
  }) async {
    await _client.from('disease_logs').update({
      'name': name,
      'kind': kind,
      'severity': severity,
      'status': status,
      'observed_date': _dateOnly(observedDate),
      'treatment':
          (treatment != null && treatment.trim().isNotEmpty) ? treatment.trim() : null,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteDiseaseLog(String id) async {
    await _client.from('disease_logs').delete().eq('id', id);
  }

  Future<List<PlotComment>> getComments(String plotId) async {
    final rows = await _client
        .from('plot_comments')
        .select()
        .eq('plot_id', plotId)
        .order('created_at', ascending: false);
    return rows.map(PlotComment.fromMap).toList();
  }

  Future<void> addComment({
    required String farmId,
    required String plotId,
    required String body,
  }) async {
    final user = _client.auth.currentUser;
    await _client.from('plot_comments').insert({
      'farm_id': farmId,
      'plot_id': plotId,
      'body': body.trim(),
      'created_by': user?.id,
    });
  }

  Future<void> deleteComment(String id) async {
    await _client.from('plot_comments').delete().eq('id', id);
  }

  static double _sum(List<Map<String, dynamic>> rows, String key) {
    var total = 0.0;
    for (final r in rows) {
      total += (r[key] as num?)?.toDouble() ?? 0;
    }
    return total;
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Financial + activity rollup for a single plot.
class PlotSummary {
  const PlotSummary({
    required this.expenseTotal,
    required this.expenseCount,
    required this.harvestCount,
    required this.harvestQty,
    required this.harvestUnit,
    required this.salesTotal,
    required this.salesCount,
  });

  final double expenseTotal;
  final int expenseCount;
  final int harvestCount;
  final double harvestQty;
  final String harvestUnit;
  final double salesTotal;
  final int salesCount;

  double get profit => salesTotal - expenseTotal;
}

final plotSummaryProvider =
    FutureProvider.family<PlotSummary, String>((ref, plotId) {
  return ref.watch(plotDetailRepositoryProvider).getSummary(plotId);
});

final plotDiseaseLogsProvider =
    FutureProvider.family<List<DiseaseLog>, String>((ref, plotId) {
  return ref.watch(plotDetailRepositoryProvider).getDiseaseLogs(plotId);
});

final plotCommentsProvider =
    FutureProvider.family<List<PlotComment>, String>((ref, plotId) {
  return ref.watch(plotDetailRepositoryProvider).getComments(plotId);
});
