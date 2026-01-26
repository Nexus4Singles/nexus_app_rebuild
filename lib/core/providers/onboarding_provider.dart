import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/onboarding_config_model.dart';
import 'config_provider.dart';

// ============================================================================
// ONBOARDING CONFIG PROVIDERS (for profile setup)
// ============================================================================

/// Provider for onboarding configuration
final onboardingConfigProvider = FutureProvider<OnboardingConfig>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadOnboardingConfig();
});

/// Provider for hobbies list
final hobbiesListProvider = FutureProvider<List<String>>((ref) async {
  final config = await ref.watch(onboardingConfigProvider.future);
  return config.hobbies;
});

/// Provider for professions list
final professionsListProvider = FutureProvider<List<String>>((ref) async {
  final config = await ref.watch(onboardingConfigProvider.future);
  return config.professions;
});

/// Provider for desired qualities list
final desireQualitiesListProvider = FutureProvider<List<String>>((ref) async {
  final config = await ref.watch(onboardingConfigProvider.future);
  return config.desireQualities;
});

/// Provider for Nigerian states list
final statesListProvider = FutureProvider<List<String>>((ref) async {
  final config = await ref.watch(onboardingConfigProvider.future);
  return config.states;
});

/// Provider for churches list
final churchesListProvider = FutureProvider<List<String>>((ref) async {
  final config = await ref.watch(onboardingConfigProvider.future);
  return config.churches;
});

/// Provider for educational levels list
final educationalLevelsListProvider = FutureProvider<List<String>>((ref) async {
  final config = await ref.watch(onboardingConfigProvider.future);
  return config.educationalLevels;
});

// ============================================================================
// SEARCH FILTERS PROVIDERS (for dating section Search/Explore page)
// ============================================================================

/// Provider for search filters configuration
final searchFiltersConfigProvider = FutureProvider<SearchFiltersConfig>((
  ref,
) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadSearchFiltersConfig();
});

/// Provider for country of residence filter options
final countryFiltersProvider = FutureProvider<List<String>>((ref) async {
  final config = await ref.watch(searchFiltersConfigProvider.future);
  return config.countryOfResidenceFilters;
});

/// Provider for relationship distance filter options
final distanceFiltersProvider = FutureProvider<List<String>>((ref) async {
  final config = await ref.watch(searchFiltersConfigProvider.future);
  return config.relationshipDistanceFilters;
});

/// Provider for marital status filter options
final maritalStatusFiltersProvider = FutureProvider<List<String>>((ref) async {
  final config = await ref.watch(searchFiltersConfigProvider.future);
  return config.maritalStatusFilters;
});

/// Provider for has kids filter options
final hasKidsFiltersProvider = FutureProvider<List<String>>((ref) async {
  final config = await ref.watch(searchFiltersConfigProvider.future);
  return config.hasKidsFilters;
});

/// Provider for genotype filter options
final genotypeFiltersProvider = FutureProvider<List<String>>((ref) async {
  final config = await ref.watch(searchFiltersConfigProvider.future);
  return config.genotypeFilters;
});
