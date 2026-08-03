import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/local_store.dart';
import '../../../core/offline/offline_repository.dart';
import '../../../core/offline/sync_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/worker.dart';
import '../../../models/worker_attendance.dart';
import '../../../models/worker_payment.dart';

final workerRepositoryProvider = Provider<WorkerRepository>((ref) {
  return WorkerRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(syncServiceProvider),
  );
});

/// The worker roster (public.workers) plus attendance and pay records
/// (public.worker_attendance, public.worker_payments), all offline-first.
///
/// The roster uses [OfflineRepository] directly (this repo *is* the `workers`
/// table); attendance and payments go through the two table-scoped stores
/// below, since one mixin instance maps to one table. So a worker can be added,
/// marked present, and paid with no signal at all — the writes queue locally
/// and reconcile on reconnect.
class WorkerRepository with OfflineRepository {
  WorkerRepository(this.client, this.sync)
      : _attendance = _AttendanceStore(client, sync),
        _payments = _PaymentStore(client, sync);

  @override
  final SupabaseClient client;

  @override
  final SyncService sync;

  final _AttendanceStore _attendance;
  final _PaymentStore _payments;

  @override
  String get table => 'workers';

  // ------------------------------------------------------------- roster

  /// Active workers first, then alphabetical.
  Future<List<Worker>> getWorkers(String farmId) async =>
      _shape(await fetchRows(farmId));

  /// Cached-first stream for the workers roster (instant paint).
  Stream<List<Worker>> watchWorkers(String farmId) =>
      watchRows(farmId).map(_shape);

  static List<Worker> _shape(List<Map<String, dynamic>> rows) {
    final workers = rows.map(Worker.fromMap).toList();
    workers.sort((a, b) {
      if (a.active != b.active) return a.active ? -1 : 1;
      return a.fullName.toLowerCase().compareTo(b.fullName.toLowerCase());
    });
    return workers;
  }

  Future<Worker> createWorker({
    required String farmId,
    required String fullName,
    String? position,
    String? phone,
    num? dailyWage,
    DateTime? hireDate,
    bool active = true,
  }) async {
    final row = await createRow({
      'farm_id': farmId,
      'full_name': fullName,
      'active': active,
      if (position != null && position.trim().isNotEmpty)
        'position': position.trim(),
      if (phone != null && phone.trim().isNotEmpty) 'phone': phone.trim(),
      if (dailyWage != null) 'daily_wage': dailyWage,
      if (hireDate != null) 'hire_date': _dateOnly(hireDate),
    });
    return Worker.fromMap(row);
  }

  Future<void> updateWorker({
    required String id,
    required String fullName,
    String? position,
    String? phone,
    num? dailyWage,
    DateTime? hireDate,
    required bool active,
  }) async {
    await updateRow(id, {
      'full_name': fullName,
      'position': (position != null && position.trim().isNotEmpty)
          ? position.trim()
          : null,
      'phone': (phone != null && phone.trim().isNotEmpty) ? phone.trim() : null,
      'daily_wage': dailyWage,
      'hire_date': hireDate == null ? null : _dateOnly(hireDate),
      'active': active,
    });
  }

  /// Deleting a worker cascades their attendance and payments on the server
  /// (ON DELETE CASCADE). Any local attendance/payment rows for the worker are
  /// left behind harmlessly and purged on the next pull.
  Future<void> deleteWorker(String id) => deleteRow(id);

  // --------------------------------------------------------- attendance

  Future<List<WorkerAttendance>> getAttendance(
    String workerId, {
    int limit = 60,
  }) async {
    final rows = await _rowsForWorker(_attendance, workerId);
    final mine = rows.where((r) => r['worker_id'] == workerId).toList()
      ..sort((a, b) => _dateStr(b).compareTo(_dateStr(a)));
    return mine.take(limit).map(WorkerAttendance.fromMap).toList();
  }

  /// Mark (or re-mark) one day. The server enforces a unique (worker_id, date)
  /// index; offline we resolve that upsert against the local store — if the day
  /// already has a row we update it, otherwise we insert — so re-marking never
  /// queues a duplicate the index would later reject. Cross-device conflicts are
  /// last-write-wins, per the Phase D design.
  Future<void> markAttendance({
    required String farmId,
    required String workerId,
    required DateTime date,
    required String status,
    num? hours,
    String? notes,
  }) async {
    final dateStr = _dateOnly(date);
    final values = {
      'farm_id': farmId,
      'worker_id': workerId,
      'date': dateStr,
      'status': status,
      'hours': hours,
      'notes': (notes != null && notes.trim().isNotEmpty) ? notes.trim() : null,
      'created_by': client.auth.currentUser?.id,
    };
    final existing = LocalStore.instance
        .list('worker_attendance')
        .where((r) => r['worker_id'] == workerId && r['date'] == dateStr)
        .toList();
    if (existing.isNotEmpty) {
      await _attendance.updateRow(existing.first['id'] as String, values);
    } else {
      await _attendance.createRow(values);
    }
  }

  Future<void> deleteAttendance(String id) => _attendance.deleteRow(id);

  // ----------------------------------------------------------- payments

  Future<List<WorkerPayment>> getPayments(String workerId) async {
    final rows = await _rowsForWorker(_payments, workerId);
    final mine = rows.where((r) => r['worker_id'] == workerId).toList()
      ..sort((a, b) => _dateStr(b).compareTo(_dateStr(a)));
    return mine.map(WorkerPayment.fromMap).toList();
  }

  Future<void> addPayment({
    required String farmId,
    required String workerId,
    required num amount,
    required DateTime date,
    DateTime? periodStart,
    DateTime? periodEnd,
    String? method,
    String? notes,
  }) async {
    await _payments.createRow({
      'farm_id': farmId,
      'worker_id': workerId,
      'amount': amount,
      'date': _dateOnly(date),
      if (periodStart != null) 'period_start': _dateOnly(periodStart),
      if (periodEnd != null) 'period_end': _dateOnly(periodEnd),
      if (method != null) 'method': method,
      if (notes != null && notes.trim().isNotEmpty) 'notes': notes.trim(),
      'created_by': client.auth.currentUser?.id,
    });
  }

  Future<void> deletePayment(String id) => _payments.deleteRow(id);

  // ------------------------------------------------------------- helpers

  /// Attendance/payments are read per worker but stored (and synced) per farm.
  /// We find the worker's farm from the local roster, then let the store pull
  /// the whole farm's rows local-first; the caller filters down to the worker.
  Future<List<Map<String, dynamic>>> _rowsForWorker(
    OfflineRepository store,
    String workerId,
  ) async {
    final farmId = LocalStore.instance.get('workers', workerId)?['farm_id'];
    if (farmId is String) return store.fetchRows(farmId);
    return LocalStore.instance.list(store.table);
  }

  static String _dateStr(Map<String, dynamic> row) => (row['date'] as String?) ?? '';

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// `worker_attendance`, offline-first. Joined worker name survives an online
/// pull; offline-created rows carry the worker id only (name fills in on pull).
class _AttendanceStore with OfflineRepository {
  _AttendanceStore(this.client, this.sync);

  @override
  final SupabaseClient client;

  @override
  final SyncService sync;

  @override
  String get table => 'worker_attendance';

  @override
  String get selectClause => '*, worker:workers(full_name)';
}

/// `worker_payments`, offline-first (same joined-name behaviour as attendance).
class _PaymentStore with OfflineRepository {
  _PaymentStore(this.client, this.sync);

  @override
  final SupabaseClient client;

  @override
  final SyncService sync;

  @override
  String get table => 'worker_payments';

  @override
  String get selectClause => '*, worker:workers(full_name)';
}

/// The worker roster for [farmId]. Also feeds the task assignee dropdown.
final workersForFarmProvider =
    StreamProvider.family<List<Worker>, String>((ref, farmId) {
  return ref.watch(workerRepositoryProvider).watchWorkers(farmId);
});

/// Recent attendance for one worker (newest first).
final workerAttendanceProvider =
    FutureProvider.family<List<WorkerAttendance>, String>((ref, workerId) {
  return ref.watch(workerRepositoryProvider).getAttendance(workerId);
});

/// All payments to one worker (newest first).
final workerPaymentsProvider =
    FutureProvider.family<List<WorkerPayment>, String>((ref, workerId) {
  return ref.watch(workerRepositoryProvider).getPayments(workerId);
});
