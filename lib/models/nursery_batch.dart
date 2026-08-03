/// A batch of seedlings raised in the nursery (public.nursery_batches).
class NurseryBatch {
  const NurseryBatch({
    required this.id,
    required this.farmId,
    required this.name,
    required this.sowDate,
    required this.status,
    this.variety,
    this.seedSource,
    this.cropId,
    this.plotId,
    this.quantitySown,
    this.quantityGerminated,
    this.quantityTransplanted,
    this.expectedTransplantDate,
    this.actualTransplantDate,
    this.notes,
    this.cropName,
    this.plotName,
  });

  final String id;
  final String farmId;
  final String name;
  final DateTime sowDate;

  /// sown | germinating | hardening | ready | transplanted | failed
  final String status;

  final String? variety;
  final String? seedSource;
  final String? cropId;
  final String? plotId;
  final int? quantitySown;
  final int? quantityGerminated;
  final int? quantityTransplanted;
  final DateTime? expectedTransplantDate;
  final DateTime? actualTransplantDate;
  final String? notes;
  final String? cropName;
  final String? plotName;

  bool get isClosed => status == 'transplanted' || status == 'failed';

  /// Share of sown seed that came up, when both numbers are known.
  double? get germinationRate {
    final sown = quantitySown;
    final up = quantityGerminated;
    if (sown == null || up == null || sown <= 0) return null;
    return up / sown;
  }

  /// Ready (or overdue) to go into the ground.
  bool get isDueToTransplant {
    if (isClosed) return false;
    if (status == 'ready') return true;
    final due = expectedTransplantDate;
    if (due == null) return false;
    final now = DateTime.now();
    return !due.isAfter(DateTime(now.year, now.month, now.day));
  }

  factory NurseryBatch.fromMap(Map<String, dynamic> map) {
    final crop = map['crop'] as Map<String, dynamic>?;
    final plot = map['plot'] as Map<String, dynamic>?;
    return NurseryBatch(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      name: (map['name'] as String?) ?? '',
      sowDate: DateTime.parse(map['sow_date'] as String),
      status: (map['status'] as String?) ?? 'sown',
      variety: map['variety'] as String?,
      seedSource: map['seed_source'] as String?,
      cropId: map['crop_id'] as String?,
      plotId: map['plot_id'] as String?,
      quantitySown: map['quantity_sown'] as int?,
      quantityGerminated: map['quantity_germinated'] as int?,
      quantityTransplanted: map['quantity_transplanted'] as int?,
      expectedTransplantDate: map['expected_transplant_date'] == null
          ? null
          : DateTime.parse(map['expected_transplant_date'] as String),
      actualTransplantDate: map['actual_transplant_date'] == null
          ? null
          : DateTime.parse(map['actual_transplant_date'] as String),
      notes: map['notes'] as String?,
      cropName: crop?['name'] as String?,
      plotName: plot?['name'] as String?,
    );
  }
}
