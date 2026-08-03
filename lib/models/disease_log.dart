/// A pest/disease observation (public.disease_logs), optionally tied to a plot.
class DiseaseLog {
  const DiseaseLog({
    required this.id,
    required this.farmId,
    required this.name,
    required this.kind,
    required this.severity,
    required this.status,
    required this.observedDate,
    this.plotId,
    this.cropId,
    this.treatment,
    this.notes,
    this.plotName,
    this.cropName,
  });

  final String id;
  final String farmId;
  final String name;
  final String kind; // 'pest' | 'disease'
  final String severity; // 'low' | 'medium' | 'high'
  final String status; // 'active' | 'treated' | 'resolved'
  final DateTime observedDate;
  final String? plotId;
  final String? cropId;
  final String? treatment;
  final String? notes;

  /// Joined names, populated by the farm-wide list (null in plot-scoped reads).
  final String? plotName;
  final String? cropName;

  /// Still a live problem, as opposed to treated or resolved.
  bool get isActive => status == 'active';

  factory DiseaseLog.fromMap(Map<String, dynamic> map) {
    final plot = map['plot'] as Map<String, dynamic>?;
    final crop = map['crop'] as Map<String, dynamic>?;
    return DiseaseLog(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      name: map['name'] as String,
      kind: (map['kind'] as String?) ?? 'disease',
      severity: (map['severity'] as String?) ?? 'medium',
      status: (map['status'] as String?) ?? 'active',
      observedDate: DateTime.parse(map['observed_date'] as String),
      plotId: map['plot_id'] as String?,
      cropId: map['crop_id'] as String?,
      treatment: map['treatment'] as String?,
      notes: map['notes'] as String?,
      plotName: plot?['name'] as String?,
      cropName: crop?['name'] as String?,
    );
  }
}
