import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';

final aiAnalyticsRepositoryProvider = Provider<AiAnalyticsRepository>((ref) {
  return AiAnalyticsRepository(ref.watch(supabaseClientProvider));
});

/// Reads AI usage stats and derives a 0–100 health score per crop from the
/// disease log and past AI diagnoses. All queries are farm-scoped under RLS.
class AiAnalyticsRepository {
  AiAnalyticsRepository(this._client);

  final SupabaseClient _client;

  Future<AiAnalytics> getAnalytics(String farmId) async {
    final monthStart = DateTime.utc(DateTime.now().year, DateTime.now().month, 1)
        .toIso8601String();

    final results = await Future.wait([
      _client
          .from('ai_diagnoses')
          .select('plant_name, disease_name, confidence, health_status, created_at')
          .eq('farm_id', farmId),
      _client
          .from('ai_messages')
          .select('id')
          .eq('farm_id', farmId)
          .eq('role', 'user'),
    ]);

    final diag = results[0];
    final chatCount = results[1].length;

    final thisMonth = diag.where((d) {
      final c = d['created_at'] as String?;
      return c != null && c.compareTo(monthStart) >= 0;
    }).length;

    final confidences = diag
        .map((d) => (d['confidence'] as num?)?.toDouble() ?? 0)
        .where((c) => c > 0)
        .toList();
    final avgConfidence = confidences.isEmpty
        ? 0.0
        : confidences.reduce((a, b) => a + b) / confidences.length;

    final topDisease = _mode(diag
        .map((d) => d['disease_name'] as String?)
        .where((s) => s != null && s.trim().isNotEmpty)
        .cast<String>());
    final topCrop = _mode(diag
        .map((d) => d['plant_name'] as String?)
        .where((s) => s != null && s.trim().isNotEmpty && s != 'Unknown plant')
        .cast<String>());

    return AiAnalytics(
      diagnosisCount: diag.length,
      diagnosisThisMonth: thisMonth,
      chatCount: chatCount,
      avgConfidence: avgConfidence,
      topDisease: topDisease,
      topCrop: topCrop,
    );
  }

  Future<List<CropHealth>> getCropHealth(String farmId) async {
    final results = await Future.wait([
      _client
          .from('crops')
          .select('id, name, variety, stage')
          .eq('farm_id', farmId)
          .neq('stage', 'completed')
          .order('name'),
      _client
          .from('disease_logs')
          .select('crop_id, severity, status')
          .eq('farm_id', farmId)
          .eq('status', 'active'),
      _client
          .from('ai_diagnoses')
          .select('crop_id, health_status, severity, created_at')
          .eq('farm_id', farmId)
          .order('created_at', ascending: false),
    ]);

    final crops = results[0];
    final diseases = results[1];
    final diagnoses = results[2];

    return crops.map((c) {
      final id = c['id'] as String;
      final cropDiseases =
          diseases.where((d) => d['crop_id'] == id).toList();
      final cropDiagnoses =
          diagnoses.where((d) => d['crop_id'] == id).toList();
      final score = _healthScore(cropDiseases, cropDiagnoses);
      return CropHealth(
        cropId: id,
        name: (c['name'] as String?) ?? 'Crop',
        variety: c['variety'] as String?,
        stage: (c['stage'] as String?) ?? 'seed',
        score: score,
        activeIssues: cropDiseases.length +
            cropDiagnoses.where((d) => d['health_status'] == 'diseased').length,
      );
    }).toList();
  }

  /// 100 = perfectly healthy. Active diseases and recent 'diseased' diagnoses
  /// pull it down by severity; recent 'healthy' diagnoses nudge it back up.
  static int _healthScore(
    List<Map<String, dynamic>> diseases,
    List<Map<String, dynamic>> diagnoses,
  ) {
    var score = 100.0;
    for (final d in diseases) {
      score -= switch (d['severity'] as String?) {
        'high' => 30,
        'medium' => 18,
        'low' => 8,
        _ => 15,
      };
    }
    // Only the few most recent diagnoses matter.
    for (final d in diagnoses.take(3)) {
      final status = d['health_status'] as String?;
      if (status == 'diseased') {
        score -= switch (d['severity'] as String?) {
          'critical' => 35,
          'high' => 25,
          'medium' => 15,
          'low' => 8,
          _ => 18,
        };
      } else if (status == 'healthy') {
        score += 6;
      }
    }
    return score.clamp(0, 100).round();
  }

  static String? _mode(Iterable<String> values) {
    final counts = <String, int>{};
    for (final v in values) {
      counts[v] = (counts[v] ?? 0) + 1;
    }
    if (counts.isEmpty) return null;
    return counts.entries.reduce((a, b) => a.value >= b.value ? a : b).key;
  }
}

class AiAnalytics {
  const AiAnalytics({
    required this.diagnosisCount,
    required this.diagnosisThisMonth,
    required this.chatCount,
    required this.avgConfidence,
    required this.topDisease,
    required this.topCrop,
  });

  final int diagnosisCount;
  final int diagnosisThisMonth;
  final int chatCount;
  final double avgConfidence;
  final String? topDisease;
  final String? topCrop;
}

class CropHealth {
  const CropHealth({
    required this.cropId,
    required this.name,
    required this.score,
    required this.stage,
    required this.activeIssues,
    this.variety,
  });

  final String cropId;
  final String name;
  final int score; // 0–100
  final String stage;
  final int activeIssues;
  final String? variety;

  String get displayName =>
      (variety != null && variety!.isNotEmpty) ? '$name · $variety' : name;

  /// 'good' | 'watch' | 'risk' — coarse band for colour + label.
  String get band => score >= 75 ? 'good' : (score >= 45 ? 'watch' : 'risk');
}

final aiAnalyticsProvider =
    FutureProvider.family<AiAnalytics, String>((ref, farmId) {
  return ref.watch(aiAnalyticsRepositoryProvider).getAnalytics(farmId);
});

final cropHealthProvider =
    FutureProvider.family<List<CropHealth>, String>((ref, farmId) {
  return ref.watch(aiAnalyticsRepositoryProvider).getCropHealth(farmId);
});
