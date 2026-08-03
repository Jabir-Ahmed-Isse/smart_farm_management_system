import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/ai/image_quality.dart';
import '../../../core/util/ids.dart';
import '../../../core/supabase/supabase_providers.dart';
import '../../../models/ai_credit.dart';
import '../../../models/plant_diagnosis.dart';
import 'ai_service.dart';

/// Free-plan monthly allowance for plant diagnoses. Mirrors the Edge Function —
/// the server is authoritative; this is only for the pre-check and the UI meter.
const int kFreeDiagnosisLimit = 10;

const String _bucket = 'plant-photos';

final aiServiceProvider = Provider<AiService>((ref) {
  return AiService(ref.watch(supabaseClientProvider));
});

final plantDoctorRepositoryProvider = Provider<PlantDoctorRepository>((ref) {
  return PlantDoctorRepository(
    ref.watch(supabaseClientProvider),
    ref.watch(aiServiceProvider),
  );
});

class PlantDoctorRepository {
  PlantDoctorRepository(this._client, this._ai);

  final SupabaseClient _client;
  final AiService _ai;

  /// The whole capture→diagnosis pipeline for one photo.
  ///
  /// 1. On-device quality gate (free — rejects obvious bad shots).
  /// 2. Compress + upload the photo to the private plant-photos bucket.
  /// 3. Ask the Edge Function to diagnose (server enforces credits + Gemini).
  Future<DiagnoseOutcome> runDiagnosis({
    required Uint8List bytes,
    required String farmId,
    String? cropId,
    String? plotId,
    String language = 'en',
  }) async {
    final quality = ImageQualityChecker.inspect(bytes);
    if (!quality.ok) {
      return DiagnoseImageRejected(
        quality.reason?.name ?? 'poor_quality',
        quality.message ?? 'Please retake the photo.',
      );
    }

    final jpeg = ImageQualityChecker.compressForUpload(quality.decoded!);

    String? imagePath;
    try {
      imagePath = '$farmId/${uuidV4()}.jpg';
      await _client.storage.from(_bucket).uploadBinary(
            imagePath,
            jpeg,
            fileOptions: const FileOptions(contentType: 'image/jpeg'),
          );
    } catch (_) {
      // A failed upload shouldn't block the diagnosis — we just won't have the
      // photo in history. Send the analysis anyway.
      imagePath = null;
    }

    return _ai.diagnose(
      imageBase64: base64Encode(jpeg),
      mimeType: 'image/jpeg',
      farmId: farmId,
      cropId: cropId,
      plotId: plotId,
      imageUrl: imagePath,
      language: language,
    );
  }

  // ------------------------------------------------------------- history

  Future<List<PlantDiagnosis>> getDiagnoses(String farmId) async {
    final rows = await _client
        .from('ai_diagnoses')
        .select()
        .eq('farm_id', farmId)
        .order('created_at', ascending: false);
    return rows.map(PlantDiagnosis.fromMap).toList();
  }

  Future<void> updateRecovery(String id, String status, {String? notes}) async {
    await _client.from('ai_diagnoses').update({
      'recovery_status': status,
      if (notes != null) 'notes': notes.trim().isEmpty ? null : notes.trim(),
      'updated_at': DateTime.now().toIso8601String(),
    }).eq('id', id);
  }

  Future<void> deleteDiagnosis(String id) async {
    await _client.from('ai_diagnoses').delete().eq('id', id);
  }

  /// A short-lived signed URL for a stored (private) diagnosis photo.
  Future<String?> signedImageUrl(String? path) async {
    if (path == null || path.isEmpty) return null;
    try {
      return await _client.storage.from(_bucket).createSignedUrl(path, 3600);
    } catch (_) {
      return null;
    }
  }

  // ------------------------------------------------------------- credits

  /// This month's diagnosis usage for the signed-in user.
  Future<AiCredit> diagnosisCredit() async {
    final uid = _client.auth.currentUser?.id;
    if (uid == null) return AiCredit.free('diagnosis', kFreeDiagnosisLimit);

    var plan = 'free';
    try {
      final profile = await _client
          .from('profiles')
          .select('ai_plan')
          .eq('id', uid)
          .maybeSingle();
      plan = (profile?['ai_plan'] as String?) ?? 'free';
    } catch (_) {/* column may not exist pre-migration — treat as free */}

    if (plan == 'premium') {
      return const AiCredit(
          kind: 'diagnosis', used: 0, limit: -1, plan: 'premium');
    }

    final now = DateTime.now();
    final monthStart = DateTime.utc(now.year, now.month, 1).toIso8601String();
    var used = 0;
    try {
      final rows = await _client
          .from('ai_credit_usage')
          .select('id')
          .eq('user_id', uid)
          .eq('kind', 'diagnosis')
          .gte('created_at', monthStart);
      used = (rows as List).length;
    } catch (_) {/* pre-migration — no usage yet */}

    return AiCredit(
        kind: 'diagnosis', used: used, limit: kFreeDiagnosisLimit, plan: 'free');
  }
}

/// Plant Doctor history for [farmId], newest first.
final diagnosesForFarmProvider =
    FutureProvider.family<List<PlantDiagnosis>, String>((ref, farmId) {
  return ref.watch(plantDoctorRepositoryProvider).getDiagnoses(farmId);
});

/// The signed-in user's remaining plant diagnoses this month.
final diagnosisCreditProvider = FutureProvider<AiCredit>((ref) {
  return ref.watch(plantDoctorRepositoryProvider).diagnosisCredit();
});
