# Subscription Feature - Implementation Guide

## Overview

The subscription system has been successfully implemented with the following features:

### 1. Premium Features
- **Unlimited Messaging**: Remove the 3 free chats limit for premium users
- **View Compatibility Data**: Access detailed compatibility insights for potential matches
- **View Contact Information**: Access phone numbers and social media handles

### 2. Subscription Tiers
- **Free**: Limited to 3 chat conversations
- **Monthly Premium**: ₦2,999/month
- **Quarterly Premium**: ₦7,999/quarter (Save ₦1,000)
- **Yearly Premium**: ₦24,999/year (Save ₦10,989)

### 3. Journey Purchases
- Separate section for one-off journey/course purchases
- Available to all user categories (not just dating users)
- Each journey has specific pricing per country via AppStore/PlayStore

## File Structure

```
lib/features/subscription/
├── domain/
│   └── subscription_models.dart          # Data models
├── application/
│   └── subscription_provider.dart        # State management
└── presentation/
    └── screens/
        └── subscription_screen.dart      # UI implementation
```

## Key Features Implemented

### ✅ Subscription Screen
- **Two Tabs**: Dating Features & Journey Purchases
- **Active Subscription View**: 
  - Premium badge with expiry date
  - Days remaining counter (warning when <7 days)
  - Feature list with active indicators
  - Cancel auto-renewal button
- **No Subscription View**:
  - Premium card with gradient design
  - Feature comparison
  - Subscription plan cards with savings indicators
  - "Most Popular" badge for quarterly plan

### ✅ Premium Gates
- Updated compatibility data button on user profiles
- Updated contact info button on user profiles
- Beautiful modal dialogs prompting subscription
- Direct navigation to subscription screen

### ✅ Chat Limit Integration
- Enhanced premium required dialog with feature list
- "View Plans" CTA routing to subscription screen
- Proper error messaging for free chat limits

## RevenueCat Integration (Next Step)

### Step 1: Setup RevenueCat Account
1. Go to [revenuecat.com](https://www.revenuecat.com/) and create an account
2. Create a new project for "Nexus Dating App"
3. Note your **API Keys**:
   - Public SDK Key (for the app)
   - Secret Key (for webhooks - optional)

### Step 2: Configure App Store & Play Store
1. **iOS (App Store Connect)**:
   - Create subscription products with IDs:
     - `monthly_premium`
     - `quarterly_premium`
     - `yearly_premium`
   - Configure pricing per territory
   - Add to RevenueCat dashboard

2. **Android (Google Play Console)**:
   - Create subscription products with same IDs
   - Configure pricing
   - Add to RevenueCat dashboard

3. **Journey Products** (One-time purchases):
   - Create non-consumable products for each journey
   - Format: `journey_{journeyId}`
   - Add to RevenueCat as entitlements

### Step 3: Add RevenueCat Package

Add to `pubspec.yaml`:
```yaml
dependencies:
  purchases_flutter: ^6.0.0  # Latest version
```

### Step 4: Initialize RevenueCat

Create `lib/core/services/revenuecat_service.dart`:

```dart
import 'package:purchases_flutter/purchases_flutter.dart';

class RevenueCatService {
  static const String _apiKey = 'YOUR_PUBLIC_SDK_KEY_HERE'; // iOS/Android different keys
  
  Future<void> initialize() async {
    await Purchases.setLogLevel(LogLevel.debug);
    
    PurchasesConfiguration configuration;
    if (Platform.isAndroid) {
      configuration = PurchasesConfiguration(_apiKey);
    } else if (Platform.isIOS) {
      configuration = PurchasesConfiguration(_apiKey);
    }
    
    await Purchases.configure(configuration);
  }
  
  Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      print('Error fetching offerings: $e');
      return null;
    }
  }
  
  Future<CustomerInfo> purchasePackage(Package package) async {
    return await Purchases.purchasePackage(package);
  }
  
  Future<CustomerInfo> restorePurchases() async {
    return await Purchases.restorePurchases();
  }
  
  Future<void> setUserId(String userId) async {
    await Purchases.logIn(userId);
  }
  
  Future<void> logout() async {
    await Purchases.logOut();
  }
  
  Stream<CustomerInfo> get customerInfoStream => Purchases.addCustomerInfoUpdateListener();
}
```

### Step 5: Update Subscription Screen

In `subscription_screen.dart`, update the purchase button `onPressed`:

```dart
ElevatedButton(
  onPressed: () async {
    try {
      // Show loading
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (_) => const Center(child: CircularProgressIndicator()),
      );
      
      // Get offerings from RevenueCat
      final offerings = await revenueCatService.getOfferings();
      Navigator.pop(context); // Remove loading
      
      if (offerings == null || offerings.current == null) {
        throw Exception('No offerings available');
      }
      
      // Find the package matching this tier
      final package = offerings.current!.availablePackages.firstWhere(
        (p) => p.identifier == tier.id,
      );
      
      // Make purchase
      final customerInfo = await revenueCatService.purchasePackage(package);
      
      // Update Firestore with subscription details
      if (customerInfo.entitlements.all['premium']?.isActive == true) {
        await ref.read(subscriptionNotifierProvider.notifier).updateSubscription(
          isActive: true,
          tier: tier,
          expiryDate: customerInfo.entitlements.all['premium']?.expirationDate,
          revenueCatCustomerId: customerInfo.originalAppUserId,
        );
        
        // Show success message
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Welcome to Premium! 🎉'),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
      // Handle errors
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Purchase failed: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  },
  child: const Text('Subscribe Now'),
)
```

### Step 6: Webhook Setup (Optional but Recommended)

1. In RevenueCat dashboard, go to **Webhooks**
2. Add your Firebase Cloud Function URL
3. Create a Cloud Function to handle webhook events:

```javascript
// firebase_functions/index.js
exports.revenueCatWebhook = functions.https.onRequest(async (req, res) => {
  const event = req.body.event;
  const userId = req.body.app_user_id;
  
  if (event.type === 'INITIAL_PURCHASE' || event.type === 'RENEWAL') {
    // Update user's subscription in Firestore
    const expiryDate = new Date(event.expiration_at_ms);
    
    await admin.firestore().collection('users').doc(userId).update({
      'subscription.isActive': true,
      'subscription.tier': event.product_id,
      'subscription.expiryDate': admin.firestore.Timestamp.fromDate(expiryDate),
      'subscription.autoRenew': true,
      'onPremium': true,
    });
  } else if (event.type === 'CANCELLATION' || event.type === 'EXPIRATION') {
    // Handle cancellation
    await admin.firestore().collection('users').doc(userId).update({
      'subscription.autoRenew': false,
    });
  }
  
  res.sendStatus(200);
});
```

### Step 7: Chat Service Integration

The chat service already enforces the 3 free chat limit. To add premium bypass, update `chat_service.dart`:

```dart
// Before checking free chat limit
final userDoc = await _firestore.collection('users').doc(meUid).get();
final userData = userDoc.data();
final subscription = userData?['subscription'] as Map<String, dynamic>?;
final isPremium = subscription?['isActive'] == true;

// Skip limit check if premium
if (isPremium) {
  // Allow unlimited chats
  // ... proceed with message sending
} else {
  // Check free chat limit (existing code)
  // ...
}
```

## Firestore Data Structure

### User Document
```json
{
  "uid": "user123",
  "subscription": {
    "isActive": true,
    "tier": "monthly_premium",
    "startDate": "2026-01-23T10:00:00Z",
    "expiryDate": "2026-02-23T10:00:00Z",
    "autoRenew": true,
    "revenueCatCustomerId": "rc_user123",
    "revenueCatSubscriptionId": "sub_abc123"
  },
  "onPremium": true  // Legacy flag for backward compatibility
}
```

### User Purchases Subcollection
```
users/{userId}/purchases/{purchaseId}
{
  "type": "journey",
  "journeyId": "prepare_for_marriage_v1",
  "journeyTitle": "Preparing for Marriage",
  "purchaseDate": "2026-01-20T15:30:00Z",
  "pricePaid": 4999.00,
  "currency": "NGN",
  "revenueCatTransactionId": "txn_xyz789",
  "isActive": true
}
```

## Testing

### Test Premium Features Without Payment
Run the app with debug flag:
```bash
flutter run --dart-define=NEXUS_DEBUG_UNLOCK_PREMIUM=true
```

This bypasses premium gates for UI testing purposes only.

### Test Subscription Flow
1. Use RevenueCat's **Sandbox Testing**:
   - iOS: Create sandbox test account in App Store Connect
   - Android: Add test account in Google Play Console
   
2. Test scenarios:
   - New subscription purchase
   - Subscription renewal
   - Cancellation (auto-renew off)
   - Restore purchases
   - Expired subscription

## UI Screenshots Locations

The subscription screen includes:
- ✨ Gradient hero header with premium icon
- 📊 Two-tab layout (Dating Features / Journey Purchases)
- 💳 Beautiful subscription plan cards with savings indicators
- ⭐ "Most Popular" badge on quarterly plan
- ✅ Feature list with active/inactive indicators
- 🎯 Empty states for no subscriptions/journeys
- 🚫 Cancel auto-renewal functionality
- 📱 Fully responsive design

## Next Steps

1. **Get RevenueCat API Keys** - Share with developer when ready
2. **Configure Products** - Set up in App Store Connect & Play Console
3. **Test in Sandbox** - Verify purchase flow end-to-end
4. **Deploy Cloud Function** - For webhook handling (optional)
5. **Production Release** - Submit updated app to stores

## Support

For questions or issues:
- RevenueCat Docs: https://docs.revenuecat.com/
- Flutter Plugin: https://docs.revenuecat.com/docs/flutter
- Support: help@revenuecat.com

---

**Status**: Ready for RevenueCat integration ✅  
**Last Updated**: January 23, 2026
