import 'dart:async';

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../supabase/supabase_providers.dart';
import 'local_store.dart';
import 'outbox.dart';

/// What the sync engine is doing right now, for the UI banner.
class SyncStatus {
  const SyncStatus({
    required this.online,
    required this.syncing,
    required this.pending,
    required this.stuck,
    this.lastSyncedAt,
    this.lastError,
  });

  final bool online;
  final bool syncing;
  final int pending;
  final int stuck;
  final DateTime? lastSyncedAt;
  final String? lastError;

  bool get hasPending => pending > 0;

  /// Everything the device knows about has reached the server.
  bool get isClean => online && !syncing && pending == 0 && stuck == 0;

  SyncStatus copyWith({
    bool? online,
    bool? syncing,
    int? pending,
    int? stuck,
    DateTime? lastSyncedAt,
    String? lastError,
    bool clearError = false,
  }) =>
      SyncStatus(
        online: online ?? this.online,
        syncing: syncing ?? this.syncing,
        pending: pending ?? this.pending,
        stuck: stuck ?? this.stuck,
        lastSyncedAt: lastSyncedAt ?? this.lastSyncedAt,
        lastError: clearError ? null : (lastError ?? this.lastError),
      );

  static const initial =
      SyncStatus(online: true, syncing: false, pending: 0, stuck: 0);
}

final syncServiceProvider = Provider<SyncService>((ref) {
  final service = SyncService(ref.watch(supabaseClientProvider), ref);
  ref.onDispose(service.dispose);
  return service;
});

/// Live sync state for the UI.
final syncStatusProvider = StateProvider<SyncStatus>((ref) => SyncStatus.initial);

/// Drains the outbox to Supabase when a connection is available, and pulls
/// server changes back into the local store.
class SyncService {
  SyncService(this._client, this._ref);

  final SupabaseClient _client;
  final Ref _ref;

  StreamSubscription<List<ConnectivityResult>>? _connSub;
  Timer? _retryTimer;
  bool _draining = false;

  void start() {
    _refreshCounts();
    _connSub = Connectivity().onConnectivityChanged.listen((results) {
      final online = !results.contains(ConnectivityResult.none);
      _setStatus((s) => s.copyWith(online: online));
      // Coming back online is the moment queued work should go out.
      if (online) unawaited(drain());
    });
    // A periodic nudge covers the case where connectivity looks fine but the
    // server was unreachable — captive portals, server restarts, flaky mobile.
    _retryTimer = Timer.periodic(const Duration(minutes: 2), (_) => drain());
  }

  void dispose() {
    _connSub?.cancel();
    _retryTimer?.cancel();
  }

  void _setStatus(SyncStatus Function(SyncStatus) update) {
    final notifier = _ref.read(syncStatusProvider.notifier);
    notifier.state = update(notifier.state);
  }

  void _refreshCounts() {
    final outbox = Outbox.instance;
    _setStatus((s) => s.copyWith(
          pending: outbox.pendingCount,
          stuck: outbox.stuck().length,
        ));
  }

  /// Push every queued write, oldest first. Stops at the first network-looking
  /// failure so ordering is preserved; permanent rejections are counted against
  /// the entry and eventually park it as "stuck" for the user to resolve.
  Future<void> drain() async {
    if (_draining) return;
    final outbox = Outbox.instance;
    final entries = outbox.pending();
    if (entries.isEmpty) {
      _refreshCounts();
      return;
    }

    _draining = true;
    _setStatus((s) => s.copyWith(syncing: true, clearError: true));
    try {
      for (final entry in entries) {
        try {
          await _push(entry);
          await outbox.remove(entry.key);
        } on PostgrestException catch (e) {
          // The server answered and refused — retrying immediately will not
          // help, so record it and keep going with the rest of the queue.
          await outbox.recordFailure(entry, e);
          _setStatus((s) => s.copyWith(lastError: e.message));
        } catch (e) {
          // Looks like a transport problem: stop, keep order, try again later.
          await outbox.recordFailure(entry, e);
          _setStatus((s) => s.copyWith(lastError: e.toString(), online: false));
          break;
        }
      }
      _setStatus((s) => s.copyWith(lastSyncedAt: DateTime.now()));
    } finally {
      _draining = false;
      _setStatus((s) => s.copyWith(syncing: false));
      _refreshCounts();
    }
  }

  Future<void> _push(OutboxEntry entry) async {
    switch (entry.op) {
      case SyncOp.insert:
        final row = await _client
            .from(entry.table)
            .insert(entry.payload)
            .select()
            .single();
        // Keep the local copy authoritative-shaped (server defaults, triggers).
        await LocalStore.instance.put(entry.table, row);
      case SyncOp.update:
        await _client
            .from(entry.table)
            .update(entry.payload)
            .eq('id', entry.rowId);
      case SyncOp.delete:
        await _client.from(entry.table).delete().eq('id', entry.rowId);
        await LocalStore.instance.purge(entry.table, entry.rowId);
    }
  }

  /// Fetch [table] for [farmId] and refresh the local mirror.
  ///
  /// Pending local writes win: a row still in the outbox is not overwritten by
  /// the server's older copy, and is not purged as "missing upstream".
  Future<List<Map<String, dynamic>>> pull(
    String table,
    String farmId, {
    String select = '*',
  }) async {
    final rows = await _client.from(table).select(select).eq('farm_id', farmId);
    final list = rows.map((r) => Map<String, dynamic>.from(r)).toList();

    final pendingIds = Outbox.instance.pendingIds(table);
    final store = LocalStore.instance;
    await store.putAll(
      table,
      list.where((r) => !pendingIds.contains(r['id'])).toList(),
    );
    await store.reconcile(
      table,
      farmId,
      list.map((r) => r['id'] as String).toSet(),
      pendingIds,
    );
    await store.setLastSync(table, DateTime.now());
    return store.list(table, farmId: farmId);
  }

  /// Abandon a write that the server keeps rejecting.
  Future<void> discardStuck(int key) async {
    await Outbox.instance.discard(key);
    _refreshCounts();
  }
}
