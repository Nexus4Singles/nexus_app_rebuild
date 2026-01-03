import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/core/session/guest_session_provider.dart';
import 'package:nexus_app_min_test/core/user/current_user_gender_provider.dart';
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
  if (!firebaseReady) return const [];
  final compat = await ref.watch(compatibilityStatusProvider.future);
  if (compat != CompatibilityStatus.complete) return const [];

  final gender = await ref.watch(currentUserGenderProvider.future);
  if (gender == null) return const [];

  String opposite(String g) {
    final v = g.toLowerCase();
    if (v == 'male') return 'female';
    if (v == 'female') return 'male';
    return '';
  }

  final genderToShow = opposite(gender);
  if (genderToShow.isEmpty) return const [];

  final filters = ref.watch(datingSearchFiltersProvider);
  final service = ref.read(datingSearchServiceProvider);

  return service.search(genderToShow: genderToShow, filters: filters);
});
