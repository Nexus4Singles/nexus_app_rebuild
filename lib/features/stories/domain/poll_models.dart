import 'dart:convert';

class PollsPayload {
  final int version;
  final List<Poll> polls;

  const PollsPayload({required this.version, required this.polls});

  factory PollsPayload.fromJson(Map<String, dynamic> json) {
    final pollsJson = (json['polls'] as List<dynamic>? ?? const []);
    return PollsPayload(
      version: (json['version'] as num?)?.toInt() ?? 1,
      polls:
          pollsJson
              .whereType<Map<String, dynamic>>()
              .map(Poll.fromJson)
              .toList(),
    );
  }

  static PollsPayload fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('polls.v1.json must be a JSON object');
    }
    return PollsPayload.fromJson(decoded);
  }
}

class Poll {
  final String id;
  final String question;
  final List<PollOption> options;

  /// Optional: insight message shown after vote (by optionId).
  final Map<String, String> insights;

  /// Optional: seeded counts used for local/dev results.
  final Map<String, int> seedCounts;

  const Poll({
    required this.id,
    required this.question,
    required this.options,
    required this.insights,
    required this.seedCounts,
  });

  factory Poll.fromJson(Map<String, dynamic> json) {
    final optionsJson = (json['options'] as List<dynamic>? ?? const []);
    final insightsJson = (json['insights'] as Map?) ?? const {};
    final seedCountsJson = (json['seedCounts'] as Map?) ?? const {};

    return Poll(
      id: (json['id'] ?? '') as String,
      question: (json['question'] ?? '') as String,
      options:
          optionsJson
              .whereType<Map<String, dynamic>>()
              .map(PollOption.fromJson)
              .toList(),
      insights: insightsJson.map(
        (k, v) => MapEntry(k.toString(), v.toString()),
      ),
      seedCounts: seedCountsJson.map(
        (k, v) => MapEntry(k.toString(), (v as num).toInt()),
      ),
    );
  }
}

class PollOption {
  final String id;
  final String text;

  const PollOption({required this.id, required this.text});

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: (json['id'] ?? '') as String,
      text: (json['text'] ?? '') as String,
    );
  }
}
