import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/offline/offline_repository.dart';
import '../../../core/offline/sync_service.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/task.dart';

final taskRepositoryProvider = Provider<TaskRepository>((ref) {
  return TaskRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(syncServiceProvider),
  );
});

/// Farm tasks (public.tasks), offline-first: reads come from the local store
/// and writes queue through the outbox, so a task can be created and completed
/// with no signal at all.
class TaskRepository with OfflineRepository {
  TaskRepository(this.client, this.sync);

  @override
  final SupabaseClient client;

  @override
  final SyncService sync;

  @override
  String get table => 'tasks';

  @override
  String get selectClause =>
      'id, farm_id, title, description, status, priority, due_date, '
      'completed_at, plot_id, crop_id, worker_id, created_at, updated_at, '
      'worker:workers(full_name), plot:plots(name), crop:crops(name)';

  /// Open tasks first (soonest due date first), then everything else.
  Future<List<FarmTask>> getTasks(String farmId) async =>
      _shape(await fetchRows(farmId));

  /// Cached-first stream for the tasks list (instant paint).
  Stream<List<FarmTask>> watchTasks(String farmId) =>
      watchRows(farmId).map(_shape);

  static List<FarmTask> _shape(List<Map<String, dynamic>> rows) {
    final tasks = rows.map(FarmTask.fromMap).toList();
    tasks.sort((a, b) {
      if (a.isOpen != b.isOpen) return a.isOpen ? -1 : 1;
      final ad = a.dueDate, bd = b.dueDate;
      if (ad == null && bd == null) return 0;
      if (ad == null) return 1;
      if (bd == null) return -1;
      return a.isOpen ? ad.compareTo(bd) : bd.compareTo(ad);
    });
    return tasks;
  }

  Future<void> createTask({
    required String farmId,
    required String title,
    String? description,
    String status = 'pending',
    String priority = 'medium',
    DateTime? dueDate,
    String? plotId,
    String? cropId,
    String? workerId,
  }) async {
    await createRow({
      'farm_id': farmId,
      'title': title,
      'status': status,
      'priority': priority,
      if (description != null && description.trim().isNotEmpty)
        'description': description.trim(),
      if (dueDate != null) 'due_date': _dateOnly(dueDate),
      if (plotId != null) 'plot_id': plotId,
      if (cropId != null) 'crop_id': cropId,
      if (workerId != null) 'worker_id': workerId,
      if (status == 'completed') 'completed_at': DateTime.now().toIso8601String(),
      'created_by': client.auth.currentUser?.id,
    });
  }

  Future<void> updateTask({
    required String id,
    required String title,
    String? description,
    required String status,
    required String priority,
    DateTime? dueDate,
    String? plotId,
    String? cropId,
    String? workerId,
    DateTime? completedAt,
  }) async {
    await updateRow(id, {
      'title': title,
      'description': (description != null && description.trim().isNotEmpty)
          ? description.trim()
          : null,
      'status': status,
      'priority': priority,
      'due_date': dueDate == null ? null : _dateOnly(dueDate),
      'plot_id': plotId,
      'crop_id': cropId,
      'worker_id': workerId,
      // Stamp on completion, clear when a task is reopened.
      'completed_at': status == 'completed'
          ? (completedAt ?? DateTime.now()).toIso8601String()
          : null,
    });
  }

  /// Tick / untick a task from the list without opening the editor.
  Future<void> setDone(String id, bool done) async {
    await updateRow(id, {
      'status': done ? 'completed' : 'pending',
      'completed_at': done ? DateTime.now().toIso8601String() : null,
    });
  }

  Future<void> deleteTask(String id) => deleteRow(id);

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}

/// All tasks for [farmId].
final tasksForFarmProvider =
    StreamProvider.family<List<FarmTask>, String>((ref, farmId) {
  return ref.watch(taskRepositoryProvider).watchTasks(farmId);
});
