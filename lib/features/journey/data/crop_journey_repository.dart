import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/journey_event.dart';

final cropJourneyRepositoryProvider = Provider<CropJourneyRepository>((ref) {
  return CropJourneyRepository(ref.watch(supabaseClientProvider));
});

/// Builds a crop's [CropJourney] by aggregating its records across modules.
class CropJourneyRepository {
  CropJourneyRepository(this._client);
  final SupabaseClient _client;

  DateTime? _d(Object? v) =>
      v == null ? null : DateTime.tryParse(v.toString());
  double _num(Object? v) => (v as num?)?.toDouble() ?? 0;

  Future<CropJourney> journey(String cropId) async {
    final crop = await _client
        .from('crops')
        .select()
        .eq('id', cropId)
        .maybeSingle();
    if (crop == null) {
      throw StateError('Crop not found');
    }

    Map<String, dynamic>? plot;
    if (crop['plot_id'] != null) {
      plot = await _client
          .from('plots')
          .select('name, type')
          .eq('id', crop['plot_id'])
          .maybeSingle();
    }

    // Pull each related record set in parallel.
    final results = await Future.wait([
      _client
          .from('expenses')
          .select('*, category:expense_categories(name_en)')
          .eq('crop_id', cropId),
      _client.from('irrigation_logs').select().eq('crop_id', cropId),
      _client.from('disease_logs').select().eq('crop_id', cropId),
      _client.from('ai_diagnoses').select().eq('crop_id', cropId),
      _client.from('harvests').select().eq('crop_id', cropId),
      _client.from('sales').select().eq('crop_id', cropId),
      _client.from('tasks').select().eq('crop_id', cropId),
    ]);
    final expenses = results[0];
    final irrigations = results[1];
    final diseases = results[2];
    final diagnoses = results[3];
    final harvests = results[4];
    final sales = results[5];
    final tasks = results[6];

    final events = <JourneyEvent>[];

    // Planting.
    final planted = _d(crop['planting_date']);
    if (planted != null) {
      events.add(JourneyEvent(
        type: JEventType.planted,
        date: planted,
        title: 'Crop Planted',
        description: [
          if ((crop['variety'] as String?)?.isNotEmpty == true)
            'Variety: ${crop['variety']}',
          if ((crop['seed_brand'] as String?)?.isNotEmpty == true)
            'Seed: ${crop['seed_brand']}',
        ].join(' · '),
        tags: {'crop'},
      ));
    }

    // Expenses (fertilizer vs general).
    var totalExpenses = 0.0;
    for (final e in expenses) {
      final cat =
          ((e['category'] as Map?)?['name_en'] as String?)?.trim() ?? 'Expense';
      final cost = _num(e['total_cost']);
      totalExpenses += cost;
      final isFert = cat.toLowerCase().contains('fertil');
      events.add(JourneyEvent(
        type: isFert ? JEventType.fertilizer : JEventType.expense,
        date: _d(e['date']) ?? _d(e['created_at']) ?? DateTime.now(),
        title: isFert ? 'Fertilizer Applied' : cat,
        description: e['description'] as String?,
        cost: cost,
        tags: {'financial', if (isFert) 'fertilizer'},
        details: [
          if ((e['quantity']) != null)
            ('Quantity', '${e['quantity']} ${e['unit'] ?? ''}'.trim()),
          if ((e['supplier'] as String?)?.isNotEmpty == true)
            ('Supplier', e['supplier'] as String),
        ],
      ));
    }

    // Irrigation.
    for (final w in irrigations) {
      totalExpenses += _num(w['cost']);
      events.add(JourneyEvent(
        type: JEventType.irrigation,
        date: _d(w['date']) ?? _d(w['created_at']) ?? DateTime.now(),
        title: 'Irrigation',
        cost: _num(w['cost']) == 0 ? null : _num(w['cost']),
        tags: {'irrigation'},
        details: [
          if ((w['method'] as String?)?.isNotEmpty == true)
            ('Method', w['method'] as String),
          if (w['volume'] != null)
            ('Volume', '${w['volume']} ${w['volume_unit'] ?? 'L'}'),
          if (w['duration_minutes'] != null)
            ('Duration', '${w['duration_minutes']} min'),
        ],
      ));
    }

    // Disease logs.
    var diseaseCount = 0;
    for (final d in diseases) {
      diseaseCount++;
      final sev = (d['severity'] as String?) ?? 'low';
      final kind = (d['kind'] as String?) ?? 'disease';
      final hasTreatment = (d['treatment'] as String?)?.isNotEmpty == true;
      events.add(JourneyEvent(
        type: JEventType.disease,
        date: _d(d['observed_date']) ?? _d(d['created_at']) ?? DateTime.now(),
        title: kind == 'pest' ? 'Pest Detected' : 'Disease Detected',
        danger: (d['status'] as String?) == 'active',
        tags: {'disease', if (hasTreatment) 'treatment'},
        details: [
          ('Type', (d['name'] as String?) ?? '—'),
          ('Severity', _cap(sev)),
          ('Status', _cap((d['status'] as String?) ?? 'active')),
          if (hasTreatment) ('Treatment', d['treatment'] as String),
        ],
      ));
    }

    // AI diagnoses (rich card, matches the design).
    var diagnosisCount = 0;
    for (final a in diagnoses) {
      diagnosisCount++;
      final unhealthy =
          (a['health_status'] as String?)?.toLowerCase() != 'healthy';
      final conf = a['confidence'];
      events.add(JourneyEvent(
        type: JEventType.ai,
        date: _d(a['created_at']) ?? DateTime.now(),
        title: unhealthy ? 'Disease Detected' : 'AI Scan — Healthy',
        danger: unhealthy,
        tags: {'ai', if (unhealthy) 'disease'},
        photos: [
          if ((a['image_url'] as String?)?.isNotEmpty == true)
            a['image_url'] as String,
        ],
        details: [
          if ((a['disease_name'] as String?)?.isNotEmpty == true)
            ('Type', a['disease_name'] as String),
          if (conf != null)
            ('Confidence', '${(_num(conf) <= 1 ? _num(conf) * 100 : _num(conf)).round()}%'),
          if ((a['severity'] as String?)?.isNotEmpty == true)
            ('Severity', _cap(a['severity'] as String)),
          if ((a['recovery_status'] as String?)?.isNotEmpty == true)
            ('Recovery', _cap(a['recovery_status'] as String)),
        ],
        actionLabel: 'View AI Report',
        diagnosisId: a['id'] as String?,
      ));
    }

    // Harvests.
    var harvestCount = 0;
    for (final h in harvests) {
      harvestCount++;
      events.add(JourneyEvent(
        type: JEventType.harvest,
        date: _d(h['date']) ?? _d(h['created_at']) ?? DateTime.now(),
        title: 'Harvest Completed',
        tags: {'harvest'},
        details: [
          ('Quantity', '${h['quantity']} ${h['unit'] ?? ''}'.trim()),
          if ((h['grade'] as String?)?.isNotEmpty == true)
            ('Grade', h['grade'] as String),
        ],
      ));
    }

    // Sales.
    var totalRevenue = 0.0;
    var saleCount = 0;
    for (final s in sales) {
      saleCount++;
      final rev = _num(s['total_price']);
      totalRevenue += rev;
      events.add(JourneyEvent(
        type: JEventType.sale,
        date: _d(s['date']) ?? _d(s['created_at']) ?? DateTime.now(),
        title: 'Sale Completed',
        cost: null,
        tags: {'financial', 'sales'},
        details: [
          if ((s['customer'] as String?)?.isNotEmpty == true)
            ('Buyer', s['customer'] as String)
          else if ((s['market'] as String?)?.isNotEmpty == true)
            ('Buyer', s['market'] as String),
          ('Quantity', '${s['quantity']} ${s['unit'] ?? ''}'.trim()),
          ('Price', '\$${_num(s['unit_price']).toStringAsFixed(2)}/${s['unit'] ?? 'unit'}'),
          ('Revenue', '\$${rev.toStringAsFixed(0)}'),
        ],
      ));
    }

    // Completed tasks (labour).
    for (final tk in tasks) {
      if ((tk['status'] as String?) != 'completed') continue;
      events.add(JourneyEvent(
        type: JEventType.task,
        date: _d(tk['completed_at']) ?? _d(tk['due_date']) ?? DateTime.now(),
        title: (tk['title'] as String?) ?? 'Task completed',
        tags: {'workers'},
        details: const [],
      ));
    }

    events.sort((a, b) => a.date.compareTo(b.date));

    // Health score heuristic.
    final activeDiseases = diseases
        .where((d) => (d['status'] as String?) == 'active')
        .length;
    final highSev = [...diseases, ...diagnoses]
        .where((d) => (d['severity'] as String?)?.toLowerCase() == 'high')
        .length;
    final resolved = diseases
        .where((d) => (d['status'] as String?) == 'resolved' ||
            (d['status'] as String?) == 'treated')
        .length;
    var score = 100 - activeDiseases * 12 - highSev * 10 + resolved * 4;
    if (score > 100) score = 100;
    if (score < 5) score = 5;

    final netProfit = totalRevenue - totalExpenses;

    return CropJourney(
      cropId: cropId,
      name: (crop['name'] as String?) ?? 'Crop',
      variety: crop['variety'] as String?,
      plotName: plot?['name'] as String?,
      plotType: plot?['type'] as String?,
      photoUrl: crop['photo_url'] as String?,
      plantingDate: planted,
      expectedHarvest: _d(crop['expected_harvest_date']),
      stage: (crop['stage'] as String?) ?? 'seed',
      expectedYield: crop['expected_yield'] as num?,
      yieldUnit: crop['yield_unit'] as String?,
      healthScore: score,
      healthLabel: _healthLabel(score),
      healthStatus: score >= 75
          ? 'HEALTHY'
          : score >= 50
              ? 'MONITOR'
              : 'AT RISK',
      aiSummary: _summary(
        name: (crop['name'] as String?) ?? 'crop',
        diseaseCount: diseaseCount + diagnosisCount,
        activeDiseases: activeDiseases,
        irrigationCount: irrigations.length,
        harvestCount: harvestCount,
        netProfit: netProfit,
        revenue: totalRevenue,
      ),
      totalExpenses: totalExpenses,
      totalRevenue: totalRevenue,
      netProfit: netProfit,
      events: events,
      diagnosisCount: diagnosisCount,
      diseaseCount: diseaseCount,
      irrigationCount: irrigations.length,
      harvestCount: harvestCount,
      saleCount: saleCount,
    );
  }

  static String _cap(String s) =>
      s.isEmpty ? s : s[0].toUpperCase() + s.substring(1);

  static String _healthLabel(int score) => score >= 90
      ? 'Excellent'
      : score >= 75
          ? 'Good'
          : score >= 60
              ? 'Fair'
              : score >= 40
                  ? 'Poor'
                  : 'Critical';

  static String _summary({
    required String name,
    required int diseaseCount,
    required int activeDiseases,
    required int irrigationCount,
    required int harvestCount,
    required double netProfit,
    required double revenue,
  }) {
    final b = StringBuffer();
    b.write('This $name crop has ');
    b.write(activeDiseases == 0
        ? 'progressed well. '
        : 'faced some challenges. ');
    if (diseaseCount == 0) {
      b.write('No diseases were detected. ');
    } else {
      b.write('$diseaseCount health ${diseaseCount == 1 ? 'issue was' : 'issues were'} '
          '${activeDiseases == 0 ? 'detected and resolved' : 'detected'}. ');
    }
    b.write(irrigationCount == 0
        ? 'No irrigation has been logged yet. '
        : 'Irrigation was logged $irrigationCount ${irrigationCount == 1 ? 'time' : 'times'}. ');
    if (harvestCount > 0) {
      b.write('Harvest is complete. ');
    }
    if (revenue > 0) {
      b.write(netProfit >= 0
          ? 'The crop is profitable so far, with a net of \$${netProfit.toStringAsFixed(0)}.'
          : 'Costs currently exceed revenue by \$${netProfit.abs().toStringAsFixed(0)}.');
    } else {
      b.write('No sales have been recorded yet.');
    }
    return b.toString();
  }
}

final cropJourneyProvider =
    FutureProvider.family<CropJourney, String>((ref, cropId) {
  return ref.watch(cropJourneyRepositoryProvider).journey(cropId);
});
