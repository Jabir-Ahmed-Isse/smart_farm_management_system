import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

/// An admin broadcast (public.admin_broadcasts) — an in-app announcement.
class Broadcast {
  const Broadcast({
    required this.id,
    required this.title,
    required this.body,
    required this.audience,
    required this.active,
    required this.createdAt,
  });

  final String id;
  final String title;
  final String body;

  /// all | farmers | experts | premium
  final String audience;
  final bool active;
  final DateTime createdAt;

  factory Broadcast.fromMap(Map<String, dynamic> m) => Broadcast(
        id: m['id'] as String,
        title: (m['title'] as String?) ?? '',
        body: (m['body'] as String?) ?? '',
        audience: (m['audience'] as String?) ?? 'all',
        active: (m['active'] as bool?) ?? true,
        createdAt:
            DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// One audit-log row (public.audit_logs).
class AuditLog {
  const AuditLog({
    required this.id,
    this.actorName,
    required this.action,
    this.targetType,
    this.targetId,
    this.detail,
    required this.createdAt,
  });

  final int id;
  final String? actorName;
  final String action;
  final String? targetType;
  final String? targetId;
  final Map<String, dynamic>? detail;
  final DateTime createdAt;

  factory AuditLog.fromMap(Map<String, dynamic> m) => AuditLog(
        id: (m['id'] as num).toInt(),
        actorName: m['actor_name'] as String?,
        action: (m['action'] as String?) ?? '',
        targetType: m['target_type'] as String?,
        targetId: m['target_id'] as String?,
        detail: m['detail'] is Map
            ? Map<String, dynamic>.from(m['detail'] as Map)
            : null,
        createdAt:
            DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
      );
}

/// A platform setting (public.system_settings).
class SystemSetting {
  const SystemSetting({
    required this.key,
    this.value,
    this.description,
    this.updatedAt,
  });

  final String key;
  final String? value;
  final String? description;
  final DateTime? updatedAt;

  /// True/false-style settings render as a switch.
  bool get isBool => value == 'true' || value == 'false';
  bool get boolValue => value == 'true';

  factory SystemSetting.fromMap(Map<String, dynamic> m) => SystemSetting(
        key: m['key'] as String,
        value: m['value'] as String?,
        description: m['description'] as String?,
        updatedAt: m['updated_at'] == null
            ? null
            : DateTime.tryParse(m['updated_at'] as String),
      );
}

final adminSystemRepositoryProvider = Provider<AdminSystemRepository>((ref) {
  return AdminSystemRepository(ref.watch(supabaseClientProvider));
});

/// Admin management of broadcasts, audit logs and system settings — every call
/// hits an is_admin()-gated SECURITY DEFINER RPC.
class AdminSystemRepository {
  AdminSystemRepository(this._client);
  final SupabaseClient _client;

  // --- broadcasts (notifications) ---
  Future<List<Broadcast>> broadcasts() async {
    final rows = await _client.rpc('admin_list_broadcasts');
    return (rows as List)
        .map((e) => Broadcast.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> createBroadcast({
    required String title,
    required String body,
    required String audience,
  }) async {
    await _client.rpc('admin_create_broadcast', params: {
      'p_title': title,
      'p_body': body,
      'p_audience': audience,
    });
  }

  Future<void> deleteBroadcast(String id) async {
    await _client.rpc('admin_delete_broadcast', params: {'p_id': id});
  }

  // --- audit logs ---
  Future<List<AuditLog>> auditLogs({int limit = 100}) async {
    final rows = await _client.rpc('admin_list_audit_logs', params: {
      'p_limit': limit,
    });
    return (rows as List)
        .map((e) => AuditLog.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  // --- system settings ---
  Future<List<SystemSetting>> settings() async {
    final rows = await _client.rpc('admin_list_settings');
    return (rows as List)
        .map((e) => SystemSetting.fromMap(Map<String, dynamic>.from(e as Map)))
        .toList();
  }

  Future<void> setSetting(String key, String value) async {
    await _client.rpc('admin_set_setting', params: {
      'p_key': key,
      'p_value': value,
    });
  }
}

final adminBroadcastsProvider = FutureProvider<List<Broadcast>>((ref) {
  return ref.watch(adminSystemRepositoryProvider).broadcasts();
});

final adminAuditLogsProvider = FutureProvider<List<AuditLog>>((ref) {
  return ref.watch(adminSystemRepositoryProvider).auditLogs();
});

final adminSettingsProvider = FutureProvider<List<SystemSetting>>((ref) {
  return ref.watch(adminSystemRepositoryProvider).settings();
});
