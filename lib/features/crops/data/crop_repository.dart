import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/supabase/supabase_providers.dart';
import '../../../models/crop.dart';

final cropRepositoryProvider = Provider<CropRepository>((ref) {
  return CropRepository(ref.watch(supabaseClientProvider));
});

/// Writes crops (public.crops, RLS is_farm_member — direct insert works).
class CropRepository {
  CropRepository(this._client);

  final SupabaseClient _client;

  Future<Crop> createCrop({
    required String farmId,
    required String name,
    String? variety,
    String? plotId,
    String stage = 'seed',
    DateTime? plantingDate,
  }) async {
    final row = await _client
        .from('crops')
        .insert({
          'farm_id': farmId,
          'name': name,
          'stage': stage,
          if (variety != null && variety.trim().isNotEmpty)
            'variety': variety.trim(),
          if (plotId != null) 'plot_id': plotId,
          if (plantingDate != null) 'planting_date': _dateOnly(plantingDate),
        })
        .select()
        .single();
    return Crop.fromMap(row);
  }

  Future<Crop> updateCrop({
    required String id,
    required String name,
    String? variety,
    String? plotId,
    required String stage,
  }) async {
    final row = await _client
        .from('crops')
        .update({
          'name': name,
          'variety': (variety != null && variety.trim().isNotEmpty)
              ? variety.trim()
              : null,
          'plot_id': plotId,
          'stage': stage,
          'updated_at': DateTime.now().toIso8601String(),
        })
        .eq('id', id)
        .select()
        .single();
    return Crop.fromMap(row);
  }

  Future<void> deleteCrop(String id) async {
    await _client.from('crops').delete().eq('id', id);
  }

  static String _dateOnly(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
