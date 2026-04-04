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

  JourneyV1? findByReference(String reference) {
    final raw = reference.trim();
    if (raw.isEmpty) return null;

    // 1) Canonical ID exact match
    for (final j in journeys) {
      if (j.id == raw) return j;
    }

    // 2) Canonical ID case-insensitive fallback
    final lowered = raw.toLowerCase();
    for (final j in journeys) {
      if (j.id.toLowerCase() == lowered) return j;
    }

    // 3) Legacy title exact match
    for (final j in journeys) {
      if (j.title == raw) return j;
    }

    // 4) Legacy title case-insensitive fallback
    for (final j in journeys) {
      if (j.title.toLowerCase() == lowered) return j;
    }

    return null;
  }

  String? resolveJourneyId(String reference) {
    return findByReference(reference)?.id;
  }
}

class JourneyV1 {
  final String id;
  final String title;
  final String subtitle;
  final String summary;
  final int priorityRank;
  final String icon;

  /// Optional gender targeting. Example: ['male'], ['female'], or empty for all.
  final List<String> allowedGenders;

  // cover (optional)
  final String? themeTag;
  final String? accentIcon;
  final String? heroImage;

  final List<MissionV1> missions;

  JourneyV1({
    required this.id,
    required this.title,
    required this.subtitle,
    required this.summary,
    required this.priorityRank,
    required this.icon,
    this.allowedGenders = const [],
    this.themeTag,
    this.accentIcon,
    this.heroImage,
    required this.missions,
  });

  factory JourneyV1.fromJson(Map<String, dynamic> json) {
    final missionsJson = (json['missions'] as List<dynamic>? ?? []);
    final cover = json['cover'] as Map<String, dynamic>?;
    final genders =
        (json['allowedGenders'] as List<dynamic>?)
            ?.map((e) => e.toString().toLowerCase())
            .toList();

    // Check both 'id' and 'journeyId' fields - journey files use 'journeyId'
    final journeyId = (json['journeyId'] ?? json['id'] ?? '') as String;

    return JourneyV1(
      id: journeyId,
      title: (json['title'] ?? '') as String,
      subtitle: (json['subtitle'] ?? '') as String,
      summary: (json['summary'] ?? '') as String,
      priorityRank: (json['priorityRank'] ?? 9999) as int,
      icon: (json['icon'] ?? 'sparkles') as String,
      allowedGenders: genders ?? const [],
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

    int _readInt(List<String> keys, int fallback) {
      for (final key in keys) {
        final value = json[key];
        if (value is int) return value;
        if (value is num) return value.toInt();
        if (value is String) {
          final parsed = int.tryParse(value.trim());
          if (parsed != null) return parsed;
        }
      }
      return fallback;
    }

    bool _readBool(List<String> keys, bool fallback) {
      for (final key in keys) {
        final value = json[key];
        if (value is bool) return value;
      }
      return fallback;
    }

    final missionNumber = _readInt([
      'missionNumber',
      'activityNumber',
      'number',
      'index',
    ], 0);
    final isFree = _readBool(['isFree'], missionNumber == 1);
    final requiresPartnerPresent = _readBool([
      'requiresPartnerPresent',
      'requiresCompanion',
    ], false);

    return MissionV1(
      missionNumber: missionNumber,
      id: (json['id'] ?? '') as String,
      isFree: isFree,
      title: (json['title'] ?? '') as String,
      subtitle: (json['subtitle'] ?? '') as String,
      timeBoxMinutes: _readInt([
        'timeBoxMinutes',
        'duration',
        'durationMinutes',
      ], 5),
      requiresPartnerPresent: requiresPartnerPresent,
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
  final String
  type; // mission_card, instruction_card, choice_card, tip_card, reflection_card
  final String icon;
  final String title;
  final String? flavor; // e.g. teaching, reflection, action, question, tip
  final String? text;
  final List<String>? bullets;
  final String? prompt; // Single prompt (legacy or new format)
  final List<String>? prompts; // Multiple prompts array (new format)
  final List<String>? options; // Choice options (legacy format)
  final String? reflection; // Reflection prompt text
  final String?
  responseType; // e.g. 'open-text', 'single-select', 'multiple-select'

  MissionCardV1({
    required this.type,
    required this.icon,
    required this.title,
    this.flavor,
    this.text,
    this.bullets,
    this.prompt,
    this.prompts,
    this.options,
    this.reflection,
    this.responseType,
  });

  factory MissionCardV1.fromJson(Map<String, dynamic> json) {
    // Handle both 'type' and 'cardType' field names for compatibility
    final cardType =
        (json['type'] ?? json['cardType'] ?? 'instruction_card') as String;

    // Get options from either 'options' field or convert from 'prompts' array
    List<String>? finalOptions;
    List<String>? promptsList;

    // First, try to get prompts array (new format)
    final promptsFromJson =
        (json['prompts'] as List<dynamic>?)?.map((e) => e.toString()).toList();

    if (promptsFromJson != null && promptsFromJson.isNotEmpty) {
      promptsList = promptsFromJson;
      // For question cards with prompts, convert prompts to options
      if (cardType == 'question' || cardType == 'choice_card') {
        finalOptions = promptsFromJson;
      }
    }

    // Fall back to options field if present
    if (finalOptions == null) {
      finalOptions =
          (json['options'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList();
    }

    return MissionCardV1(
      type: cardType,
      icon: (json['icon'] ?? 'sparkles') as String,
      title: (json['title'] ?? '') as String,
      flavor: json['flavor'] as String?,
      text: json['text'] as String?,
      bullets:
          (json['bullets'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList(),
      prompt: json['prompt'] as String?,
      prompts: promptsList,
      options: finalOptions,
      reflection: json['reflection'] as String?,
      responseType: json['responseType'] as String?,
    );
  }
}
