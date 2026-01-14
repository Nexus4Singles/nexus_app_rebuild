import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';

import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/core/session/guest_session_provider.dart';
import 'package:nexus_app_min_test/core/user/current_user_gender_provider.dart';
import 'package:nexus_app_min_test/core/user/current_user_disabled_provider.dart';
import 'package:nexus_app_min_test/features/compatibility_quiz/application/compatibility_status_provider.dart';

import '../data/dating_search_service.dart';
import '../domain/dating_profile.dart';
import '../domain/dating_search_filters.dart';

final datingSearchFiltersProvider = StateProvider<DatingSearchFilters>((ref) {
  return const DatingSearchFilters(minAge: 21, maxAge: 70);
});

final datingSearchResultsProvider = FutureProvider<List<DatingProfile>>((
  ref,
) async {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  if (!firebaseReady) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[DatingSearchResults] firebaseReady=false -> returning []');
    }
    return const [];
  }

  // Hard gate: disabled users cannot search.
  final isDisabled = await ref.watch(currentUserDisabledProvider.future);
  if (isDisabled) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[DatingSearchResults] current user disabled -> returning []');
    }
    return const [];
  }

  final compat = await ref.watch(compatibilityStatusProvider.future);
  if (compat != CompatibilityStatus.complete) {
    if (kDebugMode) {
      // ignore: avoid_print
      print(
        '[DatingSearchResults] compatibilityStatus=$compat -> returning []',
      );
    }
    return const [];
  }

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
      print('[DatingSearchResults] using debug gender override: $gender');
    }
  }

  if (gender == null || gender.trim().isEmpty) {
    if (kDebugMode) {
      // ignore: avoid_print
      print('[DatingSearchResults] gender is null/empty -> returning []');
    }
    return const [];
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
    return const [];
  }

  final filters = ref.watch(datingSearchFiltersProvider);

  final service = ref.read(datingSearchServiceProvider);

  if (kDebugMode) {
    // ignore: avoid_print
    print(
      '[DatingSearchResults] searching genderToShow=$genderToShow, filters=$filters',
    );
  }

  final results = await service.search(
    genderToShow: genderToShow,
    filters: filters,
  );

  if (kDebugMode) {
    // ignore: avoid_print
    print('[DatingSearchResults] results=${results.length}');
  }

  return results;
});
