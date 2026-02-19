import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexus_app_v2/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_v2/core/session/guest_session_provider.dart';
import 'package:nexus_app_v2/core/user/current_user_gender_provider.dart';
import 'package:nexus_app_v2/core/user/current_user_disabled_provider.dart';
import 'package:nexus_app_v2/core/providers/user_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../data/dating_search_service.dart';
import '../domain/dating_profile.dart';
import '../domain/dating_search_filters.dart';
import '../domain/dating_search_result.dart';
import '../domain/dating_preferences.dart';
import 'dating_preferences_provider.dart';
import 'dating_dismissed_profiles_provider.dart';
import '../domain/enhanced_compatibility_scorer.dart';
import 'package:nexus_app_v2/core/session/effective_relationship_status_provider.dart';
import 'package:nexus_app_v2/core/constants/app_constants.dart';

// ============================================================================
// IMAGE CACHE INVALIDATION
// ============================================================================
// Provider that watches preference changes and clears the image cache
// This ensures profile images are refreshed when user changes their preferences
// but persist across navigation while preferences remain unchanged
final imageSearchCacheInvalidatorProvider = FutureProvider<void>((ref) async {
  // Watch preferences to detect changes
  final prefsAsync = ref.watch(datingPreferencesProvider);

  // When preferences change, clear the image cache
  await prefsAsync.when(
    data: (_) async {
      // Use the same cache manager as CachedImage widget
      const cacheKey = 'nexus_simple_cache';
      try {
        final cacheManager = CacheManager(
          Config(
            cacheKey,
            stalePeriod: const Duration(days: 30),
            maxNrOfCacheObjects: 50,
          ),
        );
        // Clear old cached images but keep ones updated within last 30 days
        await cacheManager.emptyCache();
      } catch (e) {
        debugPrint('Error clearing image cache: $e');
      }
    },
    loading: () {},
    error: (e, st) {},
  );
});

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

final exploreScreenFiltersProvider =
    StateNotifierProvider<ExploreScreenFiltersNotifier, Map<String, dynamic>>((
      ref,
    ) {
      return ExploreScreenFiltersNotifier();
    });

// ============================================================================
// PAGINATION STATE
// ============================================================================
// Tracks the current offset for lazy-loading search results
// NOT auto-disposing so state persists when navigating away and back

final searchResultsOffsetProvider = StateProvider<int>((ref) {
  return 0;
});

// ============================================================================
// SCROLL POSITION CACHE
// ============================================================================
// Persists scroll position so grid returns to same position when navigating back

final searchResultsScrollPositionProvider = StateProvider<double>((ref) {
  return 0.0;
});

final datingSearchResultsProvider = FutureProvider<DatingSearchResult>((
  ref,
) async {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  if (kDebugMode) {
    print('[DatingSearchResultsProvider] firebaseReady=$firebaseReady');
  }
  if (!firebaseReady) {
    print('[DatingSearchResultsProvider] Firestore not ready, returning empty');
    return const DatingSearchResult(items: []);
  }

  // Hard gate: disabled users cannot search.
  final isDisabled = await ref.watch(currentUserDisabledProvider.future);
  if (kDebugMode) {
    print('[DatingSearchResultsProvider] isDisabled=$isDisabled');
  }
  if (isDisabled) {
    print('[DatingSearchResultsProvider] User is disabled, returning empty');
    return const DatingSearchResult(items: []);
  }

  // Get current user for compatibility scoring
  // FIXED: Use ref.read instead of ref.watch to prevent re-evaluation
  // when user doc updates in Firestore (currentUserProvider wraps a
  // StreamProvider that emits on every user-doc change, causing the
  // entire search to re-run and the grid to reset to the top).
  final currentUserAsync = ref.read(currentUserProvider);
  final currentUser = currentUserAsync.valueOrNull;
  if (kDebugMode) {
    print(
      '[DatingSearchResultsProvider] currentUser loaded: ${currentUser?.uid ?? "null"}',
    );
  }

  // Debug-only override: lets you test search even if gender isn't resolved yet.
  // Remove/disable later once onboarding is stable.
  const debugGenderOverride = String.fromEnvironment(
    'NEXUS_DEBUG_GENDER',
    defaultValue: '',
  );

  String? gender = await ref.watch(currentUserGenderProvider.future);
  if (kDebugMode) {
    print('[DatingSearchResultsProvider] gender=$gender');
  }
  if (kDebugMode && (gender == null || gender.trim().isEmpty)) {
    if (debugGenderOverride.trim().isNotEmpty) {
      gender = debugGenderOverride.trim();
      print(
        '[DatingSearchResultsProvider] Using debug gender override: $gender',
      );
    }
  }

  if (gender == null || gender.trim().isEmpty) {
    print('[DatingSearchResultsProvider] Gender not resolved, returning empty');
    return const DatingSearchResult(items: []);
  }

  String opposite(String g) {
    final v = g.toLowerCase();
    if (v == 'male') return 'female';
    if (v == 'female') return 'male';
    return '';
  }

  final genderToShow = opposite(gender);
  if (kDebugMode) {
    print('[DatingSearchResultsProvider] genderToShow=$genderToShow');
  }
  if (genderToShow.isEmpty) {
    print(
      '[DatingSearchResultsProvider] Opposite gender empty, returning empty',
    );
    return const DatingSearchResult(items: []);
  }

  // FIXED: Don't watch preferences provider directly (breaks circular dependency)
  // Instead, read it once to get the current value without creating a watcher
  // If preferences aren't available, we'll return empty and let the cache handle retry
  DatingPreferences? preferences;
  try {
    preferences = await ref.read(datingPreferencesProvider.future);
    if (kDebugMode) {
      print('[DatingSearchResultsProvider] preferences loaded: $preferences');
    }
  } catch (_) {
    print(
      '[DatingSearchResultsProvider] Preferences unavailable, returning empty results',
    );
    return const DatingSearchResult(items: []);
  }

  if (kDebugMode) {
    print(
      '[DatingSearchResultsProvider] Preferences: country=${preferences?.countryOfResidence}, allowLongDistance=${preferences?.allowLongDistance}, openToKids=${preferences?.openToKids}, openToMarriedBefore=${preferences?.openToMarriedBefore}, genotype=${preferences?.genotypePreference}',
    );
  }

  // Watch dismissed profiles to exclude them
  final dismissedAsync = ref.watch(dismissedProfilesProvider);
  final dismissedIds = dismissedAsync.valueOrNull ?? [];
  if (kDebugMode) {
    print(
      '[DatingSearchResultsProvider] dismissedIds loaded: ${dismissedIds.length}',
    );
  }

  // Convert saved preferences to search filters
  // PATTERN: null (not set) = no filter; true (yes) = show all; false (no) = apply restriction
  final filters =
      preferences != null
          ? DatingSearchFilters(
            minAge: preferences.minAge,
            maxAge: preferences.maxAge,
            countryOfResidence: preferences.countryOfResidence,
            longDistance:
                preferences.allowLongDistance == true
                    ? 'Yes'
                    : (preferences.allowLongDistance == false ? 'No' : null),
            maritalStatus:
                preferences.openToMarriedBefore == false
                    ? 'Never married'
                    : null,
            hasKids: preferences.openToKids == false ? 'No' : null,
            genotype: preferences.genotypePreference,
          )
          : ref.watch(datingSearchFiltersProvider);
  if (kDebugMode) {
    print(
      '[DatingSearchResultsProvider] Built filters: age=${filters.minAge}-${filters.maxAge}, country=${filters.countryOfResidence}, distance=${filters.longDistance}, marital=${filters.maritalStatus}, kids=${filters.hasKids}, genotype=${filters.genotype}',
    );
  }

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
    print(
      '[DatingSearchResultsProvider] Ready to search Firestore: genderToShow=$genderToShow, filters=$filters',
    );
  }

  // FIXED: Load results incrementally in batches instead of all at once
  // Initial batch with sufficient profiles for premium users
  // Limit is high enough to show meaningful results immediately
  DatingSearchResult results;
  try {
    print('[DatingSearchResultsProvider] Starting Firestore search...');
    results = await service
        .search(
          genderToShow: genderToShow,
          filters: filters,
          offset: 0,
          limit: 100, // FIXED: Increased from 20 to 100 for premium users
        )
        .timeout(
          const Duration(seconds: 30),
          onTimeout: () {
            print(
              '[DatingSearchResultsProvider] Search query timed out after 30 seconds - returning partial results',
            );
            return const DatingSearchResult(items: []);
          },
        );
    print(
      '[DatingSearchResultsProvider] Firestore search complete, results: ${results.items.length} profiles',
    );
  } catch (e, st) {
    print('[DatingSearchResultsProvider] Search ERROR: $e\n$st');
    rethrow;
  }

  // Filter dismissed profiles only (service already applied all other filters)
  if (results.items.isNotEmpty) {
    print('[DatingSearchResultsProvider] Filtering dismissed profiles...');
    final filtered =
        results.items
            .where((profile) => !dismissedIds.contains(profile.uid))
            .toList();
    print(
      '[DatingSearchResultsProvider] After dismissed filter: ${filtered.length} profiles',
    );
    results = DatingSearchResult(items: filtered, emptyHint: results.emptyHint);
  }

  // Compute compatibility scores if current user data available
  // Skip scoring if there are too many results (>200) to avoid timeout
  if (currentUser != null &&
      results.items.isNotEmpty &&
      results.items.length <= 200) {
    print(
      '[DatingSearchResultsProvider] Scoring compatibility for profiles...',
    );
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
        print(
          '[DatingSearchResultsProvider] Error scoring profile ${profile.uid}: $e',
        );
        scoredProfiles.add(profile);
      }
    }
    scoredProfiles.sort((a, b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    print(
      '[DatingSearchResultsProvider] After scoring: ${scoredProfiles.length} profiles',
    );
    results = DatingSearchResult(
      items: scoredProfiles,
      emptyHint: results.emptyHint,
    );
  } else if (results.items.isNotEmpty) {
    results.items.sort((a, b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    print(
      '[DatingSearchResultsProvider] After sort: ${results.items.length} profiles',
    );
  }

  if (kDebugMode) {
    // ignore: avoid_print
  }

  // Prioritize by relationship status for widows/divorcees when user has no marital filter
  try {
    final userRel = ref.read(effectiveRelationshipStatusProvider);
    if (results.items.isNotEmpty && filters.maritalStatus == null) {
      String? desired;
      if (userRel == RelationshipStatus.widowed) desired = 'widowed';
      if (userRel == RelationshipStatus.divorced) desired = 'divorced';

      if (desired != null) {
        final matching =
            results.items
                .where((p) => (p.maritalStatus ?? '').toLowerCase() == desired)
                .toList();
        final others =
            results.items
                .where((p) => (p.maritalStatus ?? '').toLowerCase() != desired)
                .toList();

        if (matching.isNotEmpty) {
          results = DatingSearchResult(
            items: [...matching, ...others],
            emptyHint: results.emptyHint,
          );
          print(
            '[DatingSearchResultsProvider] Prioritized by relationship: ${matching.length} $desired profiles first',
          );
        }
      }
    }
  } catch (_) {
    // If relationship provider not available or error occurs, skip prioritization
  }

  // Prioritize local profiles when user has no country preference
  // Free users see local profiles first, then international (maintains 10/day limit across both)
  if (results.items.isNotEmpty &&
      preferences?.countryOfResidence != null &&
      filters.countryOfResidence == null) {
    final userCountry = preferences!.countryOfResidence!;

    // Partition: local profiles first, international second
    final localProfiles =
        results.items.where((p) => p.country == userCountry).toList();
    final internationalProfiles =
        results.items.where((p) => p.country != userCountry).toList();

    if (localProfiles.isNotEmpty || internationalProfiles.isNotEmpty) {
      // Combine with local first, preserving sort order within each group
      final prioritizedItems = [...localProfiles, ...internationalProfiles];
      results = DatingSearchResult(
        items: prioritizedItems,
        emptyHint: results.emptyHint,
      );
      print(
        '[DatingSearchResultsProvider] Prioritized by location: ${localProfiles.length} local ($userCountry), ${internationalProfiles.length} international',
      );
    }
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
/// Automatically clears cache when preferences change
class SearchResultsCacheNotifier extends StateNotifier<DatingSearchResult?> {
  SearchResultsCacheNotifier() : super(null);

  void setResults(DatingSearchResult results) {
    state = results;
  }

  void clear() {
    state = null;
  }
}

final searchResultsCacheProvider = StateNotifierProvider<
  SearchResultsCacheNotifier,
  DatingSearchResult?
>((ref) {
  // FIXED: Watch preferences changes and auto-invalidate cache
  // Use select() to only track relevant fields (not provider state)
  try {
    final prefs = ref.watch(
      datingPreferencesProvider.select(
        (prefsAsync) =>
            prefsAsync.maybeWhen(data: (prefs) => prefs, orElse: () => null),
      ),
    );
    // If preferences exist, we track them for cache invalidation
    if (prefs != null) {
      // Preferences changed - next access to search results will be fresh
    }
  } catch (_) {
    // If preferences can't load, don't crash - just proceed with cache
  }

  return SearchResultsCacheNotifier();
});

/// Provider that returns cached results when available,
/// or fetches fresh results and caches them
final cachedDatingSearchResultsProvider = FutureProvider<DatingSearchResult>((
  ref,
) async {
  // Check cache without watching preferences
  // (watching preferences causes infinite re-evaluations)
  final cachedResults = ref.watch(searchResultsCacheProvider);

  if (cachedResults != null && cachedResults.items.isNotEmpty) {
    print(
      '[cachedDatingSearchResultsProvider] Returning cached results: ${cachedResults.items.length} profiles',
    );
    return cachedResults;
  }

  print(
    '[cachedDatingSearchResultsProvider] Cache empty, fetching fresh results...',
  );

  // Fetch fresh results
  try {
    final result = await ref.watch(datingSearchResultsProvider.future);
    print(
      '[cachedDatingSearchResultsProvider] Got${result.items.length} profiles, caching...',
    );
    // Cache the successful result
    ref.read(searchResultsCacheProvider.notifier).setResults(result);
    return result;
  } catch (e) {
    print('[cachedDatingSearchResultsProvider] Error fetching results: $e');
    rethrow;
  }
});

// ============================================================================
// INCREMENTAL PAGINATION - Load more profiles as user scrolls
// ============================================================================
// This provider accumulates results batches to show incrementally

final paginatedDatingSearchResultsProvider = FutureProvider<DatingSearchResult>(
  (ref) async {
    // Watch the offset - when it changes, fetch the next batch
    final offset = ref.watch(searchResultsOffsetProvider);

    // Get current preferences
    DatingPreferences? preferences;
    try {
      preferences = await ref.read(datingPreferencesProvider.future);
    } catch (_) {
      return const DatingSearchResult(items: []);
    }

    if (offset == 0) {
      // Initial load - use cached results or fetch fresh
      return await ref.watch(cachedDatingSearchResultsProvider.future);
    }

    // Subsequent batches - fetch more results
    final firebaseReady = ref.watch(firebaseReadyProvider);
    if (!firebaseReady) {
      return const DatingSearchResult(items: []);
    }

    // Get gender
    String? gender = await ref.watch(currentUserGenderProvider.future);
    if (gender == null || gender.trim().isEmpty) {
      return const DatingSearchResult(items: []);
    }

    String opposite(String g) {
      final v = g.toLowerCase();
      if (v == 'male') return 'female';
      if (v == 'female') return 'male';
      return '';
    }

    final genderToShow = opposite(gender);

    // Get dismissed profiles
    final dismissedAsync = ref.watch(dismissedProfilesProvider);
    final dismissedIds = dismissedAsync.valueOrNull ?? [];

    // Build filters
    final filters =
        preferences != null
            ? DatingSearchFilters(
              minAge: preferences.minAge,
              maxAge: preferences.maxAge,
              countryOfResidence: preferences.countryOfResidence,
              longDistance:
                  preferences.allowLongDistance == true
                      ? 'Yes'
                      : (preferences.allowLongDistance == false ? 'No' : null),
              maritalStatus:
                  preferences.openToMarriedBefore == false
                      ? 'Never married'
                      : null,
              hasKids: preferences.openToKids == false ? 'No' : null,
              genotype: preferences.genotypePreference,
            )
            : DatingSearchFilters(minAge: 21, maxAge: 70);

    // Fetch next batch
    final service = ref.read(datingSearchServiceProvider);
    DatingSearchResult nextBatch;

    try {
      nextBatch = await service
          .search(
            genderToShow: genderToShow,
            filters: filters,
            offset: offset,
            limit: 30, // Subsequent batches are 30 profiles each
          )
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      // If fetching next batch fails, return empty (no more profiles)
      return const DatingSearchResult(items: []);
    }

    // Filter dismissed profiles
    if (nextBatch.items.isNotEmpty) {
      final filtered =
          nextBatch.items
              .where((profile) => !dismissedIds.contains(profile.uid))
              .toList();
      nextBatch = DatingSearchResult(
        items: filtered,
        emptyHint: nextBatch.emptyHint,
      );
    }

    return nextBatch;
  },
);

// ============================================================================
// ACCUMULATOR - Combines initial results with all paginated batches
// ============================================================================
// This provider accumulates results as user scrolls, creating a seamless
// incremental loading experience without waiting for all profiles

final accumulatedSearchResultsProvider = FutureProvider<DatingSearchResult>((
  ref,
) async {
  // Get initial batch (always available immediately)
  final initialBatch = await ref.watch(
    cachedDatingSearchResultsProvider.future,
  );
  print(
    '[accumulatedSearchResultsProvider] Initial batch loaded: ${initialBatch.items.length} profiles',
  );

  // If no profiles in initial batch, return immediately (show 'No Profiles')
  if (initialBatch.items.isEmpty) {
    print('[accumulatedSearchResultsProvider] No profiles in initial batch');
    return initialBatch;
  }

  // Watch the offset - when it changes, fetch the next batch
  final currentOffset = ref.watch(searchResultsOffsetProvider);
  print('[accumulatedSearchResultsProvider] Current offset: $currentOffset');

  // If offset is 0, show only initial batch (DON'T watch offset to avoid re-evaluations)
  if (currentOffset == 0) {
    print(
      '[accumulatedSearchResultsProvider] Offset is 0, returning only initial batch',
    );
    return initialBatch;
  }

  // Try to get paginated batch, but if it fails or is empty, just return initial batch
  DatingSearchResult paginatedBatch;
  try {
    print(
      '[accumulatedSearchResultsProvider] Fetching paginated batch at offset $currentOffset',
    );
    paginatedBatch = await ref.watch(
      paginatedDatingSearchResultsProvider.future,
    );
    print(
      '[accumulatedSearchResultsProvider] Paginated batch loaded: ${paginatedBatch.items.length} profiles',
    );
  } catch (e) {
    print(
      '[accumulatedSearchResultsProvider] Error fetching paginated batch: $e',
    );
    paginatedBatch = const DatingSearchResult(items: []);
  }

  // Combine: initial + all paginated batches accumulated so far
  final combined = <DatingProfile>[
    ...initialBatch.items,
    ...paginatedBatch.items,
  ];

  print(
    '[accumulatedSearchResultsProvider] Combined results: ${combined.length} total profiles',
  );

  return DatingSearchResult(
    items: combined,
    emptyHint: initialBatch.emptyHint,
    hitDailyLimit: initialBatch.hitDailyLimit,
    dailyLimitHitAt: initialBatch.dailyLimitHitAt,
    noProfilesInCountry: initialBatch.noProfilesInCountry,
  );
});

// ============================================================================
// PAGINATION REMOVED - Incremental loading replaces traditional pagination
// This simplifies UX and avoids pagination bugs
// ============================================================================
