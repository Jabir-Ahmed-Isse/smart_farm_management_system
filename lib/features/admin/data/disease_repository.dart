import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image/image.dart' as img;
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ai/image_quality.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../core/util/ids.dart';
import '../../../models/disease.dart';

final diseaseRepositoryProvider = Provider<DiseaseRepository>((ref) {
  return DiseaseRepository(ref.watch(supabaseClientProvider));
});

/// Disease reference database CRUD (admin-gated by RLS) + reference-image
/// upload to the public reference-images bucket.
class DiseaseRepository {
  DiseaseRepository(this._client);

  final SupabaseClient _client;

  Future<List<Disease>> list(String search) async {
    var query = _client.from('diseases').select();
    if (search.trim().isNotEmpty) {
      query = query.or('name.ilike.%$search%,crop.ilike.%$search%');
    }
    final rows = await query.order('name');
    return rows.map(Disease.fromMap).toList();
  }

  Future<void> create(Disease d) async {
    await _client.from('diseases').insert({
      ...d.toWriteMap(),
      'created_by': _client.auth.currentUser?.id,
    });
  }

  Future<void> update(String id, Disease d) async {
    await _client.from('diseases').update({
      ...d.toWriteMap(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> delete(String id) async {
    await _client.from('diseases').delete().eq('id', id);
  }

  Future<String> uploadReferenceImage(Uint8List bytes) async {
    final decoded = img.decodeImage(bytes);
    final jpeg = decoded == null
        ? bytes
        : ImageQualityChecker.compressForUpload(decoded, maxEdge: 1400);
    final path = '${uuidV4()}.jpg';
    await _client.storage.from('reference-images').uploadBinary(
          path,
          jpeg,
          fileOptions: const FileOptions(contentType: 'image/jpeg'),
        );
    return _client.storage.from('reference-images').getPublicUrl(path);
  }
}

final diseasesProvider =
    FutureProvider.family<List<Disease>, String>((ref, search) {
  return ref.watch(diseaseRepositoryProvider).list(search);
});
