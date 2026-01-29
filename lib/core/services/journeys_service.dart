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
    // Try legacy aggregated catalog (v1) first for other statuses
    // but for singles, prioritize the v2 folder structure
    if (status != RelationshipStatus.singleNeverMarried) {
      try {
        final assetPath = _assetForStatus(status);
        final raw = await rootBundle.loadString(assetPath);
        return json.decode(raw) as Map<String, dynamic>;
      } catch (e) {
        print(
          '[JourneysService] Failed to load aggregate file for $status: $e',
        );
      }
    }

    // For singles or as fallback, load from v2 folder structure
    return await _loadCatalogFromFolderStructure(status);
  }

  String _assetForStatus(RelationshipStatus status) {
    switch (status) {
      case RelationshipStatus.married:
        return 'assets/config/journeys/journeys_married.v1.json';
      case RelationshipStatus.divorced:
        return 'assets/config/journeys/journeys_divorced.v1.json';
      case RelationshipStatus.widowed:
        return 'assets/config/journeys/journeys_widowed.v1.json';
      case RelationshipStatus.singleNeverMarried:
        return 'assets/config/journeys/journeys_singles.v1.json';
    }
  }

  Future<Map<String, dynamic>> _loadCatalogFromFolderStructure(
    RelationshipStatus status,
  ) async {
    // Direct file loading approach: try to load journey files by their expected paths
    // This is more reliable than manifest scanning and doesn't depend on build artifacts

    final folder = _getCatalogFolder(status);
    // final prefix = _getPrefixForStatus(status); // No longer used

    if (folder == null) {
      return _emptyJourneyCatalog(status);
    }

    print('[JourneysService] Loading journeys from: $folder');

    final journeys = <Map<String, dynamic>>[];

    // For singles, load from the flagship folder with known filenames
    if (status == RelationshipStatus.singleNeverMarried) {
      final knownFiles = <String>[
        'singles_journey_01_identity_self_worth_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_02_cultural_lies_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_03_healing_past_wounds_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_04_family_patterns_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_05_emotional_readiness_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_06_emotional_intelligence_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_07_secure_confidence_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_08_toxic_triggers_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_09_biblical_femininity_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_09_biblical_masculinity_FLAGSHIP_POLISHED.json',
        'singles_journey_10_communicate_better_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_11_healthy_boundaries_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_12_financial_readiness_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_13_red_flags_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_14_compatibility_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_15_dating_purpose_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_16_sexual_chemistry_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_17_faith_alignment_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_18_purity_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_19_choosing_spouse_FLAGSHIP_POLISHED_FINAL.json',
        'singles_journey_20_fear_commitment_FLAGSHIP_POLISHED_FINAL.json',
      ];

      for (final fileName in knownFiles) {
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

  String? _getCatalogFolder(RelationshipStatus status) {
    return switch (status) {
      RelationshipStatus.singleNeverMarried =>
        'assets/config/journeys/singles_catalog_FLAGSHIP_FINAL/',
      RelationshipStatus.married =>
        'assets/config/journeys/married_catalog_FLAGSHIP_FINAL/',
      RelationshipStatus.divorced =>
        'assets/config/journeys/divorced_catalog_FLAGSHIP_FINAL/',
      RelationshipStatus.widowed =>
        'assets/config/journeys/widowed_catalog_FLAGSHIP_FINAL/',
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
    final id = _string(j, const [
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

    final subtitle = _string(j, const ['subtitle'], '');
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
