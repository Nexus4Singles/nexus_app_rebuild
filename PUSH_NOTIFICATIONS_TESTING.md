# Push Notifications - Testing Checklist

## Pre-Testing Setup

- [ ] Run `flutter pub get` to install dependencies
- [ ] iOS: Added Push Notifications capability in Xcode
- [ ] iOS: Added Background Modes → Remote notifications in Xcode  
- [ ] iOS: Added `FirebaseAppDelegateProxyEnabled: false` to Info.plist
- [ ] Android: Added FCM metadata to AndroidManifest.xml
- [ ] App: Initialize FCM in main app widget with `ref.watch(fcmInitializationProvider)`
- [ ] Cloud Functions: Deployed with `firebase deploy --only functions`
- [ ] Firestore Rules: Updated to allow notification reads (optional but recommended)

## Initialization Tests

### ✅ FCM Token Generation
- [ ] App requests notification permission on first launch
- [ ] FCM token is generated and logged to console
- [ ] FCM token is saved to Firestore at `users/{userId}/fcmToken`
- [ ] Token includes `platform: "ios"` or `"android"`
- [ ] Token includes `lastUpdated` timestamp

**How to verify:**
```dart
// In your app
final service = ref.read(notificationServiceProvider);
print('FCM Token: ${service.fcmToken}');
```
Check Firebase Console → Firestore → users/{userId} → fcmToken field exists

### ✅ Service Initialization
- [ ] `NotificationService` initializes without errors
- [ ] Local notifications plugin initializes
- [ ] Android notification channel created (name: "Nexus Notifications")
- [ ] iOS notification permissions requested

**Check logs for:**
```
User granted notification permission
FCM Token: <long-token-string>
```

## Cloud Function Tests

### ✅ Function Deployment
```bash
firebase functions:list
```
- [ ] `sendPushNotification` - Deployed successfully
- [ ] `onNewChatMessage` - Deployed successfully
- [ ] `onProfileVerified` - Deployed successfully
- [ ] `checkExpiringSubscriptions` - Deployed successfully

### ✅ Function Logs
```bash
firebase functions:log
```
- [ ] No deployment errors
- [ ] Functions showing in logs

## Notification Type Tests

### 1. Chat Message Notification 💬

**Setup:**
- Two devices/accounts needed
- User A and User B

**Test Steps:**
1. [ ] User A sends message to User B in chat
2. [ ] Verify message document created in `chats/{chatId}/messages/{messageId}`
3. [ ] Verify `onNewChatMessage` Cloud Function triggered
4. [ ] Verify notification document created at `users/{userB}/notifications/{id}`
5. [ ] Verify `sendPushNotification` Cloud Function triggered
6. [ ] User B receives notification on device

**Verification Points:**
- [ ] Notification title: "Message from {User A name}"
- [ ] Notification body: Message preview (max 50 chars)
- [ ] Notification data includes: `chatId`, `senderId`, `senderName`
- [ ] Tap notification → App opens to chat thread
- [ ] Notification marked as `isSent: true` in Firestore

**Check logs:**
```bash
firebase functions:log --only onNewChatMessage
firebase functions:log --only sendPushNotification
```

---

### 2. Admin Message Notification 📢

**Setup:**
- One user account
- Admin access (or manual trigger)

**Test Steps:**
1. [ ] Trigger admin message notification:
   ```dart
   await NotificationHelpers.sendAdminMessageNotification(
     userId: 'userId123',
     message: 'Welcome to Nexus Premium!',
   );
   ```
2. [ ] Verify notification document created at `users/{userId}/notifications/{id}`
3. [ ] Verify `sendPushNotification` triggered
4. [ ] User receives notification

**Verification Points:**
- [ ] Notification title: "Message from Admin"
- [ ] Notification body: Admin's message
- [ ] Tap notification → App opens to profile/admin section
- [ ] Notification marked as `isSent: true`

---

### 3. Profile Verified Notification ✓

**Setup:**
- One user account with `moderationStatus: "pending"`
- Firebase Console access

**Test Steps:**
1. [ ] User has `moderationStatus: "pending"` in Firestore
2. [ ] In Firebase Console, change `moderationStatus` to `"verified"`
3. [ ] Verify `onProfileVerified` Cloud Function triggered
4. [ ] Verify notification document created
5. [ ] User receives notification

**Verification Points:**
- [ ] Notification title: "Profile Verified! ✓"
- [ ] Notification body: "Your profile has been verified..."
- [ ] Notification route: `/dating`
- [ ] Tap notification → App opens to dating section
- [ ] Only triggers on pending → verified (not other changes)

**Check logs:**
```bash
firebase functions:log --only onProfileVerified
```

**Manual Verification in Firestore:**
- Before: `moderationStatus: "pending"`
- After: `moderationStatus: "verified"`
- Notification doc created in `users/{userId}/notifications/`

---

### 4. Journey Purchase Notification 📚

**Setup:**
- One user account
- Journey available for purchase

**Test Steps:**
1. [ ] Purchase a journey (or call):
   ```dart
   final notifier = ref.read(subscriptionNotifierProvider.notifier);
   await notifier.recordJourneyPurchase(
     journeyId: 'journey123',
     journeyTitle: 'Communication in Relationships',
     pricePaid: 5000.0,
   );
   ```
2. [ ] Verify purchase document created at `users/{userId}/purchases/{journeyId}`
3. [ ] Verify notification document created
4. [ ] User receives notification

**Verification Points:**
- [ ] Notification title: "Journey Purchased!"
- [ ] Notification body: "You've purchased {journeyTitle}"
- [ ] Notification route: `/journeys`
- [ ] Purchase document has `type: "journey"`
- [ ] Notification sent immediately after purchase

---

### 5. Subscription Activated Notification 👑

**Setup:**
- One user account
- Ability to update subscription

**Test Steps:**
1. [ ] Activate subscription:
   ```dart
   final notifier = ref.read(subscriptionNotifierProvider.notifier);
   await notifier.updateSubscription(
     isActive: true,
     tier: SubscriptionTier.monthly,
     expiryDate: DateTime.now().add(Duration(days: 30)),
   );
   ```
2. [ ] Verify subscription document updated at `users/{userId}/subscription`
3. [ ] Verify notification document created
4. [ ] User receives notification

**Verification Points:**
- [ ] Notification title: "Premium Activated!"
- [ ] Notification body: "Your {tier} subscription is active"
- [ ] Notification route: `/subscription`
- [ ] Only sent when `isActive: true` and tier != free
- [ ] Subscription object has correct `startDate` and `expiryDate`

---

### 6. Subscription Expiring Notification ⚠️

**Setup:**
- User with active subscription expiring in 3 days
- Subscription has `autoRenew: false`

**Test Steps:**
1. [ ] Create test subscription in Firestore:
   ```json
   {
     "subscription": {
       "isActive": true,
       "tier": "monthly_premium",
       "expiryDate": "<3 days from now>",
       "autoRenew": false
     }
   }
   ```
2. [ ] Manually trigger scheduled function (for testing):
   ```bash
   firebase functions:shell
   > checkExpiringSubscriptions()
   ```
3. [ ] Verify notification created
4. [ ] User receives notification

**Verification Points:**
- [ ] Only sent if `autoRenew: false`
- [ ] Only sent if expiring in exactly 3 days
- [ ] Notification title: "Subscription Expiring Soon"
- [ ] Notification body: "Expires in 3 days..."
- [ ] Notification route: `/subscription`
- [ ] Runs automatically every 24 hours (via Cloud Scheduler)

**Production Check:**
- [ ] Cloud Scheduler job exists in Firebase Console
- [ ] Job runs daily
- [ ] Check next scheduled run time

---

## Device-Specific Tests

### iOS Testing 📱

- [ ] **Physical device** (simulator doesn't support push)
- [ ] App requests notification permission on launch
- [ ] User grants permission in system dialog
- [ ] Foreground: Local notification shows while app open
- [ ] Background: Push notification shows in notification center
- [ ] Locked: Push notification wakes device
- [ ] Tap notification: App opens to correct route
- [ ] Badge count updates (optional)
- [ ] Sound plays with notification

**iOS Settings Check:**
- Settings → Nexus → Notifications → Enabled
- Allow Notifications: ON
- Sounds: ON
- Badges: ON

### Android Testing 🤖

- [ ] Works on emulator (Android 8.0+)
- [ ] Works on physical device
- [ ] Android 13+: Permission request shows
- [ ] Android <13: Auto-granted permission
- [ ] Foreground: Notification shows in status bar
- [ ] Background: Notification shows in notification tray
- [ ] Tap notification: App opens to correct route
- [ ] Notification channel visible in system settings
- [ ] Sound plays with notification

**Android Settings Check:**
- Settings → Apps → Nexus → Notifications → Enabled
- "Nexus Notifications" channel exists and enabled

---

## Integration Tests

### Multi-Device Chat Flow
- [ ] User A sends message
- [ ] User B receives notification (app closed)
- [ ] User B taps notification
- [ ] App opens directly to chat with User A
- [ ] Message visible in chat thread

### Profile Verification Flow
- [ ] User submits profile for verification
- [ ] Admin changes status to verified
- [ ] User receives notification
- [ ] User taps notification
- [ ] App opens to dating section
- [ ] Profile visible to other users

### Subscription Flow
- [ ] User purchases subscription
- [ ] Notification received immediately
- [ ] User taps notification
- [ ] App opens to subscription screen
- [ ] Subscription status shows "Active"

---

## Error Handling Tests

### No FCM Token
- [ ] User denies notification permission
- [ ] App continues to function normally
- [ ] No crashes or errors
- [ ] Notifications queued but not sent
- [ ] User can enable notifications later in settings

### Cloud Function Errors
- [ ] Invalid FCM token → Function logs error, marks `isSent: false`
- [ ] User deleted → Function handles gracefully
- [ ] Missing data → Function logs error but doesn't crash

### Network Issues
- [ ] Offline: Notifications queue locally
- [ ] Back online: Notifications sync and send
- [ ] Poor connection: Retries handled by FCM

---

## Performance Tests

### Token Management
- [ ] Token saved on first launch
- [ ] Token refreshes automatically on expiry
- [ ] Token deleted on logout
- [ ] New token generated on re-login
- [ ] Multiple devices: Each has own token

### Notification Delivery Speed
- [ ] Chat notification: <3 seconds end-to-end
- [ ] Profile verification: <5 seconds
- [ ] Purchase notification: <2 seconds
- [ ] Batch notifications: All delivered within 10 seconds

### Database Load
- [ ] 100 notifications created → All delivered
- [ ] 1000+ old notifications → No performance issues
- [ ] Notification queries: <500ms response time

---

## Security Tests

### Firestore Rules
- [ ] Users can only read their own notifications
- [ ] Users cannot create notifications (Cloud Function only)
- [ ] Users can update only `isRead` field
- [ ] Users cannot delete notifications

### Data Privacy
- [ ] FCM tokens stored securely
- [ ] Notification content appropriate for push
- [ ] No sensitive data in notification payload
- [ ] User data not exposed to other users

---

## Production Readiness Checklist

### Configuration
- [ ] Firebase project in production mode
- [ ] Cloud Functions region configured (us-central1)
- [ ] FCM API key secured
- [ ] Android SHA-1 fingerprints added to Firebase
- [ ] iOS APNs certificate uploaded to Firebase

### Monitoring
- [ ] Cloud Function error alerts configured
- [ ] FCM delivery reports enabled
- [ ] Notification open rate tracking (optional)
- [ ] Error logging to monitoring service

### Documentation
- [ ] User-facing: How to enable/disable notifications
- [ ] Developer: Troubleshooting guide
- [ ] Support team: Common notification issues

### Compliance
- [ ] Privacy policy mentions push notifications
- [ ] User consent for notifications obtained
- [ ] Opt-out mechanism available
- [ ] GDPR compliance (if applicable)

---

## Final Verification

- [ ] All 6 notification types tested and working
- [ ] iOS and Android both tested
- [ ] Cloud Functions deployed and running
- [ ] No console errors
- [ ] No Firestore errors
- [ ] Performance acceptable
- [ ] User experience smooth
- [ ] Documentation complete

---

## 🎉 Congratulations!

If all checkboxes are ticked, your push notification system is **production-ready**! 

Your users will now receive:
- Instant chat notifications
- Profile status updates
- Purchase confirmations
- Subscription reminders

This will significantly increase user engagement and retention! 📈

---

**Testing Duration**: 2-3 hours  
**Last Updated**: January 2025  
**Status**: Ready for production deployment
