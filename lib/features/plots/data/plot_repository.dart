import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/plot.dart';

final plotRepositoryProvider = Provider<PlotRepository>((ref) {
  return PlotRepository(ref.watch(supabaseClientProvider));
});

/// Writes plots (public.plots, RLS is_farm_member — direct insert works).
class PlotRepository {
  PlotRepository(this._client);

  final SupabaseClient _client;

  Future<Plot> createPlot({
    required String farmId,
    required String name,
    String type = 'open_field',
    num? area,
    String areaUnit = 'hectare',
  }) async {
    final row = await _client
        .from('plots')
        .insert({
          'farm_id': farmId,
          'name': name,
          'type': type,
          'area_unit': areaUnit,
          if (area != null) 'area': area,
        })
        .select()
        .single();
    return Plot.fromMap(row);
  }

  Future<Plot> updatePlot({
    required String id,
    required String name,
    required String type,
    num? area,
  }) async {
    final row = await _client
        .from('plots')
        .update({
          'name': name,
          'type': type,
          'area': area,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return Plot.fromMap(row);
  }

  Future<void> deletePlot(String id) async {
    await _client.from('plots').delete().eq('id', id);
  }
}
