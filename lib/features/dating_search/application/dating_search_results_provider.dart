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
    print('[DatingSearchResultsProvider] Preferences: '
        'country=${preferences?.countryOfResidence}, '
        'allowLongDistance=${preferences?.allowLongDistance}, '
        'openToKids=${preferences?.openToKids}, '
        'openToMarriedBefore=${preferences?.openToMarriedBefore}, '
        'genotype=${preferences?.genotypePreference}');
  }
  
  // Watch dismissed profiles to exclude them
  final dismissedAsync = ref.watch(dismissedProfilesProvider);
  final dismissedIds = dismissedAsync.valueOrNull ?? [];
  
  // Convert saved preferences to search filters
  // PATTERN: null (not set) = no filter; true (yes) = no filter; false (no) = apply filter
  final filters = preferences != null
      ? DatingSearchFilters(
          minAge: preferences.minAge,
          maxAge: preferences.maxAge,
          countryOfResidence: preferences.countryOfResidence,
          // allowLongDistance: null/true = any distance; false = local only
          longDistance: preferences.allowLongDistance == true ? 'Yes' : (preferences.allowLongDistance == false ? 'No' : null),
          // openToMarriedBefore: null/true = any marital status; false = never married only
          maritalStatus: preferences.openToMarriedBefore == false ? 'Never married' : null,
          // openToKids: null/true = any kid status; false = no kids only
          hasKids: preferences.openToKids == false ? 'No' : null,
          // genotypePreference: null = any genotype; value = specific genotype
          genotype: preferences.genotypePreference,
        )
      : ref.watch(datingSearchFiltersProvider);
  
  if (kDebugMode) {
    // ignore: avoid_print
    print('[DatingSearchResultsProvider] Built filters: '
        'country=${filters.countryOfResidence}, '
        'distance=${filters.longDistance}, '
        'marital=${filters.maritalStatus}, '
        'kids=${filters.hasKids}, '
        'genotype=${filters.genotype}');
  }

  final service = ref.read(datingSearchServiceProvider);

  if (kDebugMode) {
    // ignore: avoid_print
    print(
      '[DatingSearchResults] searching genderToShow=$genderToShow, filters=$filters',
    );
  }

  var results = await service.search(
    genderToShow: genderToShow,
    filters: filters,
  ).timeout(
    const Duration(seconds: 30),
    onTimeout: () {
      if (kDebugMode) {
        // ignore: avoid_print
        print('[DatingSearchResults] Search query timed out after 30 seconds - returning empty');
      }
      // On timeout, return empty results to show no-profiles screen
      return const DatingSearchResult(items: []);
    },
  );

  // Filter dismissed profiles only (service already applied all other filters)
  if (results.items.isNotEmpty) {
    final filtered = results.items
        .where((profile) => !dismissedIds.contains(profile.uid))
        .toList();
    
    results = DatingSearchResult(items: filtered, emptyHint: results.emptyHint);
  }

  // Compute compatibility scores if current user data available
  // Skip scoring if there are too many results (>200) to avoid timeout
  if (currentUser != null && results.items.isNotEmpty && results.items.length <= 200) {
    final scoredProfiles = <DatingProfile>[];
    
    // Extract current user compatibility data
    final userAMaritalStatus = currentUser.compatibility?.getCompatibilityField('maritalStatus');
    final userAHaveKids = currentUser.compatibility?.getCompatibilityField('haveKids');
    final userAGenotype = currentUser.compatibility?.getCompatibilityField('genotype');
    final userAPersonalityType = currentUser.compatibility?.getCompatibilityField('personalityType');
    final userARegularIncome = currentUser.compatibility?.getCompatibilityField('regularSourceOfIncome');
    final userALongDistance = currentUser.compatibility?.getCompatibilityField('longDistance');
    final userABelieveInCohabiting = currentUser.compatibility?.getCompatibilityField('believeInCohabiting');
    final userAShouldSpeakTongues = currentUser.compatibility?.getCompatibilityField('shouldChristianSpeakInTongue');
    final userABeliefInTithing = currentUser.compatibility?.getCompatibilityField('believeInTithing');
    
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
          userADesiredQualities: currentUser.desiredQualities?.split(',').map((s) => s.trim()).toList() ?? [],
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
          userBDesiredQualities: profile.desiredQualities?.split(',').map((s) => s.trim()).toList() ?? [],
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
          print('[DatingSearchResults] Error scoring profile ${profile.uid}: $e');
        }
        // If scoring fails, include profile without score
        scoredProfiles.add(profile);
      }
    }

    // Sort by compatibility score (highest first)
    scoredProfiles.sort((a, b) {
      final scoreA = a.compatibilityScore ?? 0;
      final scoreB = b.compatibilityScore ?? 0;
      return scoreB.compareTo(scoreA);
    });

    results = DatingSearchResult(
      items: scoredProfiles,
      emptyHint: results.emptyHint,
    );
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
