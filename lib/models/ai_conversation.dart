/// A saved AI Farm Assistant conversation (public.ai_conversations).
class AiConversation {
  const AiConversation({
    required this.id,
    required this.farmId,
    required this.title,
    required this.language,
    required this.updatedAt,
  });

  final String id;
  final String farmId;
  final String title;
  final String language;
  final DateTime updatedAt;

  factory AiConversation.fromMap(Map<String, dynamic> map) => AiConversation(
        id: map['id'] as String,
        farmId: map['farm_id'] as String,
        title: (map['title'] as String?)?.trim().isNotEmpty == true
            ? (map['title'] as String).trim()
            : 'New chat',
        language: (map['language'] as String?) ?? 'en',
        updatedAt: DateTime.tryParse(map['updated_at'] as String? ?? '') ??
            DateTime.now(),
      );
}
