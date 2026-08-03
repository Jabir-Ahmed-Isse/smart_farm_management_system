import 'package:flutter/widgets.dart';
import 'package:material_symbols_icons/symbols.dart';

/// A decoded WMO weather code — the shared vocabulary Open-Meteo returns.
class WeatherCondition {
  const WeatherCondition(this.label, this.icon);
  final String label;
  final IconData icon;

  /// Map a WMO code (0–99) to a farmer-readable label and an icon.
  /// https://open-meteo.com/en/docs — "Weather variable documentation".
  static WeatherCondition fromCode(int code) {
    return switch (code) {
      0 => const WeatherCondition('Clear sky', Symbols.clear_day),
      1 => const WeatherCondition('Mostly clear', Symbols.partly_cloudy_day),
      2 => const WeatherCondition('Partly cloudy', Symbols.partly_cloudy_day),
      3 => const WeatherCondition('Overcast', Symbols.cloud),
      45 || 48 => const WeatherCondition('Fog', Symbols.foggy),
      51 || 53 || 55 =>
        const WeatherCondition('Drizzle', Symbols.rainy_light),
      56 || 57 =>
        const WeatherCondition('Freezing drizzle', Symbols.rainy),
      61 => const WeatherCondition('Light rain', Symbols.rainy_light),
      63 => const WeatherCondition('Rain', Symbols.rainy),
      65 => const WeatherCondition('Heavy rain', Symbols.rainy_heavy),
      66 || 67 =>
        const WeatherCondition('Freezing rain', Symbols.rainy),
      71 || 73 || 75 || 77 =>
        const WeatherCondition('Snow', Symbols.weather_snowy),
      80 || 81 => const WeatherCondition('Rain showers', Symbols.rainy),
      82 =>
        const WeatherCondition('Heavy showers', Symbols.rainy_heavy),
      85 || 86 =>
        const WeatherCondition('Snow showers', Symbols.weather_snowy),
      95 => const WeatherCondition('Thunderstorm', Symbols.thunderstorm),
      96 || 99 =>
        const WeatherCondition('Storm with hail', Symbols.thunderstorm),
      _ => const WeatherCondition('—', Symbols.cloud),
    };
  }
}

/// Current conditions at the farm right now.
class CurrentWeather {
  const CurrentWeather({
    required this.time,
    required this.temperature,
    required this.apparentTemperature,
    required this.humidity,
    required this.precipitation,
    required this.windSpeed,
    required this.windGusts,
    required this.weatherCode,
  });

  final DateTime time;
  final double temperature;
  final double apparentTemperature;
  final int humidity;
  final double precipitation;
  final double windSpeed;
  final double windGusts;
  final int weatherCode;

  WeatherCondition get condition => WeatherCondition.fromCode(weatherCode);

  factory CurrentWeather.fromJson(Map<String, dynamic> j) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    return CurrentWeather(
      time: DateTime.tryParse(j['time'] as String? ?? '') ?? DateTime.now(),
      temperature: d(j['temperature_2m']),
      apparentTemperature: d(j['apparent_temperature']),
      humidity: (j['relative_humidity_2m'] as num?)?.round() ?? 0,
      precipitation: d(j['precipitation']),
      windSpeed: d(j['wind_speed_10m']),
      windGusts: d(j['wind_gusts_10m']),
      weatherCode: (j['weather_code'] as num?)?.round() ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
        'time': time.toIso8601String(),
        'temperature_2m': temperature,
        'apparent_temperature': apparentTemperature,
        'relative_humidity_2m': humidity,
        'precipitation': precipitation,
        'wind_speed_10m': windSpeed,
        'wind_gusts_10m': windGusts,
        'weather_code': weatherCode,
      };
}

/// One day in the 7-day outlook.
class DailyForecast {
  const DailyForecast({
    required this.date,
    required this.weatherCode,
    required this.tempMax,
    required this.tempMin,
    required this.precipitationSum,
    required this.precipitationProbability,
    required this.windMax,
  });

  final DateTime date;
  final int weatherCode;
  final double tempMax;
  final double tempMin;
  final double precipitationSum;
  final int precipitationProbability;
  final double windMax;

  WeatherCondition get condition => WeatherCondition.fromCode(weatherCode);

  Map<String, dynamic> toJson() => {
        'date': date.toIso8601String(),
        'weather_code': weatherCode,
        'temp_max': tempMax,
        'temp_min': tempMin,
        'precip_sum': precipitationSum,
        'precip_prob': precipitationProbability,
        'wind_max': windMax,
      };

  factory DailyForecast.fromJson(Map<String, dynamic> j) {
    double d(Object? v) => (v as num?)?.toDouble() ?? 0;
    return DailyForecast(
      date: DateTime.tryParse(j['date'] as String? ?? '') ?? DateTime.now(),
      weatherCode: (j['weather_code'] as num?)?.round() ?? 0,
      tempMax: d(j['temp_max']),
      tempMin: d(j['temp_min']),
      precipitationSum: d(j['precip_sum']),
      precipitationProbability: (j['precip_prob'] as num?)?.round() ?? 0,
      windMax: d(j['wind_max']),
    );
  }
}

enum AlertSeverity { info, warning, danger }

/// A farmer-facing advisory derived from the forecast (not a met-office alert).
class WeatherAlert {
  const WeatherAlert({
    required this.severity,
    required this.title,
    required this.message,
    required this.icon,
  });

  final AlertSeverity severity;
  final String title;
  final String message;
  final IconData icon;
}

/// Everything the weather screen shows for one farm at one moment.
class WeatherReport {
  const WeatherReport({
    required this.current,
    required this.daily,
    required this.alerts,
    required this.fetchedAt,
    this.stale = false,
  });

  final CurrentWeather current;
  final List<DailyForecast> daily;
  final List<WeatherAlert> alerts;
  final DateTime fetchedAt;

  /// True when served from cache because the network was unavailable.
  final bool stale;

  WeatherReport asStale() => WeatherReport(
        current: current,
        daily: daily,
        alerts: alerts,
        fetchedAt: fetchedAt,
        stale: true,
      );

  Map<String, dynamic> toJson() => {
        'current': current.toJson(),
        'daily': daily.map((d) => d.toJson()).toList(),
        'fetched_at': fetchedAt.toIso8601String(),
      };

  /// Rebuild from cache. Alerts are re-derived so the rules can evolve without
  /// invalidating stored payloads.
  factory WeatherReport.fromCache(Map<String, dynamic> j) {
    final current =
        CurrentWeather.fromJson(Map<String, dynamic>.from(j['current'] as Map));
    final daily = (j['daily'] as List)
        .map((e) => DailyForecast.fromJson(Map<String, dynamic>.from(e as Map)))
        .toList();
    return WeatherReport(
      current: current,
      daily: daily,
      alerts: deriveAlerts(current, daily),
      fetchedAt:
          DateTime.tryParse(j['fetched_at'] as String? ?? '') ?? DateTime.now(),
      stale: true,
    );
  }

  /// Turn a raw forecast into farm advisories. Thresholds are tuned for hot,
  /// mostly-dry Somali growing conditions (heat and rain matter far more than
  /// frost), and each alert says what to actually do about it.
  static List<WeatherAlert> deriveAlerts(
    CurrentWeather current,
    List<DailyForecast> daily,
  ) {
    final alerts = <WeatherAlert>[];
    final today = daily.isNotEmpty ? daily.first : null;
    final soon = daily.take(3).toList();

    // Extreme heat — plan field work and irrigation around it.
    final heat = [
      current.apparentTemperature,
      if (today != null) today.tempMax,
    ].fold<double>(0, (m, v) => v > m ? v : m);
    if (heat >= 40) {
      alerts.add(WeatherAlert(
        severity: AlertSeverity.danger,
        title: 'Extreme heat',
        message: 'Up to ${heat.round()}°C. Irrigate early morning or evening, '
            'and avoid heavy field work at midday.',
        icon: Symbols.thermometer,
      ));
    } else if (heat >= 35) {
      alerts.add(WeatherAlert(
        severity: AlertSeverity.warning,
        title: 'High heat',
        message:
            '${heat.round()}°C expected. Keep crops and livestock watered.',
        icon: Symbols.thermometer,
      ));
    }

    // Heavy rain in the next few days — hold off spraying/fertilising.
    final wetDay = soon
        .where((d) => d.precipitationSum >= 20 || d.precipitationProbability >= 70)
        .toList();
    if (wetDay.isNotEmpty) {
      final d = wetDay.first;
      alerts.add(WeatherAlert(
        severity: AlertSeverity.warning,
        title: 'Heavy rain likely',
        message: '${d.precipitationSum.round()} mm around '
            '${_weekday(d.date)}. Delay spraying and fertilising, and check '
            'drainage.',
        icon: Symbols.rainy_heavy,
      ));
    }

    // Strong wind — spray drift and structure risk.
    final windy = [
      current.windGusts,
      if (today != null) today.windMax,
    ].fold<double>(0, (m, v) => v > m ? v : m);
    if (windy >= 45) {
      alerts.add(WeatherAlert(
        severity: AlertSeverity.warning,
        title: 'Strong winds',
        message: 'Gusts near ${windy.round()} km/h. Secure structures and '
            'avoid spraying — drift wastes chemical.',
        icon: Symbols.air,
      ));
    }

    // Dry spell — no meaningful rain across the whole outlook.
    if (daily.isNotEmpty) {
      final totalRain =
          daily.fold<double>(0, (s, d) => s + d.precipitationSum);
      if (totalRain < 2 && heat >= 30) {
        alerts.add(const WeatherAlert(
          severity: AlertSeverity.info,
          title: 'Dry week ahead',
          message: 'Little or no rain expected. Plan irrigation and mulch to '
              'hold soil moisture.',
          icon: Symbols.water_drop,
        ));
      }
    }

    return alerts;
  }

  static String _weekday(DateTime d) {
    const names = [
      'Monday', 'Tuesday', 'Wednesday', 'Thursday',
      'Friday', 'Saturday', 'Sunday'
    ];
    return names[(d.weekday - 1) % 7];
  }
}
