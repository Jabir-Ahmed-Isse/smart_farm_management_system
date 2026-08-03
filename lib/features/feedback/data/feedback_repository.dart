import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/feedback_item.dart';

final feedbackRepositoryProvider = Provider<FeedbackRepository>((ref) {
  return FeedbackRepository(ref.watch(supabaseClientProvider));
});

class FeedbackRepository {
  FeedbackRepository(this._client);
  final SupabaseClient _client;

  /// Farmer submits feedback (via SECURITY DEFINER RPC).
  Future<void> submit({
    required String category,
    required String subject,
    required String message,
  }) async {
    await _client.rpc('submit_feedback', params: {
      'p_category': category,
      'p_subject': subject,
      'p_message': message,
    });
  }

  /// The signed-in user's own submissions (RLS scopes to own rows).
  Future<List<FeedbackItem>> myFeedback() async {
    final rows = await _client
        .from('feedback')
        .select()
        .order('created_at', ascending: false);
    return rows
        .map((r) => FeedbackItem.fromMap(Map<String, dynamic>.from(r)))
        .toList();
  }

  /// Admin: all feedback, optionally filtered by status.
  Future<List<FeedbackItem>> adminList({String? status}) async {
    final rows = await _client.rpc('admin_list_feedback', params: {
      if (status != null) 'p_status': status,
    });
    return (rows as List)
        .map((e) => FeedbackItem.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Admin: set status and/or reply.
  Future<void> respond({
    required String id,
    String? status,
    String? response,
  }) async {
    await _client.rpc('admin_respond_feedback', params: {
      'p_id': id,
      if (status != null) 'p_status': status,
      if (response != null) 'p_response': response,
    });
  }
}

/// The current user's own feedback list.
final myFeedbackProvider = FutureProvider<List<FeedbackItem>>((ref) {
  return ref.watch(feedbackRepositoryProvider).myFeedback();
});

/// Admin feedback list, filtered by an optional status (null = all).
final adminFeedbackProvider =
    FutureProvider.family<List<FeedbackItem>, String?>((ref, status) {
  return ref.watch(feedbackRepositoryProvider).adminList(status: status);
});
