import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/cached_fetch.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/equipment.dart';

final equipmentRepositoryProvider = Provider<EquipmentRepository>((ref) {
  return EquipmentRepository(ref.watch(supabaseClientProvider));
});

/// Equipment (public.equipment) and its service history
/// (public.equipment_maintenance). Both RLS is_farm_member — direct writes.
class EquipmentRepository {
  EquipmentRepository(this._client);

  final SupabaseClient _client;

  // ---------------------------------------------------------- equipment

  /// In-service items first, then retired; alphabetical within each.
  Future<List<Equipment>> getEquipment(String farmId) async {
    final list = await cachedList(
      table: 'equipment',
      farmId: farmId,
      fetch: () =>
          _client.from('equipment').select().eq('farm_id', farmId).order('name'),
      fromMap: Equipment.fromMap,
    );
    list.sort((a, b) {
      if (a.isRetired != b.isRetired) return a.isRetired ? 1 : -1;
      return a.name.toLowerCase().compareTo(b.name.toLowerCase());
    });
    return list;
  }

  Future<void> createEquipment({
    required String farmId,
    required String name,
    required String status,
    String? type,
    String? serialNumber,
    DateTime? purchaseDate,
    num? purchaseCost,
    DateTime? nextServiceDate,
    String? notes,
  }) async {
    await _client.from('equipment').insert({
      'farm_id': farmId,
      'name': name,
      'status': status,
      if (type != null && type.trim().isNotEmpty) 'type': type.trim(),
      if (serialNumber != null && serialNumber.trim().isNotEmpty)
        'serial_number': serialNumber.trim(),
      if (purchaseDate != null) 'purchase_date': _dateOnly(purchaseDate),
      if (purchaseCost != null) 'purchase_cost': purchaseCost,
      if (nextServiceDate != null)
        'next_service_date': _dateOnly(nextServiceDate),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  Future<void> updateEquipment({
    required String id,
    required String name,
    required String status,
    String? type,
    String? serialNumber,
    DateTime? purchaseDate,
    num? purchaseCost,
    DateTime? nextServiceDate,
    String? notes,
  }) async {
    await _client.from('equipment').update({
      'name': name,
      'status': status,
      'type': (type != null && type.trim().isNotEmpty) ? type.trim() : null,
      'serial_number':
          (serialNumber != null && serialNumber.trim().isNotEmpty)
              ? serialNumber.trim()
              : null,
      'purchase_date':
          purchaseDate == null ? null : _dateOnly(purchaseDate),
      'purchase_cost': purchaseCost,
      'next_service_date':
          nextServiceDate == null ? null : _dateOnly(nextServiceDate),
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteEquipment(String id) async {
    await _client.from('equipment').delete().eq('id', id);
  }

  // -------------------------------------------------------- maintenance

  Future<List<MaintenanceLog>> getMaintenance(String equipmentId) async {
    final rows = await _client
        .from('equipment_maintenance')
        .select()
        .eq('equipment_id', equipmentId)
        .order('date', ascending: false);
    return rows.map(MaintenanceLog.fromMap).toList();
  }

  Future<void> addMaintenance({
    required String farmId,
    required String equipmentId,
    required DateTime date,
    required String kind,
    num? cost,
    String? performedBy,
    String? notes,
  }) async {
    await _client.from('equipment_maintenance').insert({
      'farm_id': farmId,
      'equipment_id': equipmentId,
      'date': _dateOnly(date),
      'kind': kind,
      if (cost != null) 'cost': cost,
      if (performedBy != null && performedBy.trim().isNotEmpty)
        'performed_by': performedBy.trim(),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  Future<void> deleteMaintenance(String id) async {
    await _client.from('equipment_maintenance').delete().eq('id', id);
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// All equipment for [farmId].
final equipmentForFarmProvider =
    FutureProvider.family<List<Equipment>, String>((ref, farmId) {
  return ref.watch(equipmentRepositoryProvider).getEquipment(farmId);
});

/// Service history for one machine (newest first).
final maintenanceForEquipmentProvider =
    FutureProvider.family<List<MaintenanceLog>, String>((ref, equipmentId) {
  return ref.watch(equipmentRepositoryProvider).getMaintenance(equipmentId);
});
