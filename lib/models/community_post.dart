/// A post in the global community feed (public.community_posts), enriched by
/// the get_community_feed RPC with author info + like/comment counts.
class CommunityPost {
  const CommunityPost({
    required this.id,
    required this.authorId,
    required this.authorName,
    this.authorAvatar,
    this.authorRole,
    required this.body,
    this.imageUrl,
    required this.createdAt,
    required this.likeCount,
    required this.commentCount,
    required this.likedByMe,
    this.pinned = false,
  });

  final String id;
  final String authorId;
  final String authorName;
  final String? authorAvatar;
  final String? authorRole;
  final String body;
  final String? imageUrl;
  final DateTime createdAt;
  final int likeCount;
  final int commentCount;
  final bool likedByMe;
  final bool pinned;

  bool get isExpert => authorRole == 'expert' || authorRole == 'agronomist';
  bool get isAdmin => authorRole == 'admin';

  CommunityPost copyWith(
          {int? likeCount, bool? likedByMe, int? commentCount, bool? pinned}) =>
      CommunityPost(
        id: id,
        authorId: authorId,
        authorName: authorName,
        authorAvatar: authorAvatar,
        authorRole: authorRole,
        body: body,
        imageUrl: imageUrl,
        createdAt: createdAt,
        likeCount: likeCount ?? this.likeCount,
        commentCount: commentCount ?? this.commentCount,
        likedByMe: likedByMe ?? this.likedByMe,
        pinned: pinned ?? this.pinned,
      );

  factory CommunityPost.fromMap(Map<String, dynamic> m) => CommunityPost(
        id: m['id'] as String,
        authorId: (m['author_id'] as String?) ?? '',
        authorName: (m['author_name'] as String?)?.trim().isNotEmpty == true
            ? (m['author_name'] as String).trim()
            : 'Farmer',
        authorAvatar: m['author_avatar'] as String?,
        authorRole: m['author_role'] as String?,
        body: (m['body'] as String?) ?? '',
        imageUrl: m['image_url'] as String?,
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
        likeCount: (m['like_count'] as num?)?.toInt() ?? 0,
        commentCount: (m['comment_count'] as num?)?.toInt() ?? 0,
        likedByMe: (m['liked_by_me'] as bool?) ?? false,
        pinned: (m['pinned'] as bool?) ?? false,
      );
}

/// A comment on a post (via the get_post_comments RPC).
class CommunityComment {
  const CommunityComment({
    required this.id,
    required this.authorName,
    this.authorAvatar,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String authorName;
  final String? authorAvatar;
  final String body;
  final DateTime createdAt;

  factory CommunityComment.fromMap(Map<String, dynamic> m) => CommunityComment(
        id: m['id'] as String,
        authorName: (m['author_name'] as String?)?.trim().isNotEmpty == true
            ? (m['author_name'] as String).trim()
            : 'Farmer',
        authorAvatar: m['author_avatar'] as String?,
        body: (m['body'] as String?) ?? '',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}
