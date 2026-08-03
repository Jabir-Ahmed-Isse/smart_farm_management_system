/// A 1:1 chat thread with the other participant's details + last-message
/// preview (from the get_chat_threads RPC).
class ChatThread {
  const ChatThread({
    required this.threadId,
    required this.otherId,
    required this.otherName,
    this.otherAvatar,
    this.lastMessage,
    this.lastAt,
  });

  final String threadId;
  final String otherId;
  final String otherName;
  final String? otherAvatar;
  final String? lastMessage;
  final DateTime? lastAt;

  factory ChatThread.fromMap(Map<String, dynamic> m) => ChatThread(
        threadId: m['thread_id'] as String,
        otherId: (m['other_id'] as String?) ?? '',
        otherName: (m['other_name'] as String?)?.trim().isNotEmpty == true
            ? (m['other_name'] as String).trim()
            : 'Farmer',
        otherAvatar: m['other_avatar'] as String?,
        lastMessage: m['last_message'] as String?,
        lastAt: m['last_at'] == null
            ? null
            : DateTime.tryParse(m['last_at'] as String),
      );
}

/// A farmer in the directory, for starting a new chat (from search_farmers).
class Farmer {
  const Farmer({
    required this.id,
    required this.name,
    this.avatar,
    this.role,
  });

  final String id;
  final String name;
  final String? avatar;
  final String? role;

  bool get isExpert => role == 'expert' || role == 'agronomist';

  factory Farmer.fromMap(Map<String, dynamic> m) => Farmer(
        id: m['id'] as String,
        name: (m['full_name'] as String?)?.trim().isNotEmpty == true
            ? (m['full_name'] as String).trim()
            : 'Farmer',
        avatar: m['avatar_url'] as String?,
        role: m['role'] as String?,
      );
}

/// One chat message. `isMine` is derived by comparing [senderId] to the
/// current user, so the same shape works for the RPC and the realtime stream.
class ChatMessage {
  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String senderId;
  final String body;
  final DateTime createdAt;

  factory ChatMessage.fromMap(Map<String, dynamic> m) => ChatMessage(
        id: m['id'] as String,
        senderId: (m['sender_id'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        createdAt: DateTime.tryParse(m['created_at'] as String? ?? '') ??
            DateTime.now(),
      );
}
