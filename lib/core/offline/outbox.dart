import 'package:hive_ce_flutter/hive_flutter.dart';

/// What a queued write does when it reaches the server.
enum SyncOp { insert, update, delete }

/// A write made on the device that has not reached Supabase yet.
class OutboxEntry {
  const OutboxEntry({
    required this.key,
    required this.table,
    required this.op,
    required this.rowId,
    required this.payload,
    required this.createdAt,
    this.attempts = 0,
    this.lastError,
  });

  final int key;
  final String table;
  final SyncOp op;
  final String rowId;
  final Map<String, dynamic> payload;
  final DateTime createdAt;
  final int attempts;
  final String? lastError;

  /// Given up on after repeated rejections — almost always a permanent problem
  /// (RLS denial, constraint violation), not a flaky connection.
  bool get isStuck => attempts >= 5;

  Map<String, dynamic> toMap() => {
        'table': table,
        'op': op.name,
        'row_id': rowId,
        'payload': payload,
        'created_at': createdAt.toIso8601String(),
        'attempts': attempts,
        'last_error': lastError,
      };

  static OutboxEntry fromMap(int key, Map map) => OutboxEntry(
        key: key,
        table: map['table'] as String,
        op: SyncOp.values.firstWhere((o) => o.name == map['op'],
            orElse: () => SyncOp.insert),
        rowId: map['row_id'] as String,
        payload: Map<String, dynamic>.from(map['payload'] as Map? ?? const {}),
        createdAt:
            DateTime.tryParse(map['created_at'] as String? ?? '') ?? DateTime.now(),
        attempts: (map['attempts'] as int?) ?? 0,
        lastError: map['last_error'] as String?,
      );
}

/// FIFO queue of pending writes. Order matters: an insert must reach the server
/// before the update that follows it, so entries are drained oldest-first.
class Outbox {
  Outbox._(this._box);

  static const _boxName = 'sfms_outbox';

  final Box<Map> _box;

  static Outbox? _instance;
  static Outbox get instance {
    final i = _instance;
    if (i == null) throw StateError('Outbox.init() must be awaited before use.');
    return i;
  }

  static Future<Outbox> init() async {
    if (_instance != null) return _instance!;
    return _instance = Outbox._(await Hive.openBox<Map>(_boxName));
  }

  /// Oldest first, skipping entries that have already failed too often.
  List<OutboxEntry> pending() {
    final all = _box.keys
        .whereType<int>()
        .map((k) => OutboxEntry.fromMap(k, _box.get(k)!))
        .where((e) => !e.isStuck)
        .toList()
      ..sort((a, b) => a.createdAt.compareTo(b.createdAt));
    return all;
  }

  List<OutboxEntry> stuck() => _box.keys
      .whereType<int>()
      .map((k) => OutboxEntry.fromMap(k, _box.get(k)!))
      .where((e) => e.isStuck)
      .toList();

  int get pendingCount => pending().length;

  /// Row ids with a queued write, so a pull does not delete them locally.
  Set<String> pendingIds(String table) => _box.keys
      .whereType<int>()
      .map((k) => OutboxEntry.fromMap(k, _box.get(k)!))
      .where((e) => e.table == table)
      .map((e) => e.rowId)
      .toSet();

  Future<void> add({
    required String table,
    required SyncOp op,
    required String rowId,
    required Map<String, dynamic> payload,
  }) async {
    await _box.add(OutboxEntry(
      key: -1,
      table: table,
      op: op,
      rowId: rowId,
      payload: payload,
      createdAt: DateTime.now(),
    ).toMap());
  }

  Future<void> remove(int key) => _box.delete(key);

  Future<void> recordFailure(OutboxEntry entry, Object error) async {
    await _box.put(entry.key, {
      ...entry.toMap(),
      'attempts': entry.attempts + 1,
      'last_error': error.toString(),
    });
  }

  /// Drop a stuck entry the user has chosen to abandon.
  Future<void> discard(int key) => _box.delete(key);

  Future<void> clear() => _box.clear();
}
