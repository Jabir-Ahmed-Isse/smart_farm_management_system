/// A row from public.sales, with the joined crop name when available.
class Sale {
  const Sale({
    required this.id,
    required this.farmId,
    required this.date,
    required this.quantity,
    required this.unit,
    required this.unitPrice,
    required this.discount,
    required this.totalPrice,
    required this.paymentStatus,
    this.cropId,
    this.cropName,
    this.customer,
    this.market,
    this.paymentMethod,
  });

  final String id;
  final String farmId;
  final DateTime date;
  final num quantity;
  final String unit;
  final num unitPrice;
  final num discount;
  final num totalPrice;
  final String paymentStatus;
  final String? cropId;
  final String? cropName;
  final String? customer;
  final String? market;
  final String? paymentMethod;

  String get title => 'Sold ${cropName ?? 'produce'}';

  factory Sale.fromMap(Map<String, dynamic> map) {
    final crop = map['crop'];
    return Sale(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      date: DateTime.parse(map['date'] as String),
      quantity: (map['quantity'] as num?) ?? 0,
      unit: (map['unit'] as String?) ?? 'kg',
      unitPrice: (map['unit_price'] as num?) ?? 0,
      discount: (map['discount'] as num?) ?? 0,
      totalPrice: (map['total_price'] as num?) ?? 0,
      paymentStatus: (map['payment_status'] as String?) ?? 'paid',
      cropId: map['crop_id'] as String?,
      cropName: crop is Map ? crop['name'] as String? : null,
      customer: map['customer'] as String?,
      market: map['market'] as String?,
      paymentMethod: map['payment_method'] as String?,
    );
  }
}
