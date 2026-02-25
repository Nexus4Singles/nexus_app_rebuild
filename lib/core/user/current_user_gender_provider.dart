import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nexus_app_v2/core/session/guest_session_provider.dart';
import 'current_user_doc_provider.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';

/// Extracts the current user's gender from Firestore.
/// - v2 users: nexus2.gender
/// - v1 users: root-level gender
/// - Guest users (presurvey): guest session gender
///
/// CRITICAL: This provider only uses guest session for UNAUTHENTICATED users.
/// For authenticated users, gender MUST come from Firestore, never from guest session.
/// This prevents showing cached gender from previous logins.
///
/// This is a StreamProvider that properly invalidates when the user changes,
/// ensuring no stale gender values are cached across logout/login cycles.
final currentUserGenderProvider = StreamProvider<String?>((ref) async* {
  // Watch auth state AND the current user doc
  // When EITHER changes, this provider resets and yields fresh values
  final authStateAsync = ref.watch(authStateProvider);

  // Only proceed if we have auth data
  if (!authStateAsync.hasValue) {
    yield null;
    return;
  }

  final authState = authStateAsync.value;
  final uid = authState?.uid;
  final isAnon = authState?.isAnonymous ?? false;

  print(
    '[currentUserGenderProvider] ✓ Auth state: uid=$uid, anonymous=$isAnon',
  );

  // CASE 1: No authenticated user (guest/presurvey) → use guest session
  if (authState == null || isAnon) {
    final guest = ref.watch(guestSessionProvider);
    final presurveyGender = guest?.gender;
    if (presurveyGender != null && presurveyGender.trim().isNotEmpty) {
      print(
        '[currentUserGenderProvider] ✓ Guest user using session gender: $presurveyGender',
      );
      yield presurveyGender.toLowerCase();
    } else {
      print('[currentUserGenderProvider] ✗ No auth user and no guest gender');
      yield null;
    }
    return;
  }

  // CASE 2: Authenticated user → MUST get from Firestore, NOT guest session
  // Watch currentUserDocProvider and check if it's ready
  final userDocAsync = ref.watch(currentUserDocProvider);

  // Only proceed if doc has fully loaded
  if (userDocAsync is! AsyncData) {
    print(
      '[currentUserGenderProvider] User doc not ready yet (${userDocAsync.runtimeType})',
    );
    yield null;
    return;
  }

  final doc = userDocAsync.asData!.value;

  if (doc == null) {
    print('[currentUserGenderProvider] ✗ User doc is null for uid=$uid');
    yield null;
    return;
  }

  try {
    print('[currentUserGenderProvider] ✓ Firestore doc loaded: true');

    // Extract BOTH values for reconciliation
    String? v2Gender =
        (doc['nexus2'] as Map?)
            ?.cast<String, dynamic>()['gender']
            ?.toString()
            .toLowerCase()
            .trim();

    String? v1Gender = doc['gender']?.toString().toLowerCase().trim();

    // Validate both
    final v2Valid =
        v2Gender != null &&
        v2Gender.isNotEmpty &&
        (v2Gender == 'male' || v2Gender == 'female');
    final v1Valid =
        v1Gender != null &&
        v1Gender.isNotEmpty &&
        (v1Gender == 'male' || v1Gender == 'female');

    print('[currentUserGenderProvider] 🔍 Gender reconciliation:');
    print(
      '[currentUserGenderProvider]   v1 (root): $v1Gender (valid=$v1Valid)',
    );
    print(
      '[currentUserGenderProvider]   v2 (nexus2): $v2Gender (valid=$v2Valid)',
    );

    // MISMATCH CASE: Both exist but differ → use v1 as source of truth
    if (v1Valid && v2Valid && v1Gender != v2Gender) {
      print(
        '[currentUserGenderProvider] ⚠️ MISMATCH DETECTED: v1=$v1Gender != v2=$v2Gender',
      );
      print(
        '[currentUserGenderProvider] Using v1 as source of truth, updating v2...',
      );

      try {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('users').doc(uid).update({
          'dating.profile.gender': v1Gender,
        });
        print(
          '[currentUserGenderProvider] ✓ Fixed: updated dating.profile.gender to $v1Gender',
        );
      } catch (e) {
        print('[currentUserGenderProvider] ✗ Failed to sync gender: $e');
      }

      yield v1Gender;
      return;
    }

    // CASE: Both valid and match → use either (already consistent)
    if (v1Valid && v2Valid && v1Gender == v2Gender) {
      print(
        '[currentUserGenderProvider] ✓ Both v1 & v2 match: $v1Gender (consistent)',
      );
      yield v1Gender;
      return;
    }

    // CASE: Only v1 valid → use v1 and sync to v2 if nexus2 exists
    if (v1Valid && !v2Valid) {
      print('[currentUserGenderProvider] ✓ Using v1: $v1Gender');

      // If nexus2 subdoc exists but gender missing, populate it
      if (doc['nexus2'] != null) {
        try {
          final firestore = FirebaseFirestore.instance;
          await firestore.collection('users').doc(uid).update({
            'dating.profile.gender': v1Gender,
          });
          print('[currentUserGenderProvider] ✓ Synced v1 to v2: $v1Gender');
        } catch (e) {
          print('[currentUserGenderProvider] ✗ Failed to sync to v2: $e');
        }
      }

      yield v1Gender;
      return;
    }

    // CASE: Only v2 valid → use v2 (no sync needed, v2 is already populated)
    if (v2Valid && !v1Valid) {
      print('[currentUserGenderProvider] ✓ Using v2: $v2Gender');
      yield v2Gender;
      return;
    }

    // CASE: Neither valid
    print(
      '[currentUserGenderProvider] ✗ CRITICAL: Authenticated user has no valid gender (uid=$uid)',
    );
    yield null;
  } catch (e) {
    print('[currentUserGenderProvider] ✗ Error extracting gender: $e');
    yield null;
  }
});
