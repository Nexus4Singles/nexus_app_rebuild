# Dating Profile Setup - Testing & Integration Guide

## 🧪 Testing Instructions

### Manual Testing Flow

#### Test 1: Complete Happy Path (Full Profile Creation)
```
1. Start: /dating/setup/age
2. Select age: 25
3. Continue → /dating/setup/extra-info
4. Fill all fields:
   - City: Lagos
   - Country: Nigeria
   - Nationality: Nigerian
   - Education: Bachelor's Degree
   - Profession: Software Engineer
   - Church: Foursquare Gospel Church (or select Other and type custom)
5. Continue → /dating/setup/hobbies
6. Select 3-5 hobbies from list
7. Continue → /dating/setup/qualities
8. Select 5-8 qualities from list
9. Continue → /dating/setup/photos
10. Add 2-3 photos (must have human face)
11. Continue → /dating/setup/audio
12. Click "Start Recording" → /dating/setup/audio/q1
13. Record Q1 (at least 3 seconds, max 60)
14. Click "Next" → /dating/setup/audio/q2
15. Record Q2
16. Click "Next" → /dating/setup/audio/q3
17. Record Q3
18. Click "Next" → /dating/setup/audio/summary
19. Review all 3 recordings (can play each)
20. Click "Next" → /dating/setup/contact-info
21. Fill at least 1 contact field (e.g., Instagram: @myhandle)
22. Click "Continue" → /dating/setup/complete
23. See celebration screen
24. Either:
    - If quiz already complete → redirects to /profile
    - If quiz not complete → redirects to /compatibility-quiz
```

#### Test 2: Form Validation
```
Age Screen:
- [x] Cannot proceed without selecting age
- [x] Age range 21-70 enforced

Extra Info Screen:
- [x] City required (can't be empty)
- [x] Country required (must select)
- [x] Nationality required (must select)
- [x] Education required (must select)
- [x] Profession required (must select)
- [x] Church required (must select)
- [x] If Church = "Other", must fill other church field
- [x] Cannot continue if any field empty

Hobbies Screen:
- [x] Cannot continue with 0 hobbies
- [x] Can select 1-5 hobbies
- [x] Cannot select more than 5 (haptic feedback)
- [x] Search filters list correctly

Qualities Screen:
- [x] Cannot continue with 0 qualities
- [x] Can select 1-8 qualities
- [x] Cannot select more than 8 (haptic feedback)
- [x] Search filters list correctly

Photos Screen:
- [x] Cannot continue with <2 photos
- [x] Photos must have human face (ML Kit validation)
- [x] Can add/remove photos
- [x] "Continue" button disabled if <2 photos

Audio Questions:
- [x] Recording must be 3-60 seconds
- [x] Cannot advance if <3 seconds
- [x] Recording auto-stops at 60 seconds
- [x] Can play back recording
- [x] Can restart recording
- [x] Restart clears previous recording

Contact Info Screen:
- [x] Cannot continue with 0 fields filled
- [x] Can have 1-6 fields filled
- [x] Accepts any text (no format validation yet)
- [x] Optional fields don't block submission

Profile Complete:
- [x] Shows celebration message
- [x] Checks quiz status
- [x] Routes to quiz if incomplete
- [x] Routes to profile if complete
```

#### Test 3: Navigation Back Button
```
- [x] Back button works on all screens
- [x] Back preserves form data (draft is saved)
- [x] Can navigate backward in flow
- [x] Age screen: no back button or back to previous screen
- [x] Profile complete: back button disabled if quiz incomplete
```

#### Test 4: Data Persistence
```
- [x] Fill age, go back, return → age still there
- [x] Fill extra info, go back, return → data still there
- [x] Select hobbies, go back, return → selections preserved
- [x] Record audio, go back, return → audio file preserved
- [x] Add photos, go back, return → photos preserved
- [x] Fill contact, go back, return → contacts preserved
```

#### Test 5: Edge Cases
```
- [x] Rapid navigation (clicking fast)
- [x] App backgrounding/foregrounding
- [x] Permission denied for microphone
- [x] Permission denied for photo gallery
- [x] No photos matching face detection
- [x] Storage full scenarios
- [x] Network timeout during upload
- [x] Very long church names (text overflow)
```

### UI Testing Checklist
```
- [x] All step indicators show correct step (Step X of 8)
- [x] Progress counters update correctly
- [x] Search fields work and filter results
- [x] Disabled buttons appear grayed out
- [x] Loading indicators show during async operations
- [x] Error messages are readable and helpful
- [x] Toast messages appear for feedback
- [x] Animations are smooth (no jank)
- [x] Text fields have proper keyboard types
- [x] Dropdowns show all options without cutoff
- [x] Grid layouts are responsive
- [x] Images load without stretching
```

## 🔧 Integration Steps

### 1. Backend API Integration

#### Endpoint: Create/Update Dating Profile
```
POST /api/dating/profile
Content-Type: application/json

Request Body:
{
  "age": 25,
  "city": "Lagos",
  "countryOfResidence": "Nigeria",
  "nationality": "Nigerian",
  "educationLevel": "Bachelor's Degree",
  "profession": "Software Engineer",
  "churchName": "Foursquare Gospel Church",
  "hobbies": ["Reading", "Gaming", "Cooking"],
  "desiredQualities": ["Honest", "Kind", "Ambitious"],
  "photoPaths": ["url1", "url2", "url3"],
  "audio1Path": "audio_url_1",
  "audio2Path": "audio_url_2",
  "audio3Path": "audio_url_3",
  "contactInfo": {
    "Instagram": "@myhandle",
    "WhatsApp": "+234..."
  }
}
```

### 2. File Upload Service Integration

Update the storage provider to handle:
- Photo uploads to cloud storage
- Audio file uploads to cloud storage
- Progress tracking for long uploads
- Error handling and retries

```dart
// In dating_photos_stub_screen.dart
final storage = ref.read(mediaStorageProvider);
for (var i = 0; i < _photoPaths.length; i++) {
  final path = _photoPaths[i];
  final url = await storage.uploadImage(
    localPath: path,
    objectKey: 'dating/photos/${userId}_${i}.jpg'
  );
  // Store URL in profile
}
```

### 3. Profile Submission Endpoint

```dart
// Create a new provider for submitting complete profile
final submitDatingProfileProvider = FutureProvider((ref) async {
  final draft = ref.watch(datingOnboardingDraftProvider);
  final auth = ref.watch(authStateProvider);
  
  return await submitProfileToBackend(
    userId: auth.user!.uid,
    profile: draft,
  );
});
```

### 4. Firebase/Firestore Storage Structure

```
firestore/
└── users/{userId}
    └── datingProfile/
        ├── age: number
        ├── city: string
        ├── countryOfResidence: string
        ├── nationality: string
        ├── educationLevel: string
        ├── profession: string
        ├── churchName: string
        ├── hobbies: array
        ├── desiredQualities: array
        ├── photos: array[urls]
        ├── audio1Url: string
        ├── audio2Url: string
        ├── audio3Url: string
        ├── contactInfo: map
        ├── createdAt: timestamp
        ├── updatedAt: timestamp
        ├── status: "draft" | "submitted" | "active" | "inactive"
        └── approvalStatus: "pending" | "approved" | "rejected"
```

### 5. Compatibility Quiz Integration

After profile completion, users must complete compatibility quiz:

```dart
// In dating_profile_complete_screen.dart
final quizComplete = await compatibilityQuizService.isQuizComplete(uid);

if (quizComplete) {
  Navigator.pushReplacementNamed(context, '/profile');
} else {
  Navigator.pushReplacementNamed(context, '/compatibility-quiz');
}
```

## 🚀 Deployment Checklist

### Pre-Deployment
- [ ] All tests passing
- [ ] No console errors or warnings
- [ ] Code review completed
- [ ] Backend APIs ready
- [ ] Firebase storage configured
- [ ] Firestore rules updated
- [ ] Analytics tracking added
- [ ] Error logging configured

### Deployment Steps
1. Merge to main branch
2. Run: `flutter clean && flutter pub get`
3. Run: `flutter test`
4. Build: `flutter build apk` (Android) or `flutter build ios` (iOS)
5. Test on real devices
6. Upload to stores

### Post-Deployment Monitoring
- [ ] Monitor error logs
- [ ] Check analytics
- [ ] Monitor profile submission rates
- [ ] Check for API errors
- [ ] Verify file upload success rates
- [ ] Monitor user feedback

## 📊 Analytics to Track

### Key Metrics
```
1. Profile Start Rate (% of users who start /dating/setup/age)
2. Profile Completion Rate (% who reach /dating/setup/complete)
3. Drop-off Points (which step has highest abandonment)
4. Average Time Per Step
5. Audio Recording Success Rate
6. Photo Upload Success Rate
7. Contact Info Submission Rate
8. Quiz Completion Rate (after profile)
```

### Events to Log
```
- profile_setup_started
- profile_age_selected
- profile_extra_info_submitted
- profile_hobbies_selected
- profile_qualities_selected
- profile_photos_added
- profile_audio_1_recorded
- profile_audio_2_recorded
- profile_audio_3_recorded
- profile_contact_info_submitted
- profile_completed
- profile_quiz_started
- profile_quiz_completed
```

## 🐛 Troubleshooting

### Common Issues

#### Issue: Provider state lost on navigation
**Solution**: Ensure using `ref.watch()` for listening and `ref.read()` for one-time access

#### Issue: Photos showing as rotated
**Solution**: Add image orientation handling in photo upload

#### Issue: Audio files not persisting
**Solution**: Use `getApplicationDocumentsDirectory()` and ensure proper permissions

#### Issue: Face detection not working
**Solution**: Ensure ML Kit Face Detection is properly initialized and permissions granted

#### Issue: Back button breaking state
**Solution**: Use `pushNamed` instead of `push` for consistency

## 🔐 Security Notes

1. **Audio Files**: Should be deleted after upload to cloud
2. **Photo Validation**: Must validate on backend (not just client)
3. **Profile Data**: Encrypt sensitive data in transit
4. **Audio Content**: Implement moderation (optional)
5. **Rate Limiting**: Limit profile updates to prevent abuse

## 📱 Platform-Specific Notes

### iOS
- [ ] Microphone permission in Info.plist
- [ ] Photo library permission in Info.plist
- [ ] Audio session configuration
- [ ] Background audio handling

### Android
- [ ] RECORD_AUDIO permission in AndroidManifest.xml
- [ ] READ_EXTERNAL_STORAGE permission
- [ ] Android 6+ runtime permissions
- [ ] Scoped storage compatibility

## 📚 Related Documentation

- [DATING_PROFILE_SETUP_COMPLETE.md](DATING_PROFILE_SETUP_COMPLETE.md) - Full implementation details
- [DATING_PROFILE_QUICK_REF.md](DATING_PROFILE_QUICK_REF.md) - Quick reference guide
- [DATING_IMPLEMENTATION_CHECKLIST.md](DATING_IMPLEMENTATION_CHECKLIST.md) - Completion checklist
