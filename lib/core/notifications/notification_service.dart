import 'dart:io';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'notification_models.dart';

// ============================================================================
// FIREBASE CLOUD MESSAGING SERVICE
// ============================================================================

class NotificationService {
  final FirebaseMessaging _firebaseMessaging = FirebaseMessaging.instance;
  final FlutterLocalNotificationsPlugin _localNotifications =
      FlutterLocalNotificationsPlugin();
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  String? _fcmToken;
  String? get fcmToken => _fcmToken;

  /// Initialize FCM and local notifications
  Future<void> initialize() async {
    // Request permission (iOS)
    final settings = await _firebaseMessaging.requestPermission(
      alert: true,
      badge: true,
      sound: true,
      provisional: false,
    );

    if (settings.authorizationStatus == AuthorizationStatus.authorized) {
      print('User granted notification permission');
    } else if (settings.authorizationStatus ==
        AuthorizationStatus.provisional) {
      print('User granted provisional permission');
    } else {
      print('User declined or has not accepted permission');
      return;
    }

    // Initialize local notifications
    await _initializeLocalNotifications();

    // Get FCM token (handle iOS simulator case where APNS token may not be available)
    try {
      _fcmToken = await _firebaseMessaging.getToken();
      print('FCM Token: $_fcmToken');
    } catch (e) {
      // iOS simulator or APNS token not available yet
      print('FCM Token not available (likely iOS simulator): $e');
      _fcmToken = null;
    }

    // Listen for token refresh
    _firebaseMessaging.onTokenRefresh.listen((newToken) {
      _fcmToken = newToken;
      print('FCM Token refreshed: $newToken');
      // Token will be saved when user logs in
    });

    // Handle foreground messages
    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);

    // Handle background message tap
    FirebaseMessaging.onMessageOpenedApp.listen(_handleMessageTap);

    // Check if app was opened from a notification
    final initialMessage = await _firebaseMessaging.getInitialMessage();
    if (initialMessage != null) {
      _handleMessageTap(initialMessage);
    }
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
    if (Platform.isAndroid) {
      const channel = AndroidNotificationChannel(
        'nexus_default_channel',
        'Nexus Notifications',
        description: 'Default notification channel for Nexus app',
        importance: Importance.high,
        playSound: true,
      );

      await _localNotifications
          .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin
          >()
          ?.createNotificationChannel(channel);
    }
  }

  /// Handle foreground message (show local notification)
  Future<void> _handleForegroundMessage(RemoteMessage message) async {
    print('Received foreground message: ${message.notification?.title}');

    if (message.notification != null) {
      await _showLocalNotification(
        title: message.notification!.title ?? 'Nexus',
        body: message.notification!.body ?? '',
        payload: message.data.toString(),
      );
    }
  }

  /// Show local notification
  Future<void> _showLocalNotification({
    required String title,
    required String body,
    String? payload,
  }) async {
    const androidDetails = AndroidNotificationDetails(
      'nexus_default_channel',
      'Nexus Notifications',
      channelDescription: 'Default notification channel for Nexus app',
      importance: Importance.high,
      priority: Priority.high,
      playSound: true,
      icon: '@mipmap/ic_launcher',
    );

    const iosDetails = DarwinNotificationDetails(
      presentAlert: true,
      presentBadge: true,
      presentSound: true,
    );

    const notificationDetails = NotificationDetails(
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
      // Navigation will be handled by the app
      // Store the route to navigate after app initializes
      _pendingRoute = route;
    }
  }

  /// Handle local notification tap
  void _handleNotificationTap(String payload) {
    print('Local notification tapped: $payload');
    // Parse payload and navigate
  }

  String? _pendingRoute;
  String? getPendingRouteAndClear() {
    final route = _pendingRoute;
    _pendingRoute = null;
    return route;
  }

  /// Save FCM token to Firestore
  Future<void> saveFcmToken(String userId) async {
    if (_fcmToken == null) return;

    final tokenInfo = FcmTokenInfo(
      token: _fcmToken!,
      platform: Platform.isIOS ? 'ios' : 'android',
      lastUpdated: DateTime.now(),
    );

    await _firestore.collection('users').doc(userId).update({
      'fcmToken': tokenInfo.toFirestore(),
    });

    print('FCM token saved for user: $userId');
  }

  /// Delete FCM token (on logout)
  Future<void> deleteFcmToken(String userId) async {
    await _firestore.collection('users').doc(userId).update({
      'fcmToken': FieldValue.delete(),
    });

    await _firebaseMessaging.deleteToken();
    _fcmToken = null;
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

    await notificationRef.set(record.toFirestore());
    print('Notification queued for user: $userId');
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
    final payload = NotificationPayload.profileVerified();

    await _service.sendNotificationToUser(userId: userId, payload: payload);
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
}
