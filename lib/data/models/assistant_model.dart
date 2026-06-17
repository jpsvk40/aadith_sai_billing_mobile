// "Ask your business" assistant models.

class AssistantStatus {
  final bool enabled; // company entitled (paid feature)
  final bool configured; // server has the LLM key
  final bool voiceConfigured; // server has the Sarvam key

  const AssistantStatus({this.enabled = false, this.configured = false, this.voiceConfigured = false});

  factory AssistantStatus.fromJson(Map<String, dynamic> json) => AssistantStatus(
        enabled: json['enabled'] == true,
        configured: json['configured'] == true,
        voiceConfigured: json['voiceConfigured'] == true,
      );
}

class AssistantAnswer {
  final String answer;
  final List<dynamic> data; // raw tool results (for optional drill-down rendering)
  final List<String> suggestions; // follow-up question chips

  const AssistantAnswer({required this.answer, this.data = const [], this.suggestions = const []});

  factory AssistantAnswer.fromJson(Map<String, dynamic> json) => AssistantAnswer(
        answer: json['answer']?.toString() ?? '',
        data: (json['data'] as List<dynamic>?) ?? const [],
        suggestions: ((json['suggestions'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList(),
      );
}

/// One line in the chat transcript.
class AssistantTurn {
  final bool isUser;
  final String text;
  final bool loading;
  final List<String> suggestions; // follow-up chips (assistant turns)
  final List<dynamic> data; // tool results, for a mini table (assistant turns)
  final bool animate; // typewriter-reveal this answer

  const AssistantTurn({
    required this.isUser,
    required this.text,
    this.loading = false,
    this.suggestions = const [],
    this.data = const [],
    this.animate = false,
  });
}
