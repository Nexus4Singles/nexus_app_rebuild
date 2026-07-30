# Launch Date Configuration Guide

## Overview

The waiting list countdown and market phase are configured through Firestore, **not hardcoded in the app**. This means you can change the launch date and market status at any time without deploying a new app build to the App Store or Google Play.

## Key Implementation Details

### Real-Time Architecture

- **Market Data Stream**: The app watches the `/markets/uk` document in Firestore in real-time via `marketPhaseProvider`
- **Router Logic**: `SearchResultsRouterScreen` checks `market.phase` and routes users accordingly:
  - `prelaunch` → Shows WaitingListScreen with countdown
  - `active` → Shows DailyProfilesScreen (daily profile carousel)
  - `closed` → Shows market closed error screen
- **Timer Updates**: The countdown timer updates every 1 second for real-time countdown experience

### Why This Works Without App Deployment

1. Flutter app streams from Firestore continuously
2. When you update `/markets/uk`, all users receive the update in real-time
3. No app store deployment needed
4. Works immediately for all users globally

## How to Set the Launch Date

### Step 1: Open Firestore Console

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select your Nexus App project
3. Click **Firestore Database** in the left sidebar
4. Select your production database (should be default)

### Step 2: Locate the Market Document

Navigate to the document: **`/markets/uk`**

You should see a document with these fields:
```
country: "United Kingdom"
phase: "prelaunch"
launchDate: null (or existing date)
approvedProfileCount: 0
dailyNotificationTime: "09:00"
gender: {female: 3, male: 2}
```

### Step 3: Update the Launch Date

Click the **`launchDate`** field and set it to your desired launch date/time.

**Format**: Select "Timestamp" type and choose the date/time. For example:
- **August 15, 2026 at 07:00 UTC** (recommended: launch early morning UTC for coordinated global launch)

**Action**: Click **Update** (or click elsewhere to save automatically)

### Step 4: What Happens When Launch Date Arrives

**Automatic Behavior (via Cloud Scheduler job)**:
- At the scheduled launch date/time, the `executeMarketLaunch` Cloud Function runs automatically
- This function:
  1. Updates `market.phase` from `"prelaunch"` to `"active"`
  2. Sends FCM notification to all waiting list users: "Dating market is now LIVE! Tap to discover matches."
  3. Creates market statistics document
  4. Starts daily profile refresh automation (11 PM UTC daily)

**Result**: 
- All users (existing + new) immediately see DailyProfilesScreen instead of WaitingListScreen
- Waiting list screen is no longer shown to anyone
- Daily profile recommendations carousel starts showing

## Manual Market Phase Changes (Advanced)

If you need to manually change the market phase (instead of waiting for automatic launch):

### Manually Activate Market

1. Open `/markets/uk` document in Firestore
2. Change `phase` field from `"prelaunch"` to `"active"`
3. Click **Update**

**Immediate Result**:
- All users routed to DailyProfilesScreen
- Waiting list screen no longer shown
- Daily recommendations carousel visible

### Manually Pause Market

Change `phase` to `"closed"`:
1. Open `/markets/uk` document
2. Change `phase` field from `"active"` to `"closed"`
3. Click **Update**

**Immediate Result**:
- All users see "Market Closed" error screen
- Use this if you need to pause the market temporarily

### Revert to Pre-Launch

Change `phase` back to `"prelaunch"`:
1. Open `/markets/uk` document
2. Change `phase` field to `"prelaunch"`
3. Click **Update**

**Immediate Result**:
- All users back to WaitingListScreen with countdown timer

## Testing the Implementation

### Test 1: Verify Countdown Updates in Real-Time

1. Set `launchDate` to 5 days from now
2. Open app on test device
3. Go to search/dating section
4. Watch countdown timer - it should update every second
5. Close and reopen app - countdown should still be accurate

### Test 2: Verify Post-Launch Routing

1. Set `launchDate` to the past (e.g., yesterday)
2. In `/markets/uk`, set `phase` to `"active"`
3. Open app → Should see DailyProfilesScreen (not WaitingListScreen)
4. Kill and restart app → Should still see DailyProfilesScreen
5. Uninstall and reinstall app → New user should also see DailyProfilesScreen

### Test 3: Verify Automatic Launch

1. Set `launchDate` to 5 minutes from now
2. Watch `/markets/uk` document in Firestore
3. Wait for the scheduled time to pass
4. Observe `phase` changes from `"prelaunch"` to `"active"` automatically
5. Check app - should route to DailyProfilesScreen

## FAQ

### Q: Can I change the launch date multiple times?
**A**: Yes, you can update it anytime. The app will show the updated countdown immediately.

### Q: What if I set the launch date to the past?
**A**: The countdown will show negative values or stay at 00:00:00. The Cloud Function won't trigger if the date is past. For testing, manually change `phase` to `"active"` instead.

### Q: Do users need to update their app?
**A**: No! All changes are in Firestore, which the app streams in real-time. Users see changes immediately without any app update.

### Q: What if I want to launch at a specific time (e.g., exactly 9 AM UTC)?
**A**: Set the `launchDate` timestamp to that exact time. The Cloud Function respects the exact timestamp and launches at that moment.

### Q: Can I see the launch status?
**A**: Yes, check the `phase` field in `/markets/uk`:
- `"prelaunch"` = Waiting list visible
- `"active"` = Daily profiles visible
- `"closed"` = Market closed

### Q: What happens to the countdown after launch?
**A**: The WaitingListScreen won't be shown anymore, so the countdown is no longer relevant. Users are routed to DailyProfilesScreen instead.

## Cloud Functions Involved

### `executeMarketLaunch` (Automatic)
- **Triggers**: At the `launchDate` timestamp via Cloud Scheduler
- **Updates**: `market.phase` to `"active"`
- **Notifies**: All waiting list users
- **Starts**: Daily profile refresh automation
- **Deployment**: Cloud Functions > `executeMarketLaunch`

### `refreshDiscoverProfiles` (Daily)
- **Triggers**: 11 PM UTC daily (0 23 * * *)
- **Updates**: Profiles in daily carousel
- **Notifies**: Users with new profiles available
- **Deployment**: Cloud Functions > `refreshDiscoverProfiles`

## Related Files

- **App Routing**: [lib/features/dating_search/presentation/screens/search_results_router_screen.dart](../../lib/features/dating_search/presentation/screens/search_results_router_screen.dart)
- **Waiting List Screen**: [lib/features/dating_search/presentation/screens/waiting_list_screen.dart](../../lib/features/dating_search/presentation/screens/waiting_list_screen.dart)
- **Market Phase Provider**: [lib/features/dating_search/application/market_phase_provider.dart](../../lib/features/dating_search/application/market_phase_provider.dart)
- **Market Launch Function**: [functions/execute_market_launch.js](../../functions/execute_market_launch.js)
- **Profile Refresh Function**: [functions/refresh_discover_profiles.js](../../functions/refresh_discover_profiles.js)

## Summary

**To launch the UK market without redeploying:**
1. Open Firestore Console
2. Navigate to `/markets/uk`
3. Set `launchDate` to your desired date/time
4. Wait for that time, or manually change `phase` to `"active"` to launch immediately
5. All users see changes in real-time without app update needed
