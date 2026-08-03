import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../features/profile/data/profile_repository.dart';

/// The three application roles. Mirrors the Postgres `app_role` enum
/// (farmer, manager, worker, expert, admin) collapsed to the three that drive
/// access control — manager/worker are treated as farmer-level here.
enum AppRole {
  farmer,
  expert,
  admin;

  static AppRole parse(String? raw) => switch (raw) {
        'admin' => AppRole.admin,
        'expert' => AppRole.expert,
        _ => AppRole.farmer,
      };

  bool get isAdmin => this == AppRole.admin;

  /// Experts and admins both have expert capabilities (admin is a superset).
  bool get isExpert => this == AppRole.expert || this == AppRole.admin;

  String get label => switch (this) {
        AppRole.admin => 'Super Admin',
        AppRole.expert => 'Agricultural Expert',
        AppRole.farmer => 'Farmer',
      };
}

/// The signed-in user's role, derived from their loaded profile. Defaults to
/// farmer while the profile is loading or absent — the safe, least-privileged
/// choice, so admin/expert surfaces never flash for a normal user.
final currentRoleProvider = Provider<AppRole>((ref) {
  final profile = ref.watch(myProfileProvider).valueOrNull;
  return AppRole.parse(profile?.role);
});

final isAdminProvider = Provider<bool>((ref) => ref.watch(currentRoleProvider).isAdmin);

final isExpertProvider = Provider<bool>((ref) => ref.watch(currentRoleProvider).isExpert);
