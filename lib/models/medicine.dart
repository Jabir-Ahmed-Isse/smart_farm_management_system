/// A medicine/treatment product in the admin catalog (public.medicines).
class Medicine {
  const Medicine({
    required this.id,
    required this.name,
    this.category = 'other',
    this.activeIngredient,
    this.supportedDiseases,
    this.dosagePerLiter,
    this.mixingRatio,
    this.repeatInterval,
    this.maxApplications,
    this.preHarvestInterval,
    this.organicAlternative,
    this.availability,
    this.priceLevel,
    this.safetyNotes,
  });

  final String id;
  final String name;
  final String category;
  final String? activeIngredient;
  final String? supportedDiseases;
  final String? dosagePerLiter;
  final String? mixingRatio;
  final String? repeatInterval;
  final String? maxApplications;
  final String? preHarvestInterval;
  final String? organicAlternative;
  final String? availability;
  final String? priceLevel;
  final String? safetyNotes;

  /// Total medicine for a [liters]-litre sprayer, parsed from [dosagePerLiter]
  /// (e.g. "2 ml" → "30 ml" for 15 L). Null when the dose isn't parseable.
  String? doseFor(int liters) {
    final raw = dosagePerLiter;
    if (raw == null) return null;
    final match = RegExp(r'([\d.]+)\s*([a-zA-Z%]+)?').firstMatch(raw);
    if (match == null) return null;
    final amount = double.tryParse(match.group(1)!);
    if (amount == null) return null;
    final total = amount * liters;
    final unit = (match.group(2) ?? '').trim();
    final num pretty = total == total.roundToDouble() ? total.round() : total;
    return unit.isEmpty ? '$pretty' : '$pretty $unit';
  }

  factory Medicine.fromMap(Map<String, dynamic> m) => Medicine(
        id: m['id'] as String,
        name: (m['name'] as String?) ?? '',
        category: (m['category'] as String?) ?? 'other',
        activeIngredient: m['active_ingredient'] as String?,
        supportedDiseases: m['supported_diseases'] as String?,
        dosagePerLiter: m['dosage_per_liter'] as String?,
        mixingRatio: m['mixing_ratio'] as String?,
        repeatInterval: m['repeat_interval'] as String?,
        maxApplications: m['max_applications'] as String?,
        preHarvestInterval: m['pre_harvest_interval'] as String?,
        organicAlternative: m['organic_alternative'] as String?,
        availability: m['availability'] as String?,
        priceLevel: m['price_level'] as String?,
        safetyNotes: m['safety_notes'] as String?,
      );

  /// Column map for insert/update (excludes id).
  Map<String, dynamic> toWriteMap() => {
        'name': name.trim(),
        'category': category,
        'active_ingredient': _n(activeIngredient),
        'supported_diseases': _n(supportedDiseases),
        'dosage_per_liter': _n(dosagePerLiter),
        'mixing_ratio': _n(mixingRatio),
        'repeat_interval': _n(repeatInterval),
        'max_applications': _n(maxApplications),
        'pre_harvest_interval': _n(preHarvestInterval),
        'organic_alternative': _n(organicAlternative),
        'availability': _n(availability),
        'price_level': _n(priceLevel),
        'safety_notes': _n(safetyNotes),
      };

  static String? _n(String? v) =>
      (v != null && v.trim().isNotEmpty) ? v.trim() : null;
}

const medicineCategories = <String>[
  'fungicide',
  'insecticide',
  'herbicide',
  'bactericide',
  'organic',
  'other',
];
