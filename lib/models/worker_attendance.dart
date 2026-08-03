/// One worker's attendance for one day (public.worker_attendance).
/// Unique per (worker_id, date), so marking a day again updates it.
class WorkerAttendance {
  const WorkerAttendance({
    required this.id,
    required this.farmId,
    required this.workerId,
    required this.date,
    required this.status,
    this.hours,
    this.notes,
    this.workerName,
  });

  final String id;
  final String farmId;
  final String workerId;
  final DateTime date;

  /// present | absent | half_day | leave
  final String status;

  final num? hours;
  final String? notes;
  final String? workerName;

  /// What this day is worth against the daily wage.
  double get payFraction => switch (status) {
        'present' => 1,
        'half_day' => 0.5,
        _ => 0,
      };

  factory WorkerAttendance.fromMap(Map<String, dynamic> map) {
    final worker = map['worker'] as Map<String, dynamic>?;
    return WorkerAttendance(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      workerId: map['worker_id'] as String,
      date: DateTime.parse(map['date'] as String),
      status: (map['status'] as String?) ?? 'present',
      hours: map['hours'] as num?,
      notes: map['notes'] as String?,
      workerName: worker?['full_name'] as String?,
    );
  }
}
