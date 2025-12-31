import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/config_loader_service.dart';
import '../models/assessment_model.dart';
import '../models/journey_model.dart';
import '../models/story_model.dart';
import '../constants/app_constants.dart';
import 'user_provider.dart';

/// Provider for ConfigLoaderService instance
final configLoaderProvider = Provider<ConfigLoaderService>((ref) {
  return ConfigLoaderService();
});

// ==================== ASSESSMENT CONFIGS ====================

/// Provider for Singles Readiness Assessment config
final singlesReadinessConfigProvider =
    FutureProvider<AssessmentConfig>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadSinglesReadinessConfig();
});

/// Provider for Remarriage Readiness Assessment config
final remarriageReadinessConfigProvider =
    FutureProvider<AssessmentConfig>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadRemarriageReadinessConfig();
});

/// Provider for Marriage Health Check Assessment config
final marriageHealthCheckConfigProvider =
    FutureProvider<AssessmentConfig>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadMarriageHealthCheckConfig();
});

/// Provider for assessment config based on user's relationship status
final userAssessmentConfigProvider =
    FutureProvider<AssessmentConfig?>((ref) async {
  final status = ref.watch(userRelationshipStatusProvider);
  if (status == null) return null;

  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.getAssessmentForStatus(status);
});

// ==================== JOURNEY CONFIGS ====================

/// Provider for Singles Journey Catalog
final singlesJourneyCatalogProvider =
    FutureProvider<JourneyCatalog>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  final catalog = await configLoader.loadSinglesJourneyCatalog();
  return catalog ?? const JourneyCatalog(version: "v1", audience: "singles", products: []);
});

/// Provider for Married Journey Catalog
final marriedJourneyCatalogProvider =
    FutureProvider<JourneyCatalog>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadMarriedJourneyCatalog();
});

/// Provider for journey catalog based on user's relationship status
final userJourneyCatalogProvider =
    FutureProvider<JourneyCatalog?>((ref) async {
  final status = ref.watch(userRelationshipStatusProvider);
  if (status == null) return null;

  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.getJourneyCatalogForStatus(status);
});

/// Provider for a specific journey product
final journeyProductProvider =
    FutureProvider.family<JourneyProduct?, String>((ref, productId) async {
  final status = ref.watch(userRelationshipStatusProvider);
  if (status == null) return null;

  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.getJourneyProduct(productId, status);
});

/// Provider for all journey products available to user
final userJourneyProductsProvider =
    FutureProvider<List<JourneyProduct>>((ref) async {
  final catalog = await ref.watch(userJourneyCatalogProvider.future);
  return catalog?.products ?? [];
});

// ==================== STORIES & POLLS CONFIGS ====================

/// Provider for Stories Catalog
final storiesCatalogProvider = FutureProvider<StoriesCatalog>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadStoriesCatalog();
});

/// Provider for Polls Catalog
final pollsCatalogProvider = FutureProvider<PollsCatalog>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadPollsCatalog();
});

/// Provider for current story of the week
final currentStoryOfWeekProvider = FutureProvider<Story?>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.getCurrentStoryOfWeek();
});

/// Provider for stories filtered by user's relationship status
final userStoriesProvider = FutureProvider<List<Story>>((ref) async {
  final status = ref.watch(userRelationshipStatusProvider);
  if (status == null) return [];

  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.getStoriesForAudience(status);
});

/// Provider for a specific story by ID
final storyByIdProvider =
    FutureProvider.family<Story?, String>((ref, storyId) async {
  final catalog = await ref.watch(storiesCatalogProvider.future);
  return catalog.findStory(storyId);
});

/// Provider for poll by story ID
final pollForStoryProvider =
    FutureProvider.family<Poll?, String>((ref, storyId) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.getPollForStory(storyId);
});

/// Provider for a specific poll by ID
final pollByIdProvider =
    FutureProvider.family<Poll?, String>((ref, pollId) async {
  final catalog = await ref.watch(pollsCatalogProvider.future);
  return catalog.findPoll(pollId);
});

// ==================== CONFIG PRELOADING ====================

/// Provider to preload all configs (call on app start)
final preloadConfigsProvider = FutureProvider<void>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  await configLoader.preloadAllConfigs();
});

/// Provider to clear config cache (for refresh)
final clearConfigCacheProvider = Provider<void Function()>((ref) {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.clearCache;
});
