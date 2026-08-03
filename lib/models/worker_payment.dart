/// A payment made to a worker (public.worker_payments).
class WorkerPayment {
  const WorkerPayment({
    required this.id,
    required this.farmId,
    required this.workerId,
    required this.amount,
    required this.date,
    this.periodStart,
    this.periodEnd,
    this.method,
    this.notes,
    this.workerName,
  });

  final String id;
  final String farmId;
  final String workerId;
  final num amount;
  final DateTime date;
  final DateTime? periodStart;
  final DateTime? periodEnd;

  /// payment_method enum: cash | mobile_money | bank_transfer | credit
  final String? method;

  final String? notes;
  final String? workerName;

  factory WorkerPayment.fromMap(Map<String, dynamic> map) {
    final worker = map['worker'] as Map<String, dynamic>?;
    return WorkerPayment(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      workerId: map['worker_id'] as String,
      amount: (map['amount'] as num?) ?? 0,
      date: DateTime.parse(map['date'] as String),
      periodStart: map['period_start'] == null
          ? null
          : DateTime.parse(map['period_start'] as String),
      periodEnd: map['period_end'] == null
          ? null
          : DateTime.parse(map['period_end'] as String),
      method: map['method'] as String?,
      notes: map['notes'] as String?,
      workerName: worker?['full_name'] as String?,
    );
  }
}
