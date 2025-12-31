import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexus_app_min_test/core/services/firestore_service.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/auth_service.dart';
import 'firestore_service_provider.dart';
import '../models/user_model.dart';

/// Provider for AuthService instance
final authServiceProvider = Provider<AuthService>((ref) {
  return AuthService();
});

/// Provider for FirestoreService instance
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

/// State notifier for auth operations
class AuthNotifier extends StateNotifier<AsyncValue<User?>> {
  final AuthService _authService;
  final FirestoreService _firestoreService;

  AuthNotifier(this._authService, this._firestoreService)
      : super(const AsyncValue.loading()) {
    // Initialize with current auth state
    _init();
  }

  void _init() {
    _authService.authStateChanges.listen((user) {
      state = AsyncValue.data(user);
    });
  }

  /// Sign up with email and create user document
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

      // Create initial user document with username
      if (credential.user != null) {
        final user = UserModel(
          id: credential.user!.uid,
          username: username,
          name: username, // Also set name to username for display
          email: email,
        );
        await _firestoreService.createUser(user);
      }

      state = AsyncValue.data(credential.user);
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
      state = AsyncValue.data(credential.user);
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
      if (credential != null) {
        // Check if this is a new user
        final uid = credential.user!.uid;
        final existingUser = await _firestoreService.getUser(uid);

        if (existingUser == null) {
          // Create new user document for Google sign-in
          // Don't set username yet - will be prompted
          final user = UserModel(
            id: uid,
            name: credential.user!.displayName ?? '',
            email: credential.user!.email ?? '',
            profileUrl: credential.user!.photoURL,
          );
          await _firestoreService.createUser(user);

          state = AsyncValue.data(credential.user);
          return true; // Needs username
        } else if (existingUser.username == null || existingUser.username!.isEmpty) {
          // Existing user but no username set
          state = AsyncValue.data(credential.user);
          return true; // Needs username
        }

        state = AsyncValue.data(credential.user);
        return false; // Has username
      } else {
        // User cancelled
        state = AsyncValue.data(_authService.currentUser);
        return false;
      }
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
      'name': username, // Also update name for display
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

/// Provider for auth notifier
final authNotifierProvider =
    StateNotifierProvider<AuthNotifier, AsyncValue<User?>>((ref) {
  final authService = ref.watch(authServiceProvider);
  final firestoreService = ref.watch(firestoreServiceProvider);
  return AuthNotifier(authService, firestoreService);
});
