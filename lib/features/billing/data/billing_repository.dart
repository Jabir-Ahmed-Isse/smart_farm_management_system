import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/plan_request.dart';

/// Payment display info shown to the farmer (from admin-editable settings).
class BillingInfo {
  const BillingInfo({required this.number, required this.instructions});
  final String number;
  final String instructions;

  factory BillingInfo.fromMap(Map<String, dynamic> m) => BillingInfo(
        number: (m['number'] as String?) ?? '',
        instructions: (m['instructions'] as String?) ?? '',
      );
}

final billingRepositoryProvider = Provider<BillingRepository>((ref) {
  return BillingRepository(ref.watch(supabaseClientProvider));
});

class BillingRepository {
  BillingRepository(this._client);
  final SupabaseClient _client;

  Future<BillingInfo> info() async {
    final res = await _client.rpc('billing_info');
    return BillingInfo.fromMap(Map<String, dynamic>.from(res as Map));
  }

  /// The user's current pending request, or null.
  Future<PlanRequest?> myPending() async {
    final res = await _client.rpc('my_pending_plan_request');
    if (res == null) return null;
    final map = res is List
        ? (res.isEmpty ? null : res.first as Map)
        : res as Map;
    return map == null ? null : PlanRequest.fromMap(Map<String, dynamic>.from(map));
  }

  Future<void> requestUpgrade({
    required String plan,
    required String method,
    required String reference,
  }) async {
    await _client.rpc('request_plan_upgrade', params: {
      'p_plan': plan,
      'p_method': method,
      'p_reference': reference,
    });
  }

  // --- admin ---
  Future<List<PlanRequest>> adminList({String? status = 'pending'}) async {
    final rows = await _client.rpc('admin_list_plan_requests', params: {
      'p_status': status,
    });
    return (rows as List)
        .map((e) => PlanRequest.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> adminReview({
    required String id,
    required bool approve,
    String? note,
  }) async {
    await _client.rpc('admin_review_plan_request', params: {
      'p_id': id,
      'p_approve': approve,
      if (note != null) 'p_note': note,
    });
  }
}

final billingInfoProvider = FutureProvider<BillingInfo>((ref) {
  return ref.watch(billingRepositoryProvider).info();
});

final myPendingRequestProvider = FutureProvider<PlanRequest?>((ref) {
  return ref.watch(billingRepositoryProvider).myPending();
});

final adminPlanRequestsProvider =
    FutureProvider.family<List<PlanRequest>, String?>((ref, status) {
  return ref.watch(billingRepositoryProvider).adminList(status: status);
});
