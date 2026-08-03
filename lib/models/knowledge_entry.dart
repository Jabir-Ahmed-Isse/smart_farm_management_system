/// A searchable knowledge-base note (public.ai_knowledge_base). A null farmId
/// is global (shared) knowledge; otherwise it's private to one farm.
class KnowledgeEntry {
  const KnowledgeEntry({
    required this.id,
    required this.title,
    required this.content,
    required this.tags,
    required this.source,
    required this.createdAt,
    this.farmId,
  });

  final String id;
  final String? farmId;
  final String title;
  final String content;
  final List<String> tags;

  /// 'diagnosis' | 'treatment' | 'correction' | 'manual'
  final String source;
  final DateTime createdAt;

  bool get isGlobal => farmId == null;

  /// Lowercased haystack for the on-device search filter.
  String get searchText =>
      '$title $content ${tags.join(' ')}'.toLowerCase();

  factory KnowledgeEntry.fromMap(Map<String, dynamic> map) {
    final rawTags = map['tags'];
    return KnowledgeEntry(
      id: map['id'] as String,
      farmId: map['farm_id'] as String?,
      title: (map['title'] as String?) ?? '',
      content: (map['content'] as String?) ?? '',
      tags: rawTags is List
          ? rawTags.map((e) => e.toString()).toList()
          : const [],
      source: (map['source'] as String?) ?? 'manual',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
