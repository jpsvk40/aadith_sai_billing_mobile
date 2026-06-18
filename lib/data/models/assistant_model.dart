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

/// A "take me to a screen" destination the assistant returned. `mobileRoute` is the in-app
/// route to open (null when the screen is web-only, e.g. the General Ledger pages).
class AssistantNavigate {
  final String? key; // stable page id (e.g. 'invoices', 'vouchers')
  final String label; // human label (e.g. 'Invoices')
  final String? route; // web-portal route
  final String? mobileRoute; // mobile-app route — null means web-only

  const AssistantNavigate({this.key, required this.label, this.route, this.mobileRoute});

  bool get openableOnMobile => (mobileRoute ?? '').isNotEmpty;

  factory AssistantNavigate.fromJson(Map<String, dynamic> json) => AssistantNavigate(
        key: json['key']?.toString(),
        label: json['label']?.toString() ?? 'Open',
        route: json['route']?.toString(),
        mobileRoute: (json['mobileRoute']?.toString().isNotEmpty ?? false) ? json['mobileRoute'].toString() : null,
      );
}

class AssistantAnswer {
  final String answer;
  final List<dynamic> data; // raw tool results (for optional drill-down rendering)
  final List<String> suggestions; // follow-up question chips
  final AssistantNavigate? navigate; // "open <screen>" destination, if any

  const AssistantAnswer({required this.answer, this.data = const [], this.suggestions = const [], this.navigate});

  factory AssistantAnswer.fromJson(Map<String, dynamic> json) => AssistantAnswer(
        answer: json['answer']?.toString() ?? '',
        data: (json['data'] as List<dynamic>?) ?? const [],
        suggestions: ((json['suggestions'] as List<dynamic>?) ?? const [])
            .map((e) => e.toString())
            .where((s) => s.trim().isNotEmpty)
            .toList(),
        navigate: json['navigate'] is Map
            ? AssistantNavigate.fromJson(Map<String, dynamic>.from(json['navigate'] as Map))
            : null,
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
  final AssistantNavigate? navigate; // "open <screen>" destination, if any

  const AssistantTurn({
    required this.isUser,
    required this.text,
    this.loading = false,
    this.suggestions = const [],
    this.data = const [],
    this.animate = false,
    this.navigate,
  });
}
