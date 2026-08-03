import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

/// A (name, count) pair for the "top crops / top diseases" leaderboards.
typedef NamedCount = ({String name, int count});

/// Platform-wide statistics for the Admin Dashboard, from the admin_overview
/// RPC (which is guarded by is_admin() server-side).
class AdminOverview {
  const AdminOverview({
    required this.totalUsers,
    required this.farmers,
    required this.experts,
    required this.admins,
    required this.premiumUsers,
    required this.newUsersMonth,
    required this.totalFarms,
    required this.totalDiagnoses,
    required this.diagnosesMonth,
    required this.totalChats,
    required this.aiCallsMonth,
    required this.totalPosts,
    required this.totalComments,
    required this.activeDiseases,
    required this.topCrops,
    required this.topDiseases,
  });

  final int totalUsers;
  final int farmers;
  final int experts;
  final int admins;
  final int premiumUsers;
  final int newUsersMonth;
  final int totalFarms;
  final int totalDiagnoses;
  final int diagnosesMonth;
  final int totalChats;
  final int aiCallsMonth;
  final int totalPosts;
  final int totalComments;
  final int activeDiseases;
  final List<NamedCount> topCrops;
  final List<NamedCount> topDiseases;

  static int _i(dynamic v) => (v as num?)?.toInt() ?? 0;

  static List<NamedCount> _leaderboard(dynamic raw) {
    if (raw is! List) return const [];
    return raw
        .whereType<Map>()
        .map((m) => (
              name: (m['name'] as String?)?.trim().isNotEmpty == true
                  ? (m['name'] as String).trim()
                  : 'Unknown',
              count: _i(m['count']),
            ))
        .toList();
  }

  factory AdminOverview.fromMap(Map<String, dynamic> m) => AdminOverview(
        totalUsers: _i(m['total_users']),
        farmers: _i(m['farmers']),
        experts: _i(m['experts']),
        admins: _i(m['admins']),
        premiumUsers: _i(m['premium_users']),
        newUsersMonth: _i(m['new_users_month']),
        totalFarms: _i(m['total_farms']),
        totalDiagnoses: _i(m['total_diagnoses']),
        diagnosesMonth: _i(m['diagnoses_month']),
        totalChats: _i(m['total_chats']),
        aiCallsMonth: _i(m['ai_calls_month']),
        totalPosts: _i(m['total_posts']),
        totalComments: _i(m['total_comments']),
        activeDiseases: _i(m['active_diseases']),
        topCrops: _leaderboard(m['top_crops']),
        topDiseases: _leaderboard(m['top_diseases']),
      );
}

final adminRepositoryProvider = Provider<AdminRepository>((ref) {
  return AdminRepository(ref.watch(supabaseClientProvider));
});

class AdminRepository {
  AdminRepository(this._client);

  final SupabaseClient _client;

  Future<AdminOverview> overview() async {
    final data = await _client.rpc('admin_overview');
    return AdminOverview.fromMap(Map<String, dynamic>.from(data as Map));
  }
}

final adminOverviewProvider = FutureProvider<AdminOverview>((ref) {
  return ref.watch(adminRepositoryProvider).overview();
});
