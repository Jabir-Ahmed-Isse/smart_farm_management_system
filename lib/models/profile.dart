/// A user profile row (public.profiles), 1:1 with auth.users.
class Profile {
  const Profile({
    required this.id,
    this.fullName,
    this.phone,
    this.avatarUrl,
    this.role = 'farmer',
    this.language = 'so',
    this.darkMode = false,
    this.location,
    this.suspended = false,
    this.aiPlan = 'free',
  });

  final String id;
  final String? fullName;
  final String? phone;
  final String? avatarUrl;
  final String role;
  final String language;
  final bool darkMode;
  final String? location;
  final bool suspended;
  final String aiPlan;

  factory Profile.fromMap(Map<String, dynamic> map) {
    return Profile(
      id: map['id'] as String,
      fullName: map['full_name'] as String?,
      phone: map['phone'] as String?,
      avatarUrl: map['avatar_url'] as String?,
      role: (map['role'] as String?) ?? 'farmer',
      language: (map['language'] as String?) ?? 'so',
      darkMode: (map['dark_mode'] as bool?) ?? false,
      location: map['location'] as String?,
      suspended: (map['suspended'] as bool?) ?? false,
      aiPlan: (map['ai_plan'] as String?) ?? 'free',
    );
  }
}
