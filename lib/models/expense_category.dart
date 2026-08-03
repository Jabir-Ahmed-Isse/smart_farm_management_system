/// A row from public.expense_categories (seeded, bilingual EN/SO).
class ExpenseCategory {
  const ExpenseCategory({
    required this.id,
    required this.key,
    required this.nameEn,
    required this.nameSo,
    this.sortOrder = 0,
  });

  final String id;
  final String key;
  final String nameEn;
  final String nameSo;
  final int sortOrder;

  /// Localised label. Somali when [somali] is true, otherwise English.
  String label({bool somali = false}) => somali ? nameSo : nameEn;

  factory ExpenseCategory.fromMap(Map<String, dynamic> map) {
    return ExpenseCategory(
      id: map['id'] as String,
      key: map['key'] as String,
      nameEn: map['name_en'] as String,
      nameSo: map['name_so'] as String,
      sortOrder: (map['sort_order'] as int?) ?? 0,
    );
  }
}
