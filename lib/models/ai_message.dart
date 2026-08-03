/// One turn in an AI Farm Assistant conversation (public.ai_messages).
class AiMessage {
  const AiMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.createdAt,
  });

  /// 'user' | 'assistant'
  final String role;
  final String id;
  final String content;
  final DateTime createdAt;

  bool get isUser => role == 'user';

  factory AiMessage.fromMap(Map<String, dynamic> map) => AiMessage(
        id: map['id'] as String? ?? '',
        role: (map['role'] as String?) ?? 'assistant',
        content: (map['content'] as String?) ?? '',
        createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
            DateTime.now(),
      );

  /// A transient message shown in the UI before it is persisted.
  factory AiMessage.local(String role, String content) => AiMessage(
        id: 'local-${DateTime.now().microsecondsSinceEpoch}',
        role: role,
        content: content,
        createdAt: DateTime.now(),
      );
}
