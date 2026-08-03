/// A freeform comment on a plot (public.plot_comments).
class PlotComment {
  const PlotComment({
    required this.id,
    required this.plotId,
    required this.farmId,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String plotId;
  final String farmId;
  final String body;
  final DateTime createdAt;

  factory PlotComment.fromMap(Map<String, dynamic> map) {
    return PlotComment(
      id: map['id'] as String,
      plotId: map['plot_id'] as String,
      farmId: map['farm_id'] as String,
      body: map['body'] as String,
      createdAt: DateTime.parse(map['created_at'] as String),
    );
  }
}
