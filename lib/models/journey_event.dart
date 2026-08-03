/// One entry on a crop's journey timeline, aggregated from the farm's existing
/// records (planting, irrigation, expenses, disease/AI, harvest, sales, tasks).
enum JEventType {
  planted,
  irrigation,
  fertilizer,
  expense,
  disease,
  ai,
  treatment,
  harvest,
  sale,
  task,
  weather,
}

class JourneyEvent {
  const JourneyEvent({
    required this.type,
    required this.date,
    required this.title,
    required this.tags,
    this.time,
    this.description,
    this.cost,
    this.details = const [],
    this.photos = const [],
    this.danger = false,
    this.actionLabel,
    this.diagnosisId,
  });

  final JEventType type;
  final DateTime date;
  final String title;

  /// Filter keys this event belongs to (e.g. {'sales','financial'}).
  final Set<String> tags;

  final String? time;
  final String? description;
  final double? cost;

  /// Label/value rows shown in the card body (Confidence, Severity, …).
  final List<(String, String)> details;
  final List<String> photos;

  /// Renders as the red "alert" card (disease / unhealthy AI diagnosis).
  final bool danger;

  /// Optional CTA (e.g. "View AI Report").
  final String? actionLabel;
  final String? diagnosisId;

  bool matches(String filter) => filter == 'all' || tags.contains(filter);

  /// Free-text haystack for the search box.
  String get searchText => [
        title,
        description ?? '',
        for (final d in details) '${d.$1} ${d.$2}',
      ].join(' ').toLowerCase();
}

/// The full journey for one crop: overview + timeline + summary + finances.
class CropJourney {
  const CropJourney({
    required this.cropId,
    required this.name,
    this.variety,
    this.plotName,
    this.plotType,
    this.photoUrl,
    this.plantingDate,
    this.expectedHarvest,
    required this.stage,
    this.expectedYield,
    this.yieldUnit,
    required this.healthScore,
    required this.healthLabel,
    required this.healthStatus,
    required this.aiSummary,
    required this.totalExpenses,
    required this.totalRevenue,
    required this.netProfit,
    required this.events,
    required this.diagnosisCount,
    required this.diseaseCount,
    required this.irrigationCount,
    required this.harvestCount,
    required this.saleCount,
  });

  final String cropId;
  final String name;
  final String? variety;
  final String? plotName;
  final String? plotType; // greenhouse | open_field
  final String? photoUrl;
  final DateTime? plantingDate;
  final DateTime? expectedHarvest;
  final String stage;
  final num? expectedYield;
  final String? yieldUnit;

  final int healthScore; // 0-100
  final String healthLabel; // Excellent / Good / Fair / Poor / Critical
  final String healthStatus; // HEALTHY / MONITOR / AT RISK
  final String aiSummary;

  final double totalExpenses;
  final double totalRevenue;
  final double netProfit;

  final List<JourneyEvent> events; // chronological (oldest first)

  final int diagnosisCount;
  final int diseaseCount;
  final int irrigationCount;
  final int harvestCount;
  final int saleCount;

  int? get daysPlanted => plantingDate == null
      ? null
      : DateTime.now().difference(plantingDate!).inDays;

  bool get isGreenhouse => plotType == 'greenhouse';
}

/// Timeline filter chips (key, label). "financial" spans expenses + sales.
const journeyFilters = <(String, String)>[
  ('all', 'All'),
  ('crop', 'Crop'),
  ('financial', 'Financial'),
  ('ai', 'AI'),
  ('disease', 'Disease'),
  ('treatment', 'Treatment'),
  ('irrigation', 'Irrigation'),
  ('fertilizer', 'Fertilizer'),
  ('harvest', 'Harvest'),
  ('sales', 'Sales'),
  ('workers', 'Workers'),
];
