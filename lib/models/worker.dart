/// A farm worker (public.workers).
class Worker {
  const Worker({
    required this.id,
    required this.farmId,
    required this.fullName,
    this.profileId,
    this.position,
    this.phone,
    this.dailyWage,
    this.hireDate,
    this.active = true,
  });

  final String id;
  final String farmId;
  final String fullName;

  /// Set when the worker also has an app account (public.profiles).
  final String? profileId;

  /// Free-form role, e.g. "Foreman", "Irrigation".
  final String? position;
  final String? phone;
  final num? dailyWage;
  final DateTime? hireDate;
  final bool active;

  /// "Amina Yusuf · Foreman" when a position is set, otherwise just the name.
  String get displayName => (position != null && position!.isNotEmpty)
      ? '$fullName · $position'
      : fullName;

  factory Worker.fromMap(Map<String, dynamic> map) {
    return Worker(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      fullName: (map['full_name'] as String?) ?? '',
      profileId: map['profile_id'] as String?,
      position: map['position'] as String?,
      phone: map['phone'] as String?,
      dailyWage: map['daily_wage'] as num?,
      hireDate: map['hire_date'] == null
          ? null
          : DateTime.parse(map['hire_date'] as String),
      active: (map['active'] as bool?) ?? true,
    );
  }
}
