import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/stubs/firebase_exceptions_stub.dart';
// firebase removed (stubbed)

import '../theme/app_colors.dart';

// ============================================================================
// ERROR TYPES
// ============================================================================

/// Support email for error messages
const String supportEmail = 'nexusgodlydating@gmail.com';

/// Base class for app errors
abstract class AppError implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  final String? userAction; // Suggested action for the user

  AppError(this.message, {this.code, this.originalError, this.userAction});

  @override
  String toString() => message;
}

/// Network-related errors
class NetworkError extends AppError {
  NetworkError([String? message]) 
      : super(
          message ?? 'Unable to connect. Please check your internet connection and try again.',
          userAction: 'Check your Wi-Fi or mobile data connection.',
        );
}

/// Authentication errors
class AuthError extends AppError {
  AuthError(String message, {String? code, String? userAction}) 
      : super(message, code: code, userAction: userAction);

  factory AuthError.fromFirebaseAuth(FirebaseAuthException e) {
    switch (e.code) {
      case 'user-not-found':
        return AuthError(
          'We couldn\'t find an account with this email address.',
          code: e.code,
          userAction: 'Please check your email or create a new account.',
        );
      case 'wrong-password':
        return AuthError(
          'The password you entered is incorrect.',
          code: e.code,
          userAction: 'Try again or tap "Forgot Password" to reset it.',
        );
      case 'email-already-in-use':
        return AuthError(
          'An account already exists with this email.',
          code: e.code,
          userAction: 'Try logging in instead, or use a different email.',
        );
      case 'weak-password':
        return AuthError(
          'Your password is too weak.',
          code: e.code,
          userAction: 'Use at least 8 characters with a mix of letters and numbers.',
        );
      case 'invalid-email':
        return AuthError(
          'The email address format is invalid.',
          code: e.code,
          userAction: 'Please enter a valid email address.',
        );
      case 'user-disabled':
        return AuthError(
          'This account has been disabled.',
          code: e.code,
          userAction: 'Please contact support for assistance.',
        );
      case 'too-many-requests':
        return AuthError(
          'Too many failed attempts.',
          code: e.code,
          userAction: 'Please wait a few minutes before trying again.',
        );
      case 'network-request-failed':
        return AuthError(
          'Unable to connect to the server.',
          code: e.code,
          userAction: 'Please check your internet connection.',
        );
      case 'invalid-credential':
        return AuthError(
          'Your login credentials are invalid or have expired.',
          code: e.code,
          userAction: 'Please try logging in again.',
        );
      default:
        return AuthError(
          e.message ?? 'Authentication failed. Please try again.',
          code: e.code,
        );
    }
  }
}

/// Firestore/Database errors
class DatabaseError extends AppError {
  DatabaseError(String message, {String? code, String? userAction}) 
      : super(message, code: code, userAction: userAction);

  factory DatabaseError.fromFirestore(FirebaseException e) {
    switch (e.code) {
      case 'permission-denied':
        return DatabaseError(
          'You don\'t have access to this content.',
          code: e.code,
          userAction: 'This might be premium content. Check your subscription status.',
        );
      case 'not-found':
        return DatabaseError(
          'The content you\'re looking for doesn\'t exist.',
          code: e.code,
          userAction: 'It may have been removed or the link is incorrect.',
        );
      case 'unavailable':
        return DatabaseError(
          'Our service is temporarily unavailable.',
          code: e.code,
          userAction: 'Please try again in a few moments.',
        );
      case 'deadline-exceeded':
        return DatabaseError(
          'The request took too long to complete.',
          code: e.code,
          userAction: 'Please check your connection and try again.',
        );
      default:
        return DatabaseError(
          'Something went wrong while loading your data.',
          code: e.code,
          userAction: 'Please try again. If the problem persists, contact support.',
        );
    }
  }
}

/// Validation errors
class ValidationError extends AppError {
  final String field;

  ValidationError(String message, {required this.field}) : super(message);
}

/// Permission errors
class PermissionError extends AppError {
  PermissionError(String message, {String? userAction}) 
      : super(message, userAction: userAction);
}

/// Subscription/Premium errors
class SubscriptionError extends AppError {
  SubscriptionError(String message, {String? userAction}) 
      : super(
          message,
          userAction: userAction ?? 'Check your subscription in Settings.',
        );
}

// ============================================================================
// ERROR HANDLER SERVICE
// ============================================================================

/// Service for handling errors globally
class ErrorHandlerService {
  /// Handle an error and return a user-friendly message
  String handleError(dynamic error) {
    if (error is AppError) {
      return error.message;
    }

    if (error is FirebaseAuthException) {
      return AuthError.fromFirebaseAuth(error).message;
    }

    if (error is FirebaseException) {
      return DatabaseError.fromFirestore(error).message;
    }

    if (error is TimeoutException) {
      return 'The request timed out. Please check your connection and try again.';
    }

    // Check for common error patterns
    final errorString = error.toString().toLowerCase();
    if (errorString.contains('socket') || 
        errorString.contains('network') || 
        errorString.contains('connection')) {
      return 'Unable to connect. Please check your internet connection.';
    }

    // Generic error - user-friendly
    return 'Something unexpected happened. Please try again.';
  }

  /// Get user action suggestion for an error
  String? getUserAction(dynamic error) {
    if (error is AppError && error.userAction != null) {
      return error.userAction;
    }
    return null;
  }

  /// Log error for debugging
  void logError(dynamic error, [StackTrace? stackTrace]) {
    // In debug mode, print to console
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    debugPrint('ERROR: $error');
    if (error is AppError && error.code != null) {
      debugPrint('CODE: ${error.code}');
    }
    if (stackTrace != null) {
      debugPrint('STACK TRACE:');
      debugPrint(stackTrace.toString());
    }
    debugPrint('━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━');
    
    // TODO: In production, send to Firebase Crashlytics:
    // FirebaseCrashlytics.instance.recordError(error, stackTrace);
  }

  /// Show error snackbar with optional contact support action
  void showErrorSnackBar(
    BuildContext context, 
    dynamic error, {
    bool showContactSupport = false,
    VoidCallback? onRetry,
  }) {
    final message = handleError(error);
    final userAction = getUserAction(error);
    
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.error_outline, color: Colors.white, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    message,
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
                  ),
                ),
              ],
            ),
            if (userAction != null) ...[
              const SizedBox(height: 6),
              Padding(
                padding: const EdgeInsets.only(left: 32),
                child: Text(
                  userAction,
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.85),
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ],
        ),
        backgroundColor: AppColors.error,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        duration: const Duration(seconds: 5),
        action: showContactSupport
            ? SnackBarAction(
                label: 'Get Help',
                textColor: Colors.white,
                onPressed: () {
                  // Navigate to contact support
                  Navigator.of(context).pushNamed('/contact-support');
                },
              )
            : onRetry != null
                ? SnackBarAction(
                    label: 'Retry',
                    textColor: Colors.white,
                    onPressed: onRetry,
                  )
                : SnackBarAction(
                    label: 'OK',
                    textColor: Colors.white,
                    onPressed: () {
                      ScaffoldMessenger.of(context).hideCurrentSnackBar();
                    },
                  ),
      ),
    );
  }

  /// Show error dialog for critical errors
  void showErrorDialog(
    BuildContext context, 
    dynamic error, {
    String? title,
    VoidCallback? onRetry,
  }) {
    final message = handleError(error);
    final userAction = getUserAction(error);

    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Container(
              padding: const EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Icon(Icons.error_outline, color: AppColors.error, size: 24),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                title ?? 'Oops!',
                style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              message,
              style: TextStyle(color: AppColors.textSecondary, height: 1.4),
            ),
            if (userAction != null) ...[
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    Icon(Icons.lightbulb_outline, size: 18, color: AppColors.textMuted),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        userAction,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              Navigator.of(context).pushNamed('/contact-support');
            },
            child: Text(
              'Contact Support',
              style: TextStyle(color: AppColors.textMuted),
            ),
          ),
          if (onRetry != null)
            TextButton(
              onPressed: () {
                Navigator.pop(context);
                onRetry();
              },
              child: Text('Try Again'),
            )
          else
            ElevatedButton(
              onPressed: () => Navigator.pop(context),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              child: const Text('OK'),
            ),
        ],
      ),
    );
  }

  /// Show success snackbar
  void showSuccessSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.check_circle_outline, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.green,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 3),
      ),
    );
  }

  /// Show warning snackbar
  void showWarningSnackBar(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Row(
          children: [
            const Icon(Icons.warning_amber_outlined, color: Colors.white, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                message,
                style: const TextStyle(color: Colors.white),
              ),
            ),
          ],
        ),
        backgroundColor: Colors.orange,
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        duration: const Duration(seconds: 4),
      ),
    );
  }
}

// ============================================================================
// PROVIDER
// ============================================================================

final errorHandlerProvider = Provider<ErrorHandlerService>((ref) {
  return ErrorHandlerService();
});

// ============================================================================
// ERROR BOUNDARY WIDGET
// ============================================================================

/// Widget that catches errors in its child widget tree
class ErrorBoundary extends StatefulWidget {
  final Widget child;
  final Widget Function(FlutterErrorDetails)? errorBuilder;

  const ErrorBoundary({
    super.key,
    required this.child,
    this.errorBuilder,
  });

  @override
  State<ErrorBoundary> createState() => _ErrorBoundaryState();
}

class _ErrorBoundaryState extends State<ErrorBoundary> {
  FlutterErrorDetails? _error;

  @override
  void initState() {
    super.initState();
    // Set up error handling for this subtree
    FlutterError.onError = (details) {
      setState(() {
        _error = details;
      });
    };
  }

  void _retry() {
    setState(() {
      _error = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return widget.errorBuilder?.call(_error!) ?? _buildDefaultError();
    }
    return widget.child;
  }

  Widget _buildDefaultError() {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Container(
                  padding: const EdgeInsets.all(24),
                  decoration: BoxDecoration(
                    color: AppColors.error.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.error_outline,
                    size: 64,
                    color: AppColors.error,
                  ),
                ),
                const SizedBox(height: 24),
                const Text(
                  'Something went wrong',
                  style: TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'We\'re sorry, but something unexpected happened.',
                  style: TextStyle(
                    color: AppColors.textSecondary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: _retry,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text('Try Again'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// ASYNC VALUE EXTENSIONS
// ============================================================================

/// Extension methods for handling AsyncValue errors
extension AsyncValueErrorHandling<T> on AsyncValue<T> {
  /// Handle error state with a callback
  void handleError(BuildContext context, ErrorHandlerService errorHandler) {
    whenOrNull(
      error: (error, _) {
        errorHandler.showErrorSnackBar(context, error);
      },
    );
  }
}

// ============================================================================
// RESULT TYPE
// ============================================================================

/// A Result type for better error handling
sealed class Result<T> {
  const Result();
}

class Success<T> extends Result<T> {
  final T data;
  const Success(this.data);
}

class Failure<T> extends Result<T> {
  final AppError error;
  const Failure(this.error);
}

/// Extension to create results easily
extension ResultExtensions<T> on Future<T> {
  /// Convert Future to Result
  Future<Result<T>> toResult() async {
    try {
      final data = await this;
      return Success(data);
    } catch (e) {
      if (e is AppError) {
        return Failure(e);
      }
      return Failure(NetworkError(e.toString()));
    }
  }
}

// ============================================================================
// RETRY HELPER
// ============================================================================

/// Helper for retrying failed operations
class RetryHelper {
  /// Retry an async operation with exponential backoff
  static Future<T> retry<T>({
    required Future<T> Function() operation,
    int maxAttempts = 3,
    Duration initialDelay = const Duration(seconds: 1),
  }) async {
    int attempts = 0;
    Duration delay = initialDelay;

    while (true) {
      try {
        return await operation();
      } catch (e) {
        attempts++;
        if (attempts >= maxAttempts) {
          rethrow;
        }
        await Future.delayed(delay);
        delay *= 2; // Exponential backoff
      }
    }
  }
}

// ============================================================================
// LOADING STATE WIDGET
// ============================================================================

/// Widget for showing loading state with error handling
class AsyncDataHandler<T> extends StatelessWidget {
  final AsyncValue<T> value;
  final Widget Function(T data) builder;
  final Widget? loading;
  final Widget Function(Object error, StackTrace? stackTrace)? error;
  final VoidCallback? onRetry;

  const AsyncDataHandler({
    super.key,
    required this.value,
    required this.builder,
    this.loading,
    this.error,
    this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    return value.when(
      data: builder,
      loading: () => loading ?? const Center(child: CircularProgressIndicator()),
      error: (e, st) => error?.call(e, st) ?? _buildDefaultError(context, e),
    );
  }

  Widget _buildDefaultError(BuildContext context, Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.error_outline,
              size: 48,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 16),
            Text(
              ErrorHandlerService().handleError(error),
              style: TextStyle(color: AppColors.textSecondary),
              textAlign: TextAlign.center,
            ),
            if (onRetry != null) ...[
              const SizedBox(height: 16),
              TextButton.icon(
                onPressed: onRetry,
                icon: const Icon(Icons.refresh),
                label: const Text('Retry'),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
