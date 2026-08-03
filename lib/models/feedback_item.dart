/// One feedback submission (public.feedback).
class FeedbackItem {
  const FeedbackItem({
    required this.id,
    required this.category,
    required this.subject,
    required this.message,
    required this.status,
    this.adminResponse,
    this.userName,
    this.userEmail,
    this.respondedAt,
    required this.createdAt,
  });

  final String id;

  /// bug | feature | question | general
  final String category;
  final String subject;
  final String message;

  /// open | in_review | resolved | closed
  final String status;
  final String? adminResponse;

  /// Only populated in the admin list (joined from profiles/auth).
  final String? userName;
  final String? userEmail;
  final DateTime? respondedAt;
  final DateTime createdAt;

  bool get hasResponse => (adminResponse ?? '').isNotEmpty;

  factory FeedbackItem.fromMap(Map<String, dynamic> m) => FeedbackItem(
        id: m['id'] as String,
        category: (m['category'] as String?) ?? 'general',
        subject: (m['subject'] as String?) ?? '',
        message: (m['message'] as String?) ?? '',
        status: (m['status'] as String?) ?? 'open',
        adminResponse: m['admin_response'] as String?,
        userName: m['user_name'] as String?,
        userEmail: m['user_email'] as String?,
        respondedAt: m['responded_at'] == null
            ? null
            : DateTime.tryParse(m['responded_at'] as String),
        createdAt:
            DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Category options for the submit form (code, label, icon-name-agnostic).
const feedbackCategories = <(String, String)>[
  ('bug', 'Bug / problem'),
  ('feature', 'Feature request'),
  ('question', 'Question'),
  ('general', 'General feedback'),
];

String feedbackCategoryLabel(String code) => feedbackCategories
    .firstWhere((c) => c.$1 == code, orElse: () => (code, code))
    .$2;

const feedbackStatuses = <String>['open', 'in_review', 'resolved', 'closed'];

String feedbackStatusLabel(String s) => switch (s) {
      'open' => 'Open',
      'in_review' => 'In review',
      'resolved' => 'Resolved',
      'closed' => 'Closed',
      _ => s,
    };
