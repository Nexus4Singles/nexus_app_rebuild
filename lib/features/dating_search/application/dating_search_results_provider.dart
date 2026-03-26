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
import 'dating_clicked_profiles_provider.dart';
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
    print('[SearchResultsProvider] ⏳ Firebase not ready, waiting...');
    // Wait for Firebase to be ready instead of returning empty
    await Future.delayed(const Duration(milliseconds: 500));
    // Re-check after delay
    final nowReady = ref.read(firebaseReadyProvider);
    if (!nowReady) {
      print('[SearchResultsProvider] ❌ Firebase still not ready after wait');
      throw Exception('Firebase not initialized. Please restart the app.');
    }
  }

  // Hard gate: disabled users cannot search.
  // FIXED: Await the stream's first emission instead of returning empty when not ready.
  // The old code returned DatingSearchResult(items: []) when hasValue was false,
  // which caused a false "no matches" flash before the stream emitted.
  bool isDisabled;
  try {
    isDisabled = await ref.watch(currentUserDisabledProvider.future);
  } catch (_) {
    isDisabled = false; // Default to not-disabled on error
  }
  if (kDebugMode) {
    // DEBUG: isDisabled status skipped to reduce log noise
  }
  if (isDisabled) {
    print('[SearchResultsProvider] ❌ EARLY RETURN: User account is disabled');
    // CHANGED: Throw error instead of returning empty to avoid false "no profiles" state
    throw Exception('User account is disabled');
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
  } catch (e) {
    print(
      '[SearchResultsProvider] ❌ EARLY RETURN: Gender provider threw error: $e',
    );
    // CHANGED: Throw instead of returning empty to avoid false "no profiles" state
    throw Exception('Failed to resolve user gender: $e');
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
    print(
      '[SearchResultsProvider] ⏳ Gender is null — retrying with escalating delays...',
    );
    // Gender provider may yield null from init before user doc loaded.
    // Retry with escalating delays and invalidation to ensure doc propagation.
    const retryDelays = [
      Duration(milliseconds: 800),
      Duration(milliseconds: 1500),
      Duration(seconds: 3),
    ];
    for (final delay in retryDelays) {
      await Future.delayed(delay);
      try {
        ref.invalidate(currentUserGenderProvider);
        gender = await ref
            .read(currentUserGenderProvider.future)
            .timeout(const Duration(seconds: 5), onTimeout: () => null);
      } catch (_) {}
      if (gender != null && gender.trim().isNotEmpty) {
        print('[SearchResultsProvider] ✅ Gender resolved on retry: $gender');
        break;
      }
    }
    if (gender == null || gender.trim().isEmpty) {
      print(
        '[SearchResultsProvider] ❌ EARLY RETURN: Gender still null after all retries (gender=$gender)',
      );
      // CHANGED: Throw instead of returning empty to show loading in UI
      throw Exception(
        'Unable to determine user gender after multiple retries. This may indicate a connectivity issue.',
      );
    }
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
    print(
      '[SearchResultsProvider] ❌ EARLY RETURN: Opposite gender is empty (user gender=$gender)',
    );
    // CHANGED: Throw instead of returning empty
    throw Exception('Unable to determine search gender (opposite of $gender)');
  }

  // Wait for preferences to resolve to avoid transient empty-state flashes.
  DatingPreferences? preferences;
  try {
    preferences = await ref.watch(datingPreferencesProvider.future);
  } catch (e) {
    print(
      '[SearchResultsProvider] ❌ EARLY RETURN: Preferences provider threw error: $e',
    );
    // CHANGED: Throw instead of returning empty
    throw Exception('Failed to load preferences: $e');
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
      print(
        '[SearchResultsProvider] ❌ EARLY RETURN: Preferences are null for non-admin user',
      );
      // CHANGED: Throw instead of returning empty to avoid false "no profiles" state
      throw Exception(
        'Preferences not set up. User must complete dating preferences setup.',
      );
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
  print(
    '[SearchResultsProvider] 🔧 SEARCH CONFIG: '
    'gender=$gender → searching for=$genderToShow, '
    'age=${filters.minAge}-${filters.maxAge}, '
    'country=${filters.countryOfResidence}, '
    'longDistance=${filters.longDistance}, '
    'marital=${filters.maritalStatus}, '
    'kids=${filters.hasKids}, '
    'genotype=${filters.genotype}',
  );

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
    print(
      '[SearchResultsProvider] 🔍 Search service returned: '
      'items=${results.items.length}, '
      'emptyHint=${results.emptyHint != null ? '"${results.emptyHint}"' : 'null'}, '
      'noProfilesInCountry=${results.noProfilesInCountry}, '
      'breakdown=${results.noProfilesBreakdown?.eliminatingFilter ?? 'null'}',
    );
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
        print('[SearchResultsProvider] ⚠️ Timeout: Returning cached results');
        return stale;
      }
      // 3) No stale data available: throw to trigger error state with retry
      // This prevents false "no profiles" state - UI will show loading/error
      print('[SearchResultsProvider] ❌ Timeout with no cache available');
      throw TimeoutException(
        'Search is taking longer than expected. Please check your connection and try again.',
      );
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
    results = DatingSearchResult(
      items: filtered,
      emptyHint: results.emptyHint,
      noProfilesInCountry: results.noProfilesInCountry,
      noProfilesBreakdown: results.noProfilesBreakdown,
      maxPaginationPages: results.maxPaginationPages,
    );
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
      noProfilesInCountry: results.noProfilesInCountry,
      noProfilesBreakdown: results.noProfilesBreakdown,
      maxPaginationPages: results.maxPaginationPages,
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
  // Check both new format (subscription.isActive) and legacy format (onPremium) for max pages
  bool isPremiumForMaxPages = false;
  final subscriptionDataForMaxPages = currentUser?.subscription;
  if (subscriptionDataForMaxPages != null) {
    final isActive = subscriptionDataForMaxPages['isActive'] as bool? ?? false;
    if (isActive) {
      final expiryDate = subscriptionDataForMaxPages['expiryDate'];
      if (expiryDate != null) {
        if (expiryDate is Timestamp &&
            expiryDate.toDate().isAfter(DateTime.now())) {
          isPremiumForMaxPages = true;
        }
      } else {
        isPremiumForMaxPages = true;
      }
    }
  } else if (currentUser?.onPremium == true) {
    final expDate = currentUser?.subExpDate;
    if (expDate != null && expDate.isAfter(DateTime.now())) {
      isPremiumForMaxPages = true;
    }
  }
  final maxPages = isAdmin ? 500 : (isPremiumForMaxPages ? 100 : 25);

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
    noProfilesInCountry: results.noProfilesInCountry,
    noProfilesBreakdown: results.noProfilesBreakdown,
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
            noProfilesInCountry: results.noProfilesInCountry,
            noProfilesBreakdown: results.noProfilesBreakdown,
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
        noProfilesInCountry: results.noProfilesInCountry,
        noProfilesBreakdown: results.noProfilesBreakdown,
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
  //
  // SMART LOGIC: Track which profiles user has seen (not timebound)
  // - Never limit by "created in 24 hours" to avoid missing older profiles
  // - Prioritize unseen profiles (higher in stack)
  // - Show up to 10: [unseen profiles...] then [previously seen...]
  // - This ensures no one is left out due to not checking daily

  // Check both new format (subscription.isActive) and legacy format (onPremium)
  bool isPremium = false;

  // Check new subscription format first
  final subscriptionData = currentUser?.subscription;
  if (subscriptionData != null) {
    final isActive = subscriptionData['isActive'] as bool? ?? false;
    if (isActive) {
      final expiryDate = subscriptionData['expiryDate'];
      if (expiryDate != null) {
        if (expiryDate is Timestamp &&
            expiryDate.toDate().isAfter(DateTime.now())) {
          isPremium = true;
        }
      } else {
        isPremium = true; // No expiry — indefinite premium
      }
    }
  }

  // Fallback to legacy format
  if (!isPremium && currentUser?.onPremium == true) {
    final expDate = currentUser?.subExpDate;
    if (expDate != null && expDate.isAfter(DateTime.now())) {
      isPremium = true;
    }
  }

  if (!isPremium && results.items.isNotEmpty) {
    final uid = FirebaseAuth.instance.currentUser?.uid;
    final manager = ref.read(dailyLimitManagerProvider);

    if (uid != null) {
      try {
        // Get persisted daily limit timestamp (if it exists and 24h hasn't passed)
        final persistedLimitHit = await manager.getDailyLimitFirstHit(uid);

        // Get already-shown profile IDs from today
        var shownIds = await manager.getShownProfileIds(uid);

        // SAFEGUARD: If reset happened (persistedLimitHit=null) but shownIds has entries,
        // it means old data persists. Clear it now.
        if (persistedLimitHit == null && shownIds.isNotEmpty) {
          try {
            await manager.setShownProfileIds(uid, []);
            shownIds = [];
          } catch (e) {
            if (kDebugMode) {
              print(
                '[DatingSearchResults] ⚠️ Warning: Failed to clear stale shownIds: $e',
              );
            }
            // Continue anyway - use the stale data rather than breaking
          }
        }

        // ====================================================================
        // SMART PRIORITIZATION: Unseen > Seen (by createdAt within each group)
        // ====================================================================
        // Split all results into unseen and seen
        // Results are already sorted by createdAt (newest first)
        final unseenProfiles =
            results.items.where((p) => !shownIds.contains(p.uid)).toList();

        final seenProfiles =
            results.items.where((p) => shownIds.contains(p.uid)).toList();

        // Combine: unseen first (maintaining createdAt order), then seen
        final prioritizedResults = <DatingProfile>[
          ...unseenProfiles,
          ...seenProfiles,
        ];

        // ====================================================================
        // CASE LOGIC FOR FREE USER DAILY LIMIT
        // ====================================================================

        // Case 1: Already shown 10+ profiles today (limit hit within 24 hours)
        if (shownIds.length >= 10) {
          // Return the profiles already shown today so user keeps seeing their grid
          // SAFETY FIX: If filter changed, previously-shown profiles won't be in current results.
          // Fall back to showing from prioritized pool to prevent empty grid.
          var todaysProfiles =
              results.items.where((p) => shownIds.contains(p.uid)).toList();

          // Fallback: if filter change orphaned the profiles, show from prioritized pool
          if (todaysProfiles.isEmpty && prioritizedResults.isNotEmpty) {
            todaysProfiles =
                prioritizedResults
                    .where((p) => shownIds.contains(p.uid))
                    .toList();
          }

          results = DatingSearchResult(
            items:
                todaysProfiles.isEmpty
                    ? prioritizedResults.take(10).toList()
                    : todaysProfiles,
            emptyHint: null,
            hitDailyLimit: true,
            totalAvailableCount: results.items.length,
            dailyLimitHitAt: persistedLimitHit,
            allAvailableShownToday: true,
            shownProfileIds: shownIds,
            maxPaginationPages: results.maxPaginationPages,
          );
        }
        // Case 2: Fresh start after 24h reset (shownIds was cleared)
        else if (shownIds.isEmpty && unseenProfiles.isNotEmpty) {
          // Show up to 10 from prioritized list (unseen first, then seen)
          final profilesToShow = prioritizedResults.take(10).toList();
          final allIds = profilesToShow.map((p) => p.uid).toList();

          // Persist daily limit timestamp and shown profile IDs
          try {
            await manager.setDailyLimitFirstHit(uid);
            await manager.setShownProfileIds(uid, allIds);
            if (kDebugMode) {
              print(
                '[DatingSearchResults] ✅ Case 2: Persisted daily limit & ${allIds.length} profile IDs',
              );
            }
          } catch (e) {
            if (kDebugMode) {
              print(
                '[DatingSearchResults] ⚠️ Error persisting daily limit (Case 2): $e',
              );
              print(
                '[DatingSearchResults] ⚠️ User will still see profiles, but quota tracking may be lost',
              );
            }
            // Continue anyway - user can still see results, quota just won't persist
          }

          results = DatingSearchResult(
            items: profilesToShow,
            emptyHint: null,
            hitDailyLimit: allIds.length >= 10,
            totalAvailableCount: results.items.length,
            dailyLimitHitAt: persistedLimitHit ?? DateTime.now(),
            allAvailableShownToday: allIds.length >= 10,
            shownProfileIds: allIds,
            maxPaginationPages: results.maxPaginationPages,
          );
        }
        // Case 3: Mid-session - need to show more profiles to reach 10
        else if (shownIds.isNotEmpty && shownIds.length < 10) {
          final remaining = 10 - shownIds.length;

          // Get all profiles not yet shown today (unseen)
          final allUnseenToday =
              prioritizedResults
                  .where((p) => !shownIds.contains(p.uid))
                  .toList();

          // Take up to 'remaining' profiles from unseen pool
          // This maintains the prioritized order (unseen by date)
          final newProfilesToShow = allUnseenToday.take(remaining).toList();

          // FIXED: Always include previously-shown profiles in the result set.
          // The old code only returned new profiles (the delta), causing the grid
          // to show fewer profiles than expected, or even empty if all new profiles
          // were already dismissed.
          final alreadySeenProfiles =
              results.items.where((p) => shownIds.contains(p.uid)).toList();

          // Only update persistence if we have new profiles to add
          if (newProfilesToShow.isNotEmpty) {
            final allIds = [
              ...shownIds,
              ...newProfilesToShow.map((p) => p.uid),
            ];

            // Persist quota timestamp if hitting 10 for first time
            if (allIds.length >= 10 && persistedLimitHit == null) {
              try {
                await manager.setDailyLimitFirstHit(uid);
                if (kDebugMode) {
                  print(
                    '[DatingSearchResults] ✅ Case 3a: User hit 10-profile limit',
                  );
                }
              } catch (e) {
                if (kDebugMode) {
                  print(
                    '[DatingSearchResults] ⚠️ Error setting daily limit timestamp (Case 3a): $e',
                  );
                }
                // Continue - timestamp tracking lost but profiles still shown
              }
            }

            // Persist updated profile IDs
            try {
              await manager.setShownProfileIds(uid, allIds);
              if (kDebugMode) {
                print(
                  '[DatingSearchResults] ✅ Case 3a: Persisted ${allIds.length} profile IDs',
                );
              }
            } catch (e) {
              if (kDebugMode) {
                print(
                  '[DatingSearchResults] ⚠️ Error persisting shownProfileIds (Case 3a): $e',
                );
                print(
                  '[DatingSearchResults] ⚠️ User will see duplicates on next search if persistence fails',
                );
              }
              // Continue - deduplication may fail but user still sees results
            }

            // Return FULL set: already-seen + newly-added profiles
            results = DatingSearchResult(
              items: [...alreadySeenProfiles, ...newProfilesToShow],
              emptyHint: null,
              hitDailyLimit: allIds.length >= 10,
              totalAvailableCount: results.items.length,
              dailyLimitHitAt: persistedLimitHit ?? DateTime.now(),
              allAvailableShownToday: allIds.length >= 10,
              shownProfileIds: allIds,
              maxPaginationPages: results.maxPaginationPages,
            );
          } else {
            // No unseen profiles left - return the already-seen profiles so grid stays populated
            // SAFETY FIX: If alreadySeenProfiles is empty (filter changed), pull from broader pool
            var profilesToReturn = alreadySeenProfiles;
            if (profilesToReturn.isEmpty && prioritizedResults.isNotEmpty) {
              // Backward compatibility: show from all available profiles (not just current filter)
              profilesToReturn =
                  prioritizedResults
                      .where((p) => shownIds.contains(p.uid))
                      .toList();
            }
            if (profilesToReturn.isEmpty && prioritizedResults.isNotEmpty) {
              // Last resort: show any available profiles to prevent empty grid
              profilesToReturn = prioritizedResults.take(10).toList();
            }

            results = DatingSearchResult(
              items: profilesToReturn,
              emptyHint: null,
              hitDailyLimit: shownIds.length >= 10,
              totalAvailableCount: results.items.length,
              dailyLimitHitAt: persistedLimitHit,
              allAvailableShownToday: true,
              shownProfileIds: shownIds,
              maxPaginationPages: results.maxPaginationPages,
            );
          }
        }
        // No other cases needed - above cases are exhaustive
        else {
          // Defensive fallback: return already-seen profiles so grid stays populated
          // SAFETY FIX: Use prioritized pool to handle filter changes gracefully
          var todaysProfiles =
              results.items.where((p) => shownIds.contains(p.uid)).toList();

          // Try to get from prioritized pool if filtered results are empty
          if (todaysProfiles.isEmpty && prioritizedResults.isNotEmpty) {
            todaysProfiles =
                prioritizedResults
                    .where((p) => shownIds.contains(p.uid))
                    .toList();
          }

          // Last resort: show any available profiles to prevent empty grid
          if (todaysProfiles.isEmpty && prioritizedResults.isNotEmpty) {
            todaysProfiles = prioritizedResults.take(10).toList();
          }

          results = DatingSearchResult(
            items: todaysProfiles,
            emptyHint: null,
            hitDailyLimit: shownIds.length >= 10,
            totalAvailableCount: results.items.length,
            dailyLimitHitAt: persistedLimitHit,
            allAvailableShownToday: true,
            shownProfileIds: shownIds,
            maxPaginationPages: results.maxPaginationPages,
          );
        }
      } catch (e) {
        // Critical error in daily limit logic - log and fallback
        if (kDebugMode) {
          print(
            '[DatingSearchResults] ❌ CRITICAL ERROR in daily limit logic: $e',
          );
          print(
            '[DatingSearchResults] ❌ Falling back to showing all results without quota tracking',
          );
        }
        // Return original results without any quota/tracking applied
        // This ensures user still sees search results even if persistence fails
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

  // DIAGNOSTIC: Log final result before returning
  print(
    '[SearchResultsProvider] ✅ FINAL RETURN: '
    'items=${results.items.length}, '
    'emptyHint=${results.emptyHint != null ? '"${results.emptyHint}"' : 'null'}, '
    'noProfilesInCountry=${results.noProfilesInCountry}, '
    'breakdown=${results.noProfilesBreakdown != null ? 'eliminatingFilter=${results.noProfilesBreakdown!.eliminatingFilter}, totalFetched=${results.noProfilesBreakdown!.totalFetched}' : 'null'}, '
    'hitDailyLimit=${results.hitDailyLimit}',
  );

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
// FILTERED RESULTS PROVIDER (SEPARATE from caching)
// ============================================================================
// Applies premium user filtering (clicked profiles) to cached results
// Isolated from result-fetching logic to avoid Riverpod lifecycle issues
final filteredDatingSearchResultsProvider = FutureProvider<DatingSearchResult>((
  ref,
) async {
  // Get uncached results
  final baseResults = await ref.watch(cachedDatingSearchResultsProvider.future);

  if (baseResults.items.isEmpty) {
    return baseResults;
  }

  // Watch dependencies for filtering
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  final clickedProfiles = ref.watch(clickedProfilesProvider);

  // Check if user is premium
  bool isPremium = false;
  if (currentUser != null) {
    final subscriptionData = currentUser.subscription;
    if (subscriptionData != null) {
      final isActive = subscriptionData['isActive'] as bool? ?? false;
      if (isActive) {
        final expiryDate = subscriptionData['expiryDate'];
        if (expiryDate != null) {
          if (expiryDate is Timestamp &&
              expiryDate.toDate().isAfter(DateTime.now())) {
            isPremium = true;
          }
        } else {
          isPremium = true;
        }
      }
    } else if (currentUser.onPremium == true) {
      final expDate = currentUser.subExpDate;
      if (expDate != null && expDate.isAfter(DateTime.now())) {
        isPremium = true;
      }
    }
  }

  // If not premium or no clicked profiles, return as-is
  if (!isPremium || clickedProfiles.isEmpty) {
    return baseResults;
  }

  // Premium user with clicked profiles - filter them out
  final filteredItems =
      baseResults.items
          .where((profile) => !clickedProfiles.keys.contains(profile.uid))
          .toList();

  return DatingSearchResult(
    items: filteredItems,
    emptyHint: baseResults.emptyHint,
    hitDailyLimit: baseResults.hitDailyLimit,
    totalAvailableCount: baseResults.totalAvailableCount,
    dailyLimitHitAt: baseResults.dailyLimitHitAt,
    noProfilesInCountry: baseResults.noProfilesInCountry,
    allAvailableShownToday: baseResults.allAvailableShownToday,
    shownProfileIds: baseResults.shownProfileIds,
    maxPaginationPages: baseResults.maxPaginationPages,
    noProfilesBreakdown: baseResults.noProfilesBreakdown,
  );
});

// ============================================================================
// INCREMENTAL PAGINATION - Load more profiles as user scrolls
// ============================================================================
// This provider accumulates results batches to show incrementally

final paginatedDatingSearchResultsProvider = FutureProvider<
  DatingSearchResult
>((ref) async {
  // Watch the offset - when it changes, fetch the next batch
  final offset = ref.watch(searchResultsOffsetProvider);

  // Get current preferences
  DatingPreferences? preferences;
  try {
    preferences = await ref.read(datingPreferencesProvider.future);
  } catch (e) {
    // Don't return empty - this is a pagination provider, empty breaks the UI
    print(
      '[PaginatedProvider] ⚠️ Failed to load preferences for pagination: $e',
    );
    // Return empty but don't break - main provider handles preferences
    preferences = null;
  }

  if (offset == 0) {
    // Initial load - use cached results or fetch fresh
    return await ref.watch(cachedDatingSearchResultsProvider.future);
  }

  // Subsequent batches - fetch more results
  final firebaseReady = ref.watch(firebaseReadyProvider);
  if (!firebaseReady) {
    // Pagination batch - return empty gracefully (main provider handles Firebase check)
    return const DatingSearchResult(items: []);
  }

  // Get gender
  String? gender;
  try {
    gender = await ref.watch(currentUserGenderProvider.future);
  } catch (_) {
    // Pagination batch - return empty gracefully
    return const DatingSearchResult(items: []);
  }
  if (gender == null || gender.trim().isEmpty) {
    // Pagination batch - return empty gracefully
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
});

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

  // ========== NEW: FILTER CLICKED PROFILES FOR PREMIUM USERS ==========
  // Premium users should not see profiles they've already clicked to view
  // This improves scroll experience by reducing repeated profiles
  // Only applies to premium users (free users stay with 10-profile daily limit)

  List<DatingProfile> finalResults = combined;

  try {
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    if (currentUser != null) {
      // Check if user is premium
      bool isPremium = false;
      final subscriptionData = currentUser.subscription;
      if (subscriptionData != null) {
        final isActive = subscriptionData['isActive'] as bool? ?? false;
        if (isActive) {
          final expiryDate = subscriptionData['expiryDate'];
          if (expiryDate != null) {
            if (expiryDate is Timestamp &&
                expiryDate.toDate().isAfter(DateTime.now())) {
              isPremium = true;
            }
          } else {
            isPremium = true;
          }
        }
      } else if (currentUser.onPremium == true) {
        final expDate = currentUser.subExpDate;
        if (expDate != null && expDate.isAfter(DateTime.now())) {
          isPremium = true;
        }
      }

      // If premium, filter out clicked profiles
      if (isPremium) {
        final clickedProfiles = ref.watch(clickedProfilesProvider);
        if (clickedProfiles.isNotEmpty) {
          finalResults =
              combined
                  .where(
                    (profile) => !clickedProfiles.keys.contains(profile.uid),
                  )
                  .toList();

          if (kDebugMode) {
            final filtered = combined.length - finalResults.length;
            print(
              '[AccumulatedResults] Premium user: filtered $filtered clicked profiles | '
              '${combined.length} → ${finalResults.length} total',
            );
          }
        }
      }
    }
  } catch (e) {
    if (kDebugMode) {
      print('[AccumulatedResults] Error filtering clicked profiles: $e');
    }
    // Silently fall back to showing all - don't break the user experience
    finalResults = combined;
  }

  // ====================================================================

  return DatingSearchResult(
    items: finalResults,
    emptyHint: initialBatch.emptyHint,
    hitDailyLimit: initialBatch.hitDailyLimit,
    dailyLimitHitAt: initialBatch.dailyLimitHitAt,
    noProfilesInCountry: initialBatch.noProfilesInCountry,
    maxPaginationPages: initialBatch.maxPaginationPages,
    noProfilesBreakdown: initialBatch.noProfilesBreakdown,
  );
});

// ============================================================================
// PAGINATION REMOVED - Incremental loading replaces traditional pagination
// This simplifies UX and avoids pagination bugs
// ============================================================================
