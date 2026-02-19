## Quick Start: Dating Photo Upload Troubleshooting

### Problem
Photos don't upload to DO Spaces when completing dating profile onboarding (but work in edit profile).

### Solution
Follow these steps to identify and fix the issue:

---

## Step 1: Rebuild (Required)
```bash
cd /Users/aybaj/Documents/nexus_app_v2
flutter clean
flutter pub get
flutter run
```
⚠️ **Must do full rebuild** - hot restart won't pick up diagnostic logging.

---

## Step 2: Test Photos Upload
1. Open app
2. Go to **Profile** tab
3. Tap **"Create Dating Profile"** button  
4. Follow onboarding through to **Photos screen**
5. Select 2-5 photos  
6. Tap **"Continue"** button
7. Watch console output for `[PHOTOS]` messages

---

## Step 3: Check Console Output
Run command: `flutter run`  

### What to look for:

#### ✅ SUCCESS - Photos uploaded!
You'll see:
```
[PHOTOS] 🚀 Uploading 3 photos to DO Spaces...
[PHOTOS] ✅ Uploaded photo 1: https://bucket.do-spaces.com/dating/photos/...
[PHOTOS] ✅ Uploaded photo 2: https://bucket.do-spaces.com/dating/photos/...
[PHOTOS] ✅ Uploaded photo 3: https://bucket.do-spaces.com/dating/photos/...
[PHOTOS] 💾 Saving 3 URLs to draft...
[PHOTOS] 🎬 Navigating to audio screen...
```
→ **Check dating profile later to verify photos show up**

---

#### ⏭️  CACHE SKIP - Upload skipped!
You'll see:
```
[PHOTOS] draft.photoUrls.length=3  
[PHOTOS] alreadyUploaded=true
[PHOTOS] ⏭️  Skipping upload — 3 URLs already exist
[PHOTOS] 🎬 Navigating to audio screen...
```
→ **Draft has old URLs from previous attempt**  
→ **Clear draft and retry:**
```bash
dart clear_dating_draft.dart
```
Then retry Step 2

---

#### ❌ ERROR - Upload failed!
You'll see something like:
```
[PHOTOS] ❌ Upload error for photo 1: Not authenticated
[PHOTOS] Stack trace: ...
```

**Common fixes:**

| Error | Fix |
|-------|-----|
| "Not authenticated" | Make sure you're logged into the app |
| "Presign failed (401)" | Try: Sign out → Sign in again |
| "Upload failed (403)" | Rebuild: `flutter clean && flutter run` |
| "Network" error | Check internet connection |
| Empty URL returned | Very rare - file might be corrupted |

---

## Step 4: Verify Photos for Profile
If upload succeeded:
1. Continue through onboarding (audio, contact info, etc.)
2. Complete dating profile
3. Go back to **Profile** tab
4. Tap **"Edit Dating Profile"** or view in dating search
5. **Verify your photos appear** in the dating profile view

---

## Step 5: Share Logs If Still Broken  
If photos still don't upload after rebuild, please share:

```bash
flutter run 2>&1 | tee flutter_logs.txt
# [Go through photos screen in app]
# [Paste content of flutter_logs.txt]
```

Include everything from `[PHOTOS]` messages onwards.

---

## Why This Happens

**Root Cause:** The app caches photo URLs in SharedPreferences when they're uploaded. If the app crashes or user goes back before completing the profile, those URLs stay cached. Next time, the code sees cached URLs and SKIPS the upload.

**The Fix:** Now validates that cached URLs are valid before skipping, and adds logging to show what's happening.

---

## Emergency: Clear Everything

If stuck and nothing else works:
```bash
flutter clean
rm -rf build/
flutter pub get
flutter run
```

This will:
- Clear all build artifacts
- Refresh dependencies  
- Give you a clean slate

---

## Files for Reference

- **Main code:** `lib/features/dating_onboarding/presentation/screens/dating_photos_screen.dart`
- **Details:** `DATING_PHOTO_UPLOAD_FIX.md` (in repo root)
- **Utility:** `clear_dating_draft.dart` (in repo root)

