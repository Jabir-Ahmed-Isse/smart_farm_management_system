/// A row from public.inventory_items.
class InventoryItem {
  const InventoryItem({
    required this.id,
    required this.farmId,
    required this.name,
    required this.category,
    required this.unit,
    required this.quantity,
    required this.reorderLevel,
    this.unitCost,
    this.supplier,
    this.expiryDate,
    this.notes,
  });

  final String id;
  final String farmId;
  final String name;
  final String category;
  final String unit;
  final num quantity;
  final num reorderLevel;
  final num? unitCost;
  final String? supplier;
  final DateTime? expiryDate;
  final String? notes;

  /// At or below the reorder threshold (and a threshold is set).
  bool get isLowStock => reorderLevel > 0 && quantity <= reorderLevel;

  bool get isExpired =>
      expiryDate != null && expiryDate!.isBefore(DateTime.now());

  /// Expires within the next 30 days (but not already expired).
  bool get isExpiringSoon {
    if (expiryDate == null || isExpired) return false;
    return expiryDate!.isBefore(DateTime.now().add(const Duration(days: 30)));
  }

  factory InventoryItem.fromMap(Map<String, dynamic> map) {
    return InventoryItem(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      name: map['name'] as String,
      category: (map['category'] as String?) ?? 'other',
      unit: (map['unit'] as String?) ?? 'unit',
      quantity: (map['quantity'] as num?) ?? 0,
      reorderLevel: (map['reorder_level'] as num?) ?? 0,
      unitCost: map['unit_cost'] as num?,
      supplier: map['supplier'] as String?,
      expiryDate: map['expiry_date'] == null
          ? null
          : DateTime.parse(map['expiry_date'] as String),
      notes: map['notes'] as String?,
    );
  }
}
