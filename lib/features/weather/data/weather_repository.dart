import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:hive_ce_flutter/hive_flutter.dart';
import 'package:http/http.dart' as http;
import 'package:material_symbols_icons/symbols.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/weather.dart';

final weatherRepositoryProvider = Provider<WeatherRepository>((ref) {
  return WeatherRepository(ref.watch(supabaseClientProvider));
});

/// Live weather from Open-Meteo (free, no API key, CORS-enabled). The last good
/// response is cached per location so the screen still shows something with no
/// signal — offline-first, like the rest of the app.
class WeatherRepository {
  WeatherRepository(this._client);

  final SupabaseClient _client;

  static const _cacheBox = 'sfms_weather';
  static const _endpoint = 'https://api.open-meteo.com/v1/forecast';
  static const _floodEndpoint = 'https://flood-api.open-meteo.com/v1/flood';

  Future<WeatherReport> getWeather(double lat, double lng) async {
    final uri = Uri.parse(_endpoint).replace(queryParameters: {
      'latitude': lat.toStringAsFixed(4),
      'longitude': lng.toStringAsFixed(4),
      'current': 'temperature_2m,relative_humidity_2m,apparent_temperature,'
          'precipitation,weather_code,wind_speed_10m,wind_gusts_10m',
      'daily': 'weather_code,temperature_2m_max,temperature_2m_min,'
          'precipitation_sum,precipitation_probability_max,wind_speed_10m_max',
      'timezone': 'auto',
      'forecast_days': '7',
      'wind_speed_unit': 'kmh',
    });

    // Kick off the river-flood check concurrently; it's best-effort and never
    // throws, so it can't break the main forecast.
    final floodFuture = _floodWatch(lat, lng);

    try {
      final res =
          await http.get(uri).timeout(const Duration(seconds: 12));
      if (res.statusCode != 200) {
        throw Exception('Weather service returned ${res.statusCode}');
      }
      var report = _parse(jsonDecode(res.body) as Map<String, dynamic>);
      final flood = await floodFuture;
      if (flood != null) {
        report = WeatherReport(
          current: report.current,
          daily: report.daily,
          alerts: [flood, ...report.alerts],
          fetchedAt: report.fetchedAt,
        );
      }
      await _cache(lat, lng, report);
      return report;
    } catch (_) {
      // Offline or the service is down — fall back to the last good fetch.
      final cached = await _readCache(lat, lng);
      if (cached != null) return cached;
      rethrow;
    }
  }

  /// Best-effort river-flood signal from Open-Meteo's Flood API (GloFAS river
  /// discharge). Only meaningful where a modelled river runs near the farm —
  /// returns null otherwise. Never throws: it must not break the forecast.
  Future<WeatherAlert?> _floodWatch(double lat, double lng) async {
    try {
      final uri = Uri.parse(_floodEndpoint).replace(queryParameters: {
        'latitude': lat.toStringAsFixed(4),
        'longitude': lng.toStringAsFixed(4),
        'daily': 'river_discharge',
        'forecast_days': '7',
      });
      final res = await http.get(uri).timeout(const Duration(seconds: 10));
      if (res.statusCode != 200) return null;
      final json = jsonDecode(res.body) as Map<String, dynamic>;
      final daily = json['daily'] as Map<String, dynamic>?;
      final series = (daily?['river_discharge'] as List?)
          ?.map((e) => (e as num?)?.toDouble())
          .whereType<double>()
          .toList();
      if (series == null || series.length < 2) return null;
      final baseline = series.first;
      final peak = series.reduce((a, b) => a > b ? a : b);
      // Ignore points with no real river nearby; only flag a sharp, real rise.
      if (baseline <= 0.5) return null;
      if (peak >= baseline * 1.8 && (peak - baseline) >= 2) {
        return const WeatherAlert(
          severity: AlertSeverity.danger,
          title: 'River levels rising',
          message: 'Rivers near your farm are forecast to swell sharply over '
              'the coming days. Watch low-lying plots for flooding and move '
              'animals and stored produce to higher ground.',
          icon: Symbols.tsunami,
        );
      }
      return null;
    } catch (_) {
      return null;
    }
  }

  WeatherReport _parse(Map<String, dynamic> json) {
    final current = CurrentWeather.fromJson(
        Map<String, dynamic>.from(json['current'] as Map));

    final daily = json['daily'] as Map<String, dynamic>;
    final times = (daily['time'] as List).cast<String>();
    double dAt(String key, int i) {
      final list = daily[key] as List?;
      return (list == null ? null : list[i] as num?)?.toDouble() ?? 0;
    }

    int iAt(String key, int i) {
      final list = daily[key] as List?;
      return (list == null ? null : list[i] as num?)?.round() ?? 0;
    }

    final forecast = <DailyForecast>[
      for (var i = 0; i < times.length; i++)
        DailyForecast(
          date: DateTime.tryParse(times[i]) ?? DateTime.now(),
          weatherCode: iAt('weather_code', i),
          tempMax: dAt('temperature_2m_max', i),
          tempMin: dAt('temperature_2m_min', i),
          precipitationSum: dAt('precipitation_sum', i),
          precipitationProbability: iAt('precipitation_probability_max', i),
          windMax: dAt('wind_speed_10m_max', i),
        ),
    ];

    return WeatherReport(
      current: current,
      daily: forecast,
      alerts: WeatherReport.deriveAlerts(current, forecast),
      fetchedAt: DateTime.now(),
    );
  }

  String _key(double lat, double lng) =>
      '${lat.toStringAsFixed(2)},${lng.toStringAsFixed(2)}';

  Future<void> _cache(double lat, double lng, WeatherReport report) async {
    final box = await Hive.openBox<Map>(_cacheBox);
    await box.put(_key(lat, lng), report.toJson());
  }

  Future<WeatherReport?> _readCache(double lat, double lng) async {
    final box = await Hive.openBox<Map>(_cacheBox);
    final raw = box.get(_key(lat, lng));
    if (raw == null) return null;
    try {
      return WeatherReport.fromCache(Map<String, dynamic>.from(raw));
    } catch (_) {
      return null;
    }
  }

  /// Store the farm's coordinates. Goes through a SECURITY DEFINER RPC because
  /// a direct farms UPDATE hits the ES256 bare-auth.uid() RLS bug.
  Future<void> setFarmLocation({
    required String farmId,
    required double latitude,
    required double longitude,
  }) async {
    await _client.rpc('set_farm_location', params: {
      'p_id': farmId,
      'p_lat': latitude,
      'p_lng': longitude,
    });
  }
}

/// Weather for a set of coordinates. Keyed by a record so Riverpod caches per
/// location and refetches when the farm's pin moves.
typedef LatLng = ({double lat, double lng});

final weatherForFarmProvider =
    FutureProvider.family<WeatherReport, LatLng>((ref, coords) {
  return ref.watch(weatherRepositoryProvider).getWeather(coords.lat, coords.lng);
});
