# UK Market Launch Setup Guide

## Overview
This guide walks through the setup steps to enable the UK market launch system, including the waiting list screen, 14-day countdown, and daily profiles carousel with admin controls.

## Implementation Checklist

### ✅ Phase 1: Code Implementation (COMPLETED)
- [x] Flutter UI Screens
  - [x] WaitingListScreen - premium animations, 14-day countdown, gradient design
  - [x] DailyProfilesScreen - carousel with action buttons, enhanced indicators
  - [x] MarketLaunchControlScreen - admin dashboard for market phase control
- [x] State Management
  - [x] MarketPhaseProvider - real-time market phase streaming from Firestore
  - [x] Market routing logic - SearchResultsRouterScreen updated to check market.phase
- [x] Navigation
  - [x] Added /admin/market-launch route to app_router.dart
- [x] Cloud Functions
  - [x] market_launch_manager.js - Initialize market, waitlist reminders, launch handler
  - [x] index.js - Exports for all market functions

### 🔄 Phase 2: Firestore Configuration (IN PROGRESS)
- [ ] Create /markets collection
- [ ] Create /markets/uk document with initial configuration
- [ ] Verify Firestore security rules

### 🔄 Phase 3: Cloud Functions Deployment (NEXT)
- [ ] Deploy market_launch_manager.js functions
- [ ] Set up Cloud Scheduler for 14-day waitlist reminders (9:15 AM UTC daily)
- [ ] Test initializeMarket HTTP endpoint
- [ ] Test executeMarketLaunch callable function

### ⏳ Phase 4: Integration Testing (PENDING)
- [ ] Create test users with verified status
- [ ] Trigger market initialization
- [ ] Verify waiting list screen displays correctly
- [ ] Test 14-day countdown calculation
- [ ] Verify market phase toggle works in admin panel
- [ ] Test daily profiles display after launch

---

## Detailed Setup Steps

### STEP 1: Initialize Market Document in Firestore

**Method A: Using Firebase Console (Manual)**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select the nexus-visibility-app project
3. Navigate to Firestore Database
4. Create a new collection called `markets`
5. Create a new document with ID: `uk`
6. Add the following fields:

```json
{
  "country": "United Kingdom",
  "phase": "prelaunch",
  "launchDate": null,
  "approvedProfileCount": 0,
  "gender": {
    "male": 0,
    "female": 0
  },
  "dailyNotificationTime": "09:00",
  "createdAt": <TIMESTAMP_NOW>,
  "updatedAt": <TIMESTAMP_NOW>
}
```

**Method B: Using Cloud Functions (Automated)**

After deploying Cloud Functions (Step 3), call the HTTP endpoint:

```bash
curl -X POST "https://us-central1-nexus-visibility-app.cloudfunctions.net/initializeMarket?market=uk"
```

Response:
```json
{
  "success": true,
  "message": "Market 'uk' initialized successfully",
  "data": { /* market config */ }
}
```

---

### STEP 2: Verify Firestore Security Rules

Ensure the following rules are in place in Firestore:

```javascript
// Read markets collection - all authenticated users
match /markets/{market} {
  allow read: if request.auth != null;
  allow write: if request.auth.token.admin == true;
}

// Approve profiles update to market stats
match /users/{userId} {
  allow read: if request.auth.uid == userId || request.auth.token.admin == true;
  allow update: if request.auth.token.admin == true;
}
```

---

### STEP 3: Deploy Cloud Functions

**3.1 Install Dependencies**

```bash
cd firebase_functions
npm install
```

**3.2 Deploy to Firebase**

```bash
cd ..
firebase deploy --only functions
```

Expected output:
```
✔  Function initializeMarket deployed
✔  Function send_waitlist_reminder_14day deployed
✔  Function executeMarketLaunch deployed
```

**3.3 Verify Deployment**

Check in Firebase Console → Cloud Functions → check all three functions are deployed

---

### STEP 4: Set Up Cloud Scheduler for Daily Reminders

**4.1 Create Scheduler Job**

1. Go to [Cloud Scheduler](https://console.cloud.google.com/cloudscheduler)
2. Click "Create Job"
3. Fill in the following:
   - **Name**: `send-waitlist-reminder-14day`
   - **Frequency**: `15 9 * * *` (9:15 AM UTC daily)
   - **Timezone**: `UTC`
4. Click Create
5. Click the job name to edit it
6. Set up execution:
   - **Type**: Pub/Sub
   - **Topic**: Create new topic: `send-waitlist-reminder-14day`
   - Click Create and Continue

The Pub/Sub trigger will automatically invoke the Cloud Function deployed in STEP 3.

---

### STEP 5: Test the Implementation

**5.1 Test Market Initialization**

1. Open Firebase Console → Firestore Database
2. Verify `/markets/uk` document exists with all fields
3. Note the launchDate value (should be null initially)

**5.2 Test Admin Panel Access**

1. Ensure your user has `isAdmin: true` in Firestore `/users/{userId}`
2. In the app, navigate to `/admin/market-launch`
3. You should see:
   - Market selector showing "uk"
   - Current phase: "prelaunch"
   - Approved profiles count: 0
   - Launch controls (Now, Schedule, Stay in Pre-Launch)

**5.3 Test Launch Controls**

From the admin panel:

1. **Click "📅 Schedule Launch"**
   - Select a date (default: 14 days from now)
   - Select a time (default: 14:00 UTC)
   - Click confirmation
   - Verify launchDate updates in Firestore

2. **Click "🚀 Launch Now"**
   - Click confirmation dialog
   - Verify phase changes from "prelaunch" to "active" in Firestore
   - Verified users should see DailyProfilesScreen instead of WaitingListScreen

3. **Click "⏸ Stay in Pre-Launch"**
   - Phase reverts to "prelaunch"
   - Users see WaitingListScreen again

**5.4 Test User Waiting List Experience**

1. Create test user with:
   - `verificationStatus: "verified"`
   - `countryOfResidence: "United Kingdom"`
   - `joinedWaitlistAt: <timestamp 14+ days ago>` (for reminder testing)

2. Log in as this user
3. Navigate to dating search
4. Should see WaitingListScreen with:
   - 14-day countdown (calculated from current date)
   - "5 Daily Matches" expectation card
   - Premium animations on load

**5.5 Test Launch Day Experience**

1. From admin panel, click "🚀 Launch Now"
2. Log in as verified user
3. Navigate to dating search
4. Should immediately see DailyProfilesScreen with:
   - Carousel of 5 daily profiles
   - Profile photos full-screen
   - Name, age, location (City • Country format)
   - Message and Pass buttons
   - "X of Y" indicators

---

## Key Implementation Details

### Market Phase Flow

```
User Created (Not Verified)
         ↓
    [Email Verification]
         ↓
User Verified → Country = UK
         ↓
Check Market Phase
    ├─ phase: 'prelaunch' → WaitingListScreen
    │                        (14-day countdown)
    │
    ├─ phase: 'active' → DailyProfilesScreen
    │                     (5 daily profiles carousel)
    │
    └─ phase: 'closed' → Market Closed Error
```

### Admin Market Control

```
Market Launch Control Panel
├─ Market Selector (uk/nigeria/ghana)
├─ Status Card
│  ├─ Current Phase (prelaunch/active/closed)
│  ├─ Approved Profiles Count
│  └─ Gender Distribution (♂/♀)
├─ Date/Time Picker
└─ Action Buttons
   ├─ 🚀 Launch Now (immediate)
   ├─ 📅 Schedule Launch (future date/time)
   └─ ⏸ Stay in Pre-Launch (revert to prelaunch)
```

### 14-Day Countdown Calculation

```javascript
// In WaitingListScreen
final launchDate = DateTime.now().add(const Duration(days: 14));
final now = DateTime.now();
final difference = launchDate.difference(now);

final days = difference.inDays;
final hours = difference.inHours % 24;

// Display: "X days · Y hours"
```

### Location Display Format

```dart
// Already implemented in DatingProfile.displayLocation getter
"$city • $country"

// Example output:
"London • United Kingdom"
"Lagos • Nigeria"
```

---

## Firestore Rules Reference

### Collections Structure

```
/markets/{market}
├─ country: string
├─ phase: 'prelaunch' | 'active' | 'closed'
├─ launchDate: timestamp | null
├─ approvedProfileCount: number
├─ gender
│  ├─ male: number
│  └─ female: number
├─ dailyNotificationTime: string (HH:MM format)
├─ createdAt: timestamp
└─ updatedAt: timestamp

/users/{userId}
├─ verificationStatus: 'unverified' | 'verified'
├─ countryOfResidence: string
├─ joinedWaitlistAt: timestamp (when verified)
├─ lastReminderSentAt: timestamp (last 14-day reminder)
└─ isAdmin: boolean (admin flag)

/dailyProfiles/{userId}
├─ date: timestamp (today's date)
├─ profiles: [profileId1, profileId2, ...]
└─ updatedAt: timestamp
```

---

## Troubleshooting

### Issue: Market doesn't exist in Firestore

**Solution**: 
1. Check Firebase Console → Firestore Database
2. Ensure collection `markets` exists
3. Ensure document `uk` exists with all required fields
4. Or call `initializeMarket?market=uk` endpoint to auto-create

### Issue: Waiting list screen shows "Error loading market info"

**Solution**:
1. Check user's `countryOfResidence` is "United Kingdom"
2. Verify user's `verificationStatus` is "verified"
3. Check Firestore rules allow reads to /markets/{market}

### Issue: Admin panel shows "Admin access required"

**Solution**:
1. Log in as a user with `isAdmin: true` in Firestore
2. Or add the field to your user document:
   ```javascript
   db.collection('users').doc(uid).update({ isAdmin: true })
   ```

### Issue: Cloud Function `send_waitlist_reminder_14day` not triggering

**Solution**:
1. Verify Cloud Scheduler job exists and is enabled
2. Check Cloud Scheduler job timezone is set to UTC
3. Check job frequency cron expression: `15 9 * * *`
4. Verify Pub/Sub topic exists and is connected to function

### Issue: Daily profiles don't show after launch

**Solution**:
1. Verify market phase is "active" in Firestore
2. Run `flutter analyze` to check for compilation errors
3. Verify dailyProfilesProvider has profiles available
4. Check app's market phase real-time listening working

---

## Next Steps

After completing setup:

1. Create staging profiles for testing
2. Run end-to-end tests with test users
3. Schedule UK market launch in admin panel for specific date/time
4. Monitor waitlist reminder Cloud Function logs
5. Prepare marketing announcement for launch day

---

## Production Deployment Checklist

Before going live:

- [ ] Test with 25M + 25F profiles minimum
- [ ] Verify 14-day countdown accuracy
- [ ] Test admin launch controls thoroughly
- [ ] Verify daily profiles carousel performance
- [ ] Test dark mode on all screens
- [ ] Test on multiple devices (phone, tablet)
- [ ] Verify theme colors (primary red #BA223C) displaying correctly
- [ ] Monitor Cloud Function logs for errors
- [ ] Set up alerts for failed launches
- [ ] Prepare rollback procedure if needed

---

**Last Updated**: 2024
**Status**: Setup Guide Complete
