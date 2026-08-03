import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/cached_fetch.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/livestock.dart';

final livestockRepositoryProvider = Provider<LivestockRepository>((ref) {
  return LivestockRepository(ref.watch(supabaseClientProvider));
});

/// Livestock (public.livestock) and their health / production history
/// (public.livestock_records). RLS is_farm_member — direct writes.
class LivestockRepository {
  LivestockRepository(this._client);

  final SupabaseClient _client;

  // ---------------------------------------------------------- animals

  /// Active animals first, then alphabetical.
  Future<List<Livestock>> getAnimals(String farmId) async {
    final list = await cachedList(
      table: 'livestock',
      farmId: farmId,
      fetch: () =>
          _client.from('livestock').select().eq('farm_id', farmId).order('name'),
      fromMap: Livestock.fromMap,
    );
    list.sort((a, b) {
      if (a.isActive != b.isActive) return a.isActive ? -1 : 1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<void> createAnimal({
    required String farmId,
    required String name,
    required String species,
    required int count,
    required String status,
    String? breed,
    String? sex,
    DateTime? birthDate,
    DateTime? acquiredDate,
    num? acquisitionCost,
    String? notes,
  }) async {
    await _client.from('livestock').insert({
      'farm_id': farmId,
      'name': name,
      'species': species,
      'count': count,
      'status': status,
      if (breed != null && breed.trim().isNotEmpty) 'breed': breed.trim(),
      if (sex != null) 'sex': sex,
      if (birthDate != null) 'birth_date': _dateOnly(birthDate),
      if (acquiredDate != null) 'acquired_date': _dateOnly(acquiredDate),
      if (acquisitionCost != null) 'acquisition_cost': acquisitionCost,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  Future<void> updateAnimal({
    required String id,
    required String name,
    required String species,
    required int count,
    required String status,
    String? breed,
    String? sex,
    DateTime? birthDate,
    DateTime? acquiredDate,
    num? acquisitionCost,
    String? notes,
  }) async {
    await _client.from('livestock').update({
      'name': name,
      'species': species,
      'count': count,
      'status': status,
      'breed': (breed != null && breed.trim().isNotEmpty) ? breed.trim() : null,
      'sex': sex,
      'birth_date': birthDate == null ? null : _dateOnly(birthDate),
      'acquired_date': acquiredDate == null ? null : _dateOnly(acquiredDate),
      'acquisition_cost': acquisitionCost,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteAnimal(String id) async {
    await _client.from('livestock').delete().eq('id', id);
  }

  // ---------------------------------------------------------- records

  Future<List<LivestockRecord>> getRecords(String livestockId) async {
    final rows = await _client
        .from('livestock_records')
        .select()
        .eq('livestock_id', livestockId)
        .order('date', ascending: false);
    return rows.map(LivestockRecord.fromMap).toList();
  }

  Future<void> addRecord({
    required String farmId,
    required String livestockId,
    required DateTime date,
    required String kind,
    num? quantity,
    String? unit,
    num? cost,
    String? notes,
  }) async {
    await _client.from('livestock_records').insert({
      'farm_id': farmId,
      'livestock_id': livestockId,
      'date': _dateOnly(date),
      'kind': kind,
      if (quantity != null) 'quantity': quantity,
      if (unit != null && unit.trim().isNotEmpty) 'unit': unit.trim(),
      if (cost != null) 'cost': cost,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  Future<void> deleteRecord(String id) async {
    await _client.from('livestock_records').delete().eq('id', id);
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// All livestock for [farmId].
final livestockForFarmProvider =
    FutureProvider.family<List<Livestock>, String>((ref, farmId) {
  return ref.watch(livestockRepositoryProvider).getAnimals(farmId);
});

/// Health / production history for one animal or herd (newest first).
final livestockRecordsProvider =
    FutureProvider.family<List<LivestockRecord>, String>((ref, livestockId) {
  return ref.watch(livestockRepositoryProvider).getRecords(livestockId);
});
