import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/admin_user.dart';

/// Search/filter parameters for the user list.
typedef UserQuery = ({String search, String role});

final adminUsersRepositoryProvider = Provider<AdminUsersRepository>((ref) {
  return AdminUsersRepository(ref.watch(supabaseClientProvider));
});

/// Admin user & role management — all through is_admin()-guarded RPCs.
class AdminUsersRepository {
  AdminUsersRepository(this._client);

  final SupabaseClient _client;

  Future<List<AdminUser>> list(UserQuery q, {int limit = 100, int offset = 0}) async {
    final rows = await _client.rpc('admin_list_users', params: {
      'p_search': q.search,
      'p_role': q.role,
      'p_limit': limit,
      'p_offset': offset,
    });
    return (rows as List)
        .map((e) => AdminUser.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> setRole(String userId, String role) =>
      _client.rpc('admin_set_role', params: {'p_user': userId, 'p_role': role});

  Future<void> setSuspended(String userId, bool suspended) => _client.rpc(
      'admin_set_suspended', params: {'p_user': userId, 'p_suspended': suspended});

  Future<void> resetCredits(String userId, {String kind = ''}) => _client
      .rpc('admin_reset_credits', params: {'p_user': userId, 'p_kind': kind});

  Future<Map<String, dynamic>> detail(String userId) async {
    final data = await _client.rpc('admin_user_detail', params: {'p_user': userId});
    return Map<String, dynamic>.from(data as Map);
  }
}

final adminUsersProvider =
    FutureProvider.family<List<AdminUser>, UserQuery>((ref, q) {
  return ref.watch(adminUsersRepositoryProvider).list(q);
});

final adminUserDetailProvider =
    FutureProvider.family<Map<String, dynamic>, String>((ref, userId) {
  return ref.watch(adminUsersRepositoryProvider).detail(userId);
});
