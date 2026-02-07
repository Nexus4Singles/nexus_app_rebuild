import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/core/session/guest_session_provider.dart';
import 'package:nexus_app_min_test/core/user/current_user_gender_provider.dart';
import 'package:nexus_app_min_test/core/user/current_user_disabled_provider.dart';
import 'package:nexus_app_min_test/core/providers/user_provider.dart';
import '../data/dating_search_service.dart';
import '../domain/dating_profile.dart';
import '../domain/dating_search_filters.dart';
import '../domain/dating_search_result.dart';
import '../domain/dating_preferences.dart';
import 'dating_preferences_provider.dart';
import 'dating_dismissed_profiles_provider.dart';
import '../domain/enhanced_compatibility_scorer.dart';

// Helper to extract compatibility data from UserModel
extension CompatibilityDataExtension on dynamic {
  String? getCompatibilityField(String key) {
    if (this == null) return null;
    if (this is Map<String, dynamic>) {
      final value = this[key];
      return value != null ? value.toString().trim() : null;
    }
    return null;
  }
}

final datingSearchFiltersProvider = StateProvider<DatingSearchFilters>((ref) {
  return const DatingSearchFilters(minAge: 21, maxAge: 70);
});

// ============================================================================
// EXPLORE/SEARCH SCREEN PERSISTENT FILTERS
// ============================================================================
// This provider persists the filter state on the explore/search screen
// so it doesn't reset when navigating away and back

class ExploreScreenFiltersNotifier extends StateNotifier<Map<String, dynamic>> {
  ExploreScreenFiltersNotifier()
      : super({
          'minAge': 21,
          'maxAge': 65,
          'countryOfResidence': null,
          'longDistance': null,
          'maritalStatus': null,
          'kids': null,
          'genotype': null,
        });

  void setAgeRange(int min, int max) {
    state = {...state, 'minAge': min, 'maxAge': max};
  }

  void setCountryOfResidence(String? value) {
    state = {...state, 'countryOfResidence': value};
  }

  void setLongDistance(String? value) {
    state = {...state, 'longDistance': value};
  }

  void setMaritalStatus(String? value) {
    state = {...state, 'maritalStatus': value};
  }

  void setKids(String? value) {
    state = {...state, 'kids': value};
  }

  void setGenotype(String? value) {
    state = {...state, 'genotype': value};
  }

  void clearAll() {
    state = {
      'minAge': 21,
      'maxAge': 65,
      'countryOfResidence': null,
      'longDistance': null,
      'maritalStatus': null,
      'kids': null,
      'genotype': null,
    };
  }
}

final exploreScreenFiltersProvider = StateNotifierProvider<
    ExploreScreenFiltersNotifier,
    Map<String, dynamic>>((ref) {
  return ExploreScreenFiltersNotifier();
});

// ============================================================================
// PAGINATION STATE
// ============================================================================
// Tracks the current offset for lazy-loading search results

final searchResultsOffsetProvider = StateProvider<int>((ref) {
  return 0;
});

final datingSearchResultsProvider = FutureProvider<DatingSearchResult>((
  ref,
) async {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  if (!firebaseReady) {
    if (kDebugMode) {
      // ignore: avoid_print
    }
    return const DatingSearchResult(items: []);
  }

  // Hard gate: disabled users cannot search.
  final isDisabled = await ref.watch(currentUserDisabledProvider.future);
  if (isDisabled) {
    if (kDebugMode) {
      // ignore: avoid_print
    }
    return const DatingSearchResult(items: []);
  }

  // Get current user for compatibility scoring
  final currentUserAsync = ref.watch(currentUserProvider);
  final currentUser = currentUserAsync.valueOrNull;

  // Debug-only override: lets you test search even if gender isn't resolved yet.
  // Remove/disable later once onboarding is stable.
  const debugGenderOverride = String.fromEnvironment(
    'NEXUS_DEBUG_GENDER',
    defaultValue: '',
  );

  String? gender = await ref.watch(currentUserGenderProvider.future);
  if (kDebugMode && (gender == null || gender.trim().isEmpty)) {
    if (debugGenderOverride.trim().isNotEmpty) {
      gender = debugGenderOverride.trim();
      // ignore: avoid_print
    }
  }

  if (gender == null || gender.trim().isEmpty) {
    if (kDebugMode) {
      // ignore: avoid_print
    }
    return const DatingSearchResult(items: []);
  }

  String opposite(String g) {
    final v = g.toLowerCase();
    if (v == 'male') return 'female';
    if (v == 'female') return 'male';
    return '';
  }

  final genderToShow = opposite(gender);
  if (genderToShow.isEmpty) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[DatingSearchResults] gender="$gender" -> opposite empty -> returning []',
      );
    }
    return const DatingSearchResult(items: []);
  }

  // Watch saved preferences - WAIT for them to load
  final preferencesAsync = ref.watch(datingPreferencesProvider);
  final preferences = preferencesAsync.when(
    data: (prefs) => prefs,
    loading: () => throw Exception('Preferences still loading'),
    error: (err, stack) => null,
  );

  if (kDebugMode) {
    // ignore: avoid_print
    print(
      '[DatingSearchResultsProvider] Preferences: '
      'country=${preferences?.countryOfResidence}, '
      'allowLongDistance=${preferences?.allowLongDistance}, '
      'openToKids=${preferences?.openToKids}, '
      'openToMarriedBefore=${preferences?.openToMarriedBefore}, '
      'genotype=${preferences?.genotypePreference}',
    );
  }

  // Watch dismissed profiles to exclude them
  final dismissedAsync = ref.watch(dismissedProfilesProvider);
  final dismissedIds = dismissedAsync.valueOrNull ?? [];

  // Convert saved preferences to search filters
  // PATTERN: null (not set) = no filter; true (yes) = show all; false (no) = apply restriction
  final filters =
      preferences != null
          ? DatingSearchFilters(
            minAge: preferences.minAge,
            maxAge: preferences.maxAge,
            countryOfResidence: preferences.countryOfResidence,
            // allowLongDistance:
            // Question: "Would you like to connect with people outside your location?"
            // - true (Yes) = show profiles willing to do long distance (outside location)
            // - false (No) = show only local profiles (Not willing to do long distance)
            // - null (No Preference) = don't filter by distance
            longDistance:
                preferences.allowLongDistance == true
                    ? 'Yes' // "Yes" = show profiles open to long distance (outside location)
                    : (preferences.allowLongDistance == false ? 'No' : null), // "No" = show local only
            // openToMarriedBefore: null/true = any marital status; false = never married only
            maritalStatus:
                preferences.openToMarriedBefore == false
                    ? 'Never married'
                    : null,
            // openToKids: null/true = any kid status; false = no kids only
            hasKids: preferences.openToKids == false ? 'No' : null,
            // genotypePreference: null = any genotype; value = specific genotype
            genotype: preferences.genotypePreference,
          )
          : ref.watch(datingSearchFiltersProvider);

  if (kDebugMode) {
    // ignore: avoid_print
    print(
      '[DatingSearchResultsProvider] Built filters: '
      'age=${filters.minAge}-${filters.maxAge}, '
      'country=${filters.countryOfResidence}, '
      'distance=${filters.longDistance}, '
      'marital=${filters.maritalStatus}, '
      'kids=${filters.hasKids}, '
      'genotype=${filters.genotype}',
    );
  }

  final service = ref.read(datingSearchServiceProvider);

  if (kDebugMode) {
    // ignore: avoid_print
    print(
      '[DatingSearchResults] searching genderToShow=$genderToShow, filters=$filters',
    );
  }

  // Search with saved preferences (will fall back to age-only if exhausted)
  // Load all matching profiles at once instead of paginating
  DatingSearchResult results;
  try {
    results = await service
        .search(
          genderToShow: genderToShow,
          filters: filters,
          limit: 10000, // Load all at once
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            if (kDebugMode) {
              // ignore: avoid_print
              print(
                '[DatingSearchResults] Search query timed out after 30 seconds - returning empty',
              );
            }
            // On timeout, return empty results to show no-profiles screen
            return const DatingSearchResult(items: []);
          },
        );
  } catch (e, st) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[DatingSearchResults] Search ERROR: $e\n$st',
      );
    }
    rethrow;
  }

  // Filter dismissed profiles only (service already applied all other filters)
  if (results.items.isNotEmpty) {
    final filtered =
        results.items
            .where((profile) => !dismissedIds.contains(profile.uid))
            .toList();

    results = DatingSearchResult(items: filtered, emptyHint: results.emptyHint);
  }

  // Compute compatibility scores if current user data available
  // Skip scoring if there are too many results (>200) to avoid timeout
  if (currentUser != null &&
      results.items.isNotEmpty &&
      results.items.length <= 200) {
    final scoredProfiles = <DatingProfile>[];

    // Extract current user compatibility data
    final userAMaritalStatus = currentUser.compatibility?.getCompatibilityField(
      'maritalStatus',
    );
    final userAHaveKids = currentUser.compatibility?.getCompatibilityField(
      'haveKids',
    );
    final userAGenotype = currentUser.compatibility?.getCompatibilityField(
      'genotype',
    );
    final userAPersonalityType = currentUser.compatibility
        ?.getCompatibilityField('personalityType');
    final userARegularIncome = currentUser.compatibility?.getCompatibilityField(
      'regularSourceOfIncome',
    );
    final userALongDistance = currentUser.compatibility?.getCompatibilityField(
      'longDistance',
    );
    final userABelieveInCohabiting = currentUser.compatibility
        ?.getCompatibilityField('believeInCohabiting');
    final userAShouldSpeakTongues = currentUser.compatibility
        ?.getCompatibilityField('shouldChristianSpeakInTongue');
    final userABeliefInTithing = currentUser.compatibility
        ?.getCompatibilityField('believeInTithing');

    for (final profile in results.items) {
      try {
        final score = EnhancedCompatibilityScorer.scoreMatch(
          // Current user fields
          userAMaritalStatus: userAMaritalStatus,
          userAHaveKids: userAHaveKids,
          userAGenotype: userAGenotype,
          userAPersonalityType: userAPersonalityType,
          userARegularIncome: userARegularIncome,
          userALongDistance: userALongDistance,
          userABeliefInCohabiting: userABelieveInCohabiting,
          userAShouldSpeakTongues: userAShouldSpeakTongues,
          userABeliefInTithing: userABeliefInTithing,
          userAHobbies: currentUser.hobbies,
          userADesiredQualities:
              currentUser.desiredQualities
                  ?.split(',')
                  .map((s) => s.trim())
                  .toList() ??
              [],
          // Match profile fields
          userBMaritalStatus: profile.maritalStatus,
          userBHaveKids: profile.haveKids,
          userBGenotype: profile.genotype,
          userBPersonalityType: profile.personalityType,
          userBRegularIncome: profile.regularSourceOfIncome,
          userBLongDistance: profile.longDistance,
          userBBeliefInCohabiting: profile.believeInCohabiting,
          userBShouldSpeakTongues: profile.shouldChristianSpeakInTongue,
          userBBeliefInTithing: profile.believeInTithing,
          userBHobbies: profile.hobbies,
          userBDesiredQualities:
              profile.desiredQualities
                  ?.split(',')
                  .map((s) => s.trim())
                  .toList() ??
              [],
        );

        // Create new profile with scores
        scoredProfiles.add(
          DatingProfile(
            uid: profile.uid,
            name: profile.name,
            age: profile.age,
            gender: profile.gender,
            city: profile.city,
            country: profile.country,
            educationLevel: profile.educationLevel,
            profession: profile.profession,
            photos: profile.photos,
            createdAt: profile.createdAt,
            verificationStatus: profile.verificationStatus,
            maritalStatus: profile.maritalStatus,
            haveKids: profile.haveKids,
            genotype: profile.genotype,
            regularSourceOfIncome: profile.regularSourceOfIncome,
            longDistance: profile.longDistance,
            personalityType: profile.personalityType,
            believeInCohabiting: profile.believeInCohabiting,
            shouldChristianSpeakInTongue: profile.shouldChristianSpeakInTongue,
            believeInTithing: profile.believeInTithing,
            hobbies: profile.hobbies,
            desiredQualities: profile.desiredQualities,
            compatibilityScore: score.score,
            scoreBreakdown: score.fieldScores,
            badges: score.badges,
          ),
        );
      } catch (e) {
        if (kDebugMode) {
          // ignore: avoid_print
          print(
            '[DatingSearchResults] Error scoring profile ${profile.uid}: $e',
          );
        }
        // If scoring fails, include profile without score
        scoredProfiles.add(profile);
      }
    }

    // Sort by profile creation date (newest first) - single sort for all results
    scoredProfiles.sort((a, b) {
      // Sort by date descending (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });

    results = DatingSearchResult(
      items: scoredProfiles,
      emptyHint: results.emptyHint,
    );
  } else if (results.items.isNotEmpty) {
    // If no scoring (too many profiles or missing user data), sort by creation date
    results.items.sort((a, b) {
      // Sort by date descending (newest first)
      return b.createdAt.compareTo(a.createdAt);
    });
  }

  if (kDebugMode) {
    // ignore: avoid_print
  }

  // Check if user is premium
  final isPremium = currentUser?.onPremium == true;

  // Apply daily limit for free users (10 profiles per day)
  // Check if there's a stored timestamp for when the limit was hit
  DateTime? limitHitAt;

  if (!isPremium && results.items.length >= 10) {
    // Check if user has a stored timestamp for daily limit
    // If no timestamp, this is the first time hitting the limit today
    limitHitAt = DateTime.now();

    // Limit to 10 profiles for free users
    results = DatingSearchResult(
      items: results.items.take(10).toList(),
      emptyHint: results.emptyHint,
      hitDailyLimit: true,
      totalAvailableCount: results.items.length,
      dailyLimitHitAt: limitHitAt,
    );
  }

  // Update lastRefreshedAt in Firestore if preferences exist and need refresh
  if (preferences != null && preferences.needsRefresh()) {
    try {
      await ref
          .read(datingPreferencesNotifierProvider.notifier)
          .updateLastRefresh();
    } catch (_) {
      // Silently fail - not critical
    }
  }

  return results;
});

/// Notifier to cache the last successful search results
class SearchResultsCacheNotifier extends StateNotifier<DatingSearchResult?> {
  SearchResultsCacheNotifier() : super(null);

  void setResults(DatingSearchResult results) {
    state = results;
  }

  void clear() {
    state = null;
  }
}

final searchResultsCacheProvider =
    StateNotifierProvider<SearchResultsCacheNotifier, DatingSearchResult?>(
        (ref) {
  return SearchResultsCacheNotifier();
});

/// Provider that returns cached results when available,
/// or fetches fresh results and caches them
final cachedDatingSearchResultsProvider =
    FutureProvider<DatingSearchResult>((ref) async {
  // Watch the cache
  final cachedResults = ref.watch(searchResultsCacheProvider);
  
  // If we have cached results, return them immediately without refetching
  if (cachedResults != null && cachedResults.items.isNotEmpty) {
    return cachedResults;
  }

  // Otherwise, fetch fresh results
  try {
    final result = await ref.watch(datingSearchResultsProvider.future);
    // Cache the successful result
    ref.read(searchResultsCacheProvider.notifier).setResults(result);
    return result;
  } catch (e) {
    rethrow;
  }
});

// ============================================================================
// PAGINATION REMOVED - All profiles now load at once
// This simplifies UX and avoids pagination bugs
// ============================================================================
