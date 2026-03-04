import 'package:flutter/foundation.dart';
import 'package:nexus_app_v2/core/auth/firebase_auth_import.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service for Firebase Authentication operations.
/// Currently supports email/password auth. Google Sign-In can be enabled later.
class AuthService {
  final FirebaseAuth _auth;

  AuthService({FirebaseAuth? auth}) : _auth = auth ?? FirebaseAuth.instance;

  /// Get current user
  User? get currentUser => _auth.currentUser;

  /// Get current user ID
  String? get currentUserId => _auth.currentUser?.uid;

  /// Check if user is signed in
  bool get isSignedIn => _auth.currentUser != null;

  /// Stream of auth state changes
  Stream<User?> get authStateChanges => _auth.authStateChanges();

  /// Stream of user changes
  Stream<User?> get userChanges => _auth.userChanges();

  /// Check if Google Sign-In is available (disabled until configured)
  bool get isGoogleSignInAvailable => false;

  // ==================== EMAIL/PASSWORD AUTH ====================

  /// Sign up with email and password
  Future<UserCredential> signUpWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseAuth(e);
    } catch (e) {
      throw AuthException('Sign up failed: $e');
    }
  }

  /// Sign in with email and password
  Future<UserCredential> signInWithEmail({
    required String email,
    required String password,
  }) async {
    try {
      return await _auth.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseAuth(e);
    } catch (e) {
      throw AuthException('Sign in failed: $e');
    }
  }

  /// Sign in with email or username (converts username to email via Firestore lookup)
  Future<UserCredential> signInWithEmailOrUsername({
    required String emailOrUsername,
    required String password,
    required FirebaseFirestore firestore,
  }) async {
    try {
      // If email format, use directly
      if (emailOrUsername.contains('@')) {
        debugPrint(
          '✅ DEBUG: Input is email format, using directly: "$emailOrUsername"',
        );
        debugPrint(
          '🔐 DEBUG: Attempting Firebase Auth sign-in with email: "$emailOrUsername"',
        );
        return await _auth.signInWithEmailAndPassword(
          email: emailOrUsername,
          password: password,
        );
      }

      // Username lookup - try to authenticate with all matching usernames
      debugPrint('🔍 DEBUG: Looking up username: "$emailOrUsername"');

      final emailsToTry = <String>[];
      // Normalise: lowercase, trim, collapse multiple spaces to single space
      final lowerInput = emailOrUsername.toLowerCase().trim().replaceAll(
        RegExp(r'\s+'),
        ' ',
      );

      try {
        final usersRef = firestore.collection('users');

        // Collect all possible email matches for this username/displayName
        // NOTE: We query ALL matches (no .limit(1)) to handle potential duplicate usernames
        // Then we try authentication with each email until one succeeds

        // 1. Try case-insensitive lookup via username_lower field (preferred)
        print('🔍 DEBUG: Querying username_lower for: "$lowerInput"');
        var query =
            await usersRef.where('username_lower', isEqualTo: lowerInput).get();

        print(
          '🔍 DEBUG: username_lower query returned ${query.docs.length} documents',
        );

        for (final doc in query.docs) {
          final email = doc['email'] as String?;
          if (email != null && email.isNotEmpty) {
            emailsToTry.add(email);
          }
        }

        // 2. Fallback: exact match by username (for users without username_lower)
        if (emailsToTry.isEmpty) {
          print('🔍 DEBUG: Trying exact username match: "$emailOrUsername"');
          query =
              await usersRef
                  .where('username', isEqualTo: emailOrUsername)
                  .get();
          print(
            '🔍 DEBUG: Exact username query returned ${query.docs.length} documents',
          );

          for (final doc in query.docs) {
            final email = doc['email'] as String?;
            if (email != null && email.isNotEmpty) {
              emailsToTry.add(email);
            }
            // Backfill username_lower for this user so future logins are faster
            try {
              final storedUsername = (doc['username'] ?? '').toString();
              if (storedUsername.isNotEmpty && doc['username_lower'] == null) {
                doc.reference.update({
                  'username_lower': storedUsername
                      .trim()
                      .toLowerCase()
                      .replaceAll(RegExp(r'\s+'), ' '),
                });
              }
            } catch (_) {}
          }
        }

        // 3. Fallback: exact match by displayName
        if (emailsToTry.isEmpty) {
          print('🔍 DEBUG: Trying displayName match: "$emailOrUsername"');
          query =
              await usersRef
                  .where('displayName', isEqualTo: emailOrUsername)
                  .get();
          print(
            '🔍 DEBUG: DisplayName query returned ${query.docs.length} documents',
          );

          for (final doc in query.docs) {
            final email = doc['email'] as String?;
            if (email != null && email.isNotEmpty) {
              emailsToTry.add(email);
            }
          }
        }

        // 4. Fallback: try case-insensitive match by querying stored lowercase username
        if (emailsToTry.isEmpty) {
          print('🔍 DEBUG: Trying lowercase username match: "$lowerInput"');
          query = await usersRef.where('username', isEqualTo: lowerInput).get();
          print(
            '🔍 DEBUG: Lowercase username query returned ${query.docs.length} documents',
          );

          for (final doc in query.docs) {
            final email = doc['email'] as String?;
            if (email != null && email.isNotEmpty) {
              emailsToTry.add(email);
            }
          }
        }

        // 5. Fallback: try lowercase displayName
        if (emailsToTry.isEmpty) {
          print('🔍 DEBUG: Trying lowercase displayName match: "$lowerInput"');
          query =
              await usersRef.where('displayName', isEqualTo: lowerInput).get();
          print(
            '🔍 DEBUG: Lowercase displayName query returned ${query.docs.length} documents',
          );

          for (final doc in query.docs) {
            final email = doc['email'] as String?;
            if (email != null && email.isNotEmpty) {
              emailsToTry.add(email);
            }
          }
        }

        if (emailsToTry.isEmpty) {
          print('❌ DEBUG: No user found with username: "$emailOrUsername"');
          throw AuthException('Username not found');
        }

        print(
          '🔍 DEBUG: Found ${emailsToTry.length} potential email(s) to try: $emailsToTry',
        );

        // Try authentication with each email until one succeeds
        UserCredential? lastCredential;
        FirebaseAuthException? lastAuthError;

        for (int i = 0; i < emailsToTry.length; i++) {
          final emailToTry = emailsToTry[i];
          print(
            '🔐 DEBUG: Attempt ${i + 1}/${emailsToTry.length} - Sign in with email: "$emailToTry"',
          );

          try {
            lastCredential = await _auth.signInWithEmailAndPassword(
              email: emailToTry,
              password: password,
            );
            print(
              '✅ DEBUG: Successfully authenticated with email: "$emailToTry"',
            );
            return lastCredential;
          } on FirebaseAuthException catch (e) {
            print(
              '❌ DEBUG: Authentication failed for "$emailToTry": ${e.code} - ${e.message}',
            );
            lastAuthError = e;
            // Continue to next email
          }
        }

        // All authentication attempts failed
        if (lastAuthError != null) {
          print(
            '❌ DEBUG: All ${emailsToTry.length} authentication attempts failed',
          );
          throw AuthException.fromFirebaseAuth(lastAuthError);
        }

        throw AuthException(
          'Authentication failed for username: "$emailOrUsername"',
        );
      } catch (e) {
        print('❌ DEBUG: Username lookup/authentication error: $e');
        if (e is AuthException) rethrow;
        throw AuthException('Failed to authenticate with username: $e');
      }
    } on FirebaseAuthException catch (e) {
      print('❌ DEBUG: Firebase Auth error: ${e.code} - ${e.message}');
      throw AuthException.fromFirebaseAuth(e);
    } catch (e) {
      print('❌ DEBUG: Sign in failed: $e');
      if (e is AuthException) rethrow;
      throw AuthException('Sign in failed: $e');
    }
  }

  /// Send password reset email
  Future<void> sendPasswordResetEmail(String email) async {
    try {
      await _auth.sendPasswordResetEmail(email: email);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseAuth(e);
    } catch (e) {
      throw AuthException('Password reset failed: $e');
    }
  }

  /// Update password (requires recent login)
  Future<void> updatePassword(String newPassword) async {
    try {
      await _auth.currentUser?.updatePassword(newPassword);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseAuth(e);
    } catch (e) {
      throw AuthException('Password update failed: $e');
    }
  }

  /// Verify current password
  Future<bool> verifyPassword(String password) async {
    try {
      final user = _auth.currentUser;
      if (user == null || user.email == null) return false;

      final credential = EmailAuthProvider.credential(
        email: user.email!,
        password: password,
      );
      await user.reauthenticateWithCredential(credential);
      return true;
    } catch (e) {
      return false;
    }
  }

  // ==================== GOOGLE SIGN IN (DISABLED) ====================

  /// Sign in with Google - disabled until configured
  Future<UserCredential?> signInWithGoogle() async {
    throw AuthException('Google Sign-In is not yet configured.');
  }

  /// Check if Google is linked
  bool get isGoogleLinked {
    return _auth.currentUser?.providerData.any(
          (p) => p.providerId == 'google.com',
        ) ??
        false;
  }

  // ==================== ACCOUNT MANAGEMENT ====================

  /// Sign out
  Future<void> signOut() async {
    try {
      await _auth.signOut();
    } catch (e) {
      throw AuthException('Sign out failed: $e');
    }
  }

  /// Delete account
  Future<void> deleteAccount() async {
    try {
      await _auth.currentUser?.delete();
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseAuth(e);
    } catch (e) {
      throw AuthException('Account deletion failed: $e');
    }
  }

  /// Update email
  Future<void> updateEmail(String newEmail) async {
    try {
      await _auth.currentUser?.verifyBeforeUpdateEmail(newEmail);
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseAuth(e);
    } catch (e) {
      throw AuthException('Email update failed: $e');
    }
  }

  /// Send email verification
  Future<void> sendEmailVerification() async {
    try {
      await _auth.currentUser?.sendEmailVerification();
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseAuth(e);
    } catch (e) {
      throw AuthException('Email verification failed: $e');
    }
  }

  /// Check if email is verified
  bool get isEmailVerified => _auth.currentUser?.emailVerified ?? false;

  /// Reload user
  Future<void> reloadUser() async {
    await _auth.currentUser?.reload();
  }
}

/// Custom exception for authentication errors
class AuthException implements Exception {
  final String message;
  final String? code;

  AuthException(this.message, {this.code});

  factory AuthException.fromFirebaseAuth(FirebaseAuthException e) {
    String message;
    switch (e.code) {
      case 'user-not-found':
        message = 'No account found with this email.';
        break;
      case 'wrong-password':
        message = 'Incorrect password.';
        break;
      case 'email-already-in-use':
        message = 'An account already exists with this email.';
        break;
      case 'invalid-email':
        message = 'Please enter a valid email address.';
        break;
      case 'weak-password':
        message = 'Password must be at least 6 characters.';
        break;
      case 'user-disabled':
        message = 'This account has been disabled.';
        break;
      case 'too-many-requests':
        message = 'Too many attempts. Please try again later.';
        break;
      case 'operation-not-allowed':
        message = 'This sign-in method is not enabled.';
        break;
      case 'requires-recent-login':
        message = 'Please sign in again to complete this action.';
        break;
      case 'invalid-credential':
        message = 'Invalid credentials. Please try again.';
        break;
      case 'network-request-failed':
        message = 'Network error. Please check your connection.';
        break;
      default:
        message = e.message ?? 'Authentication failed. Please try again.';
    }
    return AuthException(message, code: e.code);
  }

  @override
  String toString() => message;
}
