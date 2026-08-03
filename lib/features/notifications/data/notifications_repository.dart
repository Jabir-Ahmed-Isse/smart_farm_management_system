import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_store.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../admin/data/admin_system_repository.dart';
import '../../profile/data/profile_repository.dart';

/// Farmer-facing view of admin broadcasts. The `broadcasts read active` RLS
/// policy lets any authenticated user read active rows; audience targeting
/// (all / farmers / experts / premium) is applied here on the client.
class NotificationsRepository {
  NotificationsRepository(this._client, this._role, this._plan);

  final SupabaseClient _client;
  final String _role;
  final String _plan;

  static const _lastSeenKey = 'notifications:last_seen';

  bool _matches(String audience) {
    switch (audience) {
      case 'farmers':
        return _role == 'farmer';
      case 'experts':
        return _role == 'expert' || _role == 'admin';
      case 'premium':
        return _plan != 'free';
      case 'all':
      default:
        return true;
    }
  }

  Future<List<Broadcast>> inbox() async {
    final rows = await _client
        .from('admin_broadcasts')
        .select()
        .eq('active', true)
        .order('created_at', ascending: false);
    return rows
        .map((r) => Broadcast.fromMap(Map<String, dynamic>.from(r)))
        .where((b) => _matches(b.audience))
        .toList();
  }

  DateTime? lastSeen() {
    final raw = LocalStore.instance.metaGet(_lastSeenKey);
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  Future<void> markAllSeen() =>
      LocalStore.instance.metaPut(_lastSeenKey, DateTime.now().toIso8601String());
}

final notificationsRepositoryProvider =
    Provider<NotificationsRepository>((ref) {
  final profile = ref.watch(myProfileProvider).valueOrNull;
  return NotificationsRepository(
    ref.watch(supabaseClientProvider),
    profile?.role ?? 'farmer',
    profile?.aiPlan ?? 'free',
  );
});

/// The announcements relevant to the signed-in user, newest first.
final myNotificationsProvider = FutureProvider<List<Broadcast>>((ref) {
  return ref.watch(notificationsRepositoryProvider).inbox();
});

/// Count of announcements newer than the user's last visit — drives the badge.
final unreadNotificationsProvider = FutureProvider<int>((ref) async {
  final repo = ref.watch(notificationsRepositoryProvider);
  final list = await ref.watch(myNotificationsProvider.future);
  final seen = repo.lastSeen();
  if (seen == null) return list.length;
  return list.where((b) => b.createdAt.isAfter(seen)).length;
});
