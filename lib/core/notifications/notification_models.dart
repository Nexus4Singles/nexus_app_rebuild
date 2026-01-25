import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';

// ============================================================================
// NOTIFICATION MODELS
// ============================================================================

/// Notification types
enum NotificationType {
  chatMessage('chat_message', 'New Message'),
  adminMessage('admin_message', 'Admin Message'),
  profileVerified('profile_verified', 'Profile Verified'),
  journeyPurchased('journey_purchased', 'Journey Purchased'),
  subscriptionActivated('subscription_activated', 'Premium Activated'),
  subscriptionExpiring('subscription_expiring', 'Subscription Expiring'),
  subscriptionExpired('subscription_expired', 'Subscription Expired');

  final String id;
  final String displayName;

  const NotificationType(this.id, this.displayName);

  static NotificationType fromId(String id) {
    return NotificationType.values.firstWhere(
      (type) => type.id == id,
      orElse: () => NotificationType.chatMessage,
    );
  }
}

/// Notification payload model
class NotificationPayload extends Equatable {
  final NotificationType type;
  final String title;
  final String body;
  final Map<String, dynamic> data;

  const NotificationPayload({
    required this.type,
    required this.title,
    required this.body,
    this.data = const {},
  });

  factory NotificationPayload.chatMessage({
    required String senderName,
    required String messagePreview,
    required String chatId,
    required String senderId,
  }) {
    return NotificationPayload(
      type: NotificationType.chatMessage,
      title: senderName,
      body: messagePreview,
      data: {'chatId': chatId, 'senderId': senderId, 'route': '/chats/$chatId'},
    );
  }

  factory NotificationPayload.adminMessage({required String message}) {
    return NotificationPayload(
      type: NotificationType.adminMessage,
      title: 'Message from Nexus Admin',
      body: message,
      data: {'route': '/profile'},
    );
  }

  factory NotificationPayload.profileVerified() {
    return const NotificationPayload(
      type: NotificationType.profileVerified,
      title: '✅ Profile Verified!',
      body:
          'Congratulations! Your profile has been verified and is now visible to other users.',
      data: {'route': '/search'},
    );
  }

  factory NotificationPayload.journeyPurchased({required String journeyTitle}) {
    return NotificationPayload(
      type: NotificationType.journeyPurchased,
      title: '🎉 Journey Unlocked!',
      body: 'You now have access to "$journeyTitle". Start your journey today!',
      data: {'route': '/challenges'},
    );
  }

  factory NotificationPayload.subscriptionActivated({required String tier}) {
    return NotificationPayload(
      type: NotificationType.subscriptionActivated,
      title: '💎 Welcome to Premium!',
      body: 'Your $tier subscription is now active. Enjoy unlimited features!',
      data: {'route': '/subscription'},
    );
  }

  factory NotificationPayload.subscriptionExpiring({required int daysLeft}) {
    return NotificationPayload(
      type: NotificationType.subscriptionExpiring,
      title: '⏰ Subscription Expiring Soon',
      body:
          'Your premium subscription will expire in $daysLeft days. Renew to keep access.',
      data: {'route': '/subscription'},
    );
  }

  factory NotificationPayload.subscriptionExpired() {
    return const NotificationPayload(
      type: NotificationType.subscriptionExpired,
      title: 'Premium Subscription Expired',
      body:
          'Your premium features are no longer active. Resubscribe to regain access.',
      data: {'route': '/subscription'},
    );
  }

  Map<String, dynamic> toJson() {
    return {'type': type.id, 'title': title, 'body': body, 'data': data};
  }

  factory NotificationPayload.fromJson(Map<String, dynamic> json) {
    return NotificationPayload(
      type: NotificationType.fromId(json['type'] as String? ?? 'chat_message'),
      title: json['title'] as String? ?? '',
      body: json['body'] as String? ?? '',
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }

  @override
  List<Object?> get props => [type, title, body, data];
}

/// Stored notification record in Firestore
class NotificationRecord extends Equatable {
  final String id;
  final String userId;
  final NotificationPayload payload;
  final DateTime createdAt;
  final bool isRead;
  final bool isSent;

  const NotificationRecord({
    required this.id,
    required this.userId,
    required this.payload,
    required this.createdAt,
    this.isRead = false,
    this.isSent = false,
  });

  factory NotificationRecord.fromFirestore(
    String id,
    Map<String, dynamic> data,
  ) {
    DateTime createdAt;
    if (data['createdAt'] is Timestamp) {
      createdAt = (data['createdAt'] as Timestamp).toDate();
    } else if (data['createdAt'] is String) {
      createdAt = DateTime.parse(data['createdAt']);
    } else {
      createdAt = DateTime.now();
    }

    return NotificationRecord(
      id: id,
      userId: data['userId'] as String? ?? '',
      payload: NotificationPayload.fromJson(
        data['payload'] as Map<String, dynamic>? ?? {},
      ),
      createdAt: createdAt,
      isRead: data['isRead'] as bool? ?? false,
      isSent: data['isSent'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'userId': userId,
      'payload': payload.toJson(),
      'createdAt': Timestamp.fromDate(createdAt),
      'isRead': isRead,
      'isSent': isSent,
    };
  }

  NotificationRecord copyWith({
    String? id,
    String? userId,
    NotificationPayload? payload,
    DateTime? createdAt,
    bool? isRead,
    bool? isSent,
  }) {
    return NotificationRecord(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      payload: payload ?? this.payload,
      createdAt: createdAt ?? this.createdAt,
      isRead: isRead ?? this.isRead,
      isSent: isSent ?? this.isSent,
    );
  }

  @override
  List<Object?> get props => [id, userId, payload, createdAt, isRead, isSent];
}

/// User's FCM token info
class FcmTokenInfo extends Equatable {
  final String token;
  final String platform; // 'ios' or 'android'
  final DateTime lastUpdated;

  const FcmTokenInfo({
    required this.token,
    required this.platform,
    required this.lastUpdated,
  });

  factory FcmTokenInfo.fromFirestore(Map<String, dynamic> data) {
    DateTime lastUpdated;
    if (data['lastUpdated'] is Timestamp) {
      lastUpdated = (data['lastUpdated'] as Timestamp).toDate();
    } else if (data['lastUpdated'] is String) {
      lastUpdated = DateTime.parse(data['lastUpdated']);
    } else {
      lastUpdated = DateTime.now();
    }

    return FcmTokenInfo(
      token: data['token'] as String? ?? '',
      platform: data['platform'] as String? ?? 'android',
      lastUpdated: lastUpdated,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'token': token,
      'platform': platform,
      'lastUpdated': Timestamp.fromDate(lastUpdated),
    };
  }

  @override
  List<Object?> get props => [token, platform, lastUpdated];
}
