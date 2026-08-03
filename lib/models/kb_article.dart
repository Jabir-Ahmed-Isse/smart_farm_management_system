/// A Knowledge Base article (public.kb_articles) + author name and the current
/// user's bookmark flag (merged client-side).
class KbArticle {
  const KbArticle({
    required this.id,
    required this.title,
    required this.body,
    required this.category,
    this.coverImageUrl,
    required this.authorId,
    this.authorName,
    required this.status,
    this.publishedAt,
    required this.createdAt,
    this.bookmarked = false,
  });

  final String id;
  final String title;
  final String body;
  final String category;
  final String? coverImageUrl;
  final String authorId;
  final String? authorName;

  /// draft | pending | published | rejected
  final String status;
  final DateTime? publishedAt;
  final DateTime createdAt;
  final bool bookmarked;

  bool get isPublished => status == 'published';
  bool get isPending => status == 'pending';

  KbArticle copyWith({bool? bookmarked}) => KbArticle(
        id: id,
        title: title,
        body: body,
        category: category,
        coverImageUrl: coverImageUrl,
        authorId: authorId,
        authorName: authorName,
        status: status,
        publishedAt: publishedAt,
        createdAt: createdAt,
        bookmarked: bookmarked ?? this.bookmarked,
      );

  factory KbArticle.fromMap(Map<String, dynamic> m, {Set<String> bookmarks = const {}}) {
    final author = m['author'];
    final id = m['id'] as String;
    return KbArticle(
      id: id,
      title: (m['title'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      category: (m['category'] as String?) ?? 'general',
      coverImageUrl: m['cover_image_url'] as String?,
      authorId: (m['author_id'] as String?) ?? '',
      authorName: author is Map ? author['full_name'] as String? : null,
      status: (m['status'] as String?) ?? 'pending',
      publishedAt: m['published_at'] == null
          ? null
          : DateTime.tryParse(m['published_at'] as String),
      createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      bookmarked: bookmarks.contains(id),
    );
  }
}

const kbCategories = <String>[
  'general',
  'pests_diseases',
  'crops',
  'soil_water',
  'livestock',
  'business',
  'weather',
];

String kbCategoryLabel(String c) => switch (c) {
      'pests_diseases' => 'Pests & Diseases',
      'crops' => 'Crops',
      'soil_water' => 'Soil & Water',
      'livestock' => 'Livestock',
      'business' => 'Farm Business',
      'weather' => 'Weather',
      _ => 'General',
    };
