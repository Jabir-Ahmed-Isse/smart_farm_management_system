/// A user's AI usage against their monthly plan, for one credit kind
/// (diagnoses or assistant questions).
class AiCredit {
  const AiCredit({
    required this.kind,
    required this.used,
    required this.limit,
    required this.plan,
  });

  /// 'diagnosis' | 'chat'
  final String kind;
  final int used;

  /// -1 = unlimited (premium).
  final int limit;

  /// 'free' | 'premium'
  final String plan;

  bool get isPremium => plan == 'premium';
  bool get unlimited => limit < 0;
  int get remaining => unlimited ? -1 : (limit - used).clamp(0, limit).toInt();
  bool get exhausted => !unlimited && used >= limit;
  double get fraction => unlimited || limit == 0 ? 0 : (used / limit).clamp(0, 1);

  /// First day of next month, when free credits reset.
  DateTime get resetsOn {
    final now = DateTime.now();
    return now.month == 12
        ? DateTime(now.year + 1, 1, 1)
        : DateTime(now.year, now.month + 1, 1);
  }

  factory AiCredit.free(String kind, int limit) =>
      AiCredit(kind: kind, used: 0, limit: limit, plan: 'free');
}
