import 'dart:convert';

/// A saved AI Plant Doctor result (public.ai_diagnoses).
///
/// The columns we filter/sort on are top-level; the full structured report
/// (symptoms, treatments, dosing, prevention …) rides in [report] and is
/// surfaced through typed getters so the UI never touches raw AI JSON.
class PlantDiagnosis {
  const PlantDiagnosis({
    required this.id,
    required this.farmId,
    this.cropId,
    this.plotId,
    this.imageUrl,
    required this.plantName,
    required this.healthStatus,
    required this.confidence,
    this.diseaseName,
    this.severity,
    required this.needsExpert,
    required this.language,
    this.recoveryStatus = 'pending',
    this.notes,
    required this.report,
    required this.createdAt,
  });

  final String id;
  final String farmId;
  final String? cropId;
  final String? plotId;
  final String? imageUrl;

  final String plantName;

  /// 'healthy' | 'diseased' | 'unknown'
  final String healthStatus;

  /// 0–100.
  final num confidence;

  final String? diseaseName;

  /// 'low' | 'medium' | 'high' | 'critical'
  final String? severity;

  /// True when confidence < 70 — the UI recommends an expert.
  final bool needsExpert;

  /// 'en' | 'so'
  final String language;

  /// 'pending' | 'recovering' | 'recovered' | 'failed' (farmer-updated).
  final String recoveryStatus;
  final String? notes;

  /// The full structured diagnosis as returned by the model.
  final Map<String, dynamic> report;

  final DateTime createdAt;

  bool get isHealthy => healthStatus == 'healthy';
  bool get isDiseased => healthStatus == 'diseased';
  int get confidencePct => confidence.round();

  // --- structured fields drawn from [report] -------------------------------

  String? get plantVariety => _str('plant_variety');
  List<String> get possibleDiseases => _list('possible_diseases');
  String? get affectedPart => _str('affected_part');
  String? get diseaseStage => _str('disease_stage');
  List<String> get symptoms => _list('symptoms');
  String? get cause => _str('cause');
  String? get environmentalFactors => _str('environmental_factors');
  String? get spreadRisk => _str('spread_risk');
  String? get estimatedYieldLoss => _str('estimated_yield_loss');
  String? get recoveryProbability => _str('recovery_probability');
  List<String> get recommendedActions => _list('recommended_actions');
  List<String> get organicTreatment => _list('organic_treatment');
  List<String> get safetyInstructions => _list('safety_instructions');
  List<String> get protectiveEquipment => _list('protective_equipment');
  List<String> get preventionTips => _list('prevention_tips');
  String? get expectedRecoveryTime => _str('expected_recovery_time');
  String? get weatherRecommendation => _str('weather_recommendation');

  ChemicalTreatment? get chemicalTreatment {
    final raw = report['chemical_treatment'];
    if (raw is Map) return ChemicalTreatment.fromMap(Map<String, dynamic>.from(raw));
    return null;
  }

  /// Two or three medicine options so the farmer can pick by what's available
  /// or affordable. New reports carry `medicine_options`; older ones fall back
  /// to the single `chemical_treatment` field.
  List<ChemicalTreatment> get medicineOptions {
    final raw = report['medicine_options'];
    if (raw is List) {
      final list = raw
          .whereType<Map>()
          .map((m) => ChemicalTreatment.fromMap(Map<String, dynamic>.from(m)))
          .where((c) => c.hasContent)
          .toList();
      if (list.isNotEmpty) return list;
    }
    final single = chemicalTreatment;
    return (single != null && single.hasContent) ? [single] : const [];
  }

  String? _str(String key) {
    final v = report[key];
    return (v is String && v.trim().isNotEmpty) ? v.trim() : null;
  }

  List<String> _list(String key) {
    final v = report[key];
    if (v is List) {
      return v.map((e) => e.toString()).where((s) => s.trim().isNotEmpty).toList();
    }
    return const [];
  }

  factory PlantDiagnosis.fromMap(Map<String, dynamic> map) {
    // `report` arrives as a decoded Map from PostgREST, but tolerate a String.
    final rawReport = map['report'];
    final report = switch (rawReport) {
      Map() => Map<String, dynamic>.from(rawReport),
      String() when rawReport.isNotEmpty =>
        (jsonDecode(rawReport) as Map).cast<String, dynamic>(),
      _ => <String, dynamic>{},
    };
    return PlantDiagnosis(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      cropId: map['crop_id'] as String?,
      plotId: map['plot_id'] as String?,
      imageUrl: map['image_url'] as String?,
      plantName: (map['plant_name'] as String?)?.trim().isNotEmpty == true
          ? (map['plant_name'] as String).trim()
          : 'Unknown plant',
      healthStatus: (map['health_status'] as String?) ?? 'unknown',
      confidence: (map['confidence'] as num?) ?? 0,
      diseaseName: map['disease_name'] as String?,
      severity: map['severity'] as String?,
      needsExpert: (map['needs_expert'] as bool?) ?? false,
      language: (map['language'] as String?) ?? 'en',
      recoveryStatus: (map['recovery_status'] as String?) ?? 'pending',
      notes: map['notes'] as String?,
      report: report,
      createdAt: DateTime.tryParse(map['created_at'] as String? ?? '') ??
          DateTime.now(),
    );
  }
}

/// The chemical treatment block plus the sprayer-dose calculator.
class ChemicalTreatment {
  const ChemicalTreatment({
    this.medicineName,
    this.activeIngredient,
    this.mixingRatio,
    this.dosePerLiter,
    this.repeatInterval,
    this.maxApplications,
    this.preHarvestInterval,
  });

  final String? medicineName;
  final String? activeIngredient;
  final String? mixingRatio;

  /// Free text like "2 ml" or "1.5 g" — parsed by [doseFor].
  final String? dosePerLiter;
  final String? repeatInterval;
  final String? maxApplications;
  final String? preHarvestInterval;

  factory ChemicalTreatment.fromMap(Map<String, dynamic> m) => ChemicalTreatment(
        medicineName: _s(m['medicine_name']),
        activeIngredient: _s(m['active_ingredient']),
        mixingRatio: _s(m['mixing_ratio']),
        dosePerLiter: _s(m['dose_per_liter']),
        repeatInterval: _s(m['repeat_interval']),
        maxApplications: _s(m['max_applications']),
        preHarvestInterval: _s(m['pre_harvest_interval']),
      );

  /// The numeric amount + unit pulled out of [dosePerLiter], e.g. (2.5, "ml").
  (double, String)? get _parsedDose {
    final raw = dosePerLiter;
    if (raw == null) return null;
    final match = RegExp(r'([\d.]+)\s*([a-zA-Z%]+)?').firstMatch(raw);
    if (match == null) return null;
    final amount = double.tryParse(match.group(1)!);
    if (amount == null) return null;
    return (amount, (match.group(2) ?? '').trim());
  }

  /// Total medicine for a [liters]-litre sprayer, e.g. "37.5 ml", or null if
  /// the per-litre dose could not be parsed.
  String? doseFor(int liters) {
    final parsed = _parsedDose;
    if (parsed == null) return null;
    final total = parsed.$1 * liters;
    final unit = parsed.$2;
    final num pretty = total == total.roundToDouble() ? total.round() : total;
    return unit.isEmpty ? '$pretty' : '$pretty $unit';
  }

  bool get hasContent =>
      (medicineName ?? activeIngredient ?? dosePerLiter) != null;

  static String? _s(dynamic v) =>
      (v is String && v.trim().isNotEmpty) ? v.trim() : null;
}
