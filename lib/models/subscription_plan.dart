/// A subscription plan defining monthly AI credit limits (-1 = unlimited).
class SubscriptionPlan {
  const SubscriptionPlan({
    required this.code,
    required this.name,
    required this.diagnosisLimit,
    required this.chatLimit,
    required this.insightLimit,
    required this.price,
    this.features,
    this.userCount = 0,
  });

  final String code;
  final String name;
  final int diagnosisLimit;
  final int chatLimit;
  final int insightLimit;
  final num price;
  final String? features;
  final int userCount;

  static String limitLabel(int v) => v < 0 ? 'Unlimited' : '$v';

  SubscriptionPlan copyWith({
    int? diagnosisLimit,
    int? chatLimit,
    int? insightLimit,
    num? price,
    String? features,
    int? userCount,
  }) =>
      SubscriptionPlan(
        code: code,
        name: name,
        diagnosisLimit: diagnosisLimit ?? this.diagnosisLimit,
        chatLimit: chatLimit ?? this.chatLimit,
        insightLimit: insightLimit ?? this.insightLimit,
        price: price ?? this.price,
        features: features ?? this.features,
        userCount: userCount ?? this.userCount,
      );

  factory SubscriptionPlan.fromMap(Map<String, dynamic> m) => SubscriptionPlan(
        code: m['code'] as String,
        name: (m['name'] as String?) ?? '',
        diagnosisLimit: (m['diagnosis_limit'] as num?)?.toInt() ?? 0,
        chatLimit: (m['chat_limit'] as num?)?.toInt() ?? 0,
        insightLimit: (m['insight_limit'] as num?)?.toInt() ?? 0,
        price: (m['price'] as num?) ?? 0,
        features: m['features'] as String?,
      );
}
