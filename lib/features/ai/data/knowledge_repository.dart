import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/knowledge_entry.dart';

final knowledgeRepositoryProvider = Provider<KnowledgeRepository>((ref) {
  return KnowledgeRepository(ref.watch(supabaseClientProvider));
});

/// Reads and writes the AI knowledge base (public.ai_knowledge_base). Global
/// (farm_id null) rows are readable by anyone; a farm's own notes are member
/// only and require a farm_id to write.
class KnowledgeRepository {
  KnowledgeRepository(this._client);

  final SupabaseClient _client;

  /// Global knowledge plus this farm's private notes, newest first.
  Future<List<KnowledgeEntry>> getEntries(String farmId) async {
    final rows = await _client
        .from('ai_knowledge_base')
        .select()
        .or('farm_id.eq.$farmId,farm_id.is.null')
        .order('created_at', ascending: false);
    return rows.map(KnowledgeEntry.fromMap).toList();
  }

  Future<void> addEntry({
    required String farmId,
    required String title,
    required String content,
    List<String> tags = const [],
    String source = 'manual',
  }) async {
    final user = _client.auth.currentUser;
    await _client.from('ai_knowledge_base').insert({
      'farm_id': farmId,
      'title': title.trim(),
      'content': content.trim(),
      'tags': tags,
      'source': source,
      'created_by': user?.id,
    });
  }

  Future<void> deleteEntry(String id) async {
    await _client.from('ai_knowledge_base').delete().eq('id', id);
  }
}

final knowledgeForFarmProvider =
    FutureProvider.family<List<KnowledgeEntry>, String>((ref, farmId) {
  return ref.watch(knowledgeRepositoryProvider).getEntries(farmId);
});
