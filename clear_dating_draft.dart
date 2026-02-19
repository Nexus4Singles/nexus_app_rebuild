/// Utility to diagnose and fix dating onboarding photo upload issues
///
/// Run this to clear stuck photo upload state:
/// 1. Copy this file to your test/ directory
/// 2. Run: flutter test test/dating_photo_upload_fix.dart
///
/// Or manually clear via terminal:
/// flutter run --dart-define=CLEAR_DATING_DRAFT=true

import 'package:shared_preferences/shared_preferences.dart';

/// Clear stuck dating onboarding draft (if photos aren't uploading)
Future<void> clearDatingDraft() async {
  final prefs = await SharedPreferences.getInstance();
  await prefs.remove('dating_onboarding_draft');
  print('✅ Cleared dating onboarding draft from SharedPreferences');
  print('   Next time you use dating onboarding, photos will re-upload');
}

/// Inspect current draft state (for debugging)
Future<void> inspectDatingDraft() async {
  final prefs = await SharedPreferences.getInstance();
  final draftJson = prefs.getString('dating_onboarding_draft');

  if (draftJson == null) {
    print('ℹ️  No dating draft found in SharedPreferences');
    return;
  }

  print('📋 Current dating draft state:');
  print(draftJson);
}

/// Helper to diagnose upload issues
void printDiagnostics() {
  print('''
╔══════════════════════════════════════════════════════════════════════════════╗
║                   DATING PHOTO UPLOAD DIAGNOSTICS                            ║
╚══════════════════════════════════════════════════════════════════════════════╝

If photos don't upload to DO Spaces during dating onboarding:

1. CHECK THE LOGS
   ✓ Run: flutter run
   ✓ Tap "Continue" on photos screen
   ✓ Look for:
     - "[PHOTOS] 🚀 Uploading N photos to DO Spaces..." (upload starts)
     - "[PHOTOS] ✅ Uploaded photo 1: https://..." (success)
     - "[PHOTOS] ⏭️  Skipping upload —..." (upload skipped, maybe from cache)
     - "[PHOTOS] ❌ Upload error..." (actual error)

2. IF UPLOAD IS SKIPPED
   ✓ The draft still has old URLs from previous attempt
   ✓ Clear the draft: 
     a) Run: dart clear_dating_draft.dart
     b) Or: Delete app and reinstall
     c) Or: Use DevTools to clear SharedPreferences
   ✓ Then try again

3. IF UPLOAD FAILS WITH ERROR
   ✓ Check error message in console
   ✓ Common causes:
     • "Not authenticated" → Firebase auth issue
     • "Presign failed" → Cloud Function not working
     • "Upload failed (403)" → DO Spaces auth issue
   ✓ Compare with edit profile (which works)
   ✓ If edit profile works but onboarding doesn't, check calling context

4. IF UPLOAD SUCCEEDS BUT PHOTOS DON'T SHOW
   ✓ URLs are saved to draft correctly ✓
   ✓ URLs should be saved to Firestore when profile is completed ✓
   ✓ Check dating_contact_info_screen.dart line 405-406
   ✓ Make sure photoUrls are in the Firestore payload

RECENT FIXES APPLIED:
• Added detailed logging to dating_photos_screen.dart
• Added validation to ensure returned URLs aren't empty
• Added safeguard to prevent cache-skip on URL count mismatch
• Added validation that all cached URLs are non-empty before skipping

FILES MODIFIED:
• lib/features/dating_onboarding/presentation/screens/dating_photos_screen.dart
  → Enhanced _onContinue() method with comprehensive logging
  → Added empty URL validation
  → Strengthened alreadyUploaded check with urlsAreValid condition

NEXT STEPS:
1. Rebuild app: flutter clean && flutter pub get && flutter run
2. Try adding photos and clicking Continue
3. Share console logs showing "[PHOTOS]" messages
4. Verify photos appear in final dating profile (edit mode)
''');
}

void main() {
  printDiagnostics();
}
