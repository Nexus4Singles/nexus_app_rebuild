import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:nexus_app_v2/core/constants/app_constants.dart';
import 'package:nexus_app_v2/core/session/guest_session_provider.dart';
import 'package:nexus_app_v2/core/user/user_schema_migrator.dart';
import 'package:nexus_app_v2/core/services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
import '../services/revenuecat_service.dart';
import '../services/journey_entitlements_service.dart';
import 'firestore_service_provider.dart';

/// Provider for AuthService instance
final authServiceProvider = Provider<AuthService>((ref) => AuthService());

/// Stream provider for Firebase auth state
final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Raw auth state stream for router refresh
final authStateStreamProvider = Provider<Stream<User?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  return authService.authStateChanges;
});

/// Provider for current user ID (null if not signed in)
final currentUserIdProvider = Provider<String?>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.whenData((u) => u).value;
  if (user == null) return null;
  if (user.isAnonymous) return null;
  return user.uid;
});

/// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  final user = authState.whenData((u) => u).value;
  if (user == null) return false;
  // Treat anonymous users as guests
  return !user.isAnonymous;
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref _ref;
  final AuthService _authService;
  final FirestoreService _firestoreService;

  AuthNotifier(this._ref, this._authService, this._firestoreService)
    : super(const AsyncValue.loading()) {
    _authService.authStateChanges.listen((user) async {
      // ignore: avoid_print
      print(
        '[AuthNotifier] authStateChanges -> ${user?.uid ?? "null"} verified=${user?.emailVerified} anon=${user?.isAnonymous}',
      );

      // ── RevenueCat ↔ auth sync ──────────────────────────────
      // Link/unlink RevenueCat to the current user so entitlements
      // (subscriptions & journey purchases) are scoped per-account,
      // not per-device.
      if (user != null && !user.isAnonymous) {
        try {
          await RevenueCatService.login(user.uid);
          print('[AuthNotifier] ✅ RevenueCat linked to user: ${user.uid}');

          // ── NEW: Sync any existing RevenueCat subscriptions to Firestore ──
          // This ensures v1 users' subscriptions are recognized in v2
          try {
            await _syncRevenueCatSubscriptionToFirestore(user.uid);
          } catch (syncError) {
            print(
              '[AuthNotifier] ⚠️ RevenueCat subscription sync failed (non-fatal): $syncError',
            );
            // Non-fatal - don't block login
          }
        } catch (e) {
          print('[AuthNotifier] ⚠️ RevenueCat login failed (non-fatal): $e');
        }
      } else {
        // user == null (signed out) or anonymous (guest mode)
        try {
          await RevenueCatService.logout();
          print('[AuthNotifier] ✅ RevenueCat logged out (anonymous)');
        } catch (e) {
          print('[AuthNotifier] ⚠️ RevenueCat logout failed (non-fatal): $e');
        }
        // Clear device-local journey purchase cache so the next account
        // doesn't see the previous user's purchased journeys.
        try {
          await JourneyEntitlementsService().clearAll();
        } catch (_) {}
        // Clear all other user-specific SharedPreferences keys
        await _clearUserLocalData();
      }

      if (user != null && !user.isAnonymous) {
        // Check if user document exists in Firestore
        try {
          final userDoc = await _firestoreService.getUser(user.uid);
          if (userDoc == null) {
            // During email verification the user doc may not exist yet. Keep session alive.
            if (!user.emailVerified) {
              // ignore: avoid_print
              print(
                '[AuthNotifier] Missing user doc but email not verified yet; keeping session.',
              );
              state = AsyncValue.data(user);
              return;
            }

            // If verified but missing doc, create a minimal normalized doc instead of signing out.
            // ignore: avoid_print
            print(
              '[AuthNotifier] Missing user doc for verified user; creating normalized doc.',
            );
            await _ensureUserDocNormalized(user);
          }
        } catch (e) {
          // If error checking user document, still allow them to stay signed in
          // but log the error
          print('Error checking user document: $e');
        }
      }
      state = AsyncValue.data(user);
    });
  }

  String _relationshipStatusToKey(RelationshipStatus status) {
    switch (status) {
      case RelationshipStatus.singleNeverMarried:
        return 'single_never_married';
      case RelationshipStatus.married:
        return 'married';
      case RelationshipStatus.divorced:
        return 'divorced';
      case RelationshipStatus.widowed:
        return 'widowed';
    }
  }

  Future<void> _persistPresurveyToFirestore(String uid) async {
    final guest = _ref.read(guestSessionProvider);
    if (guest == null) return;

    final payload = <String, dynamic>{};

    // v1 users already have gender; for new users, persist it if available.
    final gender = guest.gender;
    if (gender != null && gender.toString().trim().isNotEmpty) {
      payload['gender'] = gender.toString().trim();
    }

    // Relationship status drives v2 tailoring. This is v2-only (namespaced).
    final rel = guest.relationshipStatus;
    final relKey = _relationshipStatusToKey(rel);

    payload['nexus'] = {
      'relationshipStatus': relKey,
      'onboarding': {
        'presurveyCompleted': true,
        'presurveyCompletedAt': FieldValue.serverTimestamp(),
        'version': 2,
      },
    };

    // Temporary mirror for older codepaths (safe to remove later).
    payload['nexus2'] = {'relationshipStatus': relKey};

    // Write merge-safe (never overwrites existing v1 values outside these keys).
    await FirebaseFirestore.instance
        .collection('users')
        .doc(uid)
        .set(payload, SetOptions(merge: true));
  }

  Future<void> _ensureUserDocNormalized(User user, {String? username}) async {
    final uid = user.uid;
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final snap = await docRef.get();
    final raw = (snap.data() ?? <String, dynamic>{});

    // If missing doc entirely, create a minimal v2-compatible base doc (merge-safe).
    if (!snap.exists) {
      // Use directly-passed username first, fall back to SharedPreferences
      String? pendingUsername = username;
      if (pendingUsername == null || pendingUsername.trim().isEmpty) {
        try {
          final prefs = await SharedPreferences.getInstance();
          pendingUsername = prefs.getString('pending_username_$uid');
        } catch (_) {
          // Ignore prefs errors
        }
      }

      final base = <String, dynamic>{
        'uid': uid,
        'email': (user.email ?? '').trim().isEmpty ? null : user.email,
        'profileUrl': user.photoURL,
        'schemaVersion': 2,
        'isGuest': false,
        'isAdmin': false,
        'createdAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add username if available from signup
      if (pendingUsername != null && pendingUsername.trim().isNotEmpty) {
        final trimmed = pendingUsername.trim();
        base['username'] = trimmed;
        // Normalise: lowercase + collapse any multi-space runs
        base['username_lower'] = trimmed.toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        base['name'] = trimmed;
        base['displayName'] = trimmed;
      }

      await docRef.set(base, SetOptions(merge: true));

      // Clean up the pending username from prefs now that it's persisted
      try {
        final prefs = await SharedPreferences.getInstance();
        await prefs.remove('pending_username_$uid');
      } catch (_) {
        // Ignore cleanup errors
      }

      return;
    }

    // Existing doc (v1 or partial v2): patch missing v2 fields only.
    // Also check for pending username from signup that needs to be saved
    String? pendingUsername = username;
    if (pendingUsername == null || pendingUsername.trim().isEmpty) {
      try {
        final prefs = await SharedPreferences.getInstance();
        pendingUsername = prefs.getString('pending_username_$uid');
      } catch (_) {
        // Ignore prefs errors
      }
    }

    var patch = buildUserV2Patch(
      uid: uid,
      raw: raw,
      fallbackEmail: user.email,
      fallbackDisplayName: user.displayName,
      fallbackPhotoUrl: user.photoURL,
    );

    // If username/name are missing, add them from pending signup or fallback
    if (pendingUsername != null && pendingUsername.trim().isNotEmpty) {
      final trimmed = pendingUsername.trim();
      // Only set if not already present
      if ((raw['username'] == null ||
              raw['username'].toString().trim().isEmpty) &&
          (raw['name'] == null || raw['name'].toString().trim().isEmpty)) {
        patch['username'] = trimmed;
        patch['name'] = trimmed;
        patch['displayName'] = trimmed;
        patch['username_lower'] = trimmed.toLowerCase().replaceAll(
          RegExp(r'\s+'),
          ' ',
        );
        // Clean up the pending username now that it's persisted
        try {
          final prefs = await SharedPreferences.getInstance();
          await prefs.remove('pending_username_$uid');
        } catch (_) {
          // Ignore cleanup errors
        }
      }
    }

    if (patch.isEmpty) return;
    await docRef.set(patch, SetOptions(merge: true));
  }

  /// Sign up with email and create user document (merge-safe; won't overwrite v1 users)
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    state = const AsyncValue.loading();
    try {
      // If there's an anonymous user, delete it first
      final currentUser = _authService.currentUser;
      if (currentUser != null && currentUser.isAnonymous) {
        try {
          await currentUser.delete();
        } catch (_) {
          // Ignore deletion errors, proceed with signup
        }
      }

      final credential = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('force_guest');

      final user = credential.user;
      if (user == null) {
        throw Exception('Signup succeeded but user is null');
      }

      // Send email verification
      await _authService.sendEmailVerification();

      // Store username in SharedPreferences as backup (for recovery if app crashes)
      await prefs.setString('pending_username_${user.uid}', username);

      // Create the Firestore document immediately — pass username directly
      // to avoid relying solely on SharedPreferences (which can fail silently)
      await _ensureUserDocNormalized(user, username: username);

      // Also persist presurvey data
      await _persistPresurveyToFirestore(user.uid);

      // ───────────────────────────────────────────────────────────────
      // FIX: Link RevenueCat BEFORE state update to prevent Android race
      // ───────────────────────────────────────────────────────────────
      // CRITICAL: Must complete before UI can navigate to purchase screen
      // This prevents the race condition where user sees anonymous RevenueCat ID
      try {
        await RevenueCatService.login(user.uid);
        print(
          '[AuthNotifier.signUpWithEmail] ✅ RevenueCat linked to user: ${user.uid}',
        );
      } catch (e) {
        // Non-fatal: RevenueCat failure doesn't block signup
        // Listener will retry on auth state changes
        print(
          '[AuthNotifier.signUpWithEmail] ⚠️ RevenueCat login failed (non-fatal): $e',
        );
      }

      // IMPORTANT: Keep user signed in so EmailVerificationScreen can detect when verified
      // Don't sign out yet - user session stays active for verification detection
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sign in with email
  Future<void> signInWithEmail({
    required String email,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authService.signInWithEmail(
        email: email,
        password: password,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('force_guest');

      final user = credential.user;
      if (user != null) {
        // Check if there's a pending username from a signup that
        // created the auth user but failed before writing the Firestore doc.
        final pendingUsername = prefs.getString('pending_username_${user.uid}');
        await _ensureUserDocNormalized(user, username: pendingUsername);

        await _persistPresurveyToFirestore(user.uid);

        // ───────────────────────────────────────────────────────────────
        // FIX: Link RevenueCat BEFORE state update to prevent Android race
        // ───────────────────────────────────────────────────────────────
        try {
          await RevenueCatService.login(user.uid);
          print(
            '[AuthNotifier.signInWithEmail] ✅ RevenueCat linked to user: ${user.uid}',
          );
        } catch (e) {
          // Non-fatal: RevenueCat failure doesn't block signin
          // Listener will retry on auth state changes
          print(
            '[AuthNotifier.signInWithEmail] ⚠️ RevenueCat login failed (non-fatal): $e',
          );
        }
      }

      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sign in with email or username
  Future<void> signInWithEmailOrUsername({
    required String emailOrUsername,
    required String password,
  }) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authService.signInWithEmailOrUsername(
        emailOrUsername: emailOrUsername,
        password: password,
        firestore: FirebaseFirestore.instance,
      );

      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('force_guest');

      final user = credential.user;
      if (user != null) {
        // Check if there's a pending username from signup
        final pendingUsername = prefs.getString('pending_username_${user.uid}');

        await _ensureUserDocNormalized(user, username: pendingUsername);

        // Create user document if it doesn't exist (for new signups)
        if (pendingUsername != null) {
          await _firestoreService.createUser(
            UserModel(
              id: user.uid,
              name: pendingUsername,
              username: pendingUsername,
              email: user.email ?? '',
              profileUrl: null,
            ),
          );
          await prefs.remove('pending_username_${user.uid}');
        }

        await _persistPresurveyToFirestore(user.uid);

        // ───────────────────────────────────────────────────────────────
        // FIX: Link RevenueCat BEFORE state update to prevent Android race
        // ───────────────────────────────────────────────────────────────
        try {
          await RevenueCatService.login(user.uid);
          print(
            '[AuthNotifier.signInWithEmailOrUsername] ✅ RevenueCat linked to user: ${user.uid}',
          );
        } catch (e) {
          // Non-fatal: RevenueCat failure doesn't block signin
          // Listener will retry on auth state changes
          print(
            '[AuthNotifier.signInWithEmailOrUsername] ⚠️ RevenueCat login failed (non-fatal): $e',
          );
        }
      }

      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Sign in with Google
  /// Returns true if user needs to set username (new user)
  Future<bool> signInWithGoogle() async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authService.signInWithGoogle();
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('force_guest');

      if (credential == null) {
        // User cancelled
        state = AsyncValue.data(_authService.currentUser);
        return false;
      }

      final user = credential.user;
      if (user == null) {
        state = const AsyncValue.data(null);
        return false;
      }
      await _ensureUserDocNormalized(user);
      // Ensure a user doc exists (FirestoreService.createUser is hardened)
      await _firestoreService.createUser(
        UserModel(
          id: user.uid,
          name: user.displayName ?? '',
          username: null,
          email: user.email ?? '',
          profileUrl: user.photoURL,
        ),
      );
      await _persistPresurveyToFirestore(user.uid);

      // ───────────────────────────────────────────────────────────────
      // FIX: Link RevenueCat BEFORE state update to prevent Android race
      // ───────────────────────────────────────────────────────────────
      try {
        await RevenueCatService.login(user.uid);
        print(
          '[AuthNotifier.signInWithGoogle] ✅ RevenueCat linked to user: ${user.uid}',
        );
      } catch (e) {
        // Non-fatal: RevenueCat failure doesn't block signin
        // Listener will retry on auth state changes
        print(
          '[AuthNotifier.signInWithGoogle] ⚠️ RevenueCat login failed (non-fatal): $e',
        );
      }

      final needsUsername = (user.displayName ?? '').trim().isEmpty;
      state = AsyncValue.data(user);
      return needsUsername;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update username for the current user
  Future<void> updateUsername(String username) async {
    final user = _authService.currentUser;
    if (user == null || user.isAnonymous) return;

    final normalized = username.trim();
    if (normalized.isEmpty) return;

    await _firestoreService.updateUserFields(user.uid, {
      'username': normalized,
      // Normalise: lowercase + collapse any multi-space runs
      'username_lower': normalized.toLowerCase().replaceAll(
        RegExp(r'\s+'),
        ' ',
      ),
      'dating.profile.username': normalized,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  /// Sign out
  ///
  /// Cleans up RevenueCat (unlinks store account from this user) and
  /// device-local journey caches before signing out of Firebase Auth.
  /// FCM token cleanup is handled by _cleanupPreviousUser() on next login,
  /// not here, to avoid race conditions with auth state changes.
  Future<void> signOut() async {
    try {
      await RevenueCatService.logout();
    } catch (_) {}
    try {
      await JourneyEntitlementsService().clearAll();
    } catch (_) {}

    await _clearUserLocalData();
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  /// Delete account (deletes both Firestore document and Auth user)
  ///
  /// This performs a complete account deletion with timeouts to prevent hanging:
  /// 1. Clears local caches (journey entitlements, shared prefs)
  /// 2. Deletes Firestore user document
  /// 3. Deletes Firebase Auth user
  /// 4. Logs out from RevenueCat
  /// 5. Updates auth state to null
  Future<void> deleteAccount() async {
    final user = _authService.currentUser;
    if (user == null) {
      print('[AuthNotifier] ⚠️ deleteAccount called but no user found');
      return;
    }

    final userId = user.uid;
    print('[AuthNotifier] 🗑️  Starting account deletion for user: $userId');

    try {
      // Step 1: Clear journey entitlements cache (5 second timeout)
      try {
        await JourneyEntitlementsService().clearAll().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print(
              '[AuthNotifier] ⚠️ Journey entitlements clear timed out (continuing anyway)',
            );
          },
        );
        print('[AuthNotifier] ✅ Journey entitlements cleared');
      } catch (e) {
        print('[AuthNotifier] ⚠️ Failed to clear journey entitlements: $e');
      }

      // Step 2: Clear local user data (5 second timeout)
      try {
        await _clearUserLocalData().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print(
              '[AuthNotifier] ⚠️ Local data clear timed out (continuing anyway)',
            );
          },
        );
        print('[AuthNotifier] ✅ Local user data cleared');
      } catch (e) {
        print('[AuthNotifier] ⚠️ Failed to clear local user data: $e');
      }

      // Step 3: Delete Firestore user document (10 second timeout - critical step)
      try {
        await _firestoreService
            .deleteUser(userId)
            .timeout(
              const Duration(seconds: 10),
              onTimeout: () {
                throw Exception(
                  'Firestore user delete timed out after 10 seconds',
                );
              },
            );
        print('[AuthNotifier] ✅ Firestore user document deleted');
      } catch (e) {
        print('[AuthNotifier] ❌ Error deleting Firestore document: $e');
        // Set state to null immediately on critical failure
        state = const AsyncValue.data(null);
        rethrow;
      }

      // Step 4: Delete Auth user (5 second timeout)
      try {
        await _authService.deleteAccount().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print(
              '[AuthNotifier] ⚠️ Auth delete timed out (may still succeed on server)',
            );
          },
        );
        print('[AuthNotifier] ✅ Firebase Auth user deleted');
      } catch (e) {
        print('[AuthNotifier] ⚠️ Auth delete failed but Firestore done: $e');
        // Don't rethrow - Firestore deletion was successful
      }

      // Step 4b: Sign out locally to clear FirebaseAuth.instance.currentUser.
      // Without this, the cached user survives deletion and the router's
      // loading-branch fallback treats the user as still signed in,
      // sending them to presurvey instead of the welcome screen.
      try {
        await FirebaseAuth.instance.signOut();
      } catch (_) {}

      // Step 5: Logout from RevenueCat (5 second timeout - non-critical)
      try {
        await RevenueCatService.logout().timeout(
          const Duration(seconds: 5),
          onTimeout: () {
            print('[AuthNotifier] ⚠️ RevenueCat logout timed out (continuing)');
          },
        );
        print('[AuthNotifier] ✅ RevenueCat logged out');
      } catch (e) {
        print('[AuthNotifier] ⚠️ RevenueCat logout failed: $e');
        // Don't rethrow - non-critical
      }

      // Step 6: Update auth state to null (immediate - no timeout needed)
      state = const AsyncValue.data(null);
      print('[AuthNotifier] ✅ Auth state cleared - user logged out');
      print(
        '[AuthNotifier] ✅ Account deletion completed successfully for user: $userId',
      );
    } catch (e) {
      // Even if there's an error, set state to null to log user out
      print('[AuthNotifier] ❌ Error during account deletion: $e');
      state = const AsyncValue.data(null);
      rethrow;
    }
  }

  /// Syncs active RevenueCat subscriptions to Firestore
  /// Called after RevenueCat login to ensure v1 users' subscriptions are recognized in v2
  ///
  /// Problem: V1 users have subscriptions in RevenueCat but Firestore `subscription` object
  /// may not be created. This causes them to appear as free users in v2.
  ///
  /// Solution: After linking RevenueCat to the user account, check for active entitlements
  /// and sync them to the v2 `subscription` object in Firestore.
  Future<void> _syncRevenueCatSubscriptionToFirestore(String userId) async {
    try {
      final synced = await RevenueCatService.syncActiveSubscriptionToFirestore(
        userId: userId,
      );

      if (synced) {
        print(
          '[AuthNotifier] ✅ Synced RevenueCat subscription to Firestore for user: $userId',
        );
      } else {
        print(
          '[AuthNotifier] No active RevenueCat subscription found for user: $userId',
        );
      }
    } catch (e) {
      // Non-fatal - log but don't block login
      print('[AuthNotifier] ⚠️ Failed to sync RevenueCat subscription: $e');
    }
  }

  /// Wipe all user-specific SharedPreferences keys so the next account
  /// on this device starts clean.  Keys that are NOT user-scoped but
  /// hold user-specific data are enumerated here.
  Future<void> _clearUserLocalData() async {
    try {
      final prefs = await SharedPreferences.getInstance();

      // Known per-journey prefixed keys (journey_*:)
      const journeyPrefixes = [
        'journey_completed_missions:',
        'journey_last_complete:',
        'journey_streak:',
        'journey_in_progress:',
        'journey_progress::',
      ];

      // Known static keys with user-specific data
      const staticKeys = [
        'journeys.mission_responses.v1',
        'dating_onboarding_draft',
        'presurvey_local_done',
        'activeJourneyId',
        'active_journey_id',
        'activeJourney',
        'active_journey',
        'dating_search_first_completed',
        'preferences_setup_after_status_change',
      ];

      // Remove static keys
      for (final key in staticKeys) {
        await prefs.remove(key);
      }

      // Remove all prefixed journey keys
      final allKeys = prefs.getKeys();
      for (final key in allKeys) {
        for (final prefix in journeyPrefixes) {
          if (key.startsWith(prefix)) {
            await prefs.remove(key);
            break;
          }
        }
      }
    } catch (e) {
      print('[AuthNotifier] _clearUserLocalData error (non-fatal): $e');
    }
  }
}

/// Canonical provider used by UI screens/stubs.
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
      final authService = ref.watch(authServiceProvider);
      final firestoreService = ref.watch(firestoreServiceProvider);
      return AuthNotifier(ref, authService, firestoreService);
    });
