class JourneyCatalogV1 {
  final String version;
  final String category;
  final List<JourneyV1> journeys;

  JourneyCatalogV1({
    required this.version,
    required this.category,
    required this.journeys,
  });

  factory JourneyCatalogV1.fromJson(Map<String, dynamic> json) {
    final journeysJson = (json['journeys'] as List<dynamic>? ?? []);
    final parsed =
        journeysJson
            .map((e) => JourneyV1.fromJson(e as Map<String, dynamic>))
            .toList();
    parsed.sort((a, b) => a.priorityRank.compareTo(b.priorityRank));

    return JourneyCatalogV1(
      version: (json['version'] ?? '') as String,
      category: (json['category'] ?? '') as String,
      journeys: parsed,
    );
  }

  JourneyV1? findById(String id) {
    for (final j in journeys) {
      if (j.id == id) return j;
    }
    return null;
  }
}

class JourneyV1 {
  final String id;
  final String title;
  final String summary;
  final int priorityRank;
  final String icon;

  // cover (optional)
  final String? themeTag;
  final String? accentIcon;
  final String? heroImage;

  final List<MissionV1> missions;

  JourneyV1({
    required this.id,
    required this.title,
    required this.summary,
    required this.priorityRank,
    required this.icon,
    this.themeTag,
    this.accentIcon,
    this.heroImage,
    required this.missions,
  });

  factory JourneyV1.fromJson(Map<String, dynamic> json) {
    final missionsJson = (json['missions'] as List<dynamic>? ?? []);
    final cover = json['cover'] as Map<String, dynamic>?;

    return JourneyV1(
      id: (json['id'] ?? '') as String,
      title: (json['title'] ?? '') as String,
      summary: (json['summary'] ?? '') as String,
      priorityRank: (json['priorityRank'] ?? 9999) as int,
      icon: (json['icon'] ?? 'sparkles') as String,
      themeTag: cover?['themeTag'] as String?,
      accentIcon: cover?['accentIcon'] as String?,
      heroImage: cover?['heroImage'] as String?,
      missions:
          missionsJson
              .map((e) => MissionV1.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class MissionV1 {
  final int missionNumber;
  final String id;
  final bool isFree;
  final String title;
  final String subtitle;
  final int timeBoxMinutes;
  final bool requiresPartnerPresent;
  final String icon;
  final String whyThisMatters;
  final List<MissionCardV1> cards;

  MissionV1({
    required this.missionNumber,
    required this.id,
    required this.isFree,
    required this.title,
    required this.subtitle,
    required this.timeBoxMinutes,
    required this.requiresPartnerPresent,
    required this.icon,
    required this.whyThisMatters,
    required this.cards,
  });

  factory MissionV1.fromJson(Map<String, dynamic> json) {
    final cardsJson = (json['cards'] as List<dynamic>? ?? []);
    return MissionV1(
      missionNumber: (json['missionNumber'] ?? 0) as int,
      id: (json['id'] ?? '') as String,
      isFree: (json['isFree'] ?? false) as bool,
      title: (json['title'] ?? '') as String,
      subtitle: (json['subtitle'] ?? '') as String,
      timeBoxMinutes: (json['timeBoxMinutes'] ?? 5) as int,
      requiresPartnerPresent: (json['requiresPartnerPresent'] ?? false) as bool,
      icon: (json['icon'] ?? 'sparkles') as String,
      whyThisMatters: (json['whyThisMatters'] ?? '') as String,
      cards:
          cardsJson
              .map((e) => MissionCardV1.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }
}

class MissionCardV1 {
  final String type; // mission_card, instruction_card, choice_card, tip_card
  final String icon;
  final String title;
  final String? text;
  final List<String>? bullets;
  final String? prompt;
  final List<String>? options;

  MissionCardV1({
    required this.type,
    required this.icon,
    required this.title,
    this.text,
    this.bullets,
    this.prompt,
    this.options,
  });

  factory MissionCardV1.fromJson(Map<String, dynamic> json) {
    return MissionCardV1(
      type: (json['type'] ?? 'instruction_card') as String,
      icon: (json['icon'] ?? 'sparkles') as String,
      title: (json['title'] ?? '') as String,
      text: json['text'] as String?,
      bullets:
          (json['bullets'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
      prompt: json['prompt'] as String?,
      options:
          (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
    );
  }
}
