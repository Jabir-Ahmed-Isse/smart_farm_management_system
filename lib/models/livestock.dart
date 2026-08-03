/// An animal, or a group of animals tracked together (public.livestock).
class Livestock {
  const Livestock({
    required this.id,
    required this.farmId,
    required this.name,
    required this.species,
    required this.count,
    required this.status,
    this.breed,
    this.sex,
    this.birthDate,
    this.acquiredDate,
    this.acquisitionCost,
    this.notes,
  });

  final String id;
  final String farmId;
  final String name;

  /// cattle | goat | sheep | camel | poultry | donkey | bee | other
  final String species;

  /// 1 for a single animal, more for a herd or flock.
  final int count;

  /// active | sold | dead | butchered
  final String status;

  final String? breed;

  /// male | female | mixed
  final String? sex;

  final DateTime? birthDate;
  final DateTime? acquiredDate;
  final num? acquisitionCost;
  final String? notes;

  bool get isActive => status == 'active';

  bool get isHerd => count > 1;

  /// Rough age in months, when a birth date is known.
  int? get ageMonths {
    final born = birthDate;
    if (born == null) return null;
    final now = DateTime.now();
    return (now.year - born.year) * 12 + (now.month - born.month);
  }

  factory Livestock.fromMap(Map<String, dynamic> map) {
    return Livestock(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      name: (map['name'] as String?) ?? '',
      species: (map['species'] as String?) ?? 'other',
      count: (map['count'] as int?) ?? 1,
      status: (map['status'] as String?) ?? 'active',
      breed: map['breed'] as String?,
      sex: map['sex'] as String?,
      birthDate: map['birth_date'] == null
          ? null
          : DateTime.parse(map['birth_date'] as String),
      acquiredDate: map['acquired_date'] == null
          ? null
          : DateTime.parse(map['acquired_date'] as String),
      acquisitionCost: map['acquisition_cost'] as num?,
      notes: map['notes'] as String?,
    );
  }
}

/// A dated event against an animal or herd (public.livestock_records) —
/// health, breeding, or production.
class LivestockRecord {
  const LivestockRecord({
    required this.id,
    required this.farmId,
    required this.livestockId,
    required this.date,
    required this.kind,
    this.quantity,
    this.unit,
    this.cost,
    this.notes,
  });

  final String id;
  final String farmId;
  final String livestockId;
  final DateTime date;

  /// health | vaccination | treatment | feeding | breeding | milk | egg |
  /// weight | other
  final String kind;

  final num? quantity;
  final String? unit;
  final num? cost;
  final String? notes;

  /// Output events, as opposed to care/cost events.
  bool get isProduction => kind == 'milk' || kind == 'egg';

  factory LivestockRecord.fromMap(Map<String, dynamic> map) {
    return LivestockRecord(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      livestockId: map['livestock_id'] as String,
      date: DateTime.parse(map['date'] as String),
      kind: (map['kind'] as String?) ?? 'health',
      quantity: map['quantity'] as num?,
      unit: map['unit'] as String?,
      cost: map['cost'] as num?,
      notes: map['notes'] as String?,
    );
  }
}
