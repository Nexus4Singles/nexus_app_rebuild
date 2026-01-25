import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/constants/app_constants.dart';
import 'package:nexus_app_min_test/core/session/guest_session_provider.dart';
import 'package:nexus_app_min_test/core/user/user_schema_migrator.dart';
import 'package:nexus_app_min_test/core/services/firestore_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../models/user_model.dart';
import '../services/auth_service.dart';
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

  Future<void> _ensureUserDocNormalized(User user) async {
    final uid = user.uid;
    final docRef = FirebaseFirestore.instance.collection('users').doc(uid);

    final snap = await docRef.get();
    final raw = (snap.data() ?? <String, dynamic>{});

    // If missing doc entirely, create a minimal v2-compatible base doc (merge-safe).
    if (!snap.exists) {
      // Try to load pending username from SharedPreferences (set during signup)
      String? pendingUsername;
      try {
        final prefs = await SharedPreferences.getInstance();
        pendingUsername = prefs.getString('pending_username_$uid');
      } catch (_) {
        // Ignore prefs errors
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
        base['username'] = pendingUsername.trim();
        base['name'] = pendingUsername.trim();
        base['displayName'] = pendingUsername.trim();
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
    final patch = buildUserV2Patch(
      uid: uid,
      raw: raw,
      fallbackEmail: user.email,
      fallbackDisplayName: user.displayName,
      fallbackPhotoUrl: user.photoURL,
    );

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

      // Store username in SharedPreferences for later (when creating Firestore document)
      await prefs.setString('pending_username_${user.uid}', username);

      // Create the Firestore document immediately so profile screen can access it
      await _ensureUserDocNormalized(user);

      // Also persist presurvey data
      await _persistPresurveyToFirestore(user.uid);

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
        await _ensureUserDocNormalized(user);

        await _persistPresurveyToFirestore(user.uid);
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

        await _ensureUserDocNormalized(user);

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
    // TODO: Wire to Firestore once FirestoreService exposes an update method.
    // Keeping as no-op for now to avoid compile errors.
    return;
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    await _authService.sendPasswordResetEmail(email);
  }

  /// Sign out
  Future<void> signOut() async {
    await _authService.signOut();
    state = const AsyncValue.data(null);
  }

  /// Delete account (deletes both Firestore document and Auth user)
  Future<void> deleteAccount() async {
    final user = _authService.currentUser;
    if (user == null) return;

    try {
      // First delete Firestore document
      // This triggers Cloud Function to delete Auth user
      await _firestoreService.deleteUser(user.uid);

      // Then delete Auth user (redundant but ensures deletion even if Cloud Function fails)
      await _authService.deleteAccount();

      state = const AsyncValue.data(null);
    } catch (e) {
      // Even if there's an error, set state to null to log user out
      state = const AsyncValue.data(null);
      rethrow;
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
