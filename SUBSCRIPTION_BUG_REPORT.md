# SUBSCRIPTION BUG INVESTIGATION - FINDINGS & FIXES

**Date:** March 20, 2026  
**Issue:** Users who subscribe are not getting subscription benefits

---

## CRITICAL FINDINGS

### 1. ❌ NO SUBSCRIPTIONS BEING CREATED
- **Finding:** Sample of 50 users: **0 have NEW format, 0 have LEGACY format, 50 have NO subscription**
- **Impact:** Users who claim to have "subscribed" have no subscription record in Firestore
- **Root Cause:** Subscription creation happens via webhooks (Flutterwave/RevenueCat)
  - **Flutterwave webhooks:** ❌ NOT FIRING
  - **RevenueCat webhooks:** ❌ NOT FIRING

### 2. ❌ FLUTTERWAVE WEBHOOK NOT CONFIGURED
- **Evidence:** No webhook firing records in Firestore  
- **Status:** Cloud Function IS deployed (`handleUpdateUserSubscriptionStatus`)
- **Issue:** Flutterwave dashboard doesn't have the webhook URL configured
- **Fix Needed:** Configure Flutterwave dashboard to POST to:
  ```
  https://us-central1-nexus-visibility-app.cloudfunctions.net/handleUpdateUserSubscriptionStatus
  ```

### 3. ❌ REVENUECAT WEBHOOK NOT FIRING
- **Evidence:** No RevenueCat webhook records in Firestore
- **Status:** Cloud Function IS deployed (`validateSubscription`)
- **Issue:** RevenueCat dashboard not configured or wrong endpoint
- **Fix Needed:** Verify RevenueCat webhook settings point to correct URL

### 4. ⚠️ SUBSCRIPTION FORMAT MISMATCH (SECONDARY)
- **Status:** ✅ FIXED in code (`SubscriptionTier.fromId()` recognizes all formats)
- **Details:** App correctly handles variations:
  - ✅ `monthly_premium` (current)
  - ✅ `monthly` (recognized as monthly_premium)
  - ✅ `Premium` (recognized as monthly_premium)
  - ✅ `nexus_premium` (recognized as monthly_premium)
  - ✅ `monthly_premium_v2`, `nexus_premium_v2` (all recognized)

---

## USER EXPERIENCE FLOW (BROKEN)

```
1. User pays via Flutterwave or RevenueCat
   ↓
2. Payment provider should POST webhook
   ❌ WEBHOOK NOT FIRING
   ↓
3. Server should create subscription record
   ❌ NO SUBSCRIPTION CREATED
   ↓
4. App should check subscription on next login
   ❌ NO DATA FOUND → TREATED AS FREE USER
   ↓
5. Premium features blocked
   ❌ USER FRUSTRATED
```

---

## REQUIRED FIXES

### FIX #1: CONFIGURE FLUTTERWAVE WEBHOOK (CRITICAL)
**Location:** Flutterwave Merchant Dashboard → Settings → Webhooks

**Required Configuration:**
```
Event Type: payment.completed
Webhook URL: https://us-central1-nexus-visibility-app.cloudfunctions.net/handleUpdateUserSubscriptionStatus
HTTP Method: POST
Signature Verification: ENABLED (use FLUTTERWAVE_WEBHOOK_SECRET)
```

**Verification:** After configuration, test with a payment. Firestore should show a record in `flutterwave_webhooks` collection.

---

### FIX #2: VERIFY REVENUECAT WEBHOOK (CRITICAL)
**Location:** RevenueCat Dashboard → Webhooks

**Required Configuration:**
```
Event: SUBSCRIPTION_CREATED, SUBSCRIPTION_RENEWED
Webhook URL: https://us-central1-nexus-visibility-app.cloudfunctions.net/validateSubscription
HTTP Method: POST
Authentication: Use RevenueCat API key in header
```

**Verification:** Check Cloud Function logs for webhook activity.

---

### FIX #3: VERIFY APP-SIDE SUBSCRIPTION CHECKS
**Files:** 
- `lib/core/services/subscription_service.dart` → `isPremium()` ✅ (WORKING)
- `lib/features/subscription/application/subscription_provider.dart` → subscription status ✅ (WORKING)
- `lib/core/services/chat_service.dart` → `_isPremiumUser()` ✅ (WORKING)

**Issue:** Even if subscriptions exist, the app needs:
1. **Firebase ID Token** to access subscription data
2. **Real-time listener** to see updates (or logout/login to refresh)
3. **Cache invalidation** when subscription changes

**Action Items:**
- [ ] Verify users are logged in with valid Firebase tokens
- [ ] Have users logout/login after manual subscription activation
- [ ] Check if subscription listener is properly set up in app

---

### FIX #4: IMMEDIATE WORKAROUND
For users claiming to have subscribed but no benefits:

```bash
# 1. Get user email
# 2. Run manual activation
node activate_user_subscription.js [email] [expiry-date]

# Example:
node activate_user_subscription.js user@email.com "2026-04-20"

# 3. Tell user to:
#    - Close app completely
#    - Reopen app
#    - Logout and login again if needed
```

---

## INVESTIGATION SUMMARY

| Check | Result | Status |
|-------|--------|--------|
| Tier parsing logic | ✅ All formats recognized | FIXED |
| Flutterwave webhook | ❌ Not firing | **NEEDS CONFIG** |
| RevenueCat webhook | ❌ Not firing | **NEEDS CONFIG** |
| Subscriptions in DB | 0 found (0% adoption) | **CRITICAL** |
| App-side logic | ✅ Works correctly | OK |
| Premium checks | ✅ All correct | OK |

---

## RECOMMENDED ACTIONS (PRIORITY ORDER)

1. **IMMEDIATE:** Configure Flutterwave webhook in dashboard
2. **IMMEDIATE:** Verify RevenueCat webhook configuration
3. **TODAY:** Test payment flow end-to-end
4. **TODAY:** Manually activate subscriptions for affected users
5. **THIS WEEK:** Monitor webhook logs for successful payments
6. **THIS WEEK:** Add alerts for failed webhook deliveries

---

## MONITORING

After fixes are applied, watch for:

**In Cloud Function Logs:**
```
[Flutterwave] ✓ Subscription activated for user {userId}
[RevenueCat] ✅ Updated subscription for user: {userId}
```

**In Firestore:**
- `flutterwave_webhooks` collection should have entries
- `revenuecat_webhooks` collection should have entries
- User subscribers should have `subscription.tier = "monthly_premium"`

**In App:**
- Users report premium features available immediately after payment
- No need for users to restart app

---

## KEY INSIGHT

**The subscription tier parsing logic is NOT the problem.** The problem is that **subscriptions are never created** because webhooks never fire. This is purely a configuration issue in the payment provider dashboards.

Once webhooks are configured, subscriptions will be created correctly and the app will recognize them properly.
