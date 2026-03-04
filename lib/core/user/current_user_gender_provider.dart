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

    // Extract gender from ALL possible storage locations
    String? v2Gender =
        (doc['nexus2'] as Map?)
            ?.cast<String, dynamic>()['gender']
            ?.toString()
            .toLowerCase()
            .trim();

    String? v1Gender = doc['gender']?.toString().toLowerCase().trim();

    // Fallback: check dating.profile.gender (written during dating onboarding)
    final datingMap =
        (doc['dating'] is Map)
            ? (doc['dating'] as Map).cast<String, dynamic>()
            : null;
    final datingProfileMap =
        (datingMap?['profile'] is Map)
            ? (datingMap!['profile'] as Map).cast<String, dynamic>()
            : null;
    String? datingGender =
        (datingProfileMap?['gender'] ?? datingMap?['gender'])
            ?.toString()
            .toLowerCase()
            .trim();
    final datingValid =
        datingGender != null &&
        datingGender.isNotEmpty &&
        (datingGender == 'male' || datingGender == 'female');

    print(
      '[currentUserGenderProvider]   dating.profile: $datingGender (valid=$datingValid)',
    );

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

    // Helper: write resolved gender to ALL storage locations so future
    // lookups are consistent everywhere (root, nexus2, dating).
    Future<void> normalizeAllGenderFields(String resolved) async {
      try {
        final firestore = FirebaseFirestore.instance;
        await firestore.collection('users').doc(uid).set(<String, dynamic>{
          'gender': resolved,
          'nexus2': <String, dynamic>{'gender': resolved},
          'dating': <String, dynamic>{
            'gender': resolved,
            'profile': <String, dynamic>{'gender': resolved},
          },
        }, SetOptions(merge: true));
        print(
          '[currentUserGenderProvider] ✓ Normalized all gender fields to $resolved',
        );
      } catch (e) {
        print('[currentUserGenderProvider] ✗ Failed to normalize gender: $e');
      }
    }

    // Resolution priority: v2 (nexus2) > dating.profile > v1 (root).
    // nexus2.gender is the canonical source of truth.
    String? resolved;
    if (v2Valid) {
      resolved = v2Gender;
    } else if (datingValid) {
      resolved = datingGender;
    } else if (v1Valid) {
      resolved = v1Gender;
    }

    if (resolved != null) {
      // Check if any field disagrees with the resolved value and normalize.
      final needsSync =
          (v1Gender != resolved) ||
          (v2Gender != resolved) ||
          (datingGender != resolved);

      if (needsSync) {
        print(
          '[currentUserGenderProvider] ⚠️ Inconsistency detected — normalizing to $resolved',
        );
        await normalizeAllGenderFields(resolved);
      } else {
        print(
          '[currentUserGenderProvider] ✓ All gender fields consistent: $resolved',
        );
      }

      yield resolved;
      return;
    }

    // CASE: No valid gender found anywhere
    print(
      '[currentUserGenderProvider] ✗ CRITICAL: Authenticated user has no valid gender (uid=$uid)',
    );
    print('[currentUserGenderProvider]   doc keys: ${doc.keys.toList()}');
    print('[currentUserGenderProvider]   raw root gender: ${doc['gender']}');
    print(
      '[currentUserGenderProvider]   raw nexus2.gender: ${(doc['nexus2'] as Map?)?.cast<String, dynamic>()['gender']}',
    );
    print(
      '[currentUserGenderProvider]   raw dating.profile.gender: ${datingProfileMap?['gender']}',
    );
    yield null;
  } catch (e) {
    print('[currentUserGenderProvider] ✗ Error extracting gender: $e');
    yield null;
  }
});
