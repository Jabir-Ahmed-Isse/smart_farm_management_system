/// A farmer's request to upgrade to a paid plan, paid via mobile money and
/// verified by an admin (public.plan_requests).
class PlanRequest {
  const PlanRequest({
    required this.id,
    required this.plan,
    required this.amount,
    required this.method,
    this.reference,
    required this.status,
    this.userName,
    this.userEmail,
    required this.createdAt,
  });

  final String id;
  final String plan;
  final num amount;

  /// evc | zaad | sahal | edahab | other
  final String method;
  final String? reference;

  /// pending | approved | rejected
  final String status;

  /// Only populated in the admin list.
  final String? userName;
  final String? userEmail;
  final DateTime createdAt;

  factory PlanRequest.fromMap(Map<String, dynamic> m) => PlanRequest(
        id: m['id'] as String,
        plan: (m['plan'] as String?) ?? '',
        amount: (m['amount'] as num?) ?? 0,
        method: (m['method'] as String?) ?? 'evc',
        reference: m['reference'] as String?,
        status: (m['status'] as String?) ?? 'pending',
        userName: m['user_name'] as String?,
        userEmail: m['user_email'] as String?,
        createdAt:
            DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// Mobile-money methods common in Somalia.
const paymentMethods = <(String, String)>[
  ('evc', 'EVC Plus'),
  ('zaad', 'Zaad'),
  ('sahal', 'Sahal'),
  ('edahab', 'eDahab'),
  ('other', 'Other'),
];

String paymentMethodLabel(String code) => paymentMethods
    .firstWhere((m) => m.$1 == code, orElse: () => (code, code))
    .$2;
