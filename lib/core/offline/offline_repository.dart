import 'dart:async';
import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import 'local_store.dart';
import 'outbox.dart';
import 'sync_service.dart';

/// Shared offline-first behaviour for every module repository.
///
/// Reads come from the local store immediately and a pull refreshes it in the
/// background; writes land locally first and are queued for the server. The
/// screen therefore never blocks on the network, and a farmer with no signal
/// sees their own expense the moment they save it.
mixin OfflineRepository {
  SupabaseClient get client;
  SyncService get sync;

  /// Table name in Postgres — also the local store's namespace.
  String get table;

  /// PostgREST select used when pulling, so joined names survive offline.
  String get selectClause => '*';

  /// Rows for [farmId], local-first.
  ///
  /// Returns whatever is cached straight away; when [refresh] is true a pull
  /// is attempted and its result returned instead. A failed pull is not an
  /// error — it just means the cached answer stands.
  Future<List<Map<String, dynamic>>> fetchRows(
    String farmId, {
    bool refresh = true,
  }) async {
    final cached = LocalStore.instance.list(table, farmId: farmId);
    if (!refresh) return cached;
    try {
      return await sync.pull(table, farmId, select: selectClause);
    } catch (_) {
      // Offline (or the server is unhappy) — the cache is still useful.
      return cached;
    }
  }

  /// Cached-first stream of rows for [farmId].
  ///
  /// Emits the locally cached copy **immediately** (when there is one) so a
  /// screen paints straight away, then emits again with the server's answer.
  /// A list provider built on this shows real content on first frame instead
  /// of a spinner, which is the whole point of the offline mirror — unlike
  /// [fetchRows], which awaits the network before returning anything.
  ///
  /// A failed refresh is not an error: the cached emission already stood, and
  /// with no cache we emit an empty list so the screen shows its empty state
  /// rather than an endless loader.
  Stream<List<Map<String, dynamic>>> watchRows(String farmId) async* {
    final cached = LocalStore.instance.list(table, farmId: farmId);
    if (cached.isNotEmpty) yield cached;
    try {
      yield await sync.pull(table, farmId, select: selectClause);
    } catch (_) {
      if (cached.isEmpty) yield <Map<String, dynamic>>[];
    }
  }

  /// Write a new row locally and queue it for the server.
  ///
  /// The id is generated on the device so the local row is immediately
  /// referable — the server keeps that same id when the insert lands.
  Future<Map<String, dynamic>> createRow(Map<String, dynamic> values) async {
    final row = {
      ...values,
      'id': values['id'] ?? _uuidV4(),
      'created_at': DateTime.now().toIso8601String(),
      'updated_at': DateTime.now().toIso8601String(),
    };
    await LocalStore.instance.put(table, row);
    await Outbox.instance.add(
      table: table,
      op: SyncOp.insert,
      rowId: row['id'] as String,
      payload: row,
    );
    unawaited(sync.drain());
    return row;
  }

  Future<void> updateRow(String id, Map<String, dynamic> values) async {
    final existing = LocalStore.instance.get(table, id) ?? {'id': id};
    final patch = {...values, 'updated_at': DateTime.now().toIso8601String()};
    await LocalStore.instance.put(table, {...existing, ...patch});
    await Outbox.instance.add(
      table: table,
      op: SyncOp.update,
      rowId: id,
      payload: patch,
    );
    unawaited(sync.drain());
  }

  Future<void> deleteRow(String id) async {
    await LocalStore.instance.markDeleted(table, id);
    await Outbox.instance.add(
      table: table,
      op: SyncOp.delete,
      rowId: id,
      payload: const {},
    );
    unawaited(sync.drain());
  }

  /// RFC 4122 v4, so device-made ids never collide with server-made ones.
  /// Uses a cryptographic source where available — these ids become primary
  /// keys, and a collision would silently overwrite another row.
  static String _uuidV4() {
    final bytes = List<int>.generate(16, (_) => _random.nextInt(256));
    bytes[6] = (bytes[6] & 0x0F) | 0x40; // version 4
    bytes[8] = (bytes[8] & 0x3F) | 0x80; // variant 10x
    final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
    return '${hex.substring(0, 8)}-${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
  }
}

final Random _random = () {
  try {
    return Random.secure();
  } catch (_) {
    return Random();
  }
}();
