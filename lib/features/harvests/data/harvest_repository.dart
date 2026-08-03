import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/offline_repository.dart';
import '../../../core/offline/sync_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/harvest.dart';

final harvestRepositoryProvider = Provider<HarvestRepository>((ref) {
  return HarvestRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(syncServiceProvider),
  );
});

/// Harvest records (public.harvests), offline-first: a harvest can be logged
/// with no signal and syncs when the connection returns.
class HarvestRepository with OfflineRepository {
  HarvestRepository(this.client, this.sync);

  @override
  final SupabaseClient client;
  @override
  final SyncService sync;
  @override
  String get table => 'harvests';
  @override
  String get selectClause => '*, crop:crops(name)';

  Future<List<Harvest>> getHarvests(String farmId) async =>
      _shape(await fetchRows(farmId));

  /// Cached-first stream for the harvest history list (instant paint).
  Stream<List<Harvest>> watchHarvests(String farmId) =>
      watchRows(farmId).map(_shape);

  static List<Harvest> _shape(List<Map<String, dynamic>> rows) =>
      rows.map(Harvest.fromMap).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Future<String> addHarvest({
    required String farmId,
    required num quantity,
    required String unit,
    required DateTime date,
    String? cropId,
    String? plotId,
    String? grade,
    String? notes,
  }) async {
    final row = await createRow({
      'farm_id': farmId,
      'quantity': quantity,
      'unit': unit,
      'date': _dateOnly(date),
      'created_by': client.auth.currentUser?.id,
      if (cropId != null) 'crop_id': cropId,
      if (plotId != null) 'plot_id': plotId,
      if (grade != null && grade.trim().isNotEmpty) 'grade': grade.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
    return row['id'] as String;
  }

  Future<void> updateHarvest({
    required String id,
    required num quantity,
    required String unit,
    required DateTime date,
    String? cropId,
    String? plotId,
    String? grade,
    String? notes,
  }) async {
    await updateRow(id, {
      'quantity': quantity,
      'unit': unit,
      'date': _dateOnly(date),
      'crop_id': cropId,
      'plot_id': plotId,
      'grade': (grade != null && grade.trim().isNotEmpty) ? grade.trim() : null,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
    });
  }

  Future<void> deleteHarvest(String id) => deleteRow(id);

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// All harvests for [farmId], newest first (history list).
final harvestsForFarmProvider =
    StreamProvider.family<List<Harvest>, String>((ref, farmId) {
  return ref.watch(harvestRepositoryProvider).watchHarvests(farmId);
});
