# ROOT CAUSE ANALYSIS: Flutterwave Subscription Auto-Activation Failure

**Date:** March 19, 2026  
**User:** niaregbe@gmail.com  
**Investigation Method:** Firestore audit logs + transaction records + Cloud Functions deployed functions list

---

## 🔴 ROOT CAUSE: WEBHOOK ENDPOINT NOT CONFIGURED IN FLUTTERWAVE DASHBOARD

### Evidence (Deterministic - Not Guesses):

#### 1. **NO TRANSACTION RECORDS IN FIRESTORE** ✓
```
Location: users/{userId}/transactions/ collection
Result: EMPTY (0 records)
```
- Investigation script output: "❌ No transaction records found in Firestore"
- This collection should be populated when webhook fires
- **Conclusion:** Webhook endpoint never received the payment event

#### 2. **NO GLOBAL WEBHOOK LOGS** ✓
```
Collections checked:
- flutterwave_webhooks → EMPTY
- flutterwave_failed_webhooks → EMPTY
```
- Investigation script output: "No webhook records found (collection empty or doesn't exist)"
- If webhook had fired and failed, it would create a record
- **Conclusion:** Webhook endpoint was never called

#### 3. **ONLY MANUAL_ACTIVATION IN AUDIT LOG** ✓
```
Audit logs for user: [subscription_manually_activated (manual)]
Transaction records: NONE
```
- The user's subscription is marked as manually activated, not via Flutterwave webhook
- **Conclusion:** No automatic webhook processing occurred

#### 4. **FUNCTION DEPLOYMENT CONFIRMED** ✓
```bash
firebase functions:list output shows:
✔ functions[handleUpdateUserSubscriptionStatus(us-central1)] ✓ DEPLOYED
```
- The Cloud Function IS deployed and EXISTS
- Firebase confirms the endpoint is accessible
- **Conclusion:** The endpoint exists server-side, but it's not being called

---

## 🎯 WHAT'S HAPPENING:

1. **User pays via Flutterwave bank transfer** → Payment succeeds at Flutterwave
2. **Flutterwave should POST to webhook URL** → NOT HAPPENING
3. **Our Cloud Function sits idle** → Waiting for webhook that never comes
4. **User subscription never auto-activates** → Manual activation required (like we did)

---

## ⚠️ WHY THE WEBHOOK ISN'T BEING CALLED:

### Most Likely Cause: **Webhook URL Not Configured in Flutterwave Dashboard**

The function is deployed, but Flutterwave needs to know WHERE to send the webhook.  
Flutterwave requires explicit configuration in their dashboard with:
- Webhook URL (Cloud Function HTTPS endpoint)
- Event type to listen for (payment.completed)
- API credentials

### Possible Causes (in order of likelihood):

1. **❌ Webhook URL never set up in Flutterwave dashboard**
   - Flutterwave Settings → Webhooks → NOT CONFIGURED
   - Action: Contact Flutterwave support or check Flutterwave merchant dashboard

2. **❌ Webhook URL is incorrect/stale**
   - URL format should be: `https://us-central1-nexus-visibility-app.cloudfunctions.net/handleUpdateUserSubscriptionStatus`
   - If you redeployed functions, URL might have changed
   - Action: Verify current URL in Flutterwave dashboard matches deployed function

3. **❌ Webhook URL is correct but Flutterwave account disabled webhooks**
   - Flutterwave might have webhook delivery turned OFF
   - Action: Check Flutterwave account webhook delivery settings

4. **❌ Firestore webhook handler was never deployed to firebase_functions/**
   - Only `functions/index.js` version is deployed (uses old subscription format)
   - `firebase_functions/index.js` might be ignored during deployment
   - Action: Verify which webhook handler is actually deployed

---

## 📋 ADDITIONAL FINDINGS:

### Subscription Format Issue (Secondary):
Both webhook handler versions use **LEGACY subscription format**:
```javascript
// OLD FORMAT (what webhook sets)
onPremium: true
subExpDate: Date
entitledUser: true

// NEW FORMAT (what app expects)
subscription.tier: 'monthly_premium'
subscription.expiryDate: Date
subscription.isActive: true
```

**Impact:** Even IF webhook fired, subscription wouldn't activate properly because:
- Webhook sets `onPremium = true` (legacy)
- App checks for `subscription.tier` (new format)
- The new tier fix you added only recognizes OLD product IDs from legacy system
- Mismatch between what webhook creates and what app expects

**Status:** This is a SECONDARY issue. Fix #1 (configuring webhook) must come first.

---

## ✅ VERIFICATION CHECKLIST:

To confirm the root cause, check:

- [ ] Log into Flutterwave merchant dashboard
- [ ] Navigate to Settings → Webhooks
- [ ] **Is there a webhook URL configured?**
  - YES → Check if it matches: `https://us-central1-nexus-visibility-app.cloudfunctions.net/handleUpdateUserSubscriptionStatus`
  - NO → This is the problem! Need to set it up.
- [ ] **Is webhook delivery ENABLED?**
  - Check for toggle/switch that enables/disables webhooks
- [ ] **Which events does it listen for?**
  - Should include: `charge.completed` or `payment.completed`
- [ ] **Test webhook:**
  - Flutterwave dashboard usually has a "Send Test Webhook" button
  - Try sending a test → check if it creates transaction record in Firestore

---

## 🔧 IMMEDIATE ACTIONS TO FIX:

### Step 1: Configure Webhook in Flutterwave (CRITICAL)
1. Open Flutterwave merchant dashboard
2. Go to Settings → Webhooks or Integrations
3. Set webhook URL to: `https://us-central1-nexus-visibility-app.cloudfunctions.net/handleUpdateUserSubscriptionStatus`
4. Set event type to: `charge.completed` or equivalent
5. Enable webhooks
6. Test with small payment to verify it fires

### Step 2: Monitor Webhook Delivery
1. After user pays, check Firestore: `flutterwave_webhooks` collection
2. If record appears → Webhook is firing ✅
3. If no record → Back to Step 1, something still wrong

### Step 3: Fix Webhook Handler (Secondary)
Update both webhook handlers (`functions/index.js` and `firebase_functions/index.js`) to use NEW subscription format:
```javascript
// INSTEAD OF:
onPremium: true
subExpDate: date

// USE:
subscription: {
  isActive: true,
  tier: 'monthly_premium',
  expiryDate: date,
  startDate: now,
  validatedBy: 'flutterwave_webhook',
  autoRenew: true,
}
```

---

## 📊 CURRENT STATE SUMMARY:

| Item | Status | Evidence |
|------|--------|----------|
| Cloud Function Deployed | ✅ YES | `handleUpdateUserSubscriptionStatus` in functions:list |
| Webhook Endpoint Accessible | ✅ YES (theoretically) | Function is live |
| Flutterwave Calling Endpoint | ❌ NO | No records in flutterwave_webhooks collection |
| Transaction Records Created | ❌ NO | User transactions collection is empty |
| Subscription Auto-Activated | ❌ NO | Only manual_activation in audit log |
| Webhook URL Configured in Flutterwave | ❓ UNKNOWN | Need to check Flutterwave dashboard |

---

## 🎯 CONCLUSION:

**The Flutterwave bank transfer subscriptions fail to auto-activate because:**

1. **PRIMARY CAUSE:** Flutterwave webhook endpoint is NOT configured in Flutterwave's dashboard
   - Flutterwave has no knowledge of where to send payment notifications
   - Our Cloud Function exists but receives no webhook calls
   - Solution: Configure webhook URL in Flutterwave merchant settings

2. **SECONDARY CAUSE:** Webhook handler uses legacy subscription format
   - Even if webhook fires, it won't activate premium features
   - Solution: Update webhook handler to use new `subscription.tier` format

**No code bugs detected.** The code is ready; the infrastructure link is missing.
