import '../network/api_client.dart';
import '../models/assistant_model.dart';
import '../../core/constants/api_constants.dart';

class AiAssistantRepository {
  final ApiClient _client;
  AiAssistantRepository(this._client);

  Future<AssistantStatus> status() async {
    final data = await _client.get(ApiConstants.aiAssistantStatus);
    return AssistantStatus.fromJson(_asMap(data));
  }

  /// Records the user's consent to share data with the third-party AI providers (OpenAI + Sarvam).
  Future<void> grantConsent({String? version}) async {
    await _client.post(ApiConstants.aiAssistantConsent, data: {
      if (version != null) 'version': version,
      'client': 'mobile',
    });
  }

  /// Withdraws consent — the server then refuses /ask + /transcribe until the user agrees again.
  Future<void> revokeConsent() async {
    await _client.post(ApiConstants.aiAssistantConsentRevoke, data: {});
  }

  /// The proactive "morning brief" — a direct read (no LLM), shown when the assistant opens.
  Future<BusinessBrief> brief() async {
    final data = await _client.get(ApiConstants.aiAssistantBrief);
    return BusinessBrief.fromJson(_asMap(data));
  }

  Future<AssistantAnswer> ask(String question, {List<Map<String, String>> history = const []}) async {
    final data = await _client.post(ApiConstants.aiAssistantAsk, data: {
      'question': question,
      'client': 'mobile', // lets the server prefer mobile-openable pages in nav answers
      if (history.isNotEmpty) 'history': history,
    });
    return AssistantAnswer.fromJson(_asMap(data));
  }

  /// Upload a recorded audio clip; returns the transcribed text (Sarvam, auto language).
  Future<String> transcribe(String filePath) async {
    final data = await _client.uploadFile(
      ApiConstants.aiAssistantTranscribe,
      filePath,
      fieldName: 'audio',
    );
    return _asMap(data)['text']?.toString() ?? '';
  }

  Map<String, dynamic> _asMap(dynamic data) =>
      data is Map<String, dynamic> ? data : <String, dynamic>{};
}
