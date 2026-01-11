import 'dart:convert';

class JourneysPayload {
  final String version;
  final String? category;
  final List<Journey> journeys;

  const JourneysPayload({
    required this.version,
    required this.category,
    required this.journeys,
  });

  factory JourneysPayload.fromJson(Map<String, dynamic> json) {
    final journeysJson = (json['journeys'] as List<dynamic>? ?? const []);
    return JourneysPayload(
      version: (json['version'] ?? '') as String,
      category: json['category'] as String?,
      journeys:
          journeysJson
              .whereType<Map<String, dynamic>>()
              .map(Journey.fromJson)
              .toList(),
    );
  }

  static JourneysPayload fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('Journeys JSON must be a JSON object');
    }
    return JourneysPayload.fromJson(decoded);
  }
}

class Journey {
  final String id;
  final String title;
  final String audience;
  final String summary;
  final int estimatedDays;
  final String difficulty;
  final int priorityRank;

  final String heroImageAsset;

  const Journey({
    required this.id,
    required this.title,
    required this.audience,
    required this.summary,
    required this.estimatedDays,
    required this.difficulty,
    required this.priorityRank,
    required this.heroImageAsset,
  });

  factory Journey.fromJson(Map<String, dynamic> json) {
    final cover = (json['cover'] as Map<String, dynamic>?) ?? const {};
    return Journey(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      audience: (json['audience'] ?? '') as String,
      summary: (json['summary'] ?? '') as String,
      estimatedDays: (json['estimatedDays'] as num?)?.toInt() ?? 0,
      difficulty: (json['difficulty'] ?? '') as String,
      priorityRank: (json['priorityRank'] as num?)?.toInt() ?? 999,
      heroImageAsset: (cover['heroImage'] ?? '') as String,
    );
  }
}
