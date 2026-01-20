import 'package:nexus_app_min_test/core/router/safe_nav.dart';
import 'package:nexus_app_min_test/core/constants/app_constants.dart';
import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Global navigator key for push notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ============================================================================
// NOTIFICATION TYPES
// ============================================================================

/// Types of notifications the app can receive
enum NotificationType {
  newMessage('new_message', 'New Message'),
  newMatch('new_match', 'New Match'),
  newLike('new_like', 'New Like'),
  storyOfTheWeek('story_of_the_week', 'Story of the Week'),
  systemNotification('system', 'System'),
  profileView('profile_view', 'Profile View'),
  reminder('reminder', 'Reminder');

  final String value;
  final String displayName;

  const NotificationType(this.value, this.displayName);

  static NotificationType fromString(String? value) {
    return NotificationType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => NotificationType.systemNotification,
    );
  }
}

/// Notification data model
class AppNotification {
  final String id;
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;
  final DateTime receivedAt;
  final bool isRead;

  const AppNotification({
    required this.id,
    required this.type,
    required this.title,
    required this.body,
    required this.data,
    required this.receivedAt,
    this.isRead = false,
  });

  factory AppNotification.fromRemoteMessage(RemoteMessage message) {
    return AppNotification(
      id: message.messageId ?? DateTime.now().millisecondsSinceEpoch.toString(),
      type: NotificationType.fromString(message.data['type']),
      title: message.notification?.title ?? '',
      body: message.notification?.body ?? '',
      data: message.data,
      receivedAt: message.sentTime ?? DateTime.now(),
    );
  }

  AppNotification copyWith({bool? isRead}) {
    return AppNotification(
      id: id,
      type: type,
      title: title,
      body: body,
      data: data,
      receivedAt: receivedAt,
      isRead: isRead ?? this.isRead,
    );
  }
}

// ============================================================================
// NOTIFICATION SETTINGS
// ============================================================================

/// User's notification preferences
class AppNotificationSettings {
  final bool pushEnabled;
  final bool newMessageEnabled;
  final bool newMatchEnabled;
  final bool newLikeEnabled;
  final bool storyEnabled;
  final bool soundEnabled;
  final bool vibrationEnabled;

  const AppNotificationSettings({
    this.pushEnabled = true,
    this.newMessageEnabled = true,
    this.newMatchEnabled = true,
    this.newLikeEnabled = true,
    this.storyEnabled = true,
    this.soundEnabled = true,
    this.vibrationEnabled = true,
  });

  factory AppNotificationSettings.fromJson(Map<String, dynamic> json) {
    return AppNotificationSettings(
      pushEnabled: json['pushEnabled'] ?? true,
      newMessageEnabled: json['newMessageEnabled'] ?? true,
      newMatchEnabled: json['newMatchEnabled'] ?? true,
      newLikeEnabled: json['newLikeEnabled'] ?? true,
      storyEnabled: json['storyEnabled'] ?? true,
      soundEnabled: json['soundEnabled'] ?? true,
      vibrationEnabled: json['vibrationEnabled'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
    'pushEnabled': pushEnabled,
    'newMessageEnabled': newMessageEnabled,
    'newMatchEnabled': newMatchEnabled,
    'newLikeEnabled': newLikeEnabled,
    'storyEnabled': storyEnabled,
    'soundEnabled': soundEnabled,
    'vibrationEnabled': vibrationEnabled,
  };

  AppNotificationSettings copyWith({
    bool? pushEnabled,
    bool? newMessageEnabled,
    bool? newMatchEnabled,
    bool? newLikeEnabled,
    bool? storyEnabled,
    bool? soundEnabled,
    bool? vibrationEnabled,
  }) {
    return AppNotificationSettings(
      pushEnabled: pushEnabled ?? this.pushEnabled,
      newMessageEnabled: newMessageEnabled ?? this.newMessageEnabled,
      newMatchEnabled: newMatchEnabled ?? this.newMatchEnabled,
      newLikeEnabled: newLikeEnabled ?? this.newLikeEnabled,
      storyEnabled: storyEnabled ?? this.storyEnabled,
      soundEnabled: soundEnabled ?? this.soundEnabled,
      vibrationEnabled: vibrationEnabled ?? this.vibrationEnabled,
    );
  }
}

// ============================================================================
// PUSH NOTIFICATION SERVICE
// ============================================================================

/// Provider for push notification service
final pushNotificationServiceProvider = Provider<PushNotificationService>((
  ref,
) {
  return PushNotificationService();
});

/// Provider for notification settings
final notificationSettingsProvider = StateProvider<AppNotificationSettings>((
  ref,
) {
  return const AppNotificationSettings();
});

/// Provider for notification permission status
final notificationPermissionProvider = FutureProvider<AuthorizationStatus>((
  ref,
) async {
  final service = ref.watch(pushNotificationServiceProvider);
  return service.getPermissionStatus();
});

/// Service to handle push notifications via Firebase Cloud Messaging
class PushNotificationService {
  final FirebaseMessaging _messaging = FirebaseMessaging.instance;
  FirebaseFirestore? _firestore;

  FirebaseFirestore get _fs =>
      _firestore ?? (throw StateError('Firestore not ready'));
  // Stream controller for notifications
  final StreamController<AppNotification> _notificationController =
      StreamController<AppNotification>.broadcast();

  // Get notification stream
  Stream<AppNotification> get notificationStream =>
      _notificationController.stream;

  // Storage key for settings
  static const _settingsKey = 'notification_settings';

  /// Initialize the push notification service
  /// Call this during app startup
  Future<void> initialize(String? userId) async {
    debugPrint('🔔 Initializing Push Notification Service...');

    // Request permission
    final settings = await requestPermission();
    debugPrint('🔔 Push enabled: ${settings.pushEnabled}');

    if (settings.pushEnabled) {
      // Get FCM token
      final token = await getToken();
      debugPrint('🔔 FCM Token: ${token?.substring(0, 20)}...');

      // Save token to Firestore if user is logged in
      if (userId != null && token != null) {
        await saveTokenToFirestore(userId, token);
      }

      // Listen for token refresh
      _messaging.onTokenRefresh.listen((newToken) {
        if (userId != null) {
          saveTokenToFirestore(userId, newToken);
        }
      });

      // Configure message handlers
      _configureMessageHandlers();
    }

    debugPrint('🔔 Push Notification Service initialized');
  }

  /// Request notification permission
  Future<AppNotificationSettings> requestPermission() async {
    final firebaseSettings = await _messaging.requestPermission(
      alert: true,
      announcement: false,
      badge: true,
      carPlay: false,
      criticalAlert: false,
      provisional: false,
      sound: true,
    );

    final enabled =
        firebaseSettings.authorizationStatus ==
            AuthorizationStatus.authorized ||
        firebaseSettings.authorizationStatus == AuthorizationStatus.provisional;

    return AppNotificationSettings(pushEnabled: enabled);
  }

  /// Get current permission status
  Future<AuthorizationStatus> getPermissionStatus() async {
    final firebaseSettings = await _messaging.getNotificationSettings();
    return firebaseSettings.authorizationStatus;
  }

  /// Get FCM token
  Future<String?> getToken() async {
    try {
      return await _messaging.getToken();
    } catch (e) {
      debugPrint('Error getting FCM token: $e');
      return null;
    }
  }

  /// Delete FCM token (for logout)
  Future<void> deleteToken() async {
    try {
      await _messaging.deleteToken();
      debugPrint('🔔 FCM Token deleted');
    } catch (e) {
      debugPrint('Error deleting FCM token: $e');
    }
  }

  /// Save FCM token to Firestore
  Future<void> saveTokenToFirestore(String userId, String token) async {
    try {
      await _fs.collection('users').doc(userId).update({
        'fcmToken': token,
        'notificationToken': token, // Nexus 1.0 compatibility
        'tokenUpdatedAt': FieldValue.serverTimestamp(),
        'platform': Platform.isIOS ? 'ios' : 'android',
      });
      debugPrint('🔔 FCM Token saved to Firestore');
    } catch (e) {
      debugPrint('Error saving FCM token: $e');
    }
  }

  /// Remove FCM token from Firestore (for logout)
  Future<void> removeTokenFromFirestore(String userId) async {
    try {
      await _fs.collection('users').doc(userId).update({
        'fcmToken': FieldValue.delete(),
        'notificationToken': FieldValue.delete(),
      });
      debugPrint('🔔 FCM Token removed from Firestore');
    } catch (e) {
      debugPrint('Error removing FCM token: $e');
    }
  }

  /// Configure message handlers
  void _configureMessageHandlers() {
    // Foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Background/terminated message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleNotificationTap);

    // Check for initial message (app opened from terminated state)
    _checkInitialMessage();
  }

  /// Handle message received while app is in foreground
  void _handleForegroundMessage(RemoteMessage message) {
    debugPrint(
      '🔔 Foreground message received: ${message.notification?.title}',
    );

    final notification = AppNotification.fromRemoteMessage(message);
    _notificationController.add(notification);

    // Show local notification or in-app banner
    // This depends on your UI requirements
  }

  /// Handle notification tap (app opened from notification)
  void _handleNotificationTap(RemoteMessage message) {
    debugPrint('🔔 Notification tapped: ${message.notification?.title}');

    final notification = AppNotification.fromRemoteMessage(message);
    _notificationController.add(notification);

    // Navigate based on notification type
    _navigateFromNotification(message.data);
  }

  /// Check for initial message when app opens from terminated state
  Future<void> _checkInitialMessage() async {
    final initialMessage = await _messaging.getInitialMessage();
    if (initialMessage != null) {
      debugPrint('🔔 App opened from terminated state via notification');
      _handleNotificationTap(initialMessage);
    }
  }

  /// Navigate to appropriate screen based on notification data
  void _navigateFromNotification(Map<String, dynamic> data) {
    // NOTE: Deep-link navigation disabled for MVP stability.
    // Tapping a notification should only launch the app.
    // We keep this method as a no-op to avoid crashes during cold starts.
    debugPrint('🔔 Notification tapped (navigation disabled): \$data');
  }

  /// Subscribe to a topic (e.g., "weekly_stories", "all_users")
  Future<void> subscribeToTopic(String topic) async {
    try {
      await _messaging.subscribeToTopic(topic);
      debugPrint('🔔 Subscribed to topic: $topic');
    } catch (e) {
      debugPrint('Error subscribing to topic: $e');
    }
  }

  /// Unsubscribe from a topic
  Future<void> unsubscribeFromTopic(String topic) async {
    try {
      await _messaging.unsubscribeFromTopic(topic);
      debugPrint('🔔 Unsubscribed from topic: $topic');
    } catch (e) {
      debugPrint('Error unsubscribing from topic: $e');
    }
  }

  /// Load notification settings from local storage
  Future<AppNotificationSettings> loadSettings() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final json = prefs.getString(_settingsKey);
      if (json != null) {
        return AppNotificationSettings.fromJson(jsonDecode(json));
      }
    } catch (e) {
      debugPrint('Error loading notification settings: $e');
    }
    return const AppNotificationSettings();
  }

  /// Save notification settings to local storage
  Future<void> saveSettings(AppNotificationSettings settings) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_settingsKey, jsonEncode(settings.toJson()));
      debugPrint('🔔 Notification settings saved');
    } catch (e) {
      debugPrint('Error saving notification settings: $e');
    }
  }

  /// Check if a specific notification type is enabled
  bool isNotificationTypeEnabled(
    AppNotificationSettings settings,
    NotificationType type,
  ) {
    // Minimal safe default: if push is enabled globally, treat all types as enabled.
    // (Per-type toggles can be reintroduced later without affecting MVP stability.)
    if (!settings.pushEnabled) return false;
    return true;
  }

  /// Dispose the service
  void dispose() {
    _notificationController.close();
  }
}

// ============================================================================
// BACKGROUND MESSAGE HANDLER
// ============================================================================

/// This function must be top-level (not inside a class)
/// It handles messages when the app is in background or terminated
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // Note: You may need to initialize Firebase here if not already done
  // await Firebase.initializeApp();

  debugPrint('🔔 Background message received: ${message.notification?.title}');

  // Process the message (e.g., update local database, show notification)
  // Be careful: this runs in a separate isolate, so you can't access
  // Flutter-specific APIs or providers directly
}

// ============================================================================
// NOTIFICATION HELPER
// ============================================================================

/// Helper class to send notifications (for server-side or local use)
class NotificationHelper {
  /// Create notification payload for new message
  static Map<String, dynamic> newMessagePayload({
    required String recipientToken,
    required String senderName,
    required String messagePreview,
    required String chatId,
    required String senderId,
  }) {
    return {
      'to': recipientToken,
      'notification': {
        'title': senderName,
        'body': messagePreview,
        'sound': 'default',
      },
      'data': {
        'type': NotificationType.newMessage.value,
        'chatId': chatId,
        'senderId': senderId,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
      'android': {
        'priority': 'high',
        'notification': {'channel_id': 'messages', 'sound': 'default'},
      },
      'apns': {
        'payload': {
          'aps': {'sound': 'default', 'badge': 1},
        },
      },
    };
  }

  /// Create notification payload for new match
  static Map<String, dynamic> newMatchPayload({
    required String recipientToken,
    required String matchedUserName,
    required String matchedUserId,
  }) {
    return {
      'to': recipientToken,
      'notification': {
        'title': 'New Match! 🎉',
        'body': 'You and $matchedUserName have matched!',
        'sound': 'default',
      },
      'data': {
        'type': NotificationType.newMatch.value,
        'userId': matchedUserId,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    };
  }

  /// Create notification payload for new like
  static Map<String, dynamic> newLikePayload({
    required String recipientToken,
    required String likerUserId,
  }) {
    return {
      'to': recipientToken,
      'notification': {
        'title': 'Someone likes you! ❤️',
        'body': 'See who likes your profile',
        'sound': 'default',
      },
      'data': {
        'type': NotificationType.newLike.value,
        'userId': likerUserId,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    };
  }

  /// Create notification payload for story of the week
  static Map<String, dynamic> storyOfTheWeekPayload({
    required String topic,
    required String storyTitle,
    required String storyId,
  }) {
    return {
      'to': '/topics/$topic',
      'notification': {
        'title': 'Story of the Week 📖',
        'body': storyTitle,
        'sound': 'default',
      },
      'data': {
        'type': NotificationType.storyOfTheWeek.value,
        'storyId': storyId,
        'click_action': 'FLUTTER_NOTIFICATION_CLICK',
      },
    };
  }
}
