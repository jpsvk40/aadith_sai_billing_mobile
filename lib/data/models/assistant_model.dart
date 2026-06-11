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

  const AssistantAnswer({required this.answer, this.data = const []});

  factory AssistantAnswer.fromJson(Map<String, dynamic> json) => AssistantAnswer(
        answer: json['answer']?.toString() ?? '',
        data: (json['data'] as List<dynamic>?) ?? const [],
      );
}

/// One line in the chat transcript.
class AssistantTurn {
  final bool isUser;
  final String text;
  final bool loading;

  const AssistantTurn({required this.isUser, required this.text, this.loading = false});
}
