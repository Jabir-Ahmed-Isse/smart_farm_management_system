import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ai/image_quality.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/util/ids.dart';
import '../../../models/kb_article.dart';

/// Query for the article list. `status` null = no status filter (RLS scopes
/// visibility); `mine` limits to the signed-in author; `bookmarked` shows only
/// the user's saved articles.
typedef KbQuery = ({String search, String category, String? status, bool mine, bool bookmarked});

final kbRepositoryProvider = Provider<KbRepository>((ref) {
  return KbRepository(ref.watch(supabaseClientProvider));
});

class KbRepository {
  KbRepository(this._client);

  final SupabaseClient _client;

  Future<Set<String>> _myBookmarkIds() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return {};
    final rows = await _client.from('kb_bookmarks').select('article_id').eq('user_id', uid);
    return (rows as List).map((r) => r['article_id'] as String).toSet();
  }

  Future<List<KbArticle>> list(KbQuery q) async {
    final bookmarks = await _myBookmarkIds();
    var query = _client.from('kb_articles').select('*, author:profiles(full_name)');
    if (q.mine) {
      query = query.eq('author_id', _client.auth.currentUser?.id ?? '');
    }
    if (q.status != null && q.status!.isNotEmpty) {
      query = query.eq('status', q.status!);
    }
    if (q.category.isNotEmpty) {
      query = query.eq('category', q.category);
    }
    if (q.search.trim().isNotEmpty) {
      query = query.or('title.ilike.%${q.search}%,body.ilike.%${q.search}%');
    }
    final rows = await query.order('created_at', ascending: false);
    var list = rows
        .map((r) => KbArticle.fromMap(Map<String, dynamic>.from(r), bookmarks: bookmarks))
        .toList();
    if (q.bookmarked) list = list.where((a) => a.bookmarked).toList();
    return list;
  }

  Future<bool> toggleBookmark(String articleId) async {
    final r = await _client.rpc('kb_toggle_bookmark', params: {'p_article': articleId});
    return r == true;
  }

  Future<void> create(
          {required String title, required String body, required String category, String? cover}) =>
      _client.rpc('kb_create_article', params: {
        'p_title': title,
        'p_body': body,
        'p_category': category,
        'p_cover': cover,
      });

  Future<void> update(
          {required String id,
          required String title,
          required String body,
          required String category,
          String? cover}) =>
      _client.rpc('kb_update_article', params: {
        'p_id': id,
        'p_title': title,
        'p_body': body,
        'p_category': category,
        'p_cover': cover,
      });

  Future<void> setStatus(String id, String status) =>
      _client.rpc('kb_set_status', params: {'p_id': id, 'p_status': status});

  Future<void> delete(String id) => _client.rpc('kb_delete_article', params: {'p_id': id});

  Future<String> uploadCover(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    final jpeg = decoded == null
        ? bytes
        : ImageQualityChecker.compressForUpload(decoded, maxEdge: 1400);
    final path = '${uuidV4()}.jpg';
    await _client.storage.from('article-images').uploadBinary(
          path,
          jpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _client.storage.from('article-images').getPublicUrl(path);
  }
}

final kbArticlesProvider =
    FutureProvider.family<List<KbArticle>, KbQuery>((ref, q) {
  return ref.watch(kbRepositoryProvider).list(q);
});
