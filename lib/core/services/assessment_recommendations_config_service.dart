import 'dart:async';
import 'dart:convert';
import 'dart:math';
import 'package:flutter/services.dart' show rootBundle;

import '../models/assessment_recommendations_config.dart';
import '../constants/app_constants.dart';

/// Service that loads and manages assessment journey recommendations from config
class AssessmentRecommendationsConfigService {
  static const String _configPath =
      'assets/config/assessments/assessment_journey_recommendations_v2.json';

  static AssessmentRecommendationsConfig? _cachedConfig;
  static final Map<String, String> _journeySubtitleCache = {};

  const AssessmentRecommendationsConfigService();

  /// Load the configuration from assets (with caching)
  Future<AssessmentRecommendationsConfig> loadConfig() async {
    if (_cachedConfig != null) {
      print('[ConfigService] Config cache HIT');
      return _cachedConfig!;
    }

    try {
      print('[ConfigService] Loading config from: $_configPath');
      final jsonString = await rootBundle.loadString(_configPath);
      print('[ConfigService] ✓ JSON loaded (${jsonString.length} bytes)');

      final json = jsonDecode(jsonString) as Map<String, dynamic>;
      _cachedConfig = AssessmentRecommendationsConfig.fromJson(json);

      print('[ConfigService] ✓ Config deserialized successfully');
      print(
        '[ConfigService]   Marriage dims: ${_cachedConfig!.marriageHealthCheck.dimensionMappings.length}',
      );
      print(
        '[ConfigService]   Divorced dims: ${_cachedConfig!.remarriageDivorced.dimensionMappings.length}',
      );
      print(
        '[ConfigService]   Widowed dims: ${_cachedConfig!.remarriageWidowed.dimensionMappings.length}',
      );

      return _cachedConfig!;
    } catch (e) {
      print('[ConfigService] ✗ ERROR loading config: $e');
      print('[ConfigService] Stack: $e');
      // Return empty config if loading fails
      return _getEmptyConfig();
    }
  }

  /// Get journey subtitle by loading the actual journey file with timeout
  Future<String> getJourneySubtitle(String journeyId) async {
    // Check cache first
    if (_journeySubtitleCache.containsKey(journeyId)) {
      print('[ConfigService] Subtitle cache HIT for $journeyId');
      return _journeySubtitleCache[journeyId]!;
    }

    try {
      // Determine the folder based on journey ID
      late String folderPath;
      if (journeyId.startsWith('married') || journeyId.contains('married')) {
        folderPath = 'assets/config/journeys/married journeys';
      } else if (journeyId.startsWith('singles') ||
          journeyId.contains('singles')) {
        folderPath = 'assets/config/journeys/singles journeys';
      } else if (journeyId.startsWith('divorced') ||
          journeyId.contains('divorced')) {
        folderPath = 'assets/config/journeys/divorced journeys';
      } else if (journeyId.startsWith('widowed') ||
          journeyId.contains('widowed')) {
        folderPath = 'assets/config/journeys/widowed journeys';
      } else {
        print('[ConfigService] ✗ Unknown journey type for: $journeyId');
        return ''; // Unknown journey type
      }

      // Try to construct filename - journey files may be named with or without journey number
      // Try exact match first
      var path = '$folderPath/$journeyId.json';
      print('[ConfigService] Trying exact match: $path');

      try {
        final journeyJson = await rootBundle
            .loadString(path)
            .timeout(
              const Duration(seconds: 2),
              onTimeout: () => throw TimeoutException('Loading $path'),
            );
        final data = jsonDecode(journeyJson) as Map<String, dynamic>;
        final subtitle = (data['subtitle'] as String?) ?? '';
        _journeySubtitleCache[journeyId] = subtitle;
        print(
          '[ConfigService] ✓ Loaded subtitle from exact match: "${subtitle.isEmpty ? '(empty)' : subtitle.substring(0, min(50, subtitle.length))}"',
        );
        return subtitle;
      } catch (e1) {
        // Exact match failed, try with journey number prefix
        print(
          '[ConfigService] Exact match failed, trying with journey number...',
        );

        // Extract parts and try to build journey filename
        // journeyId might be "married_restoring_friendship" or just "restoring_friendship"
        final parts = journeyId.split('_');
        final typePart = parts.first; // e.g., "married"

        // Try numbered files like married_journey_01_restoring_friendship.json with optional _FLAGSHIP_POLISHED_FINAL suffix
        for (int i = 1; i <= 30; i++) {
          final numberedId =
              '${typePart}_journey_${i.toString().padLeft(2, '0')}_${parts.skip(1).join('_')}';

          // Try without suffix first
          path = '$folderPath/$numberedId.json';

          try {
            final journeyJson = await rootBundle
                .loadString(path)
                .timeout(
                  const Duration(seconds: 1),
                  onTimeout: () => throw TimeoutException('Loading $path'),
                );
            final data = jsonDecode(journeyJson) as Map<String, dynamic>;
            final subtitle = (data['subtitle'] as String?) ?? '';
            _journeySubtitleCache[journeyId] = subtitle;
            print(
              '[ConfigService] ✓ Loaded subtitle from numbered file ($numberedId): "${subtitle.isEmpty ? '(empty)' : subtitle.substring(0, min(50, subtitle.length))}"',
            );
            return subtitle;
          } catch (e2) {
            // Try with _FLAGSHIP_POLISHED_FINAL suffix (for newer json files)
            path = '$folderPath/${numberedId}_FLAGSHIP_POLISHED_FINAL.json';
            try {
              final journeyJson = await rootBundle
                  .loadString(path)
                  .timeout(
                    const Duration(seconds: 1),
                    onTimeout: () => throw TimeoutException('Loading $path'),
                  );
              final data = jsonDecode(journeyJson) as Map<String, dynamic>;
              final subtitle = (data['subtitle'] as String?) ?? '';
              _journeySubtitleCache[journeyId] = subtitle;
              print(
                '[ConfigService] ✓ Loaded subtitle from numbered file with suffix ($numberedId + _FLAGSHIP_POLISHED_FINAL): "${subtitle.isEmpty ? '(empty)' : subtitle.substring(0, min(50, subtitle.length))}"',
              );
              return subtitle;
            } catch (e3) {
              // Continue to next number
            }
          }
        }

        // If we get here, file not found
        print('[ConfigService] ⚠ Could not find journey file for $journeyId');
        _journeySubtitleCache[journeyId] = '';
        return '';
      }
    } catch (e) {
      print('[ConfigService] ⚠ Error loading subtitle for $journeyId: $e');
      _journeySubtitleCache[journeyId] = '';
      return '';
    }
  }

  /// Cache for all journey metadata (journey ID -> {title, subtitle})
  static final Map<String, Map<String, String>> _journeyMetadataCache = {};

  /// Cache for the filename mapping
  static Map<String, String>? _filenameMap;

  /// Get journey metadata (title, subtitle) using the filename mapping
  Future<Map<String, String>> getJourneyMetadata(String journeyId) async {
    // Check cache first
    if (_journeyMetadataCache.containsKey(journeyId)) {
      return _journeyMetadataCache[journeyId]!;
    }

    try {
      // Load the filename map if we haven't already
      if (_filenameMap == null) {
        final mapJson = await rootBundle.loadString(
          'assets/config/journey_id_filename_map.json',
        );
        final decoded = json.decode(mapJson) as Map<String, dynamic>;
        _filenameMap = decoded.map((k, v) => MapEntry(k, v.toString()));
      }

      // Get the filename for this journeyId
      final filename = _filenameMap![journeyId];
      if (filename == null) {
        print('[ConfigService] ⚠ No mapping found for $journeyId');
        return {};
      }

      // Determine folder based on journey type
      final type = journeyId.split('_')[0];
      final folder = _getJourneyFolder(type);
      if (folder == null) return {};

      // Load the journey file
      final path = '$folder/$filename';
      final journeyJson = await rootBundle.loadString(path);
      final data = jsonDecode(journeyJson) as Map<String, dynamic>;

      final metadata = {
        'title': (data['title'] as String?) ?? '',
        'subtitle': (data['subtitle'] as String?) ?? '',
      };

      _journeyMetadataCache[journeyId] = metadata;
      print('[ConfigService] ✓ $journeyId');
      return metadata;
    } catch (e) {
      print('[ConfigService] ❌ Error loading $journeyId: $e');
      return {};
    }
  }

  /// Helper to get folder path by journey type
  String? _getJourneyFolder(String type) {
    switch (type.toLowerCase()) {
      case 'singles':
        return 'assets/config/journeys/singles journeys';
      case 'married':
        return 'assets/config/journeys/married journeys';
      case 'divorced':
        return 'assets/config/journeys/divorced journeys';
      case 'widowed':
        return 'assets/config/journeys/widowed journeys';
      default:
        return null;
    }
  }

  /// Get recommendations for a specific assessment and dimension
  Future<List<JourneyRecommendationItem>> getRecommendationsForDimension({
    required String assessmentId,
    required String dimensionId,
  }) async {
    print(
      '[ConfigService] getRecommendationsForDimension: assessmentId=$assessmentId, dimensionId=$dimensionId',
    );
    final config = await loadConfig();
    final assessment = _getAssessmentByType(config, assessmentId);

    if (assessment == null) {
      print('[ConfigService] ✗ Assessment not found for $assessmentId');
      return [];
    }

    // Find the dimension mapping
    for (final dim in assessment.dimensionMappings) {
      if (dim.dimensionId == dimensionId) {
        print(
          '[ConfigService] ✓ Found dimension: ${dim.dimensionName}, ${dim.recommendations.length} recommendations',
        );
        return dim.recommendations;
      }
    }

    print('[ConfigService] ✗ Dimension "$dimensionId" not found in assessment');
    print(
      '[ConfigService] Available dimensions: ${assessment.dimensionMappings.map((d) => d.dimensionId).join(", ")}',
    );
    return [];
  }

  /// Get all recommendations for an assessment
  Future<AssessmentRecommendations?> getAssessmentRecommendations(
    String assessmentId,
  ) async {
    final config = await loadConfig();
    return _getAssessmentByType(config, assessmentId);
  }

  /// Helper to get assessment by ID
  AssessmentRecommendations? _getAssessmentByType(
    AssessmentRecommendationsConfig config,
    String assessmentId,
  ) {
    print(
      '[ConfigService] _getAssessmentByType called with assessmentId=$assessmentId',
    );

    if (assessmentId.contains('singles') ||
        assessmentId.contains('single_never_married')) {
      print('[ConfigService] ✓ Returning singlesReadiness');
      return config.singlesReadiness;
    } else if (assessmentId.contains('marriage') &&
        !assessmentId.contains('remarriage')) {
      print('[ConfigService] ✓ Returning marriageHealthCheck');
      return config.marriageHealthCheck;
    } else if (assessmentId.contains('divorced') ||
        assessmentId.contains('remarriage_divorced')) {
      print('[ConfigService] ✓ Returning remarriageDivorced');
      return config.remarriageDivorced;
    } else if (assessmentId.contains('widowed') ||
        assessmentId.contains('remarriage_widowed')) {
      print('[ConfigService] ✓ Returning remarriageWidowed');
      return config.remarriageWidowed;
    }
    print('[ConfigService] ✗ No matching assessment type for $assessmentId');
    return null;
  }

  /// Return empty config structure
  AssessmentRecommendationsConfig _getEmptyConfig() {
    return const AssessmentRecommendationsConfig(
      documentTitle: '',
      version: '',
      lastUpdated: '',
      methodology: '',
      singlesReadiness: AssessmentRecommendations(
        assessmentId: '',
        audience: '',
        dimensionMappings: [],
      ),
      marriageHealthCheck: AssessmentRecommendations(
        assessmentId: '',
        audience: '',
        dimensionMappings: [],
      ),
      remarriageDivorced: AssessmentRecommendations(
        assessmentId: '',
        audience: '',
        dimensionMappings: [],
      ),
      remarriageWidowed: AssessmentRecommendations(
        assessmentId: '',
        audience: '',
        dimensionMappings: [],
      ),
    );
  }
}
