# Push Notification System - Implementation Guide

## Overview

The Nexus app now has a comprehensive push notification system that sends notifications for:
- **Chat messages** - when someone sends you a message
- **Admin messages** - when admin sends you a message
- **Profile verification** - when your profile is verified by admin
- **Journey purchases** - when you successfully purchase a journey
- **Subscription activation** - when you subscribe to premium
- **Subscription expiring** - 3 days before subscription expires (automated daily check)

## Architecture

### Components

1. **Notification Models** (`lib/core/notifications/notification_models.dart`)
   - `NotificationType` enum: 7 notification types
   - `NotificationPayload`: Notification data with factory methods
   - `NotificationRecord`: Firestore storage model
   - `FcmTokenInfo`: FCM token management

2. **Notification Service** (`lib/core/notifications/notification_service.dart`)
   - FCM token management (request, save, refresh, delete)
   - Local notification display (foreground messages)
   - Notification sending (triggers Cloud Function)
   - Notification queries (get, mark as read, count unread)

3. **Notification Provider** (`lib/core/notifications/notification_provider.dart`)
   - `notificationServiceProvider`: Singleton service instance
   - `unreadNotificationCountProvider`: Stream of unread count
   - `userNotificationsProvider`: Stream of user's notifications
   - `fcmInitializationProvider`: Auto-initialize on app start

4. **Cloud Functions** (`functions/index.js`)
   - `sendPushNotification`: Triggered when notification document created
   - `onNewChatMessage`: Creates notification on new chat message
   - `onProfileVerified`: Creates notification when profile verified
   - `checkExpiringSubscriptions`: Daily cron job for expiring subscriptions

5. **Helper Functions** (in notification_service.dart)
   - `NotificationHelpers.sendChatMessageNotification()`
   - `NotificationHelpers.sendAdminMessageNotification()`
   - `NotificationHelpers.sendProfileVerifiedNotification()`
   - `NotificationHelpers.sendJourneyPurchasedNotification()`
   - `NotificationHelpers.sendSubscriptionActivatedNotification()`
   - `NotificationHelpers.sendSubscriptionExpiringNotification()`

## Setup Instructions

### 1. Install Dependencies

The following dependencies are already added to `pubspec.yaml`:
```yaml
dependencies:
  firebase_messaging: ^16.1.0
  flutter_local_notifications: ^18.0.1
```

Run:
```bash
cd /Users/aybaj/Documents/nexus_app_v2
flutter pub get
```

### 2. iOS Setup

Add the following to `ios/Runner/Info.plist`:
```xml
<!-- FCM Notification Permissions -->
<key>FirebaseAppDelegateProxyEnabled</key>
<false/>
```

Enable push notifications in Xcode:
1. Open `ios/Runner.xcworkspace` in Xcode
2. Select Runner target → Signing & Capabilities
3. Click "+ Capability" → Push Notifications
4. Click "+ Capability" → Background Modes
5. Check "Remote notifications"

### 3. Android Setup

Update `android/app/src/main/AndroidManifest.xml`:
```xml
<application>
    <!-- ... existing content ... -->
    
    <!-- FCM Default Notification Channel -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_channel_id"
        android:value="nexus_default_channel" />
    
    <!-- FCM Default Notification Icon -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_icon"
        android:resource="@mipmap/ic_launcher" />
    
    <!-- FCM Default Notification Color -->
    <meta-data
        android:name="com.google.firebase.messaging.default_notification_color"
        android:resource="@color/ic_launcher_background" />
</application>
```

### 4. Initialize Notification Service

In your `main.dart` or app initialization:

```dart
import 'package:nexus_app_min_test/core/notifications/notification_provider.dart';

// In your main app widget or initialization
class MyApp extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize FCM
    ref.watch(fcmInitializationProvider);
    
    return MaterialApp(
      // ... your app
    );
  }
}
```

### 5. Deploy Cloud Functions

Navigate to functions directory and deploy:
```bash
cd /Users/aybaj/Documents/nexus_app_v2/functions
npm install
firebase deploy --only functions
```

This will deploy:
- `sendPushNotification` - Sends FCM notifications
- `onNewChatMessage` - Triggers on new chat messages
- `onProfileVerified` - Triggers on profile verification
- `checkExpiringSubscriptions` - Daily cron job for expiring subscriptions

### 6. Test Notifications

#### Test Chat Notification
Send a message in the app - the recipient should receive a notification.

#### Test Profile Verification
In Firestore Console:
1. Go to users/{userId}
2. Change `moderationStatus` from "pending" to "verified"
3. User should receive notification

#### Test Journey Purchase
When a journey is purchased via `SubscriptionNotifier.recordJourneyPurchase()`, notification is automatically sent.

#### Test Subscription Activation
When subscription is activated via `SubscriptionNotifier.updateSubscription()`, notification is automatically sent.

## Firestore Structure

### FCM Token Storage
```
users/{userId}
  └── fcmToken: {
        token: "FCM_TOKEN_STRING",
        platform: "ios" | "android",
        lastUpdated: Timestamp
      }
```

### Notification Records
```
users/{userId}/notifications/{notificationId}
  ├── id: "notificationId"
  ├── userId: "userId"
  ├── payload: {
  │     type: "chat_message" | "admin_message" | "profile_verified" | etc.
  │     title: "Notification Title"
  │     body: "Notification Body"
  │     route: "/path/to/screen"
  │     data: { ... custom data ... }
  │   }
  ├── createdAt: Timestamp
  ├── isRead: false
  └── isSent: true
```

## Usage Examples

### Sending Chat Notification (already integrated)

Chat notifications are automatically sent by the `onNewChatMessage` Cloud Function when a message is created.

### Sending Admin Message Notification

```dart
import 'package:nexus_app_min_test/core/notifications/notification_service.dart';

await NotificationHelpers.sendAdminMessageNotification(
  userId: 'user123',
  message: 'Your profile has been reviewed.',
);
```

### Sending Journey Purchase Notification (already integrated)

Automatically sent when calling:
```dart
final notifier = ref.read(subscriptionNotifierProvider.notifier);
await notifier.recordJourneyPurchase(
  journeyId: 'journey123',
  journeyTitle: 'Communication in Relationships',
  pricePaid: 5000.0,
);
```

### Sending Subscription Activation Notification (already integrated)

Automatically sent when calling:
```dart
final notifier = ref.read(subscriptionNotifierProvider.notifier);
await notifier.updateSubscription(
  isActive: true,
  tier: SubscriptionTier.monthly,
  expiryDate: DateTime.now().add(Duration(days: 30)),
);
```

### Getting Unread Notification Count

```dart
final unreadCount = ref.watch(unreadNotificationCountProvider);

unreadCount.when(
  data: (count) => Badge(label: Text('$count')),
  loading: () => SizedBox(),
  error: (e, s) => SizedBox(),
);
```

### Displaying Notifications List

```dart
final notifications = ref.watch(userNotificationsProvider);

notifications.when(
  data: (notifs) => ListView.builder(
    itemCount: notifs.length,
    itemBuilder: (context, index) {
      final notif = notifs[index];
      return ListTile(
        title: Text(notif.payload.title),
        subtitle: Text(notif.payload.body),
        trailing: notif.isRead ? null : CircleAvatar(radius: 4),
        onTap: () {
          // Mark as read
          final service = ref.read(notificationServiceProvider);
          service.markAsRead(notif.userId, notif.id);
          
          // Navigate to route
          context.go(notif.payload.route);
        },
      );
    },
  ),
  loading: () => CircularProgressIndicator(),
  error: (e, s) => Text('Error loading notifications'),
);
```

## Notification Types & Routes

| Type | Title | Body | Route | Trigger |
|------|-------|------|-------|---------|
| `chat_message` | "Message from {name}" | Message preview (50 chars) | `/chats/{chatId}` | New message received |
| `admin_message` | "Message from Admin" | Admin's message | `/profile` | Admin sends message |
| `profile_verified` | "Profile Verified! ✓" | "Your profile has been verified..." | `/dating` | moderationStatus: pending → verified |
| `journey_purchased` | "Journey Purchased!" | "You've purchased {title}" | `/journeys` | Journey purchase completed |
| `subscription_activated` | "Premium Activated!" | "Your {tier} subscription is active" | `/subscription` | Subscription activated |
| `subscription_expiring` | "Subscription Expiring Soon" | "Expires in {days} days" | `/subscription` | 3 days before expiry (daily cron) |
| `subscription_expired` | "Subscription Expired" | "Your premium subscription has ended" | `/subscription` | On expiry date |

## Troubleshooting

### iOS Not Receiving Notifications
1. Check Info.plist has correct permissions
2. Verify APNs certificate in Firebase Console
3. Check device notification settings
4. Run on physical device (simulator doesn't support push)

### Android Not Receiving Notifications
1. Check AndroidManifest.xml has FCM metadata
2. Verify google-services.json is correct
3. Check notification channel is created
4. Test on physical device for best results

### Notifications Not Sending
1. Check Cloud Functions are deployed: `firebase functions:list`
2. Check Cloud Function logs: `firebase functions:log`
3. Verify user has FCM token in Firestore
4. Check notification document has `isSent: true`

### Token Not Saving
1. Ensure FCM initialization is called
2. Check user is authenticated before saving token
3. Verify Firestore security rules allow token writes

## Future Enhancements

1. **Rich Notifications**
   - Add images to notifications
   - Action buttons (Reply, View, etc.)

2. **Notification Preferences**
   - User settings to enable/disable notification types
   - Quiet hours

3. **Group Notifications**
   - Combine multiple chat messages into one notification

4. **Notification History Screen**
   - Dedicated screen to view all notifications
   - Filter by type, mark all as read

5. **Push Notification Analytics**
   - Track open rates
   - A/B test notification content

## Security Rules

Add to `firestore.rules`:
```javascript
match /users/{userId}/notifications/{notificationId} {
  // Users can read their own notifications
  allow read: if request.auth != null && request.auth.uid == userId;
  
  // Users can mark their notifications as read
  allow update: if request.auth != null 
                && request.auth.uid == userId
                && request.resource.data.diff(resource.data).affectedKeys().hasOnly(['isRead']);
  
  // Only Cloud Functions can create notifications
  allow create: if false;
  allow delete: if false;
}
```

## Support

For issues or questions:
- Check Cloud Function logs: `firebase functions:log`
- Check FCM token in Firestore Console
- Verify notification documents are being created
- Contact: nexusgodlydating@gmail.com
