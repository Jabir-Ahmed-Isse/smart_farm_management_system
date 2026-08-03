/// A user row for the admin user-management list (from admin_list_users).
class AdminUser {
  const AdminUser({
    required this.id,
    this.fullName,
    this.email,
    this.phone,
    required this.role,
    this.aiPlan = 'free',
    this.suspended = false,
    this.createdAt,
    this.lastSignIn,
    this.farmCount = 0,
    this.diagnosisCount = 0,
  });

  final String id;
  final String? fullName;
  final String? email;
  final String? phone;
  final String role;
  final String aiPlan;
  final bool suspended;
  final DateTime? createdAt;
  final DateTime? lastSignIn;
  final int farmCount;
  final int diagnosisCount;

  String get displayName => (fullName?.trim().isNotEmpty == true)
      ? fullName!.trim()
      : (email?.split('@').first ?? 'User');

  bool get isPremium => aiPlan == 'premium';

  static DateTime? _date(dynamic v) =>
      v == null ? null : DateTime.tryParse(v as String);

  factory AdminUser.fromMap(Map<String, dynamic> m) => AdminUser(
        id: m['id'] as String,
        fullName: m['full_name'] as String?,
        email: m['email'] as String?,
        phone: m['phone'] as String?,
        role: (m['role'] as String?) ?? 'farmer',
        aiPlan: (m['ai_plan'] as String?) ?? 'free',
        suspended: (m['suspended'] as bool?) ?? false,
        createdAt: _date(m['created_at']),
        lastSignIn: _date(m['last_sign_in']),
        farmCount: (m['farm_count'] as num?)?.toInt() ?? 0,
        diagnosisCount: (m['diagnosis_count'] as num?)?.toInt() ?? 0,
      );
}
