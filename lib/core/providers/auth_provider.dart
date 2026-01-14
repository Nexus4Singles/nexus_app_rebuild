import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/constants/app_constants.dart';
import 'package:nexus_app_min_test/core/session/guest_session_provider.dart';
import 'package:nexus_app_min_test/core/services/firestore_service.dart';

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
  return authState.whenData((user) => user?.uid).value;
});

/// Provider to check if user is authenticated
final isAuthenticatedProvider = Provider<bool>((ref) {
  final authState = ref.watch(authStateProvider);
  return authState.whenData((user) => user != null).value ?? false;
});

class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final Ref _ref;
  final AuthService _authService;
  final FirestoreService _firestoreService;

  AuthNotifier(this._ref, this._authService, this._firestoreService)
    : super(const AsyncValue.loading()) {
    _authService.authStateChanges.listen((user) {
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

    await _firestoreService.updateUserFields(uid, payload);
  }

  /// Sign up with email and create user document (merge-safe; won't overwrite v1 users)
  Future<void> signUpWithEmail({
    required String email,
    required String password,
    required String username,
  }) async {
    state = const AsyncValue.loading();
    try {
      final credential = await _authService.signUpWithEmail(
        email: email,
        password: password,
      );

      final user = credential.user;
      if (user != null) {
        // Create doc only if it doesn't exist (FirestoreService.createUser is hardened)
        await _firestoreService.createUser(
          UserModel(
            id: user.uid,
            name: username,
            username: username,
            email: email,
            profileUrl: null,
          ),
        );

        // Attach presurvey -> nexus fields (merge-safe)
        await _persistPresurveyToFirestore(user.uid);
      }

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

      final user = credential.user;
      if (user != null) {
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

      // Ensure a user doc exists (won't overwrite v1 docs)
      final existingUser = await _firestoreService.getUser(user.uid);
      if (existingUser == null) {
        await _firestoreService.createUser(
          UserModel(
            id: user.uid,
            name: user.displayName ?? '',
            username: null,
            email: user.email ?? '',
            profileUrl: user.photoURL,
          ),
        );
      }

      await _persistPresurveyToFirestore(user.uid);

      final needsUsername =
          (existingUser?.username == null || existingUser!.username!.isEmpty);
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
    if (user == null) return;

    await _firestoreService.updateUserFields(user.uid, {
      'username': username,
      'name': username,
    });
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

  /// Delete account
  Future<void> deleteAccount() async {
    await _authService.deleteAccount();
    state = const AsyncValue.data(null);
  }
}

/// Canonical provider used by UI screens/stubs.
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
      final authService = ref.watch(authServiceProvider);
      final firestoreService = ref.watch(firestoreServiceProvider);
      return AuthNotifier(ref, authService, firestoreService);
    });
