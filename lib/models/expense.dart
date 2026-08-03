/// A row from public.expenses, with the joined category name when available.
class Expense {
  const Expense({
    required this.id,
    required this.farmId,
    required this.date,
    required this.totalCost,
    this.categoryId,
    this.categoryName,
    this.plotId,
    this.cropId,
    this.description,
    this.supplier,
    this.paymentMethod,
    this.receiptUrl,
  });

  final String id;
  final String farmId;
  final DateTime date;
  final num totalCost;
  final String? categoryId;
  final String? categoryName;
  final String? plotId;
  final String? cropId;
  final String? description;
  final String? supplier;
  final String? paymentMethod;
  final String? receiptUrl;

  String get title => categoryName ?? description ?? 'Expense';

  factory Expense.fromMap(Map<String, dynamic> map) {
    final cat = map['category'];
    return Expense(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      date: DateTime.parse(map['date'] as String),
      totalCost: (map['total_cost'] as num?) ?? 0,
      categoryId: map['category_id'] as String?,
      categoryName: cat is Map ? cat['name_en'] as String? : null,
      plotId: map['plot_id'] as String?,
      cropId: map['crop_id'] as String?,
      description: map['description'] as String?,
      supplier: map['supplier'] as String?,
      paymentMethod: map['payment_method'] as String?,
      receiptUrl: map['receipt_url'] as String?,
    );
  }
}
