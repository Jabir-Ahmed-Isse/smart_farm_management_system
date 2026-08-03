import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../models/ai_credit.dart';
import '../../../models/ai_insight.dart';
import '../../../models/plant_diagnosis.dart';

/// The outcome of a diagnosis attempt — one of a small closed set the UI can
/// switch over. Both the on-device quality gate and the server share the
/// "image rejected" and "credit limit" shapes.
sealed class DiagnoseOutcome {
  const DiagnoseOutcome();
}

class DiagnoseSuccess extends DiagnoseOutcome {
  const DiagnoseSuccess(this.diagnosis, this.credits);
  final PlantDiagnosis diagnosis;
  final AiCredit? credits;
}

class DiagnoseImageRejected extends DiagnoseOutcome {
  const DiagnoseImageRejected(this.reason, this.message);
  final String reason;
  final String message;
}

class DiagnoseCreditLimit extends DiagnoseOutcome {
  const DiagnoseCreditLimit(this.credits);
  final AiCredit? credits;
}

class DiagnoseError extends DiagnoseOutcome {
  const DiagnoseError(this.message, {this.code});
  final String message;
  final String? code;
}

/// Thin client over the `ai` Edge Function. Holds no keys — the function does.
class AiService {
  AiService(this._client);

  final SupabaseClient _client;

  Future<DiagnoseOutcome> diagnose({
    required String imageBase64,
    required String mimeType,
    required String farmId,
    String? cropId,
    String? plotId,
    String? imageUrl,
    required String language,
  }) async {
    try {
      final res = await _client.functions.invoke('ai', body: {
        'action': 'diagnose',
        'imageBase64': imageBase64,
        'mimeType': mimeType,
        'farmId': farmId,
        'cropId': cropId,
        'plotId': plotId,
        'imageUrl': imageUrl,
        'language': language,
      });
      final data = _asMap(res.data);

      if (data['imageOk'] == false) {
        return DiagnoseImageRejected(
          (data['reason'] as String?) ?? 'poor_quality',
          (data['message'] as String?) ?? 'Please retake the photo.',
        );
      }
      final row = _asMap(data['diagnosis']);
      if (row.isEmpty) {
        return const DiagnoseError('The AI returned an empty result.');
      }
      return DiagnoseSuccess(
        PlantDiagnosis.fromMap(row),
        _creditFrom(data['credits'], 'diagnosis'),
      );
    } on FunctionException catch (e) {
      final details = _asMap(e.details);
      final code = details['code'] as String?;
      if (code == 'credit_limit') {
        return DiagnoseCreditLimit(_creditFrom(details['credits'], 'diagnosis'));
      }
      return DiagnoseError(
        (details['error'] as String?) ?? 'The AI service is unavailable.',
        code: code,
      );
    } catch (e) {
      return DiagnoseError(e.toString());
    }
  }

  static Map<String, dynamic> _asMap(dynamic v) =>
      v is Map ? Map<String, dynamic>.from(v) : <String, dynamic>{};

  // ------------------------------------------------------------- chat

  Future<ChatOutcome> chat({
    required String farmId,
    String? conversationId,
    required String question,
    required String language,
  }) async {
    try {
      final res = await _client.functions.invoke('ai', body: {
        'action': 'chat',
        'farmId': farmId,
        'conversationId': conversationId,
        'question': question,
        'language': language,
      });
      final data = _asMap(res.data);
      final answer = data['answer'] as String?;
      final convId = data['conversationId'] as String?;
      if (answer == null || convId == null) {
        return const ChatError('The assistant returned an empty answer.');
      }
      return ChatOk(convId, answer, _creditFrom(data['credits'], 'chat'));
    } on FunctionException catch (e) {
      final details = _asMap(e.details);
      final code = details['code'] as String?;
      if (code == 'credit_limit') {
        return ChatCreditLimit(_creditFrom(details['credits'], 'chat'));
      }
      return ChatError(
        (details['error'] as String?) ?? 'The assistant is unavailable.',
        code: code,
      );
    } catch (e) {
      return ChatError(e.toString());
    }
  }

  // ---------------------------------------------------------- insights

  Future<InsightsOutcome> insights({
    required String farmId,
    required String language,
  }) async {
    try {
      final res = await _client.functions.invoke('ai', body: {
        'action': 'insights',
        'farmId': farmId,
        'language': language,
      });
      final data = _asMap(res.data);
      final raw = data['insights'];
      final list = raw is List
          ? raw.map((e) => AiInsight.fromMap(_asMap(e))).toList()
          : <AiInsight>[];
      if (list.isEmpty) {
        return const InsightsError('No insights were generated this time.');
      }
      return InsightsOk(list, _creditFrom(data['credits'], 'insight'));
    } on FunctionException catch (e) {
      final details = _asMap(e.details);
      final code = details['code'] as String?;
      if (code == 'credit_limit') {
        return InsightsCreditLimit(_creditFrom(details['credits'], 'insight'));
      }
      return InsightsError(
        (details['error'] as String?) ?? 'Insights are unavailable.',
        code: code,
      );
    } catch (e) {
      return InsightsError(e.toString());
    }
  }

  static AiCredit? _creditFrom(dynamic raw, String kind) {
    final m = _asMap(raw);
    if (m.isEmpty) return null;
    return AiCredit(
      kind: kind,
      used: (m['used'] as num?)?.toInt() ?? 0,
      limit: (m['limit'] as num?)?.toInt() ?? 0,
      plan: (m['plan'] as String?) ?? 'free',
    );
  }
}

/// The outcome of one assistant question.
sealed class ChatOutcome {
  const ChatOutcome();
}

class ChatOk extends ChatOutcome {
  const ChatOk(this.conversationId, this.answer, this.credits);
  final String conversationId;
  final String answer;
  final AiCredit? credits;
}

class ChatCreditLimit extends ChatOutcome {
  const ChatCreditLimit(this.credits);
  final AiCredit? credits;
}

class ChatError extends ChatOutcome {
  const ChatError(this.message, {this.code});
  final String message;
  final String? code;
}

/// The outcome of one insights-generation request.
sealed class InsightsOutcome {
  const InsightsOutcome();
}

class InsightsOk extends InsightsOutcome {
  const InsightsOk(this.insights, this.credits);
  final List<AiInsight> insights;
  final AiCredit? credits;
}

class InsightsCreditLimit extends InsightsOutcome {
  const InsightsCreditLimit(this.credits);
  final AiCredit? credits;
}

class InsightsError extends InsightsOutcome {
  const InsightsError(this.message, {this.code});
  final String message;
  final String? code;
}
