import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/cached_fetch.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/nursery_batch.dart';

final nurseryRepositoryProvider = Provider<NurseryRepository>((ref) {
  return NurseryRepository(ref.watch(supabaseClientProvider));
});

/// Seedling batches (public.nursery_batches).
/// RLS is_farm_member FOR ALL — direct writes.
class NurseryRepository {
  NurseryRepository(this._client);

  final SupabaseClient _client;

  static const _select = '*, crop:crops(name), plot:plots(name)';

  /// Open batches first, then closed ones; newest sowing first within each.
  Future<List<NurseryBatch>> getBatches(String farmId) async {
    final list = await cachedList(
      table: 'nursery_batches',
      farmId: farmId,
      fetch: () => _client
          .from('nursery_batches')
          .select(_select)
          .eq('farm_id', farmId)
          .order('sow_date', ascending: false),
      fromMap: NurseryBatch.fromMap,
    );
    list.sort((a, b) {
      if (a.isClosed != b.isClosed) return a.isClosed ? 1 : -1;
      return b.sowDate.compareTo(a.sowDate);
    });
    return list;
  }

  Future<void> createBatch({
    required String farmId,
    required String name,
    required DateTime sowDate,
    required String status,
    String? variety,
    String? seedSource,
    String? cropId,
    String? plotId,
    int? quantitySown,
    int? quantityGerminated,
    int? quantityTransplanted,
    DateTime? expectedTransplantDate,
    DateTime? actualTransplantDate,
    String? notes,
  }) async {
    await _client.from('nursery_batches').insert({
      'farm_id': farmId,
      'name': name,
      'sow_date': _dateOnly(sowDate),
      'status': status,
      if (variety != null && variety.trim().isNotEmpty) 'variety': variety.trim(),
      if (seedSource != null && seedSource.trim().isNotEmpty)
        'seed_source': seedSource.trim(),
      if (cropId != null) 'crop_id': cropId,
      if (plotId != null) 'plot_id': plotId,
      if (quantitySown != null) 'quantity_sown': quantitySown,
      if (quantityGerminated != null) 'quantity_germinated': quantityGerminated,
      if (quantityTransplanted != null)
        'quantity_transplanted': quantityTransplanted,
      if (expectedTransplantDate != null)
        'expected_transplant_date': _dateOnly(expectedTransplantDate),
      if (actualTransplantDate != null)
        'actual_transplant_date': _dateOnly(actualTransplantDate),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  Future<void> updateBatch({
    required String id,
    required String name,
    required DateTime sowDate,
    required String status,
    String? variety,
    String? seedSource,
    String? cropId,
    String? plotId,
    int? quantitySown,
    int? quantityGerminated,
    int? quantityTransplanted,
    DateTime? expectedTransplantDate,
    DateTime? actualTransplantDate,
    String? notes,
  }) async {
    await _client.from('nursery_batches').update({
      'name': name,
      'sow_date': _dateOnly(sowDate),
      'status': status,
      'variety':
          (variety != null && variety.trim().isNotEmpty) ? variety.trim() : null,
      'seed_source': (seedSource != null && seedSource.trim().isNotEmpty)
          ? seedSource.trim()
          : null,
      'crop_id': cropId,
      'plot_id': plotId,
      'quantity_sown': quantitySown,
      'quantity_germinated': quantityGerminated,
      'quantity_transplanted': quantityTransplanted,
      'expected_transplant_date': expectedTransplantDate == null
          ? null
          : _dateOnly(expectedTransplantDate),
      'actual_transplant_date': actualTransplantDate == null
          ? null
          : _dateOnly(actualTransplantDate),
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteBatch(String id) async {
    await _client.from('nursery_batches').delete().eq('id', id);
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// All seedling batches for [farmId].
final nurseryForFarmProvider =
    FutureProvider.family<List<NurseryBatch>, String>((ref, farmId) {
  return ref.watch(nurseryRepositoryProvider).getBatches(farmId);
});
