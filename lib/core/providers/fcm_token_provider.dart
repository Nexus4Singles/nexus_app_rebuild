import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/services/fcm_token_service.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';

// ============================================================================
// FCM TOKEN SERVICE PROVIDER
// ============================================================================

/// Singleton instance of the FCM token service
final fcmTokenServiceProvider = Provider<FcmTokenService>((ref) {
  return FcmTokenService();
});

/// Initialize FCM on app startup
///
/// This runs once to set up the FCM service infrastructure (permissions, APNs setup, etc)
final fcmStartupInitializationProvider = FutureProvider<void>((ref) async {
  final service = ref.watch(fcmTokenServiceProvider);

  // Initialize FCM infrastructure (this is separate from user-specific setup)
  await service.initialize();
  print('[FCM Provider] ✅ FCM infrastructure initialized');
});

/// Handle user login/logout for FCM
///
/// This watches the auth state and:
/// - On user login: Gets fresh token for that user
/// - On user logout: Cleans up token and listeners
/// - On user switch: Cleans up old user, sets up new user
final fcmUserManagementProvider = FutureProvider<void>((ref) async {
  final authState = ref.watch(authStateProvider);
  final service = ref.watch(fcmTokenServiceProvider);

  // Wait for auth state to be determined
  final user = authState.maybeWhen(data: (u) => u, orElse: () => null);

  // Ensure FCM infrastructure is ready
  await ref.watch(fcmStartupInitializationProvider.future);

  // Handle user state changes
  if (user != null && !user.isAnonymous) {
    // User is logged in - set up their token
    await service.handleUserLogin(user.uid);
  } else {
    // User is logged out - clean up
    await service.handleUserLogout();
  }
});

/// Get current FCM token
///
/// Returns null if:
/// - Service not yet initialized
/// - User not logged in
/// - Token fetch failed
final currentFcmTokenProvider = Provider<String?>((ref) {
  final service = ref.watch(fcmTokenServiceProvider);
  return service.currentToken;
});

/// Get current tracked user ID
final fcmCurrentUserIdProvider = Provider<String?>((ref) {
  final service = ref.watch(fcmTokenServiceProvider);
  return service.currentUserId;
});

/// Check if FCM service is initialized
final fcmInitializedProvider = Provider<bool>((ref) {
  final service = ref.watch(fcmTokenServiceProvider);
  return service.isInitialized;
});
