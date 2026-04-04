# App Update Configuration Setup Guide

## Quick Start

### Option 1: Automatic Setup (Recommended)

Run the automated script to set up the Firestore configuration:

```bash
node scripts/setup_app_update_config.js
```

**Prerequisites:**
- Firebase Admin SDK credentials (either via `GOOGLE_APPLICATION_CREDENTIALS` environment variable or `serviceAccountKey.json` in the root)
- Node.js installed

### Option 2: Manual Firestore Configuration

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your Nexus project
3. Navigate to **Firestore Database**
4. Create a new collection called `config` (if it doesn't exist)
5. Create a new document with ID `appUpdate`
6. Add the following fields:

| Field | Type | Value | Example |
|-------|------|-------|---------|
| `latestVersion` | String | Current app version | `"2.1.0"` |
| `releaseDate` | Timestamp | Current date/time | Auto-generated |
| `changesSummary` | String | Brief update description | `"Bug fixes and new chat features"` |
| **Nested Map:** `storeUrl` |
| `storeUrl.ios` | String | iOS App Store link | `"https://apps.apple.com/app/id1234567890"` |
| `storeUrl.android` | String | Google Play link | `"https://play.google.com/store/apps/details?id=com.your.app"` |

---

## Getting Your Store URLs

### iOS App Store URL

1. Open [App Store Connect](https://appstoreconnect.apple.com/)
2. Select your app
3. Go to **App Information**
4. Copy the **App Store URL**
5. Format: `https://apps.apple.com/app/id[YOUR_APP_ID]`

**Example:** `https://apps.apple.com/app/id1234567890`

### Android Google Play URL

1. Open [Google Play Console](https://play.google.com/console/)
2. Select your app
3. Go to **App details**
4. Copy or construct the URL
5. Format: `https://play.google.com/store/apps/details?id=[PACKAGE_NAME]`

**Example:** `https://play.google.com/store/apps/details?id=com.nexus.dating`

---

## Firebase Firestore Document Structure

```json
{
  "latestVersion": "2.1.0",
  "releaseDate": "2026-03-27T10:30:00Z",
  "changesSummary": "Bug fixes, new chat features, and performance improvements",
  "storeUrl": {
    "ios": "https://apps.apple.com/app/id1234567890",
    "android": "https://play.google.com/store/apps/details?id=com.nexus.dating"
  }
}
```

---

## How It Works

1. **User launches app** → App automatically checks Firestore `config/appUpdate`
2. **Version comparison** → Compares `latestVersion` with current app version
3. **One-time per version** → SharedPreferences tracks shown versions
4. **User sees modal** → If new version available, compact modal appears
5. **User action** → Tap "Update Now" → Opens app store (iOS or Android)

---

## Updating the Version

Every time you release a new version:

1. Update the `latestVersion` in Firestore
2. Update `changesSummary` with new features/fixes
3. Update `releaseDate` to current timestamp
4. Users will automatically see the update modal on their next app launch

---

## Testing

### Reset Notification State (Development Only)

If you want to test the modal again without incrementing the version:

```dart
// In your settings screen or debug console
await AppUpdateService.resetNotificationState();
// Then relaunch the app
```

### Manual Update Check

Add this button to your settings screen:

```dart
AppBar(
  actions: [
    ManualUpdateCheckButton(),
  ],
)
```

---

## Firestore Security Rules

Add this to your Firestore rules to allow public read access to the update config (but not write):

```
match /config/{document=**} {
  allow read: if true;
  allow write: if request.auth.uid != null && isAdmin(request.auth.uid);
}
```

---

## Environment Variables

If using the automated script, set your Firebase credentials:

**Option A: Environment Variable**
```bash
export GOOGLE_APPLICATION_CREDENTIALS="/path/to/serviceAccountKey.json"
node scripts/setup_app_update_config.js
```

**Option B: Place Key in Root**
```bash
cp /path/to/serviceAccountKey.json ./serviceAccountKey.json
node scripts/setup_app_update_config.js
```

---

## Troubleshooting

### "Document already exists" message
- This is normal. The script will update the existing document.
- Your previous configuration will be merged/overwritten.

### "Firebase initialization error"
- Make sure your service account key has appropriate permissions
- Verify `GOOGLE_APPLICATION_CREDENTIALS` is correctly set
- Check that the Firebase project is accessible

### Modal not showing
- Verify `latestVersion` in Firestore is newer than app version
- Check SharedPreferences wasn't reset by uninstalling app
- Try `AppUpdateService.resetNotificationState()` for testing

---

## Version Comparison Logic

The system uses semantic versioning (SemVer):

- `2.1.0` > `2.0.9` ✅
- `2.0.0` > `1.9.9` ✅
- `3.0.0` > `2.1.0` ✅
- `2.1.0` = `2.1.0` ❌ (no update shown)

---

## Next Steps

1. ✅ Run `node scripts/setup_app_update_config.js`
2. ✅ Verify `config/appUpdate` document in Firestore
3. ✅ Update `pubspec.yaml` version number
4. ✅ Release new app version to stores
5. ✅ Update Firestore `latestVersion` when ready
6. ✅ Users will see modal on next app launch
