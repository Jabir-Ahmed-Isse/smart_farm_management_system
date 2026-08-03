import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/ai_credit.dart';
import '../../../models/ai_insight.dart';
import 'ai_service.dart';
import 'plant_doctor_repository.dart' show aiServiceProvider;

/// Free-plan monthly allowance for insight generations. Mirrors the Edge
/// Function (which is authoritative); this drives the pre-check and UI meter.
const int kFreeInsightLimit = 30;

final insightsRepositoryProvider = Provider<InsightsRepository>((ref) {
  return InsightsRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(aiServiceProvider),
  );
});

class InsightsRepository {
  InsightsRepository(this._client, this._ai);

  final SupabaseClient _client;
  final AiService _ai;

  /// The current (non-dismissed) insight cards for a farm.
  Future<List<AiInsight>> getInsights(String farmId) async {
    final rows = await _client
        .from('ai_insights')
        .select()
        .eq('farm_id', farmId)
        .eq('dismissed', false)
        .order('created_at', ascending: false);
    return rows.map(AiInsight.fromMap).toList();
  }

  /// Ask the Edge Function to (re)generate insights from live farm data.
  Future<InsightsOutcome> generate({
    required String farmId,
    required String language,
  }) {
    return _ai.insights(farmId: farmId, language: language);
  }

  Future<void> dismiss(String id) async {
    await _client.from('ai_insights').update({'dismissed': true}).eq('id', id);
  }

  /// This month's insight-generation usage for the signed-in user.
  Future<AiCredit> insightCredit() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return AiCredit.free('insight', kFreeInsightLimit);

    var plan = 'free';
    try {
      final profile = await _client
          .from('profiles')
          .select('ai_plan')
          .eq('id', uid)
          .maybeSingle();
      plan = (profile?['ai_plan'] as String?) ?? 'free';
    } catch (_) {/* pre-migration */}

    if (plan == 'premium') {
      return const AiCredit(kind: 'insight', used: 0, limit: -1, plan: 'premium');
    }

    final now = DateTime.now();
    final monthStart = DateTime.utc(now.year, now.month, 1).toIso8601String();
    var used = 0;
    try {
      final rows = await _client
          .from('ai_credit_usage')
          .select('id')
          .eq('user_id', uid)
          .eq('kind', 'insight')
          .gte('created_at', monthStart);
      used = (rows as List).length;
    } catch (_) {/* pre-migration */}

    return AiCredit(
        kind: 'insight', used: used, limit: kFreeInsightLimit, plan: 'free');
  }
}

/// Cached insight cards for [farmId], newest first.
final insightsForFarmProvider =
    FutureProvider.family<List<AiInsight>, String>((ref, farmId) {
  return ref.watch(insightsRepositoryProvider).getInsights(farmId);
});

/// The signed-in user's remaining insight generations this month.
final insightCreditProvider = FutureProvider<AiCredit>((ref) {
  return ref.watch(insightsRepositoryProvider).insightCredit();
});
