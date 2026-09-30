import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../profile/data/profile_repository.dart';

/// A persisted weather danger alert produced by the scheduled `weather-alerts`
/// Edge Function and stored in public.weather_alerts. RLS scopes reads to the
/// signed-in user's own farms, so no client-side farm filtering is needed.
class WeatherAlertRecord {
  const WeatherAlertRecord({
    required this.id,
    required this.farmId,
    required this.hazard,
    required this.severity,
    required this.title,
    required this.body,
    required this.createdAt,
  });

  final String id;
  final String farmId;
  final String hazard;
  final String severity; // info | warning | danger
  final String title;
  final String body;
  final DateTime createdAt;

  bool get isDanger => severity == 'danger';

  factory WeatherAlertRecord.fromMap(Map<String, dynamic> m) {
    return WeatherAlertRecord(
      id: m['id'] as String,
      farmId: m['farm_id'] as String,
      hazard: (m['hazard'] as String?) ?? '',
      severity: (m['severity'] as String?) ?? 'warning',
      title: (m['title'] as String?) ?? '',
      body: (m['body'] as String?) ?? '',
      createdAt:
          DateTime.tryParse(m['created_at'] as String? ?? '') ?? DateTime.now(),
    );
  }
}

/// The signed-in user's recent weather alerts, newest first. Errors (including
/// the table not existing before the migration is applied) surface as an
/// AsyncError the UI can silently ignore, so the inbox never breaks.
final myWeatherAlertsProvider =
    FutureProvider<List<WeatherAlertRecord>>((ref) async {
  // Refetch when the session/profile changes.
  ref.watch(myProfileProvider);
  final client = ref.watch(supabaseClientProvider);
  final rows = await client
      .from('weather_alerts')
      .select()
      .order('created_at', ascending: false)
      .limit(50);
  return rows
      .map((r) => WeatherAlertRecord.fromMap(Map<String, dynamic>.from(r)))
      .toList();
});
