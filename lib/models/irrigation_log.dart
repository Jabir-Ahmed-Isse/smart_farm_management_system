/// A watering event (public.irrigation_logs), optionally tied to a plot/crop.
class IrrigationLog {
  const IrrigationLog({
    required this.id,
    required this.farmId,
    required this.date,
    required this.method,
    this.plotId,
    this.cropId,
    this.source,
    this.durationMinutes,
    this.volume,
    this.volumeUnit = 'liter',
    this.cost,
    this.notes,
    this.plotName,
    this.cropName,
  });

  final String id;
  final String farmId;
  final DateTime date;

  /// drip | sprinkler | flood | furrow | manual | rain | other
  final String method;

  final String? plotId;
  final String? cropId;

  /// well | borehole | river | canal | dam | rain | municipal | tanker | other
  final String? source;

  final num? durationMinutes;
  final num? volume;
  final String volumeUnit;
  final num? cost;
  final String? notes;
  final String? plotName;
  final String? cropName;

  factory IrrigationLog.fromMap(Map<String, dynamic> map) {
    final plot = map['plot'] as Map<String, dynamic>?;
    final crop = map['crop'] as Map<String, dynamic>?;
    return IrrigationLog(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      date: DateTime.parse(map['date'] as String),
      method: (map['method'] as String?) ?? 'manual',
      plotId: map['plot_id'] as String?,
      cropId: map['crop_id'] as String?,
      source: map['source'] as String?,
      durationMinutes: map['duration_minutes'] as num?,
      volume: map['volume'] as num?,
      volumeUnit: (map['volume_unit'] as String?) ?? 'liter',
      cost: map['cost'] as num?,
      notes: map['notes'] as String?,
      plotName: plot?['name'] as String?,
      cropName: crop?['name'] as String?,
    );
  }
}
