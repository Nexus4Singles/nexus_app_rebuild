import 'dart:convert';
import 'package:flutter/services.dart';
import '../models/assessment_model.dart';
import '../models/journey_model.dart';
import '../models/story_model.dart';
import '../models/onboarding_config_model.dart';
import '../constants/app_constants.dart';

/// Service for loading JSON configuration files from assets.
/// All content (assessments, journeys, stories, polls) is JSON-driven.
/// NO hardcoded content - everything comes from config files.
class ConfigLoaderService {
  // Singleton pattern
  static final ConfigLoaderService _instance = ConfigLoaderService._internal();
  factory ConfigLoaderService() => _instance;
  ConfigLoaderService._internal();

  // Cached configs
  AssessmentConfig? _singlesReadinessConfig;
  AssessmentConfig? _remarriageReadinessConfig;
  AssessmentConfig? _marriageHealthCheckConfig;
  
  // Journey catalogs by relationship status
  JourneyCatalog? _singlesNeverMarriedJourneyCatalog;
  JourneyCatalog? _divorcedWidowedJourneyCatalog;
  JourneyCatalog? _marriedJourneyCatalog;
  
  StoriesCatalog? _storiesCatalog;
  PollsCatalog? _pollsCatalog;
  
  // Onboarding config
  OnboardingConfig? _onboardingConfig;
  SearchFiltersConfig? _searchFiltersConfig;
  List<String>? _churchesList;

  /// Load a JSON file from assets and parse it
  Future<Map<String, dynamic>> _loadJsonAsset(String path) async {
    try {
      final jsonString = await rootBundle.loadString(path);
      return json.decode(jsonString) as Map<String, dynamic>;
    } catch (e) {
      throw ConfigLoadException('Failed to load config from $path: $e');
    }
  }

  // ==================== ASSESSMENT CONFIGS ====================

  /// Load Singles Readiness Assessment config
  Future<AssessmentConfig> loadSinglesReadinessConfig() async {
    if (_singlesReadinessConfig != null) return _singlesReadinessConfig!;
    
    final jsonData = await _loadJsonAsset(AppConfig.singlesReadinessPath);
    _singlesReadinessConfig = AssessmentConfig.fromJson(jsonData);
    return _singlesReadinessConfig!;
  }

  /// Load Remarriage Readiness Assessment config
  Future<AssessmentConfig> loadRemarriageReadinessConfig() async {
    if (_remarriageReadinessConfig != null) return _remarriageReadinessConfig!;
    
    final jsonData = await _loadJsonAsset(AppConfig.remarriageReadinessPath);
    _remarriageReadinessConfig = AssessmentConfig.fromJson(jsonData);
    return _remarriageReadinessConfig!;
  }

  /// Load Marriage Health Check Assessment config
  Future<AssessmentConfig> loadMarriageHealthCheckConfig() async {
    if (_marriageHealthCheckConfig != null) return _marriageHealthCheckConfig!;
    
    final jsonData = await _loadJsonAsset(AppConfig.marriageHealthCheckPath);
    _marriageHealthCheckConfig = AssessmentConfig.fromJson(jsonData);
    return _marriageHealthCheckConfig!;
  }

  /// Get the appropriate assessment config based on relationship status
  Future<AssessmentConfig> getAssessmentForStatus(RelationshipStatus status) async {
    switch (status) {
      case RelationshipStatus.singleNeverMarried:
        return loadSinglesReadinessConfig();
      case RelationshipStatus.divorcedWidowed:
        return loadRemarriageReadinessConfig();
      case RelationshipStatus.married:
        return loadMarriageHealthCheckConfig();
    }
  }

  /// Load assessment config by type
  Future<AssessmentConfig?> loadAssessment(AssessmentType type) async {
    switch (type) {
      case AssessmentType.singlesReadiness:
        return loadSinglesReadinessConfig();
      case AssessmentType.remarriageReadiness:
        return loadRemarriageReadinessConfig();
      case AssessmentType.marriageHealthCheck:
        return loadMarriageHealthCheckConfig();
    }
  }

  // ==================== JOURNEY CONFIGS ====================
  // Separate catalogs for each relationship status

  /// Load Singles (Never Married) Journey Catalog
  /// Falls back to singles_v1.json if the v2 file is empty
  Future<JourneyCatalog> loadSinglesNeverMarriedJourneyCatalog() async {
    if (_singlesNeverMarriedJourneyCatalog != null) return _singlesNeverMarriedJourneyCatalog!;
    
    try {
      final jsonData = await _loadJsonAsset(AppConfig.singlesNeverMarriedJourneyPath);
      final catalog = JourneyCatalog.fromJson(jsonData);
      
      // If v2 file is empty, fall back to v1
      if (catalog.products.isEmpty) {
        final fallbackData = await _loadJsonAsset(AppConfig.singlesV1FallbackPath);
        _singlesNeverMarriedJourneyCatalog = JourneyCatalog.fromJson(fallbackData);
      } else {
        _singlesNeverMarriedJourneyCatalog = catalog;
      }
    } catch (_) {
      // On any error, use the v1 fallback
      final fallbackData = await _loadJsonAsset(AppConfig.singlesV1FallbackPath);
      _singlesNeverMarriedJourneyCatalog = JourneyCatalog.fromJson(fallbackData);
    }
    
    return _singlesNeverMarriedJourneyCatalog!;
  }

  /// Load Divorced/Widowed Journey Catalog (includes parenting content)
  Future<JourneyCatalog> loadDivorcedWidowedJourneyCatalog() async {
    if (_divorcedWidowedJourneyCatalog != null) return _divorcedWidowedJourneyCatalog!;
    
    final jsonData = await _loadJsonAsset(AppConfig.divorcedWidowedJourneyPath);
    _divorcedWidowedJourneyCatalog = JourneyCatalog.fromJson(jsonData);
    return _divorcedWidowedJourneyCatalog!;
  }

  /// Load Married Journey Catalog (includes parenting content)
  Future<JourneyCatalog> loadMarriedJourneyCatalog() async {
    if (_marriedJourneyCatalog != null) return _marriedJourneyCatalog!;
    
    final jsonData = await _loadJsonAsset(AppConfig.marriedJourneyPath);
    _marriedJourneyCatalog = JourneyCatalog.fromJson(jsonData);
    return _marriedJourneyCatalog!;
  }

  /// Get the appropriate journey catalog based on relationship status
  /// Each status gets its own curated content:
  /// - Singles: Dating/readiness focused
  /// - Divorced/Widowed: Healing + co-parenting content
  /// - Married: Marriage enrichment + parenting content
  Future<JourneyCatalog> getJourneyCatalogForStatus(RelationshipStatus status) async {
    switch (status) {
      case RelationshipStatus.singleNeverMarried:
        return loadSinglesNeverMarriedJourneyCatalog();
      case RelationshipStatus.divorcedWidowed:
        return loadDivorcedWidowedJourneyCatalog();
      case RelationshipStatus.married:
        return loadMarriedJourneyCatalog();
    }
  }

  /// Get a specific journey product by ID
  Future<JourneyProduct?> getJourneyProduct(String productId, RelationshipStatus status) async {
    final catalog = await getJourneyCatalogForStatus(status);
    return catalog.findProduct(productId);
  }

  /// Load journey catalog by key (for backward compatibility)
  /// Prefer using getJourneyCatalogForStatus for proper relationship-based loading
  Future<JourneyCatalog?> loadJourneyCatalog(String key) async {
    switch (key.toLowerCase()) {
      case 'singles':
      case 'single_never_married':
        return loadSinglesNeverMarriedJourneyCatalog();
      case 'divorced':
      case 'divorced_widowed':
        return loadDivorcedWidowedJourneyCatalog();
      case 'married':
        return loadMarriedJourneyCatalog();
      default:
        return null;
    }
  }

  // ==================== STORIES & POLLS CONFIGS ====================

  /// Load Stories Catalog
  Future<StoriesCatalog> loadStoriesCatalog() async {
    if (_storiesCatalog != null) return _storiesCatalog!;
    
    final jsonData = await _loadJsonAsset(AppConfig.storiesPath);
    _storiesCatalog = StoriesCatalog.fromJson(jsonData);
    return _storiesCatalog!;
  }

  /// Load Polls Catalog
  Future<PollsCatalog> loadPollsCatalog() async {
    if (_pollsCatalog != null) return _pollsCatalog!;
    
    final jsonData = await _loadJsonAsset(AppConfig.pollsPath);
    _pollsCatalog = PollsCatalog.fromJson(jsonData);
    return _pollsCatalog!;
  }

  /// Get stories filtered by audience
  Future<List<Story>> getStoriesForAudience(RelationshipStatus status) async {
    final catalog = await loadStoriesCatalog();
    final audienceKey = _statusToAudienceKey(status);
    return catalog.getStoriesForAudience(audienceKey);
  }

  /// Get current story of the week
  Future<Story?> getCurrentStoryOfWeek() async {
    final catalog = await loadStoriesCatalog();
    return catalog.currentStoryOfWeek;
  }

  /// Get poll for a specific story
  Future<Poll?> getPollForStory(String storyId) async {
    final pollsCatalog = await loadPollsCatalog();
    return pollsCatalog.findPollForStory(storyId);
  }

  // ==================== ONBOARDING CONFIG ====================

  /// Load onboarding configuration (hobbies, professions, states, etc.)
  Future<OnboardingConfig> loadOnboardingConfig() async {
    if (_onboardingConfig != null) return _onboardingConfig!;
    
    final jsonData = await _loadJsonAsset(AppConfig.onboardingConfigPath);
    _onboardingConfig = OnboardingConfig.fromJson(jsonData);
    return _onboardingConfig!;
  }

  /// Get hobbies list
  Future<List<String>> getHobbies() async {
    final config = await loadOnboardingConfig();
    return config.hobbies;
  }

  /// Get professions list
  Future<List<String>> getProfessions() async {
    final config = await loadOnboardingConfig();
    return config.professions;
  }

  /// Get desired qualities list
  Future<List<String>> getDesireQualities() async {
    final config = await loadOnboardingConfig();
    return config.desireQualities;
  }

  /// Get Nigerian states list
  Future<List<String>> getStates() async {
    final config = await loadOnboardingConfig();
    return config.states;
  }

  /// Get churches list (loaded from separate file due to corruption in main file)
  Future<List<String>> getChurches() async {
    if (_churchesList != null) return _churchesList!;
    
    try {
      final jsonData = await _loadJsonAsset(AppConfig.churchesConfigPath);
      final churches = (jsonData['churches'] as List<dynamic>?)
          ?.whereType<String>()
          .where((s) => s.isNotEmpty)
          .toList() ?? [];
      
      _churchesList = churches.isNotEmpty ? churches : OnboardingConfig.defaultChurches;
    } catch (_) {
      _churchesList = OnboardingConfig.defaultChurches;
    }
    
    return _churchesList!;
  }

  /// Get educational levels list
  Future<List<String>> getEducationalLevels() async {
    final config = await loadOnboardingConfig();
    return config.educationalLevels;
  }

  // ==================== SEARCH FILTERS CONFIG ====================
  // For dating section Search/Explore page filters (singles only)

  /// Load search filters configuration
  Future<SearchFiltersConfig> loadSearchFiltersConfig() async {
    if (_searchFiltersConfig != null) return _searchFiltersConfig!;
    
    final jsonData = await _loadJsonAsset(AppConfig.onboardingConfigPath);
    _searchFiltersConfig = SearchFiltersConfig.fromJson(jsonData);
    return _searchFiltersConfig!;
  }

  // ==================== HELPERS ====================

  /// Convert RelationshipStatus to audience key string
  String _statusToAudienceKey(RelationshipStatus status) {
    switch (status) {
      case RelationshipStatus.singleNeverMarried:
        return 'single_never_married';
      case RelationshipStatus.divorcedWidowed:
        return 'divorced_widowed';
      case RelationshipStatus.married:
        return 'married';
    }
  }

  /// Clear all cached configs (useful for testing or refresh)
  void clearCache() {
    _singlesReadinessConfig = null;
    _remarriageReadinessConfig = null;
    _marriageHealthCheckConfig = null;
    _singlesNeverMarriedJourneyCatalog = null;
    _divorcedWidowedJourneyCatalog = null;
    _marriedJourneyCatalog = null;
    _storiesCatalog = null;
    _pollsCatalog = null;
    _onboardingConfig = null;
    _searchFiltersConfig = null;
    _churchesList = null;
  }

  /// Preload all configs for faster access
  Future<void> preloadAllConfigs() async {
    await Future.wait([
      loadSinglesReadinessConfig(),
      loadRemarriageReadinessConfig(),
      loadMarriageHealthCheckConfig(),
      loadSinglesNeverMarriedJourneyCatalog(),
      loadDivorcedWidowedJourneyCatalog(),
      loadMarriedJourneyCatalog(),
      loadStoriesCatalog(),
      loadPollsCatalog(),
    ]);
  }
}

/// Exception thrown when config loading fails
class ConfigLoadException implements Exception {
  final String message;
  ConfigLoadException(this.message);

  @override
  String toString() => 'ConfigLoadException: $message';
}
