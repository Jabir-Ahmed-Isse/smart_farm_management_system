/// A row from public.tasks, with the joined worker / plot / crop names.
class FarmTask {
  const FarmTask({
    required this.id,
    required this.farmId,
    required this.title,
    required this.status,
    required this.priority,
    this.description,
    this.dueDate,
    this.completedAt,
    this.plotId,
    this.cropId,
    this.workerId,
    this.workerName,
    this.plotName,
    this.cropName,
  });

  final String id;
  final String farmId;
  final String title;

  /// task_status enum: pending | in_progress | completed | cancelled.
  final String status;

  /// task_priority enum: low | medium | high.
  final String priority;

  final String? description;
  final DateTime? dueDate;
  final DateTime? completedAt;
  final String? plotId;
  final String? cropId;
  final String? workerId;
  final String? workerName;
  final String? plotName;
  final String? cropName;

  bool get isDone => status == 'completed';
  bool get isCancelled => status == 'cancelled';

  /// Still needs doing (not completed and not cancelled).
  bool get isOpen => !isDone && !isCancelled;

  /// Past its due date and still open.
  bool get isOverdue {
    if (dueDate == null || !isOpen) return false;
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    return dueDate!.isBefore(today);
  }

  /// Due today and still open.
  bool get isDueToday {
    if (dueDate == null || !isOpen) return false;
    final now = DateTime.now();
    return dueDate!.year == now.year &&
        dueDate!.month == now.month &&
        dueDate!.day == now.day;
  }

  factory FarmTask.fromMap(Map<String, dynamic> map) {
    final worker = map['worker'] as Map<String, dynamic>?;
    final plot = map['plot'] as Map<String, dynamic>?;
    final crop = map['crop'] as Map<String, dynamic>?;
    return FarmTask(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      title: (map['title'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'pending',
      priority: (map['priority'] as String?) ?? 'medium',
      description: map['description'] as String?,
      dueDate: map['due_date'] == null
          ? null
          : DateTime.parse(map['due_date'] as String),
      completedAt: map['completed_at'] == null
          ? null
          : DateTime.parse(map['completed_at'] as String),
      plotId: map['plot_id'] as String?,
      cropId: map['crop_id'] as String?,
      workerId: map['worker_id'] as String?,
      workerName: worker?['full_name'] as String?,
      plotName: plot?['name'] as String?,
      cropName: crop?['name'] as String?,
    );
  }
}
