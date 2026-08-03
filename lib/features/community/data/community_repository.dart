import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ai/image_quality.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/util/ids.dart';
import '../../../models/community_post.dart';

import 'package:image/image.dart' as img;

final communityRepositoryProvider = Provider<CommunityRepository>((ref) {
  return CommunityRepository(ref.watch(supabaseClientProvider));
});

/// The global community feed. All reads/writes go through the SECURITY DEFINER
/// RPCs created in the community migration.
class CommunityRepository {
  CommunityRepository(this._client);

  final SupabaseClient _client;

  Future<List<CommunityPost>> getFeed() async {
    final rows = await _client.rpc('get_community_feed');
    return (rows as List)
        .map((e) => CommunityPost.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> createPost(String body, {String? imageUrl}) async {
    await _client.rpc('create_community_post', params: {
      'p_body': body.trim(),
      'p_image_url': imageUrl,
    });
  }

  /// Compress + upload a post photo to the public `community` bucket and return
  /// its public URL.
  Future<String> uploadPostImage(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    final jpeg = decoded == null
        ? bytes
        : ImageQualityChecker.compressForUpload(decoded, maxEdge: 1600);
    final path = '${uuidV4()}.jpg';
    await _client.storage.from('community').uploadBinary(
          path,
          jpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _client.storage.from('community').getPublicUrl(path);
  }

  Future<void> deletePost(String id) async {
    await _client.rpc('delete_community_post', params: {'p_id': id});
  }

  /// Report a post for moderator review (any signed-in user).
  Future<void> reportPost(String postId, String reason) async {
    await _client.rpc('report_post', params: {'p_post': postId, 'p_reason': reason});
  }

  /// Admin moderation: delete any post, pin/unpin.
  Future<void> adminDeletePost(String id) =>
      _client.rpc('admin_delete_post', params: {'p_id': id});

  Future<void> adminSetPinned(String id, bool pinned) =>
      _client.rpc('admin_set_pinned', params: {'p_id': id, 'p_pinned': pinned});

  /// Admin: suspend (ban) a user by id — blocks their access app-wide.
  Future<void> banUser(String userId) =>
      _client.rpc('admin_set_suspended', params: {'p_user': userId, 'p_suspended': true});

  /// Apply to become an agricultural expert (creates a pending application).
  Future<void> applyForExpert(String message) =>
      _client.rpc('apply_for_expert', params: {'p_message': message});

  /// Returns the new liked state (true = now liked).
  Future<bool> toggleLike(String postId) async {
    final r =
        await _client.rpc('toggle_community_like', params: {'p_post_id': postId});
    return r == true;
  }

  Future<List<CommunityComment>> getComments(String postId) async {
    final rows =
        await _client.rpc('get_post_comments', params: {'p_post_id': postId});
    return (rows as List)
        .map((e) => CommunityComment.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> addComment(String postId, String body) async {
    await _client.rpc('create_community_comment',
        params: {'p_post_id': postId, 'p_body': body.trim()});
  }
}

final communityFeedProvider = FutureProvider<List<CommunityPost>>((ref) {
  return ref.watch(communityRepositoryProvider).getFeed();
});

final postCommentsProvider =
    FutureProvider.family<List<CommunityComment>, String>((ref, postId) {
  return ref.watch(communityRepositoryProvider).getComments(postId);
});
