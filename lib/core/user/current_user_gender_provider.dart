import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_v2/core/session/guest_session_provider.dart';
import 'current_user_doc_provider.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';

/// Extracts the current user's gender from Firestore.
/// - v2 users: nexus2.gender
/// - v1 users: root-level gender
/// - Fallback: guest session gender (for presurvey users)
final currentUserGenderProvider = FutureProvider<String?>((ref) async {
  // Get current auth state
  final authState = await ref.watch(authStateProvider.future);
  print(
    '[currentUserGenderProvider] Auth state: ${authState?.uid}, anonymous=${authState?.isAnonymous}',
  );
  
  // For unauthenticated users, fall back to guest session
  if (authState == null || authState.isAnonymous) {
    final guest = ref.watch(guestSessionProvider);
    final presurveyGender = guest?.gender;
    if (presurveyGender != null && presurveyGender.trim().isNotEmpty) {
      print('[currentUserGenderProvider] Using guest session gender: $presurveyGender');
      return presurveyGender.toLowerCase();
    }
    print('[currentUserGenderProvider] No auth user and no guest gender');
    return null;
  }

  // Signed-in user: get gender from Firestore
  try {
    final doc = await ref.watch(currentUserDocProvider.future);
    print('[currentUserGenderProvider] Firestore doc loaded: ${doc != null}');
    
    if (doc == null) {
      print('[currentUserGenderProvider] User doc is null');
      return null;
    }

    // FIXED: Check multiple paths for gender - v2 first, then v1, then fallback
    print('[currentUserGenderProvider] Full Firestore doc keys: ${doc.keys.toList()}');
    
    // v2 users: stored in nexus2.gender
    String? g = (doc['nexus2'] as Map?)?.cast<String, dynamic>()['gender']?.toString().toLowerCase();
    print('[currentUserGenderProvider] nexus2.gender: $g');
    
    // v1 fallback: stored at root level
    if (g == null || g.trim().isEmpty) {
      g = doc['gender']?.toString().toLowerCase();
      print('[currentUserGenderProvider] root-level gender: $g');
    }
    
    if (g == null || g.trim().isEmpty) {
      // Last resort: try guest session
      final guest = ref.watch(guestSessionProvider);
      final presurveyGender = guest?.gender;
      if (presurveyGender != null && presurveyGender.trim().isNotEmpty) {
        print('[currentUserGenderProvider] Fallback to guest session gender: $presurveyGender');
        return presurveyGender.toLowerCase();
      }
      print('[currentUserGenderProvider] No gender found in any location');
      return null;
    }
    
    print('[currentUserGenderProvider] Returning gender: $g');
    return g;
  } catch (e, st) {
    print('[currentUserGenderProvider] Error loading gender: $e\n$st');
    // Last resort: try guest session on error
    final guest = ref.watch(guestSessionProvider);
    final presurveyGender = guest?.gender;
    if (presurveyGender != null && presurveyGender.trim().isNotEmpty) {
      print('[currentUserGenderProvider] Error fallback to guest session: $presurveyGender');
      return presurveyGender.toLowerCase();
    }
    rethrow;
  }
});
