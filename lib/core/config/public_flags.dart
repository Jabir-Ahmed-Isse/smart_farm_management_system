import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../supabase/supabase_providers.dart';

/// Non-sensitive platform flags, readable by anyone via the public_flags RPC.
class PublicFlags {
  const PublicFlags({this.maintenanceMode = false, this.signupsEnabled = true});

  final bool maintenanceMode;
  final bool signupsEnabled;

  factory PublicFlags.fromMap(Map<String, dynamic> m) => PublicFlags(
        maintenanceMode: (m['maintenance_mode'] as bool?) ?? false,
        signupsEnabled: (m['signups_enabled'] as bool?) ?? true,
      );
}

/// Reads maintenance_mode + signups_enabled. Defaults to a permissive state
/// (no maintenance, signups on) if the call fails, so a transient error never
/// locks users out.
final publicFlagsProvider = FutureProvider<PublicFlags>((ref) async {
  try {
    final res = await ref.watch(supabaseClientProvider).rpc('public_flags');
    return PublicFlags.fromMap(Map<String, dynamic>.from(res as Map));
  } catch (_) {
    return const PublicFlags();
  }
});
