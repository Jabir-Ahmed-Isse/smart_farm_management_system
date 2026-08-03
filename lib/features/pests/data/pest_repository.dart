import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/cached_fetch.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/disease_log.dart';

final pestRepositoryProvider = Provider<PestRepository>((ref) {
  return PestRepository(ref.watch(supabaseClientProvider));
});

/// Farm-wide pest & disease log (public.disease_logs). The same table backs the
/// plot-scoped list in PlotDetailRepository; here plot_id is optional so a
/// problem can be recorded against the whole farm.
class PestRepository {
  PestRepository(this._client);

  final SupabaseClient _client;

  static const _select = '*, plot:plots(name), crop:crops(name)';

  /// Active problems first, then newest observation first.
  Future<List<DiseaseLog>> getLogs(String farmId) async {
    final list = await cachedList(
      table: 'disease_logs',
      farmId: farmId,
      fetch: () => _client
          .from('disease_logs')
          .select(_select)
          .eq('farm_id', farmId)
          .order('observed_date', ascending: false),
      fromMap: DiseaseLog.fromMap,
    );
    list.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return b.observedDate.compareTo(a.observedDate);
    });
    return list;
  }

  Future<void> addLog({
    required String farmId,
    required String name,
    required String kind,
    required String severity,
    required String status,
    required DateTime observedDate,
    String? plotId,
    String? cropId,
    String? treatment,
    String? notes,
  }) async {
    await _client.from('disease_logs').insert({
      'farm_id': farmId,
      'name': name,
      'kind': kind,
      'severity': severity,
      'status': status,
      'observed_date': _dateOnly(observedDate),
      if (plotId != null) 'plot_id': plotId,
      if (cropId != null) 'crop_id': cropId,
      if (treatment != null && treatment.trim().isNotEmpty)
        'treatment': treatment.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  Future<void> updateLog({
    required String id,
    required String name,
    required String kind,
    required String severity,
    required String status,
    required DateTime observedDate,
    String? plotId,
    String? cropId,
    String? treatment,
    String? notes,
  }) async {
    await _client.from('disease_logs').update({
      'name': name,
      'kind': kind,
      'severity': severity,
      'status': status,
      'observed_date': _dateOnly(observedDate),
      'plot_id': plotId,
      'crop_id': cropId,
      'treatment': (treatment != null && treatment.trim().isNotEmpty)
          ? treatment.trim()
          : null,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteLog(String id) async {
    await _client.from('disease_logs').delete().eq('id', id);
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Every pest / disease observation on [farmId].
final pestLogsForFarmProvider =
    FutureProvider.family<List<DiseaseLog>, String>((ref, farmId) {
  return ref.watch(pestRepositoryProvider).getLogs(farmId);
});
