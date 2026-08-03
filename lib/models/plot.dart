/// A plot within a farm (public.plots). Minimal fields for now — Phase C's
/// plot-management screen will flesh this out.
class Plot {
  const Plot({
    required this.id,
    required this.farmId,
    required this.name,
    this.type = 'open_field',
    this.area,
    this.areaUnit = 'hectare',
    this.latitude,
    this.longitude,
  });

  final String id;
  final String farmId;
  final String name;
  final String type;
  final num? area;
  final String areaUnit;

  /// Centre point, used to pin the plot on the farm map.
  final double? latitude;
  final double? longitude;

  bool get hasLocation => latitude != null && longitude != null;

  factory Plot.fromMap(Map<String, dynamic> map) {
    return Plot(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      name: map['name'] as String,
      type: (map['type'] as String?) ?? 'open_field',
      area: map['area'] as num?,
      areaUnit: (map['area_unit'] as String?) ?? 'hectare',
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
    );
  }
}
