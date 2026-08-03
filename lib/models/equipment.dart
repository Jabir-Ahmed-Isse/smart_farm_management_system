/// A piece of farm equipment (public.equipment).
class Equipment {
  const Equipment({
    required this.id,
    required this.farmId,
    required this.name,
    required this.status,
    this.type,
    this.serialNumber,
    this.purchaseDate,
    this.purchaseCost,
    this.nextServiceDate,
    this.notes,
  });

  final String id;
  final String farmId;
  final String name;

  /// equipment_status enum: operational | maintenance | broken | retired
  final String status;

  final String? type;
  final String? serialNumber;
  final DateTime? purchaseDate;
  final num? purchaseCost;
  final DateTime? nextServiceDate;
  final String? notes;

  bool get isRetired => status == 'retired';

  /// Down: in the workshop or broken, so it can't be used today.
  bool get needsAttention => status == 'maintenance' || status == 'broken';

  bool get isServiceOverdue {
    if (nextServiceDate == null || isRetired) return false;
    final now = DateTime.now();
    return nextServiceDate!.isBefore(DateTime(now.year, now.month, now.day));
  }

  /// Service falls due within the next 30 days (and isn't already overdue).
  bool get isServiceDueSoon {
    if (nextServiceDate == null || isRetired || isServiceOverdue) return false;
    return nextServiceDate!.isBefore(DateTime.now().add(const Duration(days: 30)));
  }

  factory Equipment.fromMap(Map<String, dynamic> map) {
    return Equipment(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      name: (map['name'] as String?) ?? '',
      status: (map['status'] as String?) ?? 'operational',
      type: map['type'] as String?,
      serialNumber: map['serial_number'] as String?,
      purchaseDate: map['purchase_date'] == null
          ? null
          : DateTime.parse(map['purchase_date'] as String),
      purchaseCost: map['purchase_cost'] as num?,
      nextServiceDate: map['next_service_date'] == null
          ? null
          : DateTime.parse(map['next_service_date'] as String),
      notes: map['notes'] as String?,
    );
  }
}

/// A service / repair record against a piece of equipment
/// (public.equipment_maintenance).
class MaintenanceLog {
  const MaintenanceLog({
    required this.id,
    required this.farmId,
    required this.equipmentId,
    required this.date,
    required this.kind,
    this.cost,
    this.performedBy,
    this.notes,
  });

  final String id;
  final String farmId;
  final String equipmentId;
  final DateTime date;

  /// service | repair | inspection | other
  final String kind;

  final num? cost;
  final String? performedBy;
  final String? notes;

  factory MaintenanceLog.fromMap(Map<String, dynamic> map) {
    return MaintenanceLog(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      equipmentId: map['equipment_id'] as String,
      date: DateTime.parse(map['date'] as String),
      kind: (map['kind'] as String?) ?? 'service',
      cost: map['cost'] as num?,
      performedBy: map['performed_by'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
