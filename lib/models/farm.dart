/// A farm row (public.farms).
class Farm {
  const Farm({
    required this.id,
    required this.name,
    this.region,
    this.district,
    this.location,
    this.latitude,
    this.longitude,
    this.totalArea,
    this.areaUnit = 'hectare',
    this.description,
    this.photoUrl,
  });

  final String id;
  final String name;
  final String? region;
  final String? district;
  final String? location;
  final double? latitude;
  final double? longitude;
  final num? totalArea;
  final String areaUnit;
  final String? description;
  final String? photoUrl;

  bool get hasLocation => latitude != null && longitude != null;

  String get locationLabel {
    final parts = [region, district].where((p) => p != null && p.isNotEmpty);
    return parts.isEmpty ? 'No location set' : parts.join(' · ');
  }

  factory Farm.fromMap(Map<String, dynamic> map) {
    return Farm(
      id: map['id'] as String,
      name: map['name'] as String,
      region: map['region'] as String?,
      district: map['district'] as String?,
      location: map['location'] as String?,
      latitude: (map['latitude'] as num?)?.toDouble(),
      longitude: (map['longitude'] as num?)?.toDouble(),
      totalArea: map['total_area'] as num?,
      areaUnit: (map['area_unit'] as String?) ?? 'hectare',
      description: map['description'] as String?,
      photoUrl: map['photo_url'] as String?,
    );
  }
}
