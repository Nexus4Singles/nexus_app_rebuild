import 'package:nexus_app_min_test/core/stubs/firebase_auth_import.dart';
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
      String actualEmail = emailOrUsername;

      // If not an email format, look up username in Firestore
      if (!emailOrUsername.contains('@')) {
        try {
          final usersRef = firestore.collection('users');
          final query =
              await usersRef
                  .where('username', isEqualTo: emailOrUsername.toLowerCase())
                  .limit(1)
                  .get();

          if (query.docs.isEmpty) {
            throw AuthException('Username not found');
          }

          final userEmail = query.docs.first.data()['email'] as String?;
          if (userEmail == null) {
            throw AuthException('User email not found');
          }
          actualEmail = userEmail;
        } catch (e) {
          if (e is AuthException) rethrow;
          throw AuthException('Failed to look up username: $e');
        }
      }

      return await _auth.signInWithEmailAndPassword(
        email: actualEmail,
        password: password,
      );
    } on FirebaseAuthException catch (e) {
      throw AuthException.fromFirebaseAuth(e);
    } catch (e) {
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
