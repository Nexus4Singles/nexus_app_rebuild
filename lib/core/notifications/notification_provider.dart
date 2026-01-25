import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'notification_service.dart';
import 'notification_models.dart';
import 'package:nexus_app_min_test/core/providers/auth_provider.dart';

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

/// Provider to initialize FCM and save token on auth state change
final fcmInitializationProvider = Provider<void>((ref) {
  final service = ref.watch(notificationServiceProvider);
  final userId = ref.watch(currentUserIdProvider);

  // Initialize FCM when app starts
  service.initialize();

  // Save token when user logs in
  if (userId != null) {
    service.saveFcmToken(userId);
  }
});
