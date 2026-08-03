import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/cached_fetch.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/irrigation_log.dart';

final irrigationRepositoryProvider = Provider<IrrigationRepository>((ref) {
  return IrrigationRepository(ref.watch(supabaseClientProvider));
});

/// Irrigation / watering events (public.irrigation_logs).
/// RLS is_farm_member FOR ALL — direct writes.
class IrrigationRepository {
  IrrigationRepository(this._client);

  final SupabaseClient _client;

  static const _select =
      '*, plot:plots(name), crop:crops(name)';

  Future<List<IrrigationLog>> getLogs(String farmId) => cachedList(
        table: 'irrigation_logs',
        farmId: farmId,
        fetch: () => _client
            .from('irrigation_logs')
            .select(_select)
            .eq('farm_id', farmId)
            .order('date', ascending: false)
            .order('created_at', ascending: false),
        fromMap: IrrigationLog.fromMap,
      );

  Future<void> createLog({
    required String farmId,
    required DateTime date,
    required String method,
    String? plotId,
    String? cropId,
    String? source,
    num? durationMinutes,
    num? volume,
    String volumeUnit = 'liter',
    num? cost,
    String? notes,
  }) async {
    await _client.from('irrigation_logs').insert({
      'farm_id': farmId,
      'date': _dateOnly(date),
      'method': method,
      'volume_unit': volumeUnit,
      if (plotId != null) 'plot_id': plotId,
      if (cropId != null) 'crop_id': cropId,
      if (source != null) 'source': source,
      if (durationMinutes != null) 'duration_minutes': durationMinutes,
      if (volume != null) 'volume': volume,
      if (cost != null) 'cost': cost,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  Future<void> updateLog({
    required String id,
    required DateTime date,
    required String method,
    String? plotId,
    String? cropId,
    String? source,
    num? durationMinutes,
    num? volume,
    String volumeUnit = 'liter',
    num? cost,
    String? notes,
  }) async {
    await _client.from('irrigation_logs').update({
      'date': _dateOnly(date),
      'method': method,
      'plot_id': plotId,
      'crop_id': cropId,
      'source': source,
      'duration_minutes': durationMinutes,
      'volume': volume,
      'volume_unit': volumeUnit,
      'cost': cost,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteLog(String id) async {
    await _client.from('irrigation_logs').delete().eq('id', id);
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// Every watering event for [farmId], newest first.
final irrigationForFarmProvider =
    FutureProvider.family<List<IrrigationLog>, String>((ref, farmId) {
  return ref.watch(irrigationRepositoryProvider).getLogs(farmId);
});
