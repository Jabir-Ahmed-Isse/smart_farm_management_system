/// An aggregated financial/operational report for one farm over a date range.
/// Built by ReportsRepository and consumed by the screen + PDF/Excel exporters.
class FarmReport {
  const FarmReport({
    required this.farmName,
    required this.start,
    required this.end,
    required this.revenue,
    required this.expenses,
    required this.monthly,
    required this.byCategory,
    required this.crops,
    required this.harvests,
    required this.salesCount,
    required this.expenseCount,
    required this.harvestCount,
  });

  final String farmName;
  final DateTime start;
  final DateTime end;

  final num revenue;
  final num expenses;

  final List<MonthlyPoint> monthly;
  final List<CategoryAmount> byCategory;
  final List<CropPerformance> crops;
  final List<HarvestRow> harvests;

  final int salesCount;
  final int expenseCount;
  final int harvestCount;

  num get profit => revenue - expenses;
  double get margin => revenue == 0 ? 0 : (profit / revenue);

  bool get isEmpty =>
      salesCount == 0 && expenseCount == 0 && harvestCount == 0;
}

/// One month's revenue and expenses, for the trend chart.
class MonthlyPoint {
  const MonthlyPoint({
    required this.label,
    required this.month,
    required this.revenue,
    required this.expenses,
  });

  final String label; // e.g. "Jul"
  final DateTime month;
  final num revenue;
  final num expenses;
}

class CategoryAmount {
  const CategoryAmount(this.name, this.amount);
  final String name;
  final num amount;
}

class CropPerformance {
  const CropPerformance({
    required this.crop,
    required this.revenue,
    required this.expenses,
  });
  final String crop;
  final num revenue;
  final num expenses;
  num get profit => revenue - expenses;
}

class HarvestRow {
  const HarvestRow(this.crop, this.quantity, this.unit);
  final String crop;
  final num quantity;
  final String unit;
}
