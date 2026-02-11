# RevenueCat Sandbox Subscription Expiration Setup

## Issue
Sandbox subscriptions in App Store are supposed to expire in 5 minutes by default, but yours might not be configured correctly.

## Root Cause
The **expiration duration** is determined by Apple's App Store Connect configuration for your **test subscription product**, not by RevenueCat.

---

## How to Fix: Configure Sandbox Subscription Duration

### Step 1: Access App Store Connect
1. Go to [appstoreconnect.apple.com](https://appstoreconnect.apple.com)
2. Navigate to your app → **Pricing and Availability** (or **Subscriptions** depending on version)
3. Find your subscription group (e.g., "Nexus Premium")

### Step 2: Verify Subscription Product Configuration

For **each subscription product** (e.g., "nexus_premium_v2"):

1. **Click on the product** to open its details
2. Look for the **Subscription Duration** section
3. Check the following durations **(these are what sandbox subscriptions use)**:
   - **1 week** (sandbox: ~3 minutes)
   - **1 month** (sandbox: ~5 minutes) ← **Default**
   - **2 months** (sandbox: ~10 minutes)
   - **3 months** (sandbox: ~15 minutes)
   - **6 months** (sandbox: ~30 minutes)
   - **1 year** (sandbox: ~1 hour)

### Step 3: Set to Minimum Duration (5 minutes)
To get ~5 minute expiration in sandbox:
- **Ensure your subscription is set to "1 month" duration**
- Apple automatically converts this to ~5 minutes in sandbox

---

## Common Issues & Solutions

### Issue: Subscription never expires (sticks around indefinitely)
**Causes:**
1. **RevenueCat test mode disabled** - Your test purchase might be using production settings
   - Check: `RevenueCatConfig.enableTestMode = true`
   - Currently: ✅ `enableTestMode = true` in `lib/core/config/revenuecat_config.dart`

2. **Sandbox Apple ID not configured** - Using personal Apple ID instead of sandbox tester
   - **Fix:** Settings → App Store → Sign out
   - Sign in with your **Sandbox Apple ID** (from App Store Connect)

3. **Product not in Sandbox** - The subscription product exists only in production
   - **Fix:** Verify product exists in App Store Connect → your app → In-App Purchases

4. **RevenueCat Dashboard mismatch** - Product ID in code doesn't match App Store
   - Check: `RevenueCatConfig.subscriptionMonthlyId = 'nexus_premium_v2'`
   - Verify this ID exists in App Store Connect

---

## Verify Your Current Setup

### Check in RevenueCatConfig
```dart
// File: lib/core/config/revenuecat_config.dart

class RevenueCatConfig {
  static const String subscriptionMonthlyId = 'nexus_premium_v2';
  static const bool enableTestMode = true; // ✅ Ensure this is TRUE
}
```

### Check Sandbox Apple ID
1. Open Simulator or device
2. Settings → App Store → Check which Apple ID is signed in
3. It should be your **Sandbox Tester ID** (from App Store Connect)
4. Example sandbox email: `sandbox.xxxxxxxx@developer.apple.com`

### Force Refresh RevenueCat Cache
Add this to your subscription provider to debug:

```dart
// Clear cache and refresh
await Purchases.invalidateCustomerInfoCache();
final customerInfo = await Purchases.getCustomerInfo();
print('Active Entitlements: ${customerInfo.entitlements.active}');
print('Subscriptions: ${customerInfo.subscriptions}');
```

---

## Testing the 5-Minute Expiration

### Manual Test Steps:
1. ✅ Ensure `enableTestMode = true` in RevenueCatConfig
2. ✅ Device signed in with **Sandbox Apple ID** (not personal)
3. ✅ Make a test purchase
4. ✅ Watch the app for **~5 minutes**
5. ✅ Subscription should auto-renew (sandbox default)
   - Or you'll see expiration if you've set up billing grace period

### Verify Expiration
In your code, add:

```dart
final customerInfo = await Purchases.getCustomerInfo();

for (final sub in customerInfo.subscriptions.values) {
  final expiresAt = DateTime.parse(sub.expiresDate);
  final minutesUntilExpiry = expiresAt.difference(DateTime.now()).inMinutes;
  print('Subscription expires in $minutesUntilExpiry minutes');
}
```

---

## RevenueCat Dashboard Verification

1. Go to [RevenueCat Dashboard](https://app.revenuecat.com)
2. Select your app
3. **App Store Connect** → Verify:
   - ✅ API keys are correct
   - ✅ Production & Sandbox keys match your app
   - ✅ Product IDs are mapped correctly

### Current Configuration:
```
iOS API Key: appl_dfjYQwnRsUjojfOSnYGqciVcGzx
Android API Key: goog_mjvhTsGNNSzgnXyRVrIGjCmXwol
Subscription Product ID: nexus_premium_v2
Test Mode: ✅ ENABLED
```

---

## Checklist for 5-Minute Sandbox Expiration

- [ ] App Store Connect: Subscription set to **1 month** duration
- [ ] `enableTestMode = true` in RevenueCatConfig
- [ ] Sandbox Apple ID signed in on device/simulator
- [ ] RevenueCat SDK initialized with correct API key
- [ ] Product ID matches App Store: `nexus_premium_v2`
- [ ] Customer info cache cleared after purchase
- [ ] Tested with actual purchase (not just offering display)

---

## If Still Not Working

1. **Restart the app** - Force kill and relaunch
2. **Clear app data** - Uninstall and reinstall from Xcode
3. **Check Xcode logs** - Look for RevenueCat configuration errors
4. **Contact RevenueCat Support** - Include your app token ID

---

## Key Resources

- [Apple's Sandbox Testing Duration Info](https://developer.apple.com/app-store-connect/articles/sandbox-testing)
- [RevenueCat Testing Guide](https://docs.revenuecat.com/docs/testing)
- [RevenueCat iOS Setup](https://docs.revenuecat.com/docs/ios-setup)
