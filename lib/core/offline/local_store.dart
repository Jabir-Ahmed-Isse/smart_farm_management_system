import 'dart:async';

import 'package:hive_ce_flutter/hive_flutter.dart';

/// The device-local mirror of the farm's data — Phase D's source of truth.
///
/// Every entity type shares one box instead of getting its own typed table.
/// Records are keyed `"<table>:<id>"` and hold the same JSON map PostgREST
/// returns, so a repository can read a row offline exactly as it would online.
/// At one farm's data volume (thousands of rows, not millions) filtering in
/// Dart is cheap, and a new module needs no local schema change at all.
class LocalStore {
  LocalStore._(this._records, this._meta);

  static const _recordsBox = 'sfms_records';
  static const _metaBox = 'sfms_meta';

  final Box<Map> _records;
  final Box _meta;

  static LocalStore? _instance;
  static LocalStore get instance {
    final i = _instance;
    if (i == null) {
      throw StateError('LocalStore.init() must be awaited before use.');
    }
    return i;
  }

  static bool get isReady => _instance != null;

  static Future<LocalStore> init() async {
    if (_instance != null) return _instance!;
    await Hive.initFlutter();
    final records = await Hive.openBox<Map>(_recordsBox);
    final meta = await Hive.openBox(_metaBox);
    return _instance = LocalStore._(records, meta);
  }

  static String _key(String table, String id) => '$table:$id';

  /// Every non-deleted row of [table], optionally scoped to one farm.
  List<Map<String, dynamic>> list(String table, {String? farmId}) {
    final prefix = '$table:';
    final out = <Map<String, dynamic>>[];
    for (final key in _records.keys) {
      if (key is! String || !key.startsWith(prefix)) continue;
      final row = _records.get(key);
      if (row == null) continue;
      final map = Map<String, dynamic>.from(row);
      if (map['_deleted'] == true) continue;
      if (farmId != null && map['farm_id'] != farmId) continue;
      out.add(map);
    }
    return out;
  }

  Map<String, dynamic>? get(String table, String id) {
    final row = _records.get(_key(table, id));
    if (row == null) return null;
    final map = Map<String, dynamic>.from(row);
    return map['_deleted'] == true ? null : map;
  }

  Future<void> put(String table, Map<String, dynamic> row) async {
    final id = row['id'];
    if (id is! String) return;
    await _records.put(_key(table, id), row);
  }

  Future<void> putAll(String table, List<Map<String, dynamic>> rows) async {
    final entries = <String, Map<String, dynamic>>{};
    for (final row in rows) {
      final id = row['id'];
      if (id is String) entries[_key(table, id)] = row;
    }
    await _records.putAll(entries);
  }

  /// Tombstone rather than a hard delete, so a pending offline delete is not
  /// resurrected by a pull that still sees the row on the server.
  Future<void> markDeleted(String table, String id) async {
    final existing = _records.get(_key(table, id));
    final map = existing == null
        ? <String, dynamic>{'id': id}
        : Map<String, dynamic>.from(existing);
    map['_deleted'] = true;
    await _records.put(_key(table, id), map);
  }

  Future<void> purge(String table, String id) => _records.delete(_key(table, id));

  /// Drop rows of [table] that the server no longer has, so deletions made on
  /// another device eventually disappear here too. Rows still waiting in the
  /// outbox are kept — they have never reached the server yet.
  Future<void> reconcile(
    String table,
    String farmId,
    Set<String> serverIds,
    Set<String> pendingIds,
  ) async {
    final stale = list(table, farmId: farmId)
        .map((r) => r['id'] as String)
        .where((id) => !serverIds.contains(id) && !pendingIds.contains(id))
        .toList();
    for (final id in stale) {
      await purge(table, id);
    }
  }

  DateTime? lastSync(String table) {
    final raw = _meta.get('last_sync:$table');
    return raw is String ? DateTime.tryParse(raw) : null;
  }

  Future<void> setLastSync(String table, DateTime at) =>
      _meta.put('last_sync:$table', at.toIso8601String());

  /// Generic device-local key/value (UI prefs like "notifications last seen").
  Object? metaGet(String key) => _meta.get(key);
  Future<void> metaPut(String key, Object? value) => _meta.put(key, value);

  Future<void> clear() async {
    await _records.clear();
    await _meta.clear();
  }
}
