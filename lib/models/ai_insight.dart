/// An auto-generated insight card (public.ai_insights).
class AiInsight {
  const AiInsight({
    required this.id,
    required this.farmId,
    required this.kind,
    required this.title,
    required this.body,
    required this.severity,
    required this.dismissed,
    required this.createdAt,
    this.period = 'daily',
  });

  final String id;
  final String farmId;

  /// 'revenue' | 'expense' | 'inventory' | 'disease' | 'harvest' | 'crop' | 'weather' | 'general'
  final String kind;
  final String title;
  final String body;

  /// 'positive' | 'info' | 'warning' | 'critical'
  final String severity;
  final bool dismissed;
  final String period;
  final DateTime createdAt;

  factory AiInsight.fromMap(Map<String, dynamic> map) {
    return AiInsight(
      id: map['id'] as String,
      farmId: map['farm_id'] as String,
      kind: (map['kind'] as String?) ?? 'general',
      title: (map['title'] as String?) ?? '',
      body: (map['body'] as String?) ?? '',
      severity: (map['severity'] as String?) ?? 'info',
      dismissed: (map['dismissed'] as bool?) ?? false,
      period: (map['period'] as String?) ?? 'daily',
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
