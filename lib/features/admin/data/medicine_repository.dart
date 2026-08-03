import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/medicine.dart';

final medicineRepositoryProvider = Provider<MedicineRepository>((ref) {
  return MedicineRepository(ref.watch(supabaseClientProvider));
});

/// Medicine catalog CRUD. Writes are admin-gated by RLS (is_admin()), so these
/// are plain table operations — no RPC needed.
class MedicineRepository {
  MedicineRepository(this._client);

  final SupabaseClient _client;

  Future<List<Medicine>> list(String search) async {
    var query = _client.from('medicines').select();
    if (search.trim().isNotEmpty) {
      query = query.or(
          'name.ilike.%$search%,active_ingredient.ilike.%$search%,supported_diseases.ilike.%$search%');
    }
    final rows = await query.order('name');
    return rows.map(Medicine.fromMap).toList();
  }

  Future<void> create(Medicine m) async {
    await _client.from('medicines').insert({
      ...m.toWriteMap(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  Future<void> update(String id, Medicine m) async {
    await _client.from('medicines').update({
      ...m.toWriteMap(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('medicines').delete().eq('id', id);
  }
}

final medicinesProvider =
    FutureProvider.family<List<Medicine>, String>((ref, search) {
  return ref.watch(medicineRepositoryProvider).list(search);
});
