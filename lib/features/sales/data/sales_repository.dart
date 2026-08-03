import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/offline_repository.dart';
import '../../../core/offline/sync_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/sale.dart';

final salesRepositoryProvider = Provider<SalesRepository>((ref) {
  return SalesRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(syncServiceProvider),
  );
});

/// Sales records (public.sales), offline-first. Revenue on the Dashboard is the
/// sum of `sales.total_price`. total_price is derived here:
/// quantity * unitPrice - discount (floored at 0).
class SalesRepository with OfflineRepository {
  SalesRepository(this.client, this.sync);

  @override
  final SupabaseClient client;
  @override
  final SyncService sync;
  @override
  String get table => 'sales';
  @override
  String get selectClause => '*, crop:crops(name)';

  Future<List<Sale>> getSales(String farmId) async =>
      _shape(await fetchRows(farmId));

  /// Cached-first stream for the sales history list (instant paint).
  Stream<List<Sale>> watchSales(String farmId) =>
      watchRows(farmId).map(_shape);

  static List<Sale> _shape(List<Map<String, dynamic>> rows) =>
      rows.map(Sale.fromMap).toList()
        ..sort((a, b) => b.date.compareTo(a.date));

  Future<String> addSale({
    required String farmId,
    required num quantity,
    required String unit,
    required num unitPrice,
    required DateTime date,
    required String paymentStatus,
    num discount = 0,
    String? cropId,
    String? customer,
    String? market,
    String? paymentMethod,
  }) async {
    final total = (quantity * unitPrice) - discount;
    final row = await createRow({
      'farm_id': farmId,
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'discount': discount,
      'total_price': total < 0 ? 0 : total,
      'payment_status': paymentStatus,
      'date': _dateOnly(date),
      'created_by': client.auth.currentUser?.id,
      if (cropId != null) 'crop_id': cropId,
      if (customer != null && customer.trim().isNotEmpty)
        'customer': customer.trim(),
      if (market != null && market.trim().isNotEmpty) 'market': market.trim(),
      if (paymentMethod != null) 'payment_method': paymentMethod,
    });
    return row['id'] as String;
  }

  Future<void> updateSale({
    required String id,
    required num quantity,
    required String unit,
    required num unitPrice,
    required DateTime date,
    required String paymentStatus,
    num discount = 0,
    String? cropId,
    String? customer,
    String? market,
    String? paymentMethod,
  }) async {
    final total = (quantity * unitPrice) - discount;
    await updateRow(id, {
      'quantity': quantity,
      'unit': unit,
      'unit_price': unitPrice,
      'discount': discount,
      'total_price': total < 0 ? 0 : total,
      'payment_status': paymentStatus,
      'date': _dateOnly(date),
      'crop_id': cropId,
      'customer': (customer != null && customer.trim().isNotEmpty)
          ? customer.trim()
          : null,
      'market':
          (market != null && market.trim().isNotEmpty) ? market.trim() : null,
      'payment_method': paymentMethod,
    });
  }

  Future<void> deleteSale(String id) => deleteRow(id);

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// All sales for [farmId], newest first (history list).
final salesForFarmProvider =
    StreamProvider.family<List<Sale>, String>((ref, farmId) {
  return ref.watch(salesRepositoryProvider).watchSales(farmId);
});
