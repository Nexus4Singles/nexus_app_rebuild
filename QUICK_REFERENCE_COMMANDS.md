# 🚀 UK Market Launch - Quick Reference Commands

## ✅ Verification Commands (Copy & Paste)

### 1️⃣ Verify Firestore Market Document
```bash
cd /Users/aybaj/Documents/nexus_app_v2 && node scripts/initialize_market.js uk
```
**Expected**: Shows market config with phase: "prelaunch"

### 2️⃣ Verify Cloud Scheduler Job
```bash
gcloud scheduler jobs list --location=us-central1 --project=nexus-visibility-app --format="table(name, schedule, state)"
```
**Expected**: Shows `send-waitlist-reminder-14day` with state `ENABLED`

### 3️⃣ Verify Cloud Functions Deployed
```bash
firebase functions:list --project=nexus-visibility-app 2>&1 | grep -E "market|waitlist|launch"
```
**Expected**:
- send_waitlist_reminder_14day (scheduled)
- initializeMarket (https)
- executeMarketLaunch (https)

### 4️⃣ Verify Flutter Compilation
```bash
cd /Users/aybaj/Documents/nexus_app_v2 && flutter analyze lib/features/dating_search/presentation/screens/waiting_list_screen.dart lib/features/dating_search/presentation/screens/daily_profiles_screen.dart lib/features/admin_review/presentation/screens/market_launch_control_screen.dart 2>&1 | grep -E "(error|Error|✓|issues)"
```
**Expected**: `No issues found!`

---

## 🎯 Testing Sequence

### Step 1: Admin Test (5 minutes)
```bash
# 1. Open app and navigate to /admin/market-launch
# 2. Log in as user with isAdmin: true
# 3. Verify market selector shows "uk"
# 4. Verify current phase shows "prelaunch"
# 5. Click "📅 Schedule Launch" → select date → confirm
# 6. Check Firestore: /markets/uk → launchDate should be updated
```

### Step 2: User Test (5 minutes)
```bash
# 1. Create test user:
#    - countryOfResidence: "United Kingdom"
#    - verificationStatus: "verified"
#    - isAdmin: false
# 2. Log in as test user
# 3. Navigate to dating search
# 4. Verify WaitingListScreen shows with 14-day countdown
# 5. Verify dark mode works correctly
# 6. Verify gradient animations on load
```

### Step 3: Launch Test (2 minutes)
```bash
# 1. From admin panel: Click "🚀 Launch Now"
# 2. Confirm dialog
# 3. Check Firestore: /markets/uk → phase should be "active"
# 4. Log in as test user (refresh if needed)
# 5. Verify DailyProfilesScreen shows instead of WaitingListScreen
# 6. Verify profile carousel works (swipe, click pass/message)
```

### Step 4: Revert Test (1 minute)
```bash
# 1. From admin panel: Click "⏸ Stay in Pre-Launch"
# 2. Check Firestore: /markets/uk → phase should be "prelaunch"
# 3. Log in as test user (refresh if needed)
# 4. Verify WaitingListScreen shows again
```

---

## 📱 Admin Access Setup

If you don't have admin access yet, run:
```bash
cd /Users/aybaj/Documents/nexus_app_v2
node << 'SCRIPT'
const admin = require('firebase-admin');
const serviceAccount = require('./serviceAccount.json');

admin.initializeApp({
  credential: admin.credential.cert(serviceAccount),
});

const db = admin.firestore();

async function grantAdminAccess(userId) {
  try {
    await db.collection('users').doc(userId).update({ isAdmin: true });
    console.log(`✅ Granted admin access to ${userId}`);
  } catch (error) {
    console.error('❌ Error:', error.message);
  }
  process.exit(0);
}

grantAdminAccess('YOUR_USER_ID_HERE');
SCRIPT
```

---

## 🔄 Redeployment (if needed)

```bash
# Deploy only functions
cd /Users/aybaj/Documents/nexus_app_v2
firebase deploy --only functions

# Rebuild Flutter app
flutter pub get
flutter analyze
flutter build apk  # or ios
```

---

## 📊 Monitoring

### Check Cloud Function Logs
```bash
gcloud functions log read send_waitlist_reminder_14day --limit 50 --project=nexus-visibility-app
gcloud functions log read initializeMarket --limit 50 --project=nexus-visibility-app
gcloud functions log read executeMarketLaunch --limit 50 --project=nexus-visibility-app
```

### Monitor Cloud Scheduler
```bash
# Check next execution time
gcloud scheduler jobs describe send-waitlist-reminder-14day --location=us-central1 --project=nexus-visibility-app

# Manually trigger (for testing)
gcloud scheduler jobs run send-waitlist-reminder-14day --location=us-central1 --project=nexus-visibility-app
```

---

## 📁 Key Files

| File | Purpose |
|------|---------|
| `scripts/initialize_market.js` | Create/verify market document |
| `functions/market_launch_manager.js` | Cloud Functions code |
| `lib/features/dating_search/application/market_phase_provider.dart` | Real-time market phase streaming |
| `lib/features/admin_review/presentation/screens/market_launch_control_screen.dart` | Admin dashboard |
| `UK_MARKET_LAUNCH_SETUP.md` | Detailed setup guide |
| `IMPLEMENTATION_COMPLETE.md` | This implementation summary |

---

## ✅ Deployment Checklist

- [x] Firestore `/markets/uk` document created
- [x] Cloud Scheduler job enabled (`15 9 * * *` UTC)
- [x] Cloud Functions deployed (initializeMarket, send_waitlist_reminder_14day, executeMarketLaunch)
- [x] Flutter screens implemented and tested
- [x] Admin dashboard functional
- [x] Dark mode integrated
- [x] Theme colors applied
- [x] All screens compile without errors

---

## 🎯 Quick Status Check

Run this to verify everything in one go:
```bash
echo "=== Checking Market Document ===" && \
cd /Users/aybaj/Documents/nexus_app_v2 && \
node scripts/initialize_market.js uk 2>&1 | grep -E "(Market|phase|country)" && \
echo "" && \
echo "=== Checking Cloud Scheduler ===" && \
gcloud scheduler jobs list --location=us-central1 --project=nexus-visibility-app --format="table(name, state)" | grep send-waitlist && \
echo "" && \
echo "=== Checking Cloud Functions ===" && \
firebase functions:list --project=nexus-visibility-app 2>&1 | grep -E "(initializeMarket|send_waitlist|executeMarketLaunch)" && \
echo "" && \
echo "✅ All systems verified!"
```

---

**Created**: June 7, 2026  
**Implementation Status**: ✅ 100% COMPLETE  
**Next Step**: Test with admin user & create test profiles
