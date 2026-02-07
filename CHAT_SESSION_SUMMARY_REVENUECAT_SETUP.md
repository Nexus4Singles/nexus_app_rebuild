# RevenueCat Integration & Journey Purchase Setup - Chat Session Summary

**Date:** February 6-7, 2026  
**Branch:** `new_fixes`  
**Status:** In Progress - Testing Phase with StoreKit Framework

---

## Overview

This session focused on completing the RevenueCat integration for both **journey purchases** (one-time) and **premium subscriptions** (recurring). We corrected API keys, implemented dynamic product ID mapping by user category, fixed provider architecture, and set up testing infrastructure with StoreKit framework.

---

## Major Tasks Completed

### 1. ✅ RevenueCat API Key Configuration
**Status:** COMPLETE

- **Android SDK Key:** `goog_mjvhTsGNNSzgnXyRVrIGjCmXwol`
- **iOS SDK Key:** `appl_dfjYQwnRsUjojfOSnYGqciVcGzx`
- **File Modified:** `lib/core/config/revenuecat_config.dart`
- **Previous Issue:** Code was using secret API key (`sk_YnnxCarcQLFoUrMMacmTfCUsgqeqU`) instead of SDK key
- **Impact:** Corrected key type enables RevenueCat SDK to authenticate properly

### 2. ✅ Subscription Product ID Correction
**Status:** COMPLETE

- **Previous:** `nexus_premium_monthly`
- **Corrected To:** `nexus_premium_v2` (matches actual RevenueCat dashboard product)
- **File Modified:** `lib/core/config/revenuecat_config.dart`
- **Note:** Only monthly subscription currently (no quarterly or yearly)

### 3. ✅ Journey Purchase Dynamic Product ID Mapping
**Status:** COMPLETE

Created dynamic mapping from user category to RevenueCat product ID:
```dart
String _getProductIdForCategory(String category) {
  const categoryToProductId = {
    'singles': 'journey_singles',
    'married': 'journey_married',
    'divorced': 'journey_divorced',
    'widowed': 'journey_widowed',
  };
  return categoryToProductId[categoryLower] ?? 'journey_singles';
}
```

**Files Modified:**
- `lib/features/subscription/presentation/screens/journey_purchase_screen.dart`

**Why:** Each user category needs a different product ID in RevenueCat (not a single `nexus_journey_unlock`)

### 4. ✅ Fixed Category Data Flow Architecture
**Status:** COMPLETE

**Problem:** `JourneyV1` model doesn't have `category` field - only `JourneyCatalogV1` has it

**Solution:**
1. Created new provider: `journeyWithCategoryProvider` in `lib/features/challenges/providers/journeys_providers.dart`
2. This provider returns tuple: `(JourneyV1, String)` with both journey and its category
3. Updated `journey_purchase_screen.dart` to fetch category internally using this provider
4. Kept navigation simple: only pass journey object, screen retrieves category

**Files Modified:**
- `lib/features/challenges/providers/journeys_providers.dart` - Added `journeyWithCategoryProvider`
- `lib/features/subscription/presentation/screens/journey_purchase_screen.dart` - Imports provider, fetches category in `_handlePurchase()`
- `lib/features/challenges/presentation/screens/journey_detail_screen.dart` - Simplified navigation

**Why This Approach:** Avoids constructor signature issues and keeps data fetching centralized in providers

### 5. ✅ Git Commit
**Status:** COMPLETE

- **Branch:** `new_fixes`
- **Changes:** All uncommitted files and untracked files committed
- **Commit includes:** All code changes from this session

---

## Current Testing Setup (In Progress)

### RevenueCat Dashboard Configuration
**Status:** Offerings created but not yet verified

Created offerings and packages:
```
Journey Purchases:
├─ journey_singles (Ready to Submit)
├─ journey_married (Ready to Submit)
├─ journey_divorced (Ready to Submit)
└─ journey_widowed (Ready to Submit)

Premium Subscription:
└─ nexus_premium_v2 (Approved/Published)
```

**Current Issue:** Products show "Ready to Submit" status on App Store Connect (not approved yet)

### StoreKit Framework Testing
**Status:** In Progress

- User added StoreKit framework in Xcode for sandbox testing
- Approach: Run app from Xcode (not Flutter CLI) to capture StoreKit framework
- This allows simulated in-app purchases without needing approved products on App Store

**Last Attempt:** iPhone 17 Pro simulator → Architecture mismatch (Intel x86_64 vs ARM arm64)
- **Solution:** Switch to iPhone 15 or 16 simulator in Xcode
- **Next Steps:** Run from Xcode with correct simulator selection

---

## Code Architecture Summary

### RevenueCat Purchase Flow

**Journey Purchase (One-Time):**
```
User clicks "Unlock Journey"
    ↓
Navigate to JourneyPurchaseScreen(journey)
    ↓
Screen fetches: journeyWithCategoryProvider(journey.id) → (journey, category)
    ↓
Map category to product ID: journey_singles/married/divorced/widowed
    ↓
Fetch offerings from RevenueCat.getOfferings()
    ↓
Find package matching product ID
    ↓
RevenueCatService.purchasePackage(package)
    ↓
recordJourneyPurchase() → Save to Firestore users/{userId}/purchases/{journeyId}
```

**Premium Subscription:**
```
User clicks "Subscribe"
    ↓
_handleSubscriptionPurchase() in subscription_screen.dart
    ↓
Fetch offerings from RevenueCat.getOfferings()
    ↓
Find package matching 'nexus_premium_v2'
    ↓
RevenueCatService.purchasePackage(package)
    ↓
updateSubscription(isActive: true, tier: SubscriptionTier.monthly)
    ↓
Write to Firestore with onPremium flag
```

### Providers Used
- `journeyCatalogProvider` - Loads journey catalog with user category filtering
- `journeyWithCategoryProvider` - Returns (journey, category) tuple
- `journeyByIdProvider` - Fetches single journey by ID
- `subscriptionNotifierProvider` - Records purchases and subscriptions

---

## Files Modified in This Session

1. **lib/core/config/revenuecat_config.dart**
   - Updated Android/iOS SDK API keys
   - Changed subscription monthly ID to `nexus_premium_v2`

2. **lib/core/services/revenuecat_service.dart**
   - Added `debugPrint` import for better error logging

3. **lib/features/subscription/presentation/screens/journey_purchase_screen.dart**
   - Added dynamic product ID mapping by category
   - Imports `journeyWithCategoryProvider`
   - Fetches category inside `_handlePurchase()` method
   - Maps category to correct RevenueCat product ID

4. **lib/features/challenges/providers/journeys_providers.dart**
   - Added `journeyWithCategoryProvider` that returns `(JourneyV1, String)?`

5. **lib/features/challenges/presentation/screens/journey_detail_screen.dart**
   - Simplified navigation - only pass journey object

6. **lib/core/router/app_router.dart**
   - Updated to handle journey argument correctly

---

## Known Issues & Next Steps

### ⏳ Blocking Issue: StoreKit Framework Testing
**Status:** In Progress

1. iPhone 17 Pro simulator has architecture mismatch
2. **Action:** Run Xcode with iPhone 15 or 16 simulator
3. **Expected:** StoreKit will intercept purchase requests and show test purchase dialog

### ⏳ RevenueCat Offerings Not Fetching
**Status:** Blocked by StoreKit testing

1. Products are "Ready to Submit" on App Store Connect (not approved)
2. RevenueCat can't fetch offerings for unapproved products
3. **Solution:** StoreKit framework allows testing without actual approval
4. **Once Working:** Test journey purchase and subscription flows end-to-end

### ✅ Code Architecture: COMPLETE
All code changes for dynamic product ID mapping and category handling are done and committed

---

## How to Continue in Next Chat

1. **Resume from:** Xcode simulator testing with StoreKit framework
2. **Use correct simulator:** iPhone 15 Pro or iPhone 16 (not 17 Pro)
3. **Clean and rebuild:** Product → Clean Build Folder, then Run
4. **Test purchase flow:** Click "Unlock Journey" → should see StoreKit payment dialog
5. **If successful:** Verify Firestore purchase records are created
6. **Then test:** Premium subscription purchase flow

**Branch to work from:** `new_fixes` (all changes are committed there)

---

## Quick Reference: Product IDs

**Journey Purchases (One-Time):**
- `journey_singles` (for singles category)
- `journey_married` (for married category)
- `journey_divorced` (for divorced category)
- `journey_widowed` (for widowed category)

**Subscriptions (Monthly):**
- `nexus_premium_v2` (dating features premium)

**RevenueCat API Keys:**
- Android: `goog_mjvhTsGNNSzgnXyRVrIGjCmXwol`
- iOS: `appl_dfjYQwnRsUjojfOSnYGqciVcGzx`

---

## Session Notes

- User initially assumed quarterly/yearly subscriptions existed, but confirmed only monthly
- Journey categories come from `JourneyCatalogV1`, not individual `JourneyV1` objects
- Passing category through constructor caused hot-reload issues → solved with provider pattern
- Products being "Ready to Submit" prevents RevenueCat from fetching them → StoreKit framework solves this for testing
- Architecture mismatch error common with newer iPhone simulators → use iPhone 15/16 instead
