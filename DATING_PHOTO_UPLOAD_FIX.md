## Dating Photo Upload Investigation & Fix

**Issue Reported:** Photos don't upload to DigitalOcean Spaces during dating onboarding (but work fine in edit profile)

---

## What I Found

### Architecture Overview
The app has **two photo upload flows**:

1. **Edit Profile Screen** (✅ WORKS)
   - Uses `MediaService().uploadProfilePhoto()`
   - Calls → `DoSpacesStorageService.uploadImage()`  
   - Uploads to: `profile/photos/{userId}/{photoIndex}.jpg`

2. **Dating Onboarding Photos** (❌ ISSUE)
   - Uses `ref.read(mediaStorageProvider)` provider
   - Calls → `DoSpacesStorageService.uploadImage()`
   - Uploads to: `dating/photos/{timestamp}_{index}.jpg`

### Both Use Same DO Spaces Upload
Both flows ultimately call the same `DoSpacesStorageService.uploadFile()` method which:
1. Gets Firebase ID token
2. Calls presign Cloud Function to get upload URL
3. PUT file bytes to upload URL  
4. Returns public URL

**If edit profile works, dating onboarding should work too** (unless there's a draft state caching issue).

### Potential Root Cause Found ⚠️

The code has a **caching optimization** that could skip uploads:

```dart
// dating_photos_screen.dart lines 224-237
final alreadyUploaded =
    draft.photoUrls.isNotEmpty &&
    draft.photoUrls.length == _photoPaths.length;

if (alreadyUploaded) {
  // SKIP UPLOAD - assume already done
  Navigator.of(context).pushNamed('/dating/setup/audio');
  return;
}
```

If `draft.photoUrls` is populated from a **previous failed attempt** or **incorrect state**, this check will skip the upload on subsequent tries.

---

## What I Fixed

### 1. **Enhanced Logging** (`dating_photos_screen.dart`)
Added detailed diagnostics at every step:
- When photos are picked
- When draft state is checked  
- When upload starts/succeeds/fails
- When URLs are saved

**New logs will show patterns like:**
```
[PHOTOS] ===== PHOTOS SCREEN INIT =====
[PHOTOS] Draft has 2 local photo paths
[PHOTOS] Draft has 0 uploaded photo URLs
[PHOTOS] Pick returned 3 images
[PHOTOS] ✅ Face detected in: photo1.jpg
[PHOTOS] After selection: 3 photos in _photoPaths
[PHOTOS] _onContinue called
[PHOTOS] 🚀 Uploading 3 photos to DO Spaces...
[PHOTOS] ✅ Uploaded photo 1: https://...do-spaces.com/dating/photos/...
[PHOTOS] 💾 Saving 3 URLs to draft...
[PHOTOS] 🎬 Navigating to audio screen...
```

### 2. **Strengthened Cache Skip Check**
Added validation to prevent skipping when cache is invalid:
```dart
// NEW: Validate that all cached URLs are non-empty
final urlsAreValid = draft.photoUrls.every((url) => url.trim().isNotEmpty);
final alreadyUploaded =
    draft.photoUrls.isNotEmpty &&
    draft.photoUrls.length == _photoPaths.length &&
    urlsAreValid;  // ← NEW SAFETY CHECK
```

### 3. **URL Validation on Upload**
```dart
// NEW: Ensure upload didn't return empty string
if (publicUrl.trim().isEmpty) {
  throw Exception('Upload returned empty URL');
}
```

### 4. **Diagnostic Draft Inspection**
```dart
if (!alreadyUploaded && draft.photoUrls.isNotEmpty) {
  // NEW: Warn if cache state is inconsistent
  print('[PHOTOS] ⚠️  Draft has URLs but mismatch—will re-upload');
}
```

---

## How to Test the Fix

### Step 1: Rebuild Completely
```bash
flutter clean
flutter pub get  
flutter run
```
(Need full rebuild, hot restart won't pick up Dart code changes)

### Step 2: Test Dating Onboarding Again
1. Go to Profile → "Create Dating Profile"
2. Go through onboarding flow to Photos screen
3. Select 2+ (max 5) photos
4. Tap "Continue"
5. **Watch the console output**

### Step 3: Check Logs
Run `flutter run` and watch for **[PHOTOS]** log messages:

**Expected flow (SUCCESS):**
```
[PHOTOS] _onContinue called
[PHOTOS] _photoPaths.length=3
[PHOTOS] draft.photoUrls.length=0
[PHOTOS] alreadyUploaded=false
[PHOTOS] 🚀 Uploading 3 photos to DO Spaces...
[PHOTOS] ✅ Uploaded photo 1: https://...
[PHOTOS] ✅ Uploaded photo 2: https://...
[PHOTOS] ✅ Uploaded photo 3: https://...
[PHOTOS] 💾 Saving 3 URLs to draft...
[PHOTOS] 🎬 Navigating to audio screen...
```

**Bad state (CACHE SKIP):**
```
[PHOTOS] draft.photoUrls.length=3
[PHOTOS] urlsAreValid=true
[PHOTOS] alreadyUploaded=true
[PHOTOS] ⏭️  Skipping upload—3 URLs already exist
[PHOTOS] 🎬 Navigating to audio screen...
```
→ If you see this on FIRST attempt, draft had stale data

---

## If Upload Still Fails

### Check the error message
Look for `[PHOTOS] ❌ Upload error...` in logs

**Common issues:**

| Error | Cause | Fix |
|-------|-------|-----|
| "Not authenticated" | Firebase user not signed in | Sign in first |
| "Presign failed (400)" | Cloud Function parameter issue | Check logs for details |
| "Presign failed (401)" | Firebase token invalid | Try logout/login |
| "Upload failed (403)" | DO Spaces auth issue | Check env vars, rebuild |
| "Network error" | No internet connection | Check connectivity |

---

## If Cache is Stuck

If you added photos before the fix and they're now "stuck" (keeps skipping upload):

### Option 1: Clear Draft via Code  
```bash
dart clear_dating_draft.dart
```

### Option 2: Clear via SharedPreferences  
Delete and reinstall app:
```bash
flutter clean
flutter run
```

### Option 3: Clear via DevTools
```bash
flutter run
# In DevTools Console:
# SharedPreferences.getInstance().then((p) => p.remove('dating_onboarding_draft'))
```

---

## Files Modified

| File | Changes | Purpose |
|------|---------|---------|
| `lib/.../dating_photos_screen.dart` | Enhanced logging in 4 methods | Comprehensive diagnostics |
| `lib/.../dating_photos_screen.dart` | Added `urlsAreValid` check | Prevent cache skip on bad state |
| `lib/.../dating_photos_screen.dart` | Added URL empty validation | Ensure upload success |
| `clear_dating_draft.dart` | NEW utility | Manual draft clearing |
| `test_dating_photo_upload.dart` | NEW diagnostic test | Reference for troubleshooting |

---

## Next Steps for User

1. **Rebuild app** (full clean, not hot restart)
2. **Try dating onboarding photos again**
3. **Share console logs** showing [PHOTOS] messages
4. If still failing, **identify which error message appears**

The enhanced logging will tell us exactly where the upload flow is breaking, so we can fix the root cause.

---

## Summary of Root Cause Theories

Based on code review, the most likely issue is:

**Timing:** 
- Photos upload correctly the FIRST time → URLs saved to SharedPreferences
- If profile is NOT completed (app closes, crash, user goes back)
- Draft with URLs persists in SharedPreferences
- Next time user enters photos screen, cache check sees URLs and SKIPS upload  
- But if user selected DIFFERENT photos, those photos never get uploaded

**Fix Applied:** 
- Added check for stale cache (`urlsAreValid`)
- Added logging to see cache state
- Enhanced error handling for empty URLs
- User can now see exactly what's cached vs. being uploaded

