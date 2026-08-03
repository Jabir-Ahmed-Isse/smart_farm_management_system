import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/cached_fetch.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/inventory_item.dart';

final inventoryRepositoryProvider = Provider<InventoryRepository>((ref) {
  return InventoryRepository(ref.watch(supabaseClientProvider));
});

/// Inventory items (public.inventory_items, RLS is_farm_member — direct writes).
class InventoryRepository {
  InventoryRepository(this._client);

  final SupabaseClient _client;

  Future<List<InventoryItem>> getItems(String farmId) => cachedList(
        table: 'inventory_items',
        farmId: farmId,
        fetch: () => _client
            .from('inventory_items')
            .select()
            .eq('farm_id', farmId)
            .order('name'),
        fromMap: InventoryItem.fromMap,
      );

  Future<void> createItem({
    required String farmId,
    required String name,
    required String category,
    required String unit,
    required num quantity,
    required num reorderLevel,
    num? unitCost,
    String? supplier,
    DateTime? expiryDate,
    String? notes,
  }) async {
    await _client.from('inventory_items').insert({
      'farm_id': farmId,
      'name': name,
      'category': category,
      'unit': unit,
      'quantity': quantity,
      'reorder_level': reorderLevel,
      if (unitCost != null) 'unit_cost': unitCost,
      if (supplier != null && supplier.trim().isNotEmpty)
        'supplier': supplier.trim(),
      if (expiryDate != null) 'expiry_date': _dateOnly(expiryDate),
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
    });
  }

  Future<void> updateItem({
    required String id,
    required String name,
    required String category,
    required String unit,
    required num quantity,
    required num reorderLevel,
    num? unitCost,
    String? supplier,
    DateTime? expiryDate,
    String? notes,
  }) async {
    await _client.from('inventory_items').update({
      'name': name,
      'category': category,
      'unit': unit,
      'quantity': quantity,
      'reorder_level': reorderLevel,
      'unit_cost': unitCost,
      'supplier':
          (supplier != null && supplier.trim().isNotEmpty) ? supplier.trim() : null,
      'expiry_date': expiryDate == null ? null : _dateOnly(expiryDate),
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteItem(String id) async {
    await _client.from('inventory_items').delete().eq('id', id);
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// All inventory items for [farmId].
final inventoryForFarmProvider =
    FutureProvider.family<List<InventoryItem>, String>((ref, farmId) {
  return ref.watch(inventoryRepositoryProvider).getItems(farmId);
});
