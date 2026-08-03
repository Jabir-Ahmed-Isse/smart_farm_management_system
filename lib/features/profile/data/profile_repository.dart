import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/errors.dart';
import '../../../core/offline/local_store.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/farm.dart';
import '../../../models/profile.dart';

final profileRepositoryProvider = Provider<ProfileRepository>((ref) {
  return ProfileRepository(ref.watch(supabaseClientProvider));
});

/// Reads the signed-in user's profile and farms (RLS scopes rows automatically).
class ProfileRepository {
  ProfileRepository(this._client);

  final SupabaseClient _client;

  Future<Profile?> getMyProfile() async {
    final user = _client.auth.currentUser;
    if (user == null) return null;
    try {
      final data = await _client
          .from('profiles')
          .select()
          .eq('id', user.id)
          .maybeSingle();
      if (data == null) return null;
      final row = Map<String, dynamic>.from(data);
      if (LocalStore.isReady) await LocalStore.instance.put('profiles', row);
      return Profile.fromMap(row);
    } catch (e) {
      // Offline-first: serve the cached profile so role/plan/name still work.
      if (LocalStore.isReady) {
        final cached = LocalStore.instance.get('profiles', user.id);
        if (cached != null) return Profile.fromMap(cached);
      }
      if (isOfflineError(e)) throw const OfflineException();
      rethrow;
    }
  }

  /// A full JSON snapshot of the user's own data (profile + farms + records).
  Future<Map<String, dynamic>> exportMyData() async {
    final res = await _client.rpc('export_my_data');
    return Map<String, dynamic>.from(res as Map);
  }

  Future<List<Farm>> getMyFarms() async {
    final user = _client.auth.currentUser;
    if (user == null) return [];
    // Scope explicitly to the user's OWN farms. The farms RLS policy is
    // `is_farm_member(id) OR is_admin()`, so for an admin a bare select would
    // return EVERY farm in the system — leaking another farmer's farm (and its
    // finances) onto the personal dashboard. Filtering by owner_id keeps the
    // personal views personal for admins and farmers alike; the admin panel
    // uses its own is_admin()-scoped RPCs for platform-wide data.
    try {
      final rows = await _client
          .from('farms')
          .select()
          .eq('owner_id', user.id)
          .order('created_at', ascending: false);
      final list = rows.map((r) => Map<String, dynamic>.from(r)).toList();
      if (LocalStore.isReady) await LocalStore.instance.putAll('farms', list);
      return list.map(Farm.fromMap).toList();
    } catch (e) {
      // Offline-first: serve the cached farms so the app keeps working with no
      // connection instead of showing a raw socket error.
      if (LocalStore.isReady) {
        final cached = LocalStore.instance
            .list('farms')
            .where((r) => r['owner_id'] == user.id)
            .toList()
          ..sort((a, b) => (b['created_at'] ?? '')
              .toString()
              .compareTo((a['created_at'] ?? '').toString()));
        if (cached.isNotEmpty) return cached.map(Farm.fromMap).toList();
      }
      if (isOfflineError(e)) throw const OfflineException();
      rethrow;
    }
  }

  Future<Farm> createFarm({required String name, String? region}) async {
    // A live session is required.
    if (_client.auth.currentSession == null) {
      throw StateError('Your session has expired. Please sign in again.');
    }
    // Created via the create_farm SECURITY DEFINER RPC: a direct table INSERT
    // fails RLS here because the farms INSERT policy's `owner_id = auth.uid()`
    // check evaluates auth.uid() as null through the pooled PostgREST path
    // under this project's asymmetric JWTs. The RPC sets owner_id from
    // auth.uid() server-side and returns the new row.
    final row = await _client.rpc('create_farm', params: {
      'p_name': name,
      if (region != null && region.isNotEmpty) 'p_region': region,
    });
    // rpc() returns the farms row as a Map (SETOF/single composite → object).
    final map = row is List ? row.first as Map<String, dynamic> : row as Map<String, dynamic>;
    return Farm.fromMap(map);
  }

  /// Renames / re-regions a farm via the update_farm SECURITY DEFINER RPC
  /// (farms UPDATE policy uses bare auth.uid() which fails via PostgREST here).
  Future<Farm> updateFarm({
    required String id,
    required String name,
    String? region,
  }) async {
    if (_client.auth.currentSession == null) {
      throw StateError('Your session has expired. Please sign in again.');
    }
    final row = await _client.rpc('update_farm', params: {
      'p_id': id,
      'p_name': name,
      'p_region': region ?? '',
    });
    final map = row is List
        ? row.first as Map<String, dynamic>
        : row as Map<String, dynamic>;
    return Farm.fromMap(map);
  }

  /// Deletes a farm and all its data (children cascade) via delete_farm RPC.
  Future<void> deleteFarm(String id) async {
    if (_client.auth.currentSession == null) {
      throw StateError('Your session has expired. Please sign in again.');
    }
    await _client.rpc('delete_farm', params: {'p_id': id});
  }

  /// Updates the signed-in user's own profile via the update_my_profile
  /// SECURITY DEFINER RPC (profiles UPDATE uses bare auth.uid() which fails via
  /// PostgREST here, same as farms). Null fields are left unchanged.
  Future<Profile> updateMyProfile({
    String? fullName,
    String? phone,
    String? language,
  }) async {
    if (_client.auth.currentSession == null) {
      throw StateError('Your session has expired. Please sign in again.');
    }
    final row = await _client.rpc('update_my_profile', params: {
      'p_full_name': fullName,
      'p_phone': phone,
      'p_language': language,
    });
    final map = row is List
        ? row.first as Map<String, dynamic>
        : row as Map<String, dynamic>;
    return Profile.fromMap(map);
  }
}

/// The current user's profile.
final myProfileProvider = FutureProvider<Profile?>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(profileRepositoryProvider).getMyProfile();
});

/// The current user's farms.
final myFarmsProvider = FutureProvider<List<Farm>>((ref) {
  ref.watch(authStateProvider);
  return ref.watch(profileRepositoryProvider).getMyFarms();
});

/// The farm the user is currently viewing. null = fall back to the first farm.
/// Lets a user who owns several farms switch which one the dashboard and the
/// farm-scoped screens show.
final selectedFarmIdProvider = StateProvider<String?>((ref) => null);

/// Resolves [selectedFarmIdProvider] against the user's own farms, falling back
/// to the first. null while farms are loading or the user has none.
final activeFarmProvider = Provider<Farm?>((ref) {
  final farms = ref.watch(myFarmsProvider).valueOrNull ?? const <Farm>[];
  if (farms.isEmpty) return null;
  final id = ref.watch(selectedFarmIdProvider);
  return farms.firstWhere((f) => f.id == id, orElse: () => farms.first);
});
