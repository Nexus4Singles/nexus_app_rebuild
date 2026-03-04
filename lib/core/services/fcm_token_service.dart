import 'dart:io';
import 'dart:async';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Unified FCM Token Service - Single source of truth for push notification tokens
///
/// This service handles:
/// - iOS APNs token setup (CRITICAL for iOS notifications)
/// - Token generation and refresh
/// - Firestore persistence with retries
/// - User lifecycle (login/logout/switch)
/// - Race condition prevention
/// - Comprehensive logging
class FcmTokenService {
  static final FcmTokenService _instance = FcmTokenService._internal();

  factory FcmTokenService() {
    return _instance;
  }

  FcmTokenService._internal();

  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _currentUserId;
  String? _currentToken;
  StreamSubscription<String>? _tokenRefreshSubscription;
  bool _initialized = false;

  // Configuration constants
  static const Duration _tokenFetchTimeout = Duration(seconds: 10);
  static const Duration _apnsTimeout = Duration(seconds: 60);
  static const int _maxRetries = 3;
  static const Duration _retryDelay = Duration(milliseconds: 500);
  static const int _minTokenLength = 50; // FCM tokens are typically 152+ chars

  /// Get current FCM token (cached)
  String? get currentToken => _currentToken;

  /// Get current user ID being tracked
  String? get currentUserId => _currentUserId;

  /// Check if service is initialized
  bool get isInitialized => _initialized;

  /// Initialize FCM service with APNs setup for iOS
  ///
  /// This MUST be called early in app startup, before any token operations.
  /// On iOS, this waits for APNs token availability.
  Future<void> initialize() async {
    if (_initialized) {
      _logInfo('Service already initialized, skipping re-initialization');
      return;
    }

    _logInfo('Starting FCM initialization...');
    _initialized = true;

    try {
      // Step 1: Request notification permissions (iOS & Android)
      _logInfo('Requesting notification permissions...');
      final settings = await _messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
        provisional: false,
      );

      final authorized =
          settings.authorizationStatus == AuthorizationStatus.authorized;
      final provisional =
          settings.authorizationStatus == AuthorizationStatus.provisional;

      if (!authorized && !provisional) {
        _logWarning('User denied notification permissions');
        return;
      }

      _logInfo(
        'Permissions granted (authorized: $authorized, provisional: $provisional)',
      );

      // Step 2: On iOS, explicitly enable APNs if not already done
      if (Platform.isIOS) {
        _logInfo('Platform is iOS - setting up APNs...');
        await _setupApnsToken();
      }

      // Note: Message display handlers (foreground, background tap, navigation)
      // are handled by NotificationService, NOT this service.
      // This service is ONLY responsible for token management.

      _logInfo('✅ FCM token service initialization complete');
    } catch (e) {
      _logError('Failed to initialize FCM', e);
      _initialized = false;
      rethrow;
    }
  }

  /// iOS-specific: Setup APNs token
  ///
  /// On iOS, Firebase requires APNs token to be registered before generating FCM token.
  /// This method:
  /// 1. Waits for the system to issue an APNs token
  /// 2. Registers it with Firebase
  /// 3. Handles timeout gracefully
  Future<void> _setupApnsToken() async {
    try {
      _logInfo('Waiting for APNs token (max 60s)...');

      // The messaging SDK handles APNs token automatically on iOS,
      // but we need to ensure it's registered. We do this by attempting
      // token retrieval with a long timeout.
      final token = await _messaging.getToken().timeout(
        const Duration(seconds: 5),
        onTimeout: () => null,
      );

      if (token != null) {
        _logInfo('Got APNs-backed FCM token immediately');
        _currentToken = token;
        return;
      }

      // If token not immediately available, wait for refresh event
      _logInfo('Waiting for APNs registration event...');
      final completer = Completer<void>();
      StreamSubscription<String>? subscription;

      subscription = _messaging.onTokenRefresh.listen(
        (token) {
          _logInfo('Received initial APNs token event');
          _currentToken = token;
          subscription?.cancel();
          completer.complete();
        },
        onError: (e) {
          _logError('Error waiting for APNs token', e);
          subscription?.cancel();
          completer.completeError(e);
        },
      );

      await completer.future.timeout(
        _apnsTimeout,
        onTimeout: () {
          subscription?.cancel();
          _logWarning(
            'Timeout waiting for APNs token (60s). '
            'Device may not have APNs certificate. '
            'Proceeding anyway - notifications may fail on this device.',
          );
        },
      );
    } catch (e) {
      _logWarning('APNs setup failed (non-fatal): $e');
      // Non-fatal - continue anyway
    }
  }

  /// Handle user login - ensure fresh token for this user
  ///
  /// This:
  /// 1. Cleans up previous user's state
  /// 2. Gets fresh token for new user
  /// 3. Saves to Firestore with retry
  /// 4. Sets up refresh listener
  Future<void> handleUserLogin(String userId) async {
    _logInfo('User logging in: $userId');

    try {
      // If switching users, clean up previous user first
      if (_currentUserId != null && _currentUserId != userId) {
        _logInfo(
          'Switching users (${_currentUserId} → $userId), cleaning up...',
        );
        await _cleanupPreviousUser();
      }

      _currentUserId = userId;

      // Get fresh token for this user
      _currentToken = await _getTokenWithRetry();

      if (_currentToken == null) {
        _logError('Failed to obtain FCM token for user: $userId', null);
        return;
      }

      // Validate token format
      if (!_isValidToken(_currentToken!)) {
        _logError(
          'Token validation failed (invalid format): ${_currentToken?.substring(0, 20)}...',
          null,
        );
        _currentToken = null;
        return;
      }

      // Save token to Firestore with retry
      await _saveTokenToFirestoreWithRetry(userId, _currentToken!);

      // Set up token refresh listener for this user
      _setupTokenRefreshListener(userId);

      _logInfo('✅ User login completed successfully for: $userId');
    } catch (e) {
      _logError('Error during user login', e);
      rethrow;
    }
  }

  /// Handle user logout - cleanup local state and listeners only
  ///
  /// NOTE: This does NOT delete the token from Firestore because the user
  /// is already signed out at this point (Firestore rules would reject it).
  /// Instead, the token in Firestore is overwritten on next login via
  /// handleUserLogin() which saves a fresh token.
  Future<void> handleUserLogout() async {
    if (_currentUserId == null) {
      _logInfo('No user to logout');
      return;
    }

    _logInfo('User logging out: $_currentUserId');

    try {
      // Cancel token refresh listener
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;
      _logInfo('Token refresh listener cancelled');

      // Clear local state only — do NOT attempt Firestore delete here
      // (user is already signed out, Firestore rules would reject it)
      _currentUserId = null;
      _currentToken = null;
      // NOTE: Do NOT reset _initialized here.
      // The initialize() method sets up APNs and permissions which are
      // global/device-level and don't need re-initialization per user.
      // handleUserLogin() already handles per-user token setup.

      _logInfo('✅ Logout completed (local cleanup only)');
    } catch (e) {
      _logError('Error during logout', e);
      // Don't rethrow - logout should succeed even if cleanup fails
    }
  }

  /// Setup listener for FCM token refreshes
  ///
  /// This listens for when Firebase issues a new token and saves it.
  /// Properly scoped to current user to prevent contamination.
  void _setupTokenRefreshListener(String userId) {
    // Cancel any previous listener
    _tokenRefreshSubscription?.cancel();

    _logInfo('Setting up token refresh listener for user: $userId');

    _tokenRefreshSubscription = _messaging.onTokenRefresh.listen((newToken) {
      // Validate user hasn't changed since listener was set up
      if (_currentUserId != userId) {
        _logWarning(
          'Ignoring token refresh: user has changed '
          '(was $userId, now $_currentUserId)',
        );
        return;
      }

      if (!_isValidToken(newToken)) {
        _logError(
          'Token refresh validation failed: ${newToken.substring(0, 20)}...',
          null,
        );
        return;
      }

      _logInfo('Token refreshed, saving new token');
      _currentToken = newToken;
      _saveTokenToFirestoreWithRetry(
        userId,
        newToken,
      ).catchError((e) => _logError('Failed to save refreshed token', e));
    }, onError: (e) => _logError('Token refresh listener error', e));
  }

  /// Get token with retry logic
  ///
  /// Retries up to 3 times with 500ms delay between attempts.
  /// Returns null if all retries fail.
  Future<String?> _getTokenWithRetry() async {
    _logInfo('Fetching FCM token (with retries)...');

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        final token = await _messaging.getToken().timeout(_tokenFetchTimeout);

        if (token != null && token.isNotEmpty) {
          _logInfo(
            '✅ Token obtained on attempt $attempt: ${token.substring(0, 20)}...',
          );
          return token;
        }

        _logWarning('Attempt $attempt: token was null/empty');

        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay);
        }
      } catch (e) {
        _logWarning('Attempt $attempt failed: $e');

        if (attempt < _maxRetries) {
          await Future.delayed(_retryDelay);
        }
      }
    }

    _logError('Failed to obtain token after $_maxRetries attempts', null);
    return null;
  }

  /// Save token to Firestore with retry logic
  ///
  /// Saves to a consistent format and retries on failure.
  Future<void> _saveTokenToFirestoreWithRetry(
    String userId,
    String token,
  ) async {
    _logInfo('Saving token to Firestore for user: $userId');

    for (int attempt = 1; attempt <= _maxRetries; attempt++) {
      try {
        await _firestore.collection('users').doc(userId).set({
          'fcmToken': token, // Standard field - always string
          'fcmTokenPlatform': Platform.isIOS ? 'ios' : 'android',
          'fcmTokenUpdatedAt': FieldValue.serverTimestamp(),
          'fcmTokenValid': true, // Flag for Cloud Functions to verify
        }, SetOptions(merge: true));

        _logInfo('✅ Token saved successfully on attempt $attempt');
        return;
      } catch (e) {
        _logWarning('Attempt $attempt to save token failed: $e');

        if (attempt < _maxRetries) {
          await Future.delayed(const Duration(milliseconds: 300));
        }
      }
    }

    _logError('Failed to save token after $_maxRetries attempts', null);
    // Don't throw - non-critical (will retry on next refresh)
  }

  /// Delete token fields from Firestore for a given user
  /// Only called while the user is still authenticated (e.g. during user switch)
  Future<void> _deleteTokenFromFirestore(String userId) async {
    try {
      await _firestore.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
        'fcmTokenPlatform': FieldValue.delete(),
        'fcmTokenUpdatedAt': FieldValue.delete(),
        'fcmTokenValid': FieldValue.delete(),
      });
      _logInfo('Token deleted from Firestore for user: $userId');
    } catch (e) {
      _logWarning('Failed to delete token from Firestore: $e');
    }
  }

  /// Public method to cleanup a user's token when they login (to prevent stale tokens)
  /// This is called from _cleanupPreviousUser() which runs BEFORE the new user's token is saved
  /// This ensures we clean up any old token while the previous user session is still active
  /// No more permission-denied errors because cleanup happens during login, not logout
  Future<void> cleanupUserTokenIfExists(String userId) async {
    if (userId.isEmpty) return;

    _logInfo('Cleaning up any existing token for user: $userId');

    try {
      await _deleteTokenFromFirestore(userId);
    } catch (e) {
      // Non-critical - if cleanup fails, we'll just overwrite the old token anyway
      _logWarning('Could not cleanup old token for $userId (non-critical): $e');
    }
  }

  /// Clean up previous user's token
  Future<void> _cleanupPreviousUser() async {
    if (_currentUserId == null) return;

    try {
      // Cancel listener to prevent cross-contamination
      await _tokenRefreshSubscription?.cancel();
      _tokenRefreshSubscription = null;

      // Delete old token from Firestore
      await _deleteTokenFromFirestore(_currentUserId!);

      // Force delete the token from Firebase (optional but recommended)
      try {
        await _messaging.deleteToken();
      } catch (e) {
        _logWarning('Could not delete old Firebase token: $e');
      }

      _logInfo('Cleanup completed for previous user: $_currentUserId');
    } catch (e) {
      _logError('Error cleaning up previous user', e);
    }
  }

  /// Validate token format
  bool _isValidToken(String token) {
    return token.isNotEmpty && token.length >= _minTokenLength;
  }

  // ============================================================================
  // LOGGING
  // ============================================================================

  void _logInfo(String message) {
    print('[FCM Service] ℹ️ $message');
  }

  void _logWarning(String message) {
    print('[FCM Service] ⚠️  $message');
  }

  void _logError(String message, Object? error) {
    print('[FCM Service] ❌ $message${error != null ? ': $error' : ''}');
  }
}
