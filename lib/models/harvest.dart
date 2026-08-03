/// A row from public.harvests, with the joined crop name when available.
class Harvest {
  const Harvest({
    required this.id,
    required this.farmId,
    required this.date,
    required this.quantity,
    required this.unit,
    this.cropId,
    this.cropName,
    this.plotId,
    this.grade,
    this.notes,
  });

  final String id;
  final String farmId;
  final DateTime date;
  final num quantity;
  final String unit;
  final String? cropId;
  final String? cropName;
  final String? plotId;
  final String? grade;
  final String? notes;

  String get title => 'Harvested ${cropName ?? 'crop'}';

  factory Harvest.fromMap(Map<String, dynamic> map) {
    final crop = map['crop'];
    return Harvest(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      date: DateTime.parse(map['date'] as String),
      quantity: (map['quantity'] as num?) ?? 0,
      unit: (map['unit'] as String?) ?? 'kg',
      cropId: map['crop_id'] as String?,
      cropName: crop is Map ? crop['name'] as String? : null,
      plotId: map['plot_id'] as String?,
      grade: map['grade'] as String?,
      notes: map['notes'] as String?,
    );
  }
}
