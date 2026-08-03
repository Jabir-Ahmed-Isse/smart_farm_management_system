import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/cached_fetch.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/crop.dart';
import '../../../models/expense.dart';
import '../../../models/expense_category.dart';
import '../../../models/plot.dart';

final expenseRepositoryProvider = Provider<ExpenseRepository>((ref) {
  return ExpenseRepository(ref.watch(supabaseClientProvider));
});

/// Writes expenses to Supabase and reads the reference data the form needs
/// (categories, and the plots / crops for the selected farm). RLS scopes
/// every farm-owned row automatically.
class ExpenseRepository {
  ExpenseRepository(this._client);

  final SupabaseClient _client;

  static const _receiptsBucket = 'receipts';

  Future<List<ExpenseCategory>> getCategories() => cachedList(
        table: 'expense_categories',
        fetch: () =>
            _client.from('expense_categories').select().order('sort_order'),
        fromMap: ExpenseCategory.fromMap,
      );

  Future<List<Plot>> getPlots(String farmId) => cachedList(
        table: 'plots',
        farmId: farmId,
        fetch: () =>
            _client.from('plots').select().eq('farm_id', farmId).order('name'),
        fromMap: Plot.fromMap,
      );

  Future<List<Crop>> getCrops(String farmId) => cachedList(
        table: 'crops',
        farmId: farmId,
        fetch: () =>
            _client.from('crops').select().eq('farm_id', farmId).order('name'),
        fromMap: Crop.fromMap,
      );

  /// Uploads a receipt image to the private `receipts` bucket and returns the
  /// stored object path (kept in `expenses.receipt_url`). The bucket is
  /// private, so displaying it later needs a signed URL.
  Future<String> uploadReceipt({
    required String farmId,
    required Uint8List bytes,
    required String fileExt,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');

    final ext = fileExt.replaceFirst('.', '').toLowerCase();
    final path =
        '$farmId/${DateTime.now().millisecondsSinceEpoch}.${ext.isEmpty ? 'jpg' : ext}';

    await _client.storage.from(_receiptsBucket).uploadBinary(
          path,
          bytes,
          fileOptions: FileOptions(
            contentType: _contentTypeFor(ext),
            upsert: false,
          ),
        );
    return path;
  }

  /// Inserts an expense. [totalCost] maps to the required `total_cost` column;
  /// everything else is optional. Returns the inserted row's id.
  Future<String> addExpense({
    required String farmId,
    required num totalCost,
    required DateTime date,
    String? categoryId,
    String? plotId,
    String? cropId,
    String? description,
    String? supplier,
    String? paymentMethod,
    num? quantity,
    String? unit,
    num? unitPrice,
    String? receiptUrl,
  }) async {
    final user = _client.auth.currentUser;
    if (user == null) throw StateError('Not signed in');

    final row = await _client
        .from('expenses')
        .insert({
          'farm_id': farmId,
          'total_cost': totalCost,
          'date': _dateOnly(date),
          'created_by': user.id,
          if (categoryId != null) 'category_id': categoryId,
          if (plotId != null) 'plot_id': plotId,
          if (cropId != null) 'crop_id': cropId,
          if (_notBlank(description)) 'description': description!.trim(),
          if (_notBlank(supplier)) 'supplier': supplier!.trim(),
          if (paymentMethod != null) 'payment_method': paymentMethod,
          if (quantity != null) 'quantity': quantity,
          if (_notBlank(unit)) 'unit': unit!.trim(),
          if (unitPrice != null) 'unit_price': unitPrice,
          if (receiptUrl != null) 'receipt_url': receiptUrl,
        })
        .select('id')
        .single();
    return row['id'] as String;
  }

  Future<List<Expense>> getExpenses(String farmId) => cachedList(
        table: 'expenses',
        farmId: farmId,
        fetch: () => _client
            .from('expenses')
            .select('*, category:expense_categories(name_en)')
            .eq('farm_id', farmId)
            .order('date', ascending: false),
        fromMap: Expense.fromMap,
      );

  Future<void> updateExpense({
    required String id,
    required num totalCost,
    required DateTime date,
    String? categoryId,
    String? plotId,
    String? cropId,
    String? description,
    String? supplier,
    String? paymentMethod,
    String? receiptUrl,
  }) async {
    await _client.from('expenses').update({
      'total_cost': totalCost,
      'date': _dateOnly(date),
      'category_id': categoryId,
      'plot_id': plotId,
      'crop_id': cropId,
      'description': _notBlank(description) ? description!.trim() : null,
      'supplier': _notBlank(supplier) ? supplier!.trim() : null,
      'payment_method': paymentMethod,
      if (receiptUrl != null) 'receipt_url': receiptUrl,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteExpense(String id) async {
    await _client.from('expenses').delete().eq('id', id);
  }

  static bool _notBlank(String? v) => v != null && v.trim().isNotEmpty;

  /// Postgres `date` column wants a plain YYYY-MM-DD string.
  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';

  static String _contentTypeFor(String ext) {
    switch (ext) {
      case 'png':
        return 'image/png';
      case 'webp':
        return 'image/webp';
      case 'heic':
        return 'image/heic';
      case 'jpg':
      case 'jpeg':
      default:
        return 'image/jpeg';
    }
  }
}

/// Seeded expense categories (static — safe to cache for the session).
final expenseCategoriesProvider =
    FutureProvider<List<ExpenseCategory>>((ref) {
  return ref.watch(expenseRepositoryProvider).getCategories();
});

/// Plots belonging to [farmId], for the shared farm/plot/crop selector.
final plotsForFarmProvider =
    FutureProvider.family<List<Plot>, String>((ref, farmId) {
  return ref.watch(expenseRepositoryProvider).getPlots(farmId);
});

/// Crops belonging to [farmId], for the shared farm/plot/crop selector.
final cropsForFarmProvider =
    FutureProvider.family<List<Crop>, String>((ref, farmId) {
  return ref.watch(expenseRepositoryProvider).getCrops(farmId);
});

/// All expenses for [farmId], newest first (history list).
final expensesForFarmProvider =
    FutureProvider.family<List<Expense>, String>((ref, farmId) {
  return ref.watch(expenseRepositoryProvider).getExpenses(farmId);
});
