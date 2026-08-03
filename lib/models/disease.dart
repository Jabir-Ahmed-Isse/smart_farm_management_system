/// A disease reference entry in the admin database (public.diseases).
class Disease {
  const Disease({
    required this.id,
    required this.name,
    this.crop,
    this.severity = 'medium',
    this.symptoms,
    this.causes,
    this.chemicalTreatment,
    this.organicTreatment,
    this.prevention,
    this.recovery,
    this.imageUrl,
  });

  final String id;
  final String name;
  final String? crop;
  final String severity;
  final String? symptoms;
  final String? causes;
  final String? chemicalTreatment;
  final String? organicTreatment;
  final String? prevention;
  final String? recovery;
  final String? imageUrl;

  factory Disease.fromMap(Map<String, dynamic> m) => Disease(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        crop: m['crop'] as String?,
        severity: (m['severity'] as String?) ?? 'medium',
        symptoms: m['symptoms'] as String?,
        causes: m['causes'] as String?,
        chemicalTreatment: m['chemical_treatment'] as String?,
        organicTreatment: m['organic_treatment'] as String?,
        prevention: m['prevention'] as String?,
        recovery: m['recovery'] as String?,
        imageUrl: m['image_url'] as String?,
      );

  Map<String, dynamic> toWriteMap() => {
        'name': name.trim(),
        'crop': _n(crop),
        'severity': severity,
        'symptoms': _n(symptoms),
        'causes': _n(causes),
        'chemical_treatment': _n(chemicalTreatment),
        'organic_treatment': _n(organicTreatment),
        'prevention': _n(prevention),
        'recovery': _n(recovery),
        'image_url': _n(imageUrl),
      };

  static String? _n(String? v) =>
      (v != null && v.trim().isNotEmpty) ? v.trim() : null;
}

const diseaseSeverities = <String>['low', 'medium', 'high', 'critical'];
