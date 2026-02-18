import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../constants/app_constants.dart';

/// Loads journeys catalogs from assets.
/// Update the asset paths to match your real filenames in pubspec.yaml.
class JourneysService {
  const JourneysService();

  Future<Map<String, dynamic>> loadCatalogForStatus(
    RelationshipStatus status,
  ) async {
    // Load journeys directly from folder structure
    // v1 aggregated files have been deprecated
    return await _loadCatalogFromFolderStructure(status);
  }

  Future<Map<String, dynamic>> _loadCatalogFromFolderStructure(
    RelationshipStatus status,
  ) async {
    // Load journeys dynamically from status-specific folders
    // Each folder contains individual JSON files for each journey

    final folder = _getCatalogFolder(status);

    if (folder == null) {
      return _emptyJourneyCatalog(status);
    }

    print('[JourneysService] Loading journeys from: $folder');

    final journeys = <Map<String, dynamic>>[];

    // List of files to load based on status
    final filePreset = _getJourneyFilesForStatus(status);

    if (filePreset.isEmpty) {
      print('[JourneysService] No journey files configured for status=$status');
      return _emptyJourneyCatalog(status);
    }

    for (final fileName in filePreset) {
      final path = '$folder$fileName';
      try {
        final raw = await rootBundle.loadString(path);
        final data = json.decode(raw);
        final normalized = _normalizeJourneyJsonV2(data, sourcePath: path);
        if (normalized != null) {
          journeys.add(normalized);
          print('[JourneysService] ✓ Loaded: $fileName');
        }
      } catch (e) {
        print('[JourneysService] ✗ Failed to load $fileName: $e');
      }
    }

    print(
      '[JourneysService] Successfully loaded ${journeys.length} journeys for status=$status',
    );

    return {
      'version': 'journeys.v2',
      'category': switch (status) {
        RelationshipStatus.singleNeverMarried => 'singles',
        RelationshipStatus.married => 'married',
        RelationshipStatus.divorced => 'divorced',
        RelationshipStatus.widowed => 'widowed',
      },
      'journeys': journeys,
    };
  }

  List<String> _getJourneyFilesForStatus(RelationshipStatus status) {
    return switch (status) {
      RelationshipStatus.singleNeverMarried => <String>[
        'singles_journey_01_identity_self_worth.json',
        'singles_journey_02_cultural_lies.json',
        'singles_journey_03_healing_past_wounds.json',
        'singles_journey_04_family_patterns.json',
        'singles_journey_05_emotional_readiness.json',
        'singles_journey_06_emotional_intelligence.json',
        'singles_journey_07_secure_confidence.json',
        'singles_journey_08_toxic_triggers.json',
        'singles_journey_09_biblical_femininity.json',
        'singles_journey_09_biblical_masculinity.json',
        'singles_journey_10_communicate_better.json',
        'singles_journey_11_healthy_boundaries.json',
        'singles_journey_12_financial_readiness.json',
        'singles_journey_13_red_flags.json',
        'singles_journey_14_compatibility.json',
        'singles_journey_15_dating_purpose.json',
        'singles_journey_16_sexual_chemistry.json',
        'singles_journey_17_faith_alignment.json',
        'singles_journey_18_purity.json',
        'singles_journey_19_choosing_spouse.json',
        'singles_journey_20_fear_commitment.json',
      ],
      RelationshipStatus.married => <String>[
        'married_journey_01_communication_conflict.json',
        'married_journey_02_harmful_conflict_patterns.json',
        'married_journey_03_restoring_friendship.json',
        'married_journey_04_emotional_physical_intimacy.json',
        'married_journey_05_keeping_romance_alive.json',
        'married_journey_06_reigniting_sexual_desire.json',
        'married_journey_07_rebuilding_trust.json',
        'married_journey_08_handling_infidelity.json',
        'married_journey_09_roles_expectations.json',
        'married_journey_10_masculinity_femininity.json',
        'married_journey_11_cultural_differences.json',
        'married_journey_12_managing_finances.json',
        'married_journey_13_parenting_united_team.json',
        'married_journey_14_infertility.json',
        'married_journey_15_healthy_boundaries_extended_family.json',
        'married_journey_16_personal_growth.json',
        'married_journey_17_faith_spiritual_unity.json',
        'married_journey_18_shared_purpose_vision.json',
      ],
      RelationshipStatus.divorced => <String>[
        'divorced_journey_01_understanding_what_went_wrong.json',
        'divorced_journey_02_processing_pain.json',
        'divorced_journey_03_healing_restoration.json',
        'divorced_journey_04_identity_selfworth.json',
        'divorced_journey_05_letting_go_resentment.json',
        'divorced_journey_06_faith_church_community.json',
        'divorced_journey_07_financial_recovery.json',
        'divorced_journey_08_coparenting.json',
        'divorced_journey_09_anniversaries_occasions.json',
        'divorced_journey_10_ex_moves_on.json',
        'divorced_journey_11_developing_trust.json',
        'divorced_journey_12_toxic_patterns.json',
        'divorced_journey_13_emotional_readiness.json',
        'divorced_journey_14_discerning_healthy_love.json',
        'divorced_journey_15_dating_again.json',
        'divorced_journey_16_preparing_new_covenant.json',
      ],
      RelationshipStatus.widowed => <String>[
        'widowed_journey_01_navigating_grief_loss.json',
        'widowed_journey_02_staying_present_for_kids.json',
        'widowed_journey_03_dealing_with_loneliness.json',
        'widowed_journey_04_rebuilding_life.json',
        'widowed_journey_05_holidays_anniversaries.json',
        'widowed_journey_06_rediscovering_identity.json',
        'widowed_journey_07_honoring_memory.json',
        'widowed_journey_08_opening_heart_new_love.json',
        'widowed_journey_09_kids_embrace_new_commitment.json',
        'widowed_journey_10_preparing_new_covenant.json',
      ],
    };
  }

  String? _getCatalogFolder(RelationshipStatus status) {
    return switch (status) {
      RelationshipStatus.singleNeverMarried =>
        'assets/config/journeys/singles journeys/',
      RelationshipStatus.married => 'assets/config/journeys/married journeys/',
      RelationshipStatus.divorced =>
        'assets/config/journeys/divorced journeys/',
      RelationshipStatus.widowed => 'assets/config/journeys/widowed journeys/',
    };
  }

  Map<String, dynamic> _emptyJourneyCatalog(RelationshipStatus status) {
    return {
      'version': 'journeys.v2',
      'category': switch (status) {
        RelationshipStatus.singleNeverMarried => 'singles',
        RelationshipStatus.married => 'married',
        RelationshipStatus.divorced => 'divorced',
        RelationshipStatus.widowed => 'widowed',
      },
      'journeys': [],
    };
  }

  Map<String, dynamic>? _normalizeJourneyJsonV2(
    dynamic raw, {
    required String sourcePath,
  }) {
    if (raw is! Map<String, dynamic>) return null;

    // Some files may nest the journey object under a key; pick the first map that has missions/activities.
    Map<String, dynamic> j = raw;
    final candidateKeys = ['journey', 'data', 'content', 'root'];
    for (final k in candidateKeys) {
      final v = raw[k];
      if (v is Map<String, dynamic> &&
          _hasAnyList(v, const [
            'missions',
            'activities',
            'lessons',
            'steps',
            'modules',
          ])) {
        j = v;
        break;
      }
    }

    String _string(
      Map<String, dynamic> m,
      List<String> keys, [
      String def = '',
    ]) {
      for (final k in keys) {
        final v = m[k];
        if (v is String && v.trim().isNotEmpty) return v;
      }
      return def;
    }

    int _int(Map<String, dynamic> m, List<String> keys, [int def = 0]) {
      for (final k in keys) {
        final v = m[k];
        if (v is int) return v;
        if (v is num) return v.toInt();
        if (v is String) {
          final p = int.tryParse(v);
          if (p != null) return p;
        }
      }
      return def;
    }

    final title = _string(j, const ['title', 'name', 'label'], '');
    final summary = _string(j, const [
      'summary',
      'description',
      'abstract',
    ], '');
    final icon = _string(j, const ['icon'], 'sparkles');
    // Check for journeyId first (from migration), then id, slug, or generate from filename
    final id = _string(j, const [
      'journeyId',
      'id',
      'slug',
    ], _slugFromSource(sourcePath, title));
    final priorityRank = _int(j, const [
      'priorityRank',
      'order',
      'journeyNumber',
    ], 9999);
    final targetUserCategory = _string(j, const [
      'targetUserCategory',
      'audience',
      'category',
    ]);
    final allowedGenders = _allowedGendersFromCategory(targetUserCategory);

    final cover = <String, dynamic>{};
    if (j['cover'] is Map<String, dynamic>) {
      cover.addAll(j['cover'] as Map<String, dynamic>);
    }
    // Try to infer theme tag from any tags array.
    if (cover['themeTag'] == null && j['tags'] is List) {
      final tags = (j['tags'] as List).map((e) => e.toString()).toList();
      if (tags.isNotEmpty) cover['themeTag'] = tags.first;
    }

    final missions = _extractMissionsList(j);

    // Extract subtitle with summary as fallback for consistency across all journey types
    var subtitle = _string(j, const ['subtitle'], '');
    if (subtitle.isEmpty) {
      subtitle = _string(j, const ['summary', 'description'], '');
    }
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'summary': summary,
      'priorityRank': priorityRank,
      'icon': icon,
      if (allowedGenders.isNotEmpty) 'allowedGenders': allowedGenders,
      if (cover.isNotEmpty) 'cover': cover,
      'missions': missions,
    };
  }

  List<String> _allowedGendersFromCategory(String cat) {
    final lc = cat.toLowerCase();
    if (lc.contains('men') || lc.contains('male')) return ['male'];
    if (lc.contains('women') || lc.contains('female')) return ['female'];
    return const [];
  }

  bool _hasAnyList(Map<String, dynamic> m, List<String> keys) {
    for (final k in keys) {
      final v = m[k];
      if (v is List && v.isNotEmpty) return true;
    }
    return false;
  }

  List<Map<String, dynamic>> _extractMissionsList(Map<String, dynamic> j) {
    final listKeys = ['missions', 'activities', 'lessons', 'steps', 'modules'];
    List<dynamic> rawList = const [];
    for (final k in listKeys) {
      final v = j[k];
      if (v is List) {
        rawList = v;
        break;
      }
    }

    final missions = <Map<String, dynamic>>[];
    for (var i = 0; i < rawList.length; i++) {
      final item = rawList[i];
      if (item is! Map<String, dynamic>) continue;

      String _s(List<String> keys, [String def = '']) {
        for (final k in keys) {
          final v = item[k];
          if (v is String && v.trim().isNotEmpty) return v;
        }
        return def;
      }

      int _i(List<String> keys, [int def = 0]) {
        for (final k in keys) {
          final v = item[k];
          if (v is int) return v;
          if (v is num) return v.toInt();
          if (v is String) {
            final p = int.tryParse(v);
            if (p != null) return p;
          }
        }
        return def;
      }

      final mTitle = _s(['title', 'name', 'label'], '');
      final mId = _s(['id', 'slug'], _slug('$mTitle-$i'));
      final mSub = _s(['subtitle', 'summary', 'description'], '');
      final mIcon = _s(['icon'], 'sparkles');
      final mNum = _i([
        'missionNumber',
        'number',
        'index',
        'activityNumber',
      ], i + 1);
      final mTime = _i([
        'timeBoxMinutes',
        'duration',
        'durationMinutes',
        'time',
      ], 5);
      final mFree =
          (item['isFree'] is bool) ? (item['isFree'] as bool) : (mNum == 1);
      final mPartner =
          (item['requiresPartnerPresent'] as bool?) ??
          (item['requiresCompanion'] as bool?) ??
          false;
      final mWhy = _s(['whyThisMatters', 'why'], '');

      final cards = _extractCards(item, mTitle);

      missions.add({
        'missionNumber': mNum,
        'id': mId,
        'isFree': mFree,
        'title': mTitle,
        'subtitle': mSub,
        'timeBoxMinutes': mTime,
        'requiresPartnerPresent': mPartner,
        'icon': mIcon,
        'whyThisMatters': mWhy,
        'cards': cards,
      });
    }
    return missions;
  }

  List<Map<String, dynamic>> _extractCards(
    Map<String, dynamic> mission,
    String missionTitle,
  ) {
    final listKeys = ['cards', 'content', 'sections', 'blocks'];
    List<dynamic> rawList = const [];
    for (final k in listKeys) {
      final v = mission[k];
      if (v is List) {
        rawList = v;
        break;
      }
    }

    if (rawList.isEmpty) {
      // Fallback: synthesize a single info card from any known text fields.
      final text = [
        (mission['text'] ?? mission['body'] ?? mission['notes'] ?? '')
            .toString(),
      ].where((e) => e.trim().isNotEmpty).join('\n\n');
      if (text.trim().isNotEmpty) {
        return [
          {
            'type': 'mission_card',
            'icon': mission['icon'] ?? 'sparkles',
            'title': missionTitle.isEmpty ? 'Your Activity' : missionTitle,
            'text': text,
          },
        ];
      }
      return const [];
    }

    final cards = <Map<String, dynamic>>[];
    for (final c in rawList) {
      if (c is! Map<String, dynamic>) continue;

      final rawType =
          (c['cardType'] ?? c['type'] ?? c['kind'] ?? 'instruction')
              .toString()
              .toLowerCase();
      final title = (c['title'] ?? c['heading'] ?? '').toString();
      final icon = (c['icon'] ?? 'sparkles').toString();
      final text = (c['text'] ?? c['body'] ?? '').toString();
      final bullets =
          (c['bullets'] is List)
              ? (c['bullets'] as List).map((e) => e.toString()).toList()
              : null;
      final prompt = (c['prompt'] ?? '').toString();
      final options =
          (c['options'] is List)
              ? (c['options'] as List).map((e) => e.toString()).toList()
              : (c['prompts'] is List)
              ? (c['prompts'] as List).map((e) => e.toString()).toList()
              : null;
      final responseType = (c['responseType'] ?? '').toString().toLowerCase();

      // Map v2 card types to v1 renderable types
      // teaching/reflection/action -> mission_card/instruction_card
      // question -> choice_card
      String mappedType = 'instruction_card';
      if (rawType.contains('question')) {
        mappedType = 'choice_card';
      } else if (rawType.contains('choice')) {
        mappedType = 'choice_card';
      } else if (rawType.contains('mission')) {
        mappedType = 'mission_card';
      } else {
        mappedType = 'mission_card';
      }

      // If open-text response, keep as instruction card but include text prompt
      if (responseType.contains('open')) {
        mappedType = 'instruction_card';
      }

      // Ensure choice cards have options; if missing, downgrade to instruction card.
      if (mappedType == 'choice_card' && (options == null || options.isEmpty)) {
        mappedType = 'instruction_card';
      }

      final card = <String, dynamic>{
        'type': mappedType,
        'icon': icon,
        'title': title.isEmpty ? missionTitle : title,
        'flavor': rawType.isNotEmpty ? rawType : null,
      };

      if (mappedType == 'choice_card') {
        card['prompt'] = prompt.isNotEmpty ? prompt : text;
        card['options'] = options ?? const [];
      } else {
        final mergedText = text.trim().isNotEmpty ? text : prompt;
        if (mergedText.trim().isNotEmpty) card['text'] = mergedText;
        if (bullets != null && bullets.isNotEmpty) card['bullets'] = bullets;
      }

      cards.add(card);
    }
    return cards;
  }

  String _slugFromSource(String sourcePath, String title) {
    if (title.trim().isNotEmpty) return _slug(title);
    final fileName = sourcePath.split('/').last;
    final noExt = fileName.replaceAll('.json', '');
    return _slug(noExt);
  }

  String _slug(String input) {
    final lower = input.toLowerCase();
    final a = lower.replaceAll(RegExp(r'[^a-z0-9]+'), '_');
    final b = a.replaceAll(RegExp(r'_+'), '_');
    return b.replaceAll(RegExp(r'^_|_$'), '');
  }
}
