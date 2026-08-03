import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/subscription_plan.dart';

final subscriptionRepositoryProvider = Provider<SubscriptionRepository>((ref) {
  return SubscriptionRepository(ref.watch(supabaseClientProvider));
});

class SubscriptionRepository {
  SubscriptionRepository(this._client);

  final SupabaseClient _client;

  Future<List<SubscriptionPlan>> plans() async {
    final rows = await _client.from('subscription_plans').select().order('sort');
    final counts = <String, int>{};
    try {
      final c = await _client.rpc('admin_plan_counts');
      for (final r in (c as List)) {
        counts[r['code'] as String] = (r['users'] as num?)?.toInt() ?? 0;
      }
    } catch (_) {/* non-admin or unavailable — counts stay 0 */}
    return rows
        .map((r) => SubscriptionPlan.fromMap(Map<String, dynamic>.from(r))
            .copyWith(userCount: counts[r['code']] ?? 0))
        .toList();
  }

  Future<void> updatePlan(SubscriptionPlan p) async {
    await _client.from('subscription_plans').update({
      'diagnosis_limit': p.diagnosisLimit,
      'chat_limit': p.chatLimit,
      'insight_limit': p.insightLimit,
      'price': p.price,
      'features': p.features,
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('code', p.code);
  }

  Future<void> setUserPlan(String userId, String plan) =>
      _client.rpc('admin_set_plan', params: {'p_user': userId, 'p_plan': plan});

  Future<List<Map<String, dynamic>>> creditHistory(String userId) async {
    final rows = await _client.rpc('admin_credit_history', params: {'p_user': userId});
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }
}

final subscriptionPlansProvider = FutureProvider<List<SubscriptionPlan>>((ref) {
  return ref.watch(subscriptionRepositoryProvider).plans();
});
