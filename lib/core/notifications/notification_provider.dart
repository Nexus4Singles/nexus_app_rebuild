import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';
import 'notification_models.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import 'package:nexus_app_v2/core/providers/fcm_token_provider.dart';

// ============================================================================
// NOTIFICATION PROVIDERS
// ============================================================================

/// Singleton notification service instance
final notificationServiceProvider = Provider<NotificationService>((ref) {
  return NotificationService();
});

/// Provider to get unread notification count
final unreadNotificationCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(0);

  final service = ref.watch(notificationServiceProvider);
  return service.getUnreadCount(userId);
});

/// Provider to get user's notifications
final userNotificationsProvider = StreamProvider<List<NotificationRecord>>((
  ref,
) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  final service = ref.watch(notificationServiceProvider);
  return service.getUserNotifications(userId);
});

/// ✅ NEW: Combined initialization provider
///
/// This initializes BOTH:
/// 1. NotificationService - for local notification display, foreground handling, navigation
/// 2. FcmTokenService (via fcmUserManagementProvider) - for token management, APNs, retries
///
/// The two services have clean separation:
/// - NotificationService: DISPLAY (show notifications, handle taps, navigate)
/// - FcmTokenService: TOKENS (generate, persist, refresh, user lifecycle)
final fcmInitializationProvider = FutureProvider<void>((ref) async {
  // 1. Initialize notification display (local notifications, foreground handlers, message taps)
  final displayService = ref.watch(notificationServiceProvider);
  await displayService.initialize();

  // 2. Initialize FCM token management (APNs, token generation, Firestore persistence)
  await ref.watch(fcmUserManagementProvider.future);
});
