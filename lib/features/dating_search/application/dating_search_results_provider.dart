import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexus_app_v2/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_v2/core/session/guest_session_provider.dart';
import 'package:nexus_app_v2/core/user/current_user_gender_provider.dart';
import 'package:nexus_app_v2/core/user/current_user_disabled_provider.dart';
import 'package:nexus_app_v2/core/user/is_admin_provider.dart';
import 'package:nexus_app_v2/core/providers/user_provider.dart';
import 'package:flutter_cache_manager/flutter_cache_manager.dart';
import '../data/dating_search_service.dart';
import '../domain/dating_profile.dart';
import '../domain/dating_search_filters.dart';
import '../domain/dating_search_result.dart';
import '../domain/dating_preferences.dart';
import 'dating_preferences_provider.dart';
import 'dating_dismissed_profiles_provider.dart';
import 'daily_limit_provider.dart';
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

/// Provider for dating search results
///
/// ⚠️ KEPT AS FutureProvider (not converted to Stream)
/// Reason: This is a one-time query that doesn't need constant re-emission
///
/// Real-time reactivity comes from:
/// - currentUserGenderProvider (now StreamProvider)
/// - datingPreferencesProvider (now StreamProvider)
/// - dismissedProfilesProvider (now StreamProvider)
///
/// When ANY of these StreamProviders update, Riverpod automatically invalidates
/// this provider, causing it to re-run and fetch fresh results.
final datingSearchResultsProvider = FutureProvider<DatingSearchResult>((
  ref,
) async {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  if (kDebugMode) {
    // DEBUG: firebaseReady status skipped to reduce log noise
  }
  if (!firebaseReady) {
    // DEBUG: Firestore not ready - skipped to reduce log noise
    return const DatingSearchResult(items: []);
  }

  // Hard gate: disabled users cannot search.
  final isDisabledAsync = ref.watch(currentUserDisabledProvider);
  if (!isDisabledAsync.hasValue) {
    return const DatingSearchResult(items: []);
  }
  final isDisabled = isDisabledAsync.valueOrNull ?? false;
  if (kDebugMode) {
    // DEBUG: isDisabled status skipped to reduce log noise
  }
  if (isDisabled) {
    // DEBUG: User disabled - skipped to reduce log noise
    return const DatingSearchResult(items: []);
  }

  // Admin bypass: Admins can search without preferences set
  // This allows admins to view all profiles for moderation/support purposes
  final isAdminAsync = ref.watch(isAdminProvider);
  final isAdmin = isAdminAsync.maybeWhen(
    data: (admin) => admin,
    orElse: () => false,
  );

  if (isAdmin) {
    // DEBUG: Admin user bypassing preferences - skipped to reduce log noise
    // For admins, fetch all available profiles without preferences filter
    // This is handled separately in the admin profile fetching logic
  }

  // Get current user for compatibility scoring
  // Use ref.read to prevent re-evaluation on every user doc change
  final currentUserAsync = ref.read(currentUserProvider);
  final currentUser = currentUserAsync.valueOrNull;
  if (kDebugMode) {
    // DEBUG: currentUser loaded - skipped to reduce log noise
  }

  const debugGenderOverride = String.fromEnvironment(
    'NEXUS_DEBUG_GENDER',
    defaultValue: '',
  );

  // Wait for gender to resolve to avoid transient empty-state flashes.
  String? gender;
  try {
    gender = await ref.watch(currentUserGenderProvider.future);
  } catch (_) {
    return const DatingSearchResult(items: []);
  }
  if (kDebugMode) {
    // DEBUG: gender resolved - skipped to reduce log noise
  }
  if (kDebugMode && (gender == null || gender.trim().isEmpty)) {
    if (debugGenderOverride.trim().isNotEmpty) {
      gender = debugGenderOverride.trim();
      // DEBUG: gender debug override - skipped to reduce log noise
    }
  }

  if (gender == null || gender.trim().isEmpty) {
    // DEBUG: Gender not resolved - skipped to reduce log noise
    return const DatingSearchResult(items: []);
  }

  String opposite(String g) {
    final v = g.toLowerCase();
    if (v == 'male') return 'female';
    if (v == 'female') return 'male';
    return '';
  }

  final genderToShow = opposite(gender);
  // DEBUG: Critical gender check - skipped to reduce log noise
  if (kDebugMode) {
    // DEBUG: genderToShow resolved - skipped to reduce log noise
  }
  if (genderToShow.isEmpty) {
    // DEBUG: Critical opposite gender check - skipped to reduce log noise
    return const DatingSearchResult(items: []);
  }

  // Wait for preferences to resolve to avoid transient empty-state flashes.
  DatingPreferences? preferences;
  try {
    preferences = await ref.watch(datingPreferencesProvider.future);
  } catch (_) {
    return const DatingSearchResult(items: []);
  }
  if (kDebugMode) {
    // DEBUG: Preferences loaded - skipped to reduce log noise
  }

  // Check if preferences are available
  // Admins are allowed to search without preferences (they bypass this check)
  // but regular users must have preferences saved
  late final DatingPreferences resolvedPreferences;

  if (preferences == null) {
    if (!isAdmin) {
      // DEBUG: Preferences unavailable for non-admin - skipped to reduce log noise
      return const DatingSearchResult(items: []);
    }
    // DEBUG: Admin user with no preferences - skipped to reduce log noise
    // Create default preferences for admins to see a broad range of profiles
    resolvedPreferences = const DatingPreferences(
      minAge: 18,
      maxAge: 80,
      countryOfResidence: 'Any',
      allowLongDistance: true,
      openToKids: true,
      openToMarriedBefore: true,
      genotypePreference: null,
    );
  } else {
    resolvedPreferences = preferences;
  }

  if (kDebugMode) {
    // DEBUG: Preferences display - skipped to reduce log noise
  }

  // Wait for dismissed profiles to resolve to avoid transient empty-state flashes.
  List<String> dismissedIds;
  try {
    dismissedIds = await ref.watch(dismissedProfilesProvider.future);
  } catch (_) {
    dismissedIds = const [];
  }
  if (kDebugMode) {
    // DEBUG: Dismissed profiles loaded - skipped to reduce log noise
  }

  // Convert saved preferences to search filters
  // PATTERN: null (not set) = no filter; true (yes) = show all; false (no) = apply restriction
  final filters = DatingSearchFilters(
    minAge: resolvedPreferences.minAge,
    maxAge: resolvedPreferences.maxAge,
    countryOfResidence: resolvedPreferences.countryOfResidence,
    longDistance:
        resolvedPreferences.allowLongDistance == true
            ? 'Yes'
            : (resolvedPreferences.allowLongDistance == false ? 'No' : null),
    maritalStatus:
        resolvedPreferences.openToMarriedBefore == false
            ? 'Never married'
            : null,
    hasKids: resolvedPreferences.openToKids == false ? 'No' : null,
    genotype: resolvedPreferences.genotypePreference,
  );
  if (kDebugMode) {
    // DEBUG: Filters built - skipped to reduce log noise
  }

  // DEBUG: Built filters - skipped to reduce log noise

  final service = ref.read(datingSearchServiceProvider);
  if (kDebugMode) {
    // DEBUG: Ready to search - skipped to reduce log noise
  }

  // ============================================================================
  // SMART PAGINATION CAPPING WITH INACTIVE PROFILE FILTERING
  // ============================================================================
  // Strategy: As user base grows, we progressively cut off old inactive v1 profiles
  // - This respects the recent-to-old sorting already in place
  // - Old legacy profiles naturally push to back of results
  // - When pagination limit is hit, old inactive profiles are never shown
  // - Result: Reduced Firestore costs as we grow

  final now = DateTime.now();
  final ninetyDaysAgo = now.subtract(const Duration(days: 90));

  // FIXED: Load results incrementally in batches instead of all at once
  // Initial batch with sufficient profiles for premium users
  // Limit is high enough to show meaningful results immediately
  DatingSearchResult results;
  try {
    // DEBUG: Starting Firestore search - skipped to reduce log noise
    results = await service
        .search(
          genderToShow: genderToShow,
          filters: filters,
          offset: 0,
          limit: 100, // Initial richer payload
        )
        .timeout(const Duration(seconds: 30));
    // DEBUG: Firestore search complete - skipped to reduce log noise
    if (results.items.isNotEmpty) {
      // DEBUG: Sample genders - skipped to reduce log noise
    }
  } on TimeoutException {
    // World-class behavior: do not surface timeout errors.
    // 1) Retry once with a smaller payload for faster response.
    try {
      results = await service
          .search(
            genderToShow: genderToShow,
            filters: filters,
            offset: 0,
            limit: 40,
          )
          .timeout(const Duration(seconds: 12));
    } on TimeoutException {
      // 2) If still slow, fall back to last good cached results.
      final stale = ref.read(searchResultsCacheProvider);
      if (stale != null && stale.items.isNotEmpty) {
        return stale;
      }
      // 3) No stale data available: return neutral empty state (non-error)
      // so UI can keep graceful loading/refresh semantics.
      return const DatingSearchResult(items: []);
    }
  } catch (e) {
    // Non-timeout errors should still bubble to error UI.
    rethrow;
  }

  // Filter dismissed profiles only (service already applied all other filters)
  if (results.items.isNotEmpty) {
    // DEBUG: Filtering dismissed profiles - skipped to reduce log noise
    final filtered =
        results.items
            .where((profile) => !dismissedIds.contains(profile.uid))
            .toList();
    // DEBUG: After dismissed filter - skipped to reduce log noise
    results = DatingSearchResult(items: filtered, emptyHint: results.emptyHint);
  }

  // Compute compatibility scores if current user data available
  // Skip scoring if there are too many results (>200) to avoid timeout
  if (currentUser != null &&
      results.items.isNotEmpty &&
      results.items.length <= 200) {
    // DEBUG: Scoring compatibility for profiles - skipped to reduce log noise
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
        // DEBUG: Error scoring profile - skipped to reduce log noise
        scoredProfiles.add(profile);
      }
    }
    scoredProfiles.sort((a, b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    // DEBUG: After scoring - skipped to reduce log noise
    results = DatingSearchResult(
      items: scoredProfiles,
      emptyHint: results.emptyHint,
    );
  } else if (results.items.isNotEmpty) {
    results.items.sort((a, b) {
      return b.createdAt.compareTo(a.createdAt);
    });
    // DEBUG: After sort - skipped to reduce log noise
  }

  // ============================================================================
  // APPLY PAGINATION CAPPING & INACTIVE PROFILE FILTERING
  // ============================================================================
  // After all sorting and prioritization, apply pagination limits
  // This naturally cuts off old inactive v1 profiles as they're at the end

  // Determine subscription tier for pagination cap
  // Subscribed: 100 pages (2000 profiles), Free: 25 pages (500 profiles)
  // (Will use existing isPremium variable from below, for now use isAdmin)
  final maxPages = isAdmin ? 500 : (currentUser?.onPremium == true ? 100 : 25);

  // Count active (recent) vs inactive (old) profiles
  int activeCount = 0;
  int inactiveCount = 0;
  for (final profile in results.items) {
    if (profile.createdAt.isAfter(ninetyDaysAgo)) {
      activeCount++;
    } else {
      inactiveCount++;
    }
  }

  // Log inactive profile strategy
  if (kDebugMode && inactiveCount > 0) {
    print(
      '[DatingSearchResults] 📊 Profile freshness: $activeCount active (< 90 days), $inactiveCount inactive (> 90 days)',
    );
    print(
      '[DatingSearchResults] 🔒 Pagination capped at $maxPages pages (${maxPages * 20} profiles max)',
    );
  }

  // Return results with pagination cap applied at search grid level
  results = DatingSearchResult(
    items: results.items,
    emptyHint: results.emptyHint,
    maxPaginationPages: maxPages, // Pass to UI layer
  );

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
            maxPaginationPages: results.maxPaginationPages,
          );
          // DEBUG: print skipped - reducing log noise
        }
      }
    }
  } catch (_) {
    // If relationship provider not available or error occurs, skip prioritization
  }

  // Prioritize local profiles when user has no country preference
  // Free users see local profiles first, then international (maintains 10/day limit across both)
  if (results.items.isNotEmpty &&
      resolvedPreferences.countryOfResidence != null &&
      filters.countryOfResidence == null) {
    final userCountry = resolvedPreferences.countryOfResidence!;

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
        maxPaginationPages: results.maxPaginationPages,
      );
      // DEBUG: print skipped - reducing log noise
    }
  }

  // ============================================================================
  // DAILY LIMIT FOR FREE USERS (Premium users are not affected)
  // ============================================================================
  // Premium users: unlimited access to all profiles matching their filters
  // Free users: 10 profiles/day, persisted across app restarts

  final isPremium = currentUser?.onPremium == true;

  if (!isPremium && results.items.isNotEmpty) {
    // ============================================================================
    // FREE USER: 10 PROFILES/DAY LIMIT
    // ============================================================================
    // Logic:
    // - First search today: Show up to 10 NEW profiles, save their UIDs
    // - Later searches today: Show PREVIOUS 10 profiles they already viewed
    // - Premium users: Unlimited (not affected)
    // ============================================================================

    final uid = FirebaseAuth.instance.currentUser?.uid;
    final manager = ref.read(dailyLimitManagerProvider);

    if (uid != null) {
      try {
        // Get persisted daily limit timestamp (if it exists and 24h hasn't passed)
        final persistedLimitHit = await manager.getDailyLimitFirstHit(uid);

        // Get already-shown profile IDs from today
        var shownIds = await manager.getShownProfileIds(uid);

        // DEBUG: Free user logic - skipped to reduce log noise

        // SAFEGUARD: If reset happened (persistedLimitHit=null) but shownIds has entries,
        // it means old data persists. Clear it now.
        if (persistedLimitHit == null && shownIds.isNotEmpty) {
          // DEBUG: Reset detected - skipped to reduce log noise
          await manager.setShownProfileIds(uid, []);
          shownIds = [];
        }

        // Split results: profiles they've seen vs new profiles
        final profilesAlreadySeen =
            results.items.where((p) => shownIds.contains(p.uid)).toList();
        final newProfiles =
            results.items.where((p) => !shownIds.contains(p.uid)).toList();

        // DEBUG: Results breakdown - skipped to reduce log noise

        // Case 1: They've already been shown 10+ profiles today
        if (shownIds.length >= 10) {
          // DEBUG: Case 1 - skipped to reduce log noise
          results = DatingSearchResult(
            items: profilesAlreadySeen,
            emptyHint:
                'You\'ve completed your 10 profiles for today! 🎉 Swipe again or check back tomorrow.',
            hitDailyLimit: true,
            totalAvailableCount: results.items.length,
            dailyLimitHitAt: persistedLimitHit,
            allAvailableShownToday: true,
            shownProfileIds: shownIds,
            maxPaginationPages: results.maxPaginationPages,
          );
        }
        // Case 2: First day, haven't shown any profiles yet
        else if (shownIds.isEmpty && newProfiles.isNotEmpty) {
          // DEBUG: Case 2 - skipped to reduce log noise
          final profilesToShow = newProfiles.take(10).toList();
          final allIds = [...shownIds, ...profilesToShow.map((p) => p.uid)];

          // Set timestamp when limit is first triggered
          // DEBUG: Set daily limit timestamp - skipped to reduce log noise
          await manager.setDailyLimitFirstHit(uid);

          // Save the profile UIDs
          await manager.setShownProfileIds(uid, allIds);

          results = DatingSearchResult(
            items: profilesToShow,
            emptyHint: results.emptyHint,
            hitDailyLimit: allIds.length >= 10,
            totalAvailableCount: results.items.length,
            dailyLimitHitAt: persistedLimitHit ?? DateTime.now(),
            allAvailableShownToday: profilesToShow.length < 10,
            shownProfileIds: allIds,
            maxPaginationPages: results.maxPaginationPages,
          );
        }
        // Case 3: Mid-session, have some shown but < 10
        else if (shownIds.isNotEmpty && shownIds.length < 10) {
          // DEBUG: Case 3 - skipped to reduce log noise

          final remaining = 10 - shownIds.length;
          final profilesToShow = newProfiles.take(remaining).toList();
          final allIds = [...shownIds, ...profilesToShow.map((p) => p.uid)];

          // DEBUG: Set timestamp for case 3 - skipped to reduce log noise
          if (allIds.length >= 10 && persistedLimitHit == null) {
            await manager.setDailyLimitFirstHit(uid);
          }

          // Save updated profile UIDs
          await manager.setShownProfileIds(uid, allIds);

          results = DatingSearchResult(
            items: profilesToShow,
            emptyHint: results.emptyHint,
            hitDailyLimit: allIds.length >= 10,
            totalAvailableCount: results.items.length,
            dailyLimitHitAt: persistedLimitHit ?? DateTime.now(),
            allAvailableShownToday: allIds.length >= 10,
            shownProfileIds: allIds,
            maxPaginationPages: results.maxPaginationPages,
          );
        }
        // Case 4: No new profiles available (all Firestore results already shown)
        else if (newProfiles.isEmpty) {
          // DEBUG: Case 4 - skipped to reduce log noise
          results = DatingSearchResult(
            items: profilesAlreadySeen,
            emptyHint:
                profilesAlreadySeen.isNotEmpty
                    ? 'No more new profiles today. Re-swipe or come back tomorrow!'
                    : 'All available profiles for your preferences have been shown today.',
            hitDailyLimit: shownIds.length >= 10,
            totalAvailableCount: results.items.length,
            dailyLimitHitAt: persistedLimitHit,
            allAvailableShownToday: true,
            shownProfileIds: shownIds,
            maxPaginationPages: results.maxPaginationPages,
          );
        }
        // Fallback: shouldn't reach here but handle gracefully
        else {
          // DEBUG: Fallback state - skipped to reduce log noise
          results = DatingSearchResult(
            items: profilesAlreadySeen,
            emptyHint: 'Showing your previous matches.',
            hitDailyLimit: shownIds.length >= 10,
            totalAvailableCount: results.items.length,
            dailyLimitHitAt: persistedLimitHit,
            allAvailableShownToday: true,
            shownProfileIds: shownIds,
            maxPaginationPages: results.maxPaginationPages,
          );
        }
      } catch (e) {
        // DEBUG: Error applying daily limit - skipped to reduce log noise
        // Fallback: show all profiles if daily limit fails
        // (don't break the search due to persistence errors)
      }
    }
  }
  // Premium users: no daily limit applied, show all filtered profiles as-is

  // Update lastRefreshedAt in Firestore if preferences exist and need refresh
  if (resolvedPreferences.needsRefresh()) {
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
    // DEBUG: print skipped - reducing log noise
    return cachedResults;
  }

  // DEBUG: print skipped - reducing log noise

  // Fetch fresh results
  try {
    final result = await ref.watch(datingSearchResultsProvider.future);
    // DEBUG: print skipped - reducing log noise
    // Cache the successful result
    ref.read(searchResultsCacheProvider.notifier).setResults(result);
    return result;
  } catch (e) {
    // DISABLED: print('[cachedDatingSearchResultsProvider] Error fetching results: $e');
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
    } on TimeoutException {
      try {
        nextBatch = await service
            .search(
              genderToShow: genderToShow,
              filters: filters,
              offset: offset,
              limit: 20,
            )
            .timeout(const Duration(seconds: 10));
      } catch (_) {
        return const DatingSearchResult(items: []);
      }
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
//
// CRITICAL FIX: Don't return early for empty results during the loading phase.
// The base provider (datingSearchResultsProvider) needs time to complete all
// its operations (daily limit checks, compatibility scoring, etc.) before we
// decide if results are truly empty. Returning early causes the UI to flicker
// between empty state and loading state.

final accumulatedSearchResultsProvider = FutureProvider<DatingSearchResult>((
  ref,
) async {
  // Get initial batch - ALWAYS wait for it to fully load
  // This ensures datingSearchResultsProvider has completed ALL operations
  final initialBatch = await ref.watch(
    cachedDatingSearchResultsProvider.future,
  );
  // DEBUG: print skipped - reducing log noise

  // Watch the offset - when it changes, fetch the next batch
  final currentOffset = ref.watch(searchResultsOffsetProvider);
  // DISABLED: print('[accumulatedSearchResultsProvider] Current offset: $currentOffset');

  // If offset is 0, return only initial batch (should have completed all ops by now)
  if (currentOffset == 0) {
    // DEBUG: print skipped - reducing log noise
    // FIXED: Return initialBatch as-is, whether empty or not
    // If it's truly empty, that's a legitimate result after all operations complete
    return initialBatch;
  }

  // Try to get paginated batch, but if it fails or is empty, just return initial batch
  DatingSearchResult paginatedBatch;
  try {
    // DEBUG: print skipped - reducing log noise
    paginatedBatch = await ref.watch(
      paginatedDatingSearchResultsProvider.future,
    );
    // DEBUG: print skipped - reducing log noise
  } catch (e) {
    // DEBUG: print skipped - reducing log noise
    paginatedBatch = const DatingSearchResult(items: []);
  }

  // Combine: initial + all paginated batches accumulated so far
  final combined = <DatingProfile>[
    ...initialBatch.items,
    ...paginatedBatch.items,
  ];

  // DEBUG: print skipped - reducing log noise

  return DatingSearchResult(
    items: combined,
    emptyHint: initialBatch.emptyHint,
    hitDailyLimit: initialBatch.hitDailyLimit,
    dailyLimitHitAt: initialBatch.dailyLimitHitAt,
    noProfilesInCountry: initialBatch.noProfilesInCountry,
    maxPaginationPages: initialBatch.maxPaginationPages,
  );
});

// ============================================================================
// PAGINATION REMOVED - Incremental loading replaces traditional pagination
// This simplifies UX and avoids pagination bugs
// ============================================================================
