import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/chat.dart';

final chatRepositoryProvider = Provider<ChatRepository>((ref) {
  return ChatRepository(ref.watch(supabaseClientProvider));
});

/// Farmer-to-farmer direct messaging. Threads/messages are written through
/// SECURITY DEFINER RPCs; messages are read live via a Realtime stream (RLS
/// scopes it to the participants).
class ChatRepository {
  ChatRepository(this._client);

  final SupabaseClient _client;

  Future<List<ChatThread>> getThreads() async {
    final rows = await _client.rpc('get_chat_threads');
    return (rows as List)
        .map((e) => ChatThread.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  /// Find or create the thread with [otherUserId]; returns its id.
  Future<String> startChat(String otherUserId) async {
    final id = await _client.rpc('start_chat', params: {'p_other': otherUserId});
    return id as String;
  }

  /// Live-updating messages for a thread, oldest first.
  Stream<List<ChatMessage>> messages(String threadId) {
    return _client
        .from('chat_messages')
        .stream(primaryKey: ['id'])
        .eq('thread_id', threadId)
        .order('created_at')
        .map((rows) => rows.map(ChatMessage.fromMap).toList());
  }

  Future<void> sendMessage(String threadId, String body) async {
    await _client.rpc('send_chat_message',
        params: {'p_thread': threadId, 'p_body': body.trim()});
  }

  /// Other farmers you can start a chat with, optionally filtered by name.
  Future<List<Farmer>> searchFarmers(String query) async {
    final rows =
        await _client.rpc('search_farmers', params: {'p_query': query.trim()});
    return (rows as List)
        .map((e) => Farmer.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }
}

final chatThreadsProvider = FutureProvider<List<ChatThread>>((ref) {
  return ref.watch(chatRepositoryProvider).getThreads();
});

final chatMessagesProvider =
    StreamProvider.family<List<ChatMessage>, String>((ref, threadId) {
  return ref.watch(chatRepositoryProvider).messages(threadId);
});
