import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/ai_conversation.dart';
import '../../../models/ai_credit.dart';
import '../../../models/ai_message.dart';
import 'ai_service.dart';
import 'plant_doctor_repository.dart' show aiServiceProvider;

const int kFreeChatLimit = 100;

final assistantRepositoryProvider = Provider<AssistantRepository>((ref) {
  return AssistantRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(aiServiceProvider),
  );
});

class AssistantRepository {
  AssistantRepository(this._client, this._ai);

  final SupabaseClient _client;
  final AiService _ai;

  Future<List<AiConversation>> getConversations(String farmId) async {
    final rows = await _client
        .from('ai_conversations')
        .select()
        .eq('farm_id', farmId)
        .order('updated_at', ascending: false);
    return rows.map(AiConversation.fromMap).toList();
  }

  Future<List<AiMessage>> getMessages(String conversationId) async {
    final rows = await _client
        .from('ai_messages')
        .select()
        .eq('conversation_id', conversationId)
        .order('created_at', ascending: true);
    return rows.map(AiMessage.fromMap).toList();
  }

  /// Ask the assistant a question. The server gathers the farm's data, calls
  /// Gemini, saves both turns, and returns the answer.
  Future<ChatOutcome> ask({
    required String farmId,
    String? conversationId,
    required String question,
    required String language,
  }) {
    return _ai.chat(
      farmId: farmId,
      conversationId: conversationId,
      question: question,
      language: language,
    );
  }

  Future<void> deleteConversation(String id) async {
    await _client.from('ai_conversations').delete().eq('id', id);
  }

  /// This month's assistant-question usage for the signed-in user.
  Future<AiCredit> chatCredit() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return AiCredit.free('chat', kFreeChatLimit);
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
      return const AiCredit(kind: 'chat', used: 0, limit: -1, plan: 'premium');
    }
    final now = DateTime.now();
    final monthStart = DateTime.utc(now.year, now.month, 1).toIso8601String();
    var used = 0;
    try {
      final rows = await _client
          .from('ai_credit_usage')
          .select('id')
          .eq('user_id', uid)
          .eq('kind', 'chat')
          .gte('created_at', monthStart);
      used = (rows as List).length;
    } catch (_) {/* pre-migration */}
    return AiCredit(kind: 'chat', used: used, limit: kFreeChatLimit, plan: 'free');
  }
}

final conversationsForFarmProvider =
    FutureProvider.family<List<AiConversation>, String>((ref, farmId) {
  return ref.watch(assistantRepositoryProvider).getConversations(farmId);
});

final chatCreditProvider = FutureProvider<AiCredit>((ref) {
  return ref.watch(assistantRepositoryProvider).chatCredit();
});
