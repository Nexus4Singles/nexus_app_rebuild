import 'dart:io';
import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'notification_models.dart';

/// Background message handler for Firebase Messaging
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {
  // You may need to initialize Firebase here if not already done
  // await Firebase.initializeApp();
  // Handle background notification logic if needed
}

/// Global navigator key for notification navigation
final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

// ============================================================================
// FIREBASE CLOUD MESSAGING SERVICE
// ============================================================================

class NotificationService {
  // Singleton pattern - prevents duplicate listener registration
  static final NotificationService _instance = NotificationService._internal();

  factory NotificationService() {
    return _instance;
  }

  NotificationService._internal();

  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  // Guard to prevent multiple initializations (and duplicate listeners)
  bool _initialized = false;

  /// Initialize notification DISPLAY and message handling only.
  ///
  /// FCM token management is handled separately by FcmTokenService.
  /// This method only sets up:
  /// - Local notification plugin (for foreground display)
  /// - Foreground message listener (show local notification)
  /// - Background message tap listener (navigation)
  /// - Initial message check (app opened from killed state)
  Future<void> initialize() async {
    // Only initialize once - prevent duplicate listeners
    if (_initialized) {
      print('ℹ️ NotificationService already initialized (display-only mode)');
      return;
    }
    print('🔔 Initializing NotificationService (display-only mode)...');
    _initialized = true;

    // Initialize local notifications for foreground display
    await _initializeLocalNotifications();

    // Handle foreground messages (show local notification)
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // iOS: Configure foreground notification presentation (alert, sound, badge)
    if (Platform.isIOS) {
      await FirebaseMessaging.instance
          .setForegroundNotificationPresentationOptions(
            alert: true,
            badge: true,
            sound: true,
          );
    }

    // Handle background message tap (navigation)
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check if app was opened from a notification (killed state)
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }

    print('✅ NotificationService display handlers initialized');
  }

  /// Initialize local notifications for foreground display
  Future<void> _initializeLocalNotifications() async {
    const androidSettings = AndroidInitializationSettings(
      '@mipmap/ic_launcher',
    );

    const iosSettings = DarwinInitializationSettings(
      requestAlertPermission: true,
      requestBadgePermission: true,
      requestSoundPermission: true,
    );

    final initSettings = InitializationSettings(
      android: androidSettings,
      iOS: iosSettings,
    );

    await _localNotifications.initialize(
      initSettings,
      onDidReceiveNotificationResponse: (details) {
        // Handle notification tap
        if (details.payload != null) {
          _handleNotificationTap(details.payload!);
        }
      },
    );

    // Create notification channel for Android
    // NOTE: Android notification channels are IMMUTABLE after creation.
    // To apply updated settings (sound, vibration, importance), we must
    // delete the old channel and recreate it.
    if (Platform.isAndroid) {
      final androidPlugin =
          _localNotifications
              .resolvePlatformSpecificImplementation<
                AndroidFlutterLocalNotificationsPlugin
              >();

      if (androidPlugin != null) {
        // Delete old channel to ensure updated settings take effect
        await androidPlugin.deleteNotificationChannel('nexus_default_channel');

        final channel = AndroidNotificationChannel(
          'nexus_default_channel',
          'Nexus Notifications',
          description: 'Default notification channel for Nexus app',
          importance: Importance.high,
          playSound: true,
          enableVibration: true,
          vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
        );

        await androidPlugin.createNotificationChannel(channel);
      }
    }
  }

  /// Handle foreground message (show local notification)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.notification?.title}');
    print('Platform: ${Platform.operatingSystem}');

    if (message.notification != null) {
      // iOS: Native presentation is handled by setForegroundNotificationPresentationOptions
      // Don't show a second local notification to avoid duplicates
      if (Platform.isIOS) {
        print('iOS: Using native notification presentation');
        return;
      }

      // Android: Use local notification plugin to display foreground messages
      print('Android: Showing local notification');
      final payloadJson =
          message.data.isNotEmpty ? jsonEncode(message.data) : null;
      try {
        await _showLocalNotification(
          title: message.notification!.title ?? 'Nexus',
          body: message.notification!.body ?? '',
          payload: payloadJson,
        );
        print('Android: Local notification shown successfully');
      } catch (e) {
        print('Android: Failed to show local notification: $e');
      }
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    final androidDetails = AndroidNotificationDetails(
      'nexus_default_channel',
      'Nexus Notifications',
      channelDescription: 'Default notification channel for Nexus app',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      enableVibration: true,
      vibrationPattern: Int64List.fromList([0, 250, 250, 250]),
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    final notificationDetails = NotificationDetails(
      android: androidDetails,
      iOS: iosDetails,
    );

    await _localNotifications.show(
      DateTime.now().millisecondsSinceEpoch ~/ 1000,
      title,
      body,
      notificationDetails,
      payload: payload,
    );
  }

  /// Handle notification tap (from background/terminated)
  void _handleMessageTap(RemoteMessage message) {
    print('Notification tapped: ${message.data}');
    final route = message.data['route'] as String?;
    if (route != null) {
      _pendingRoute = route;
      _navigateToRoute(route);
    }
  }

  /// Handle local notification tap (foreground notifications shown via flutter_local_notifications)
  void _handleNotificationTap(String payload) {
    print('Local notification tapped: $payload');
    try {
      final data = jsonDecode(payload) as Map<String, dynamic>;
      final route = data['route'] as String?;
      if (route != null) {
        _pendingRoute = route;
        // Attempt immediate navigation if navigator is available
        _navigateToRoute(route);
      }
    } catch (e) {
      print('Failed to parse notification payload: $e');
    }
  }

  String? _pendingRoute;
  String? getPendingRouteAndClear() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  /// Navigate to a route using the global navigator key
  void _navigateToRoute(String route) {
    try {
      final navigator = navigatorKey.currentState;
      if (navigator != null) {
        navigator.pushNamed(route);
        // Clear pending route since we navigated successfully
        _pendingRoute = null;
      } else {
        print('Navigator not ready, route saved as pending: $route');
      }
    } catch (e) {
      print('Navigation failed, route saved as pending: $e');
    }
  }

  /// Send notification to specific user (trigger Cloud Function)
  Future<void> sendNotificationToUser({
    required String userId,
    required NotificationPayload payload,
  }) async {
    // Create notification record in Firestore
    // Cloud Function will detect this and send via FCM
    final notificationRef =
        _firestore
            .collection('users')
            .doc(userId)
            .collection('notifications')
            .doc();

    final record = NotificationRecord(
      id: notificationRef.id,
      userId: userId,
      payload: payload,
      createdAt: DateTime.now(),
      isRead: false,
      isSent: false,
    );

    // Enhanced debug log: notification payload and record
    print(
      '[DEBUG] sendNotificationToUser: userId=$userId, notificationId=${notificationRef.id}',
    );
    print(
      '[DEBUG] Notification payload: type=${payload.type}, title=${payload.title}, body=${payload.body}, data=${payload.data}',
    );
    print('[DEBUG] NotificationRecord: ${record.toString()}');
    try {
      await notificationRef.set(record.toFirestore());
      print(
        '[DEBUG] Notification queued for user: $userId, notificationId=${notificationRef.id}',
      );
    } catch (e) {
      print(
        '[DEBUG] sendNotificationToUser: FAILED to queue notification for user: $userId, notificationId=${notificationRef.id}, error=$e',
      );
      rethrow;
    }
  }

  /// Mark notification as read
  Future<void> markAsRead(String userId, String notificationId) async {
    await _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .doc(notificationId)
        .update({'isRead': true});
  }

  /// Get unread notification count
  Stream<int> getUnreadCount(String userId) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.docs.length);
  }

  /// Get user's notifications
  Stream<List<NotificationRecord>> getUserNotifications(
    String userId, {
    int limit = 50,
  }) {
    return _firestore
        .collection('users')
        .doc(userId)
        .collection('notifications')
        .orderBy('createdAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map(
                (doc) => NotificationRecord.fromFirestore(doc.id, doc.data()),
              )
              .toList();
        });
  }
}

// ============================================================================
// NOTIFICATION HELPERS
// ============================================================================

/// Helper functions for sending specific notification types
class NotificationHelpers {
  static final NotificationService _service = NotificationService();

  /// Send chat message notification
  static Future<void> sendChatMessageNotification({
    required String recipientId,
    required String senderName,
    required String messagePreview,
    required String chatId,
    required String senderId,
  }) async {
    final payload = NotificationPayload.chatMessage(
      senderName: senderName,
      messagePreview: messagePreview,
      chatId: chatId,
      senderId: senderId,
    );

    await _service.sendNotificationToUser(
      userId: recipientId,
      payload: payload,
    );
  }

  /// Send admin message notification
  static Future<void> sendAdminMessageNotification({
    required String userId,
    required String message,
  }) async {
    final payload = NotificationPayload.adminMessage(message: message);

    await _service.sendNotificationToUser(userId: userId, payload: payload);
  }

  /// Send profile verified notification
  static Future<void> sendProfileVerifiedNotification({
    required String userId,
  }) async {
    print('[DEBUG] sendProfileVerifiedNotification called for userId=$userId');
    final payload = NotificationPayload.profileVerified();
    print(
      '[DEBUG] ProfileVerified payload: type=[${payload.type}], title=${payload.title}, body=${payload.body}, data=${payload.data}',
    );
    try {
      await _service.sendNotificationToUser(userId: userId, payload: payload);
      print(
        '[DEBUG] sendProfileVerifiedNotification: Notification creation succeeded for userId=$userId',
      );
    } catch (e) {
      print(
        '[DEBUG] sendProfileVerifiedNotification: Notification creation FAILED for userId=$userId, error=$e',
      );
    }
  }

  /// Send journey purchased notification
  static Future<void> sendJourneyPurchasedNotification({
    required String userId,
    required String journeyTitle,
  }) async {
    final payload = NotificationPayload.journeyPurchased(
      journeyTitle: journeyTitle,
    );

    await _service.sendNotificationToUser(userId: userId, payload: payload);
  }

  /// Send subscription activated notification
  static Future<void> sendSubscriptionActivatedNotification({
    required String userId,
    required String tier,
  }) async {
    final payload = NotificationPayload.subscriptionActivated(tier: tier);

    await _service.sendNotificationToUser(userId: userId, payload: payload);
  }

  /// Send subscription expiring notification
  static Future<void> sendSubscriptionExpiringNotification({
    required String userId,
    required int daysLeft,
  }) async {
    final payload = NotificationPayload.subscriptionExpiring(
      daysLeft: daysLeft,
    );

    await _service.sendNotificationToUser(userId: userId, payload: payload);
  }

  /// Send profile pending verification notification
  static Future<void> sendProfilePendingVerificationNotification({
    required String userId,
  }) async {
    final payload = NotificationPayload.profilePendingVerification();

    await _service.sendNotificationToUser(userId: userId, payload: payload);
  }

  /// Send profile rejected notification
  static Future<void> sendProfileRejectedNotification({
    required String userId,
    String? rejectionReason,
  }) async {
    final payload = NotificationPayload.profileRejected(
      rejectionReason: rejectionReason,
    );

    await _service.sendNotificationToUser(userId: userId, payload: payload);
  }
}
