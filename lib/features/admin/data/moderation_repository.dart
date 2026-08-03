import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

final moderationRepositoryProvider = Provider<ModerationRepository>((ref) {
  return ModerationRepository(ref.watch(supabaseClientProvider));
});

/// Admin community moderation: content reports + expert applications.
class ModerationRepository {
  ModerationRepository(this._client);

  final SupabaseClient _client;

  Future<List<Map<String, dynamic>>> reports() async {
    final rows = await _client.rpc('admin_list_reports');
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  /// [action] = 'delete' (remove the post) or 'dismiss'.
  Future<void> resolveReport(String id, String action) =>
      _client.rpc('admin_resolve_report', params: {'p_id': id, 'p_action': action});

  Future<List<Map<String, dynamic>>> expertApplications() async {
    final rows = await _client.rpc('admin_list_expert_applications');
    return (rows as List).map((e) => Map<String, dynamic>.from(e as Map)).toList();
  }

  Future<void> reviewExpert(String id, bool approve) =>
      _client.rpc('admin_review_expert', params: {'p_id': id, 'p_approve': approve});
}

final adminReportsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(moderationRepositoryProvider).reports();
});

final adminExpertAppsProvider = FutureProvider<List<Map<String, dynamic>>>((ref) {
  return ref.watch(moderationRepositoryProvider).expertApplications();
});
