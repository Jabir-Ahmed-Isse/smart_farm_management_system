/// A crop planted on a farm/plot (public.crops). Minimal fields for now —
/// Phase C's crop-management screen will flesh this out.
class Crop {
  const Crop({
    required this.id,
    required this.farmId,
    this.plotId,
    required this.name,
    this.variety,
    this.stage = 'seed',
  });

  final String id;
  final String farmId;
  final String? plotId;
  final String name;
  final String? variety;
  final String stage;

  /// "Tomato · Roma" when a variety is set, otherwise just the name.
  String get displayName =>
      (variety != null && variety!.isNotEmpty) ? '$name · $variety' : name;

  factory Crop.fromMap(Map<String, dynamic> map) {
    return Crop(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      plotId: map['plot_id'] as String?,
      name: map['name'] as String,
      variety: map['variety'] as String?,
      stage: (map['stage'] as String?) ?? 'seed',
    );
  }

  Map<String, dynamic> toMap() => {
        'id': id,
        'farm_id': farmId,
        'plot_id': plotId,
        'name': name,
        'variety': variety,
        'stage': stage,
      };
}
