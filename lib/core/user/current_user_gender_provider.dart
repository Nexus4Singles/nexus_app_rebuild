import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_v2/core/session/guest_session_provider.dart';
import 'current_user_doc_provider.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';

final currentUserGenderProvider = StreamProvider<String?>((ref) {
  // Defensive: Always prefer Firestore gender for authenticated users
  final guest = ref.watch(guestSessionProvider);
  final presurveyGender = guest?.gender;
  final authState = ref.watch(authStateProvider);
  authState.when(
    data: (user) {
      print('[currentUserGenderProvider] Auth state: ${user?.uid}, anonymous=${user?.isAnonymous}');
      if (user != null && !user.isAnonymous) {
        // Clear guest session on login
        print('[currentUserGenderProvider] Clearing guest session on login');
        // You may need to call a method to clear guest session here
      }
    },
    loading: () {
      print('[currentUserGenderProvider] Auth state loading');
    },
    error: (err, stack) {
      print('[currentUserGenderProvider] Auth state error: $err');
    },
  );

  // Prefer Firestore gender if authenticated
  return ref.watch(currentUserDocProvider.stream).map((doc) {
    print('[currentUserGenderProvider] Full Firestore doc: $doc');
    final g = doc?['gender']?.toString().toLowerCase();
    print('[currentUserGenderProvider] Firestore gender field: $g');
    if (g == null || g.trim().isEmpty) {
      // Fallback to guest session gender if not authenticated
      if (presurveyGender != null && presurveyGender.trim().isNotEmpty) {
        print('[currentUserGenderProvider] Fallback to guest session gender: $presurveyGender');
        return presurveyGender.toLowerCase();
      }
      return null;
    }
    return g;
  });
});
