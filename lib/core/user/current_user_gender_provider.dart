import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/session/guest_session_provider.dart';
import 'current_user_doc_provider.dart';

final currentUserGenderProvider = FutureProvider<String?>((ref) async {
  // 1) Prefer presurvey gender (new v2 users)
  final guest = ref.watch(guestSessionProvider);
  final presurveyGender = guest?.gender;
  if (presurveyGender != null && presurveyGender.trim().isNotEmpty) {
    return presurveyGender.toLowerCase();
  }

  // 2) Fallback to existing v1 Firestore profile
  final doc = await ref.watch(currentUserDocProvider.future);
  final g = doc?['gender']?.toString().toLowerCase();
  if (g == null || g.trim().isEmpty) return null;
  return g;
});
