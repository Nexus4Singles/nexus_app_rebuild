import 'dart:convert';

class StoriesPayload {
  final int version;
  final List<Story> stories;

  const StoriesPayload({required this.version, required this.stories});

  factory StoriesPayload.fromJson(Map<String, dynamic> json) {
    final storiesJson = (json['stories'] as List<dynamic>? ?? const []);
    return StoriesPayload(
      version: (json['version'] as num?)?.toInt() ?? 1,
      stories:
          storiesJson
              .whereType<Map<String, dynamic>>()
              .map(Story.fromJson)
              .toList(),
    );
  }

  static StoriesPayload fromJsonString(String raw) {
    final decoded = jsonDecode(raw);
    if (decoded is! Map<String, dynamic>) {
      throw FormatException('stories.v1.json must be a JSON object');
    }
    return StoriesPayload.fromJson(decoded);
  }
}

class Story {
  final String id;
  final String title;
  final String category;
  final int readTimeMins;
  final String heroImageAsset;

  // Feed fields
  final String excerpt;

  // Detail fields
  final String intro;
  final List<StorySection> sections;
  final String takeawayTitle;
  final List<String> takeaways;
  final String reflectionPrompt;

  // Poll link
  final String pollId;
  final String pollCtaText;

  const Story({
    required this.id,
    required this.title,
    required this.category,
    required this.readTimeMins,
    required this.heroImageAsset,
    required this.excerpt,
    required this.intro,
    required this.sections,
    required this.takeawayTitle,
    required this.takeaways,
    required this.reflectionPrompt,
    required this.pollId,
    required this.pollCtaText,
  });

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      category: (json['category'] ?? 'General') as String,
      readTimeMins: (json['readTimeMins'] as num?)?.toInt() ?? 3,
      heroImageAsset: (json['heroImageAsset'] ?? '') as String,
      excerpt: (json['excerpt'] ?? '') as String,
      intro: (json['intro'] ?? '') as String,
      sections:
          ((json['sections'] as List<dynamic>?) ?? const [])
              .whereType<Map<String, dynamic>>()
              .map(StorySection.fromJson)
              .toList(),
      takeawayTitle: (json['takeawayTitle'] ?? 'Key Takeaways') as String,
      takeaways:
          ((json['takeaways'] as List<dynamic>?) ?? const [])
              .whereType<String>()
              .toList(),
      reflectionPrompt: (json['reflectionPrompt'] ?? '') as String,
      pollId: (json['pollId'] ?? '') as String,
      pollCtaText: (json['pollCtaText'] ?? 'Open poll') as String,
    );
  }
}

class StorySection {
  final String heading;
  final String body;

  const StorySection({required this.heading, required this.body});

  factory StorySection.fromJson(Map<String, dynamic> json) {
    return StorySection(
      heading: (json['heading'] ?? '') as String,
      body: (json['body'] ?? '') as String,
    );
  }
}
