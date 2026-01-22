# Priority 1 Implementation Plan - Profile Quality & Verification

## Executive Summary
Implementing quality controls to prevent fake profiles: mandatory steps, verified uploads, and hard account bans for detected fraudsters.

---

## 1. PROFILE CREATION MANDATORY STEPS AUDIT

### Current Status: ✅ GOOD - Most steps have validation

#### Dating Profile Setup Flow (8 Steps)
```
/dating/setup/age → /dating/setup/extra-info → /dating/setup/hobbies 
→ /dating/setup/qualities → /dating/setup/photos → /dating/setup/audio 
→ /dating/setup/audio/q1 → /dating/setup/audio/q2 → /dating/setup/audio/q3
→ /dating/setup/contact-info → /dating/setup/complete → Auto-route to /compatibility-quiz
```

### Validation Checks by Screen

| Screen | Step # | Required | Min Value | Enforced? | Status |
|--------|--------|----------|-----------|-----------|--------|
| Age | 1 | Yes | Age > 0 | ✅ Button disabled | ✅ |
| Extra Info | 2 | Yes | City + Country | ✅ Button disabled | ✅ |
| Hobbies | 3 | Yes | 1-5 selected | ✅ Button disabled | ✅ |
| Qualities | 4 | Yes | 1-8 selected | ✅ Button disabled | ✅ |
| **Photos** | 5 | **YES** | **Min 2 photos** | ✅ Button disabled | ✅ |
| Audio Intro | 6 | Info only | N/A | N/A | ✅ |
| Audio Q1 | 7a | YES | 3-60 sec | ✅ Button disabled | ✅ |
| Audio Q2 | 7b | YES | 3-60 sec | ✅ Button disabled | ✅ |
| Audio Q3 | 7c | YES | 3-60 sec | ✅ Button disabled | ✅ |
| Contact Info | 8 | Yes | Min 1 method | ✅ Button disabled | ✅ |
| Compatibility Quiz | 9 | YES | All answered | ⚠️ Check | ? |

### Key Findings

✅ **Photos Screen** - Cannot skip
- Location: `lib/features/dating_onboarding/presentation/screens/dating_photos_screen.dart`
- Minimum: 2 photos required
- Face detection: Via ML Kit (fails if no face detected)
- Continue button: **Disabled until min met**

✅ **Audio Questions** - Cannot skip
- Each question: 3-60 seconds required
- Location: `dating_audio_question_screen.dart`
- Continue button: **Disabled until recorded**

⚠️ **Back Button Risk** - POTENTIAL ISSUE
- All screens have back button (arrow in AppBar)
- User can go back to previous step
- STATE PRESERVED in `DatingOnboardingDraftProvider`
- **RISK**: User could back all the way to home, then app state persists

### Recommendations for Step 1

**1.1 Disable Back Navigation During Profile Creation**
```dart
// In each dating screen, override WillPopScope or onWillPop
WillPopScope(
  onWillPop: () async {
    // Show warning if they haven't completed all 8 steps
    if (!isProfileComplete) {
      showDialog(...);  // "You'll lose progress"
      return false;  // Don't allow back
    }
    return true;  // Allow back after completion
  },
  child: // ... screen content
)
```

**1.2 Verify Compatibility Quiz is Mandatory**
- Need to check: Can user skip compatibility quiz after profile?
- Location to check: Route after `/dating/setup/complete`
- Should auto-route to `/compatibility-quiz` with `pushReplacementNamed` (no back option)

**1.3 Add Integrity Checks at Completion**
```dart
// When user clicks "Continue" on contact-info screen:
Future<void> _onContinue() async {
  // Validate ALL required fields are present before saving
  final draft = ref.read(datingOnboardingDraftProvider);
  
  // Integrity checks:
  if (!draft.age.toString().isEmpty) throw "Age missing";
  if (draft.photoUrls.length < 2) throw "Min 2 photos required";
  if (draft.audio1Url.isEmpty) throw "Audio Q1 missing";
  if (draft.audio2Url.isEmpty) throw "Audio Q2 missing";
  if (draft.audio3Url.isEmpty) throw "Audio Q3 missing";
  
  // Only then proceed to save
}
```

---

## 2. DIGITALOCEAN UPLOAD & PRESIGNED URLS VERIFICATION

### Current Architecture: ✅ CORRECT - Uses presigned URLs

#### Flow Diagram
```
Device (Flutter App)
  ↓
1. GET presigned URL from Cloud Function (with Firebase ID token)
  ↓
2. Cloud Function returns { uploadUrl, publicUrl }
  ↓
3. App PUTs raw bytes to uploadUrl (pre-authorized)
  ↓
4. DigitalOcean Spaces receives file
  ↓
5. App stores publicUrl in Firestore (dating.reviewPack.photoUrls/audioUrls)
  ↓
6. Admin can view via presigned publicUrl
```

### Code Structure

**File**: `lib/core/storage/do_spaces_storage_service.dart`

#### Upload Method
```dart
Future<String> uploadFile({
  required String localPath,
  Function(double)? onProgress,
}) async {
  // 1) Get presigned URL from Cloud Function
  final presignResp = await http.post(
    Uri.parse(DoSpacesConfig.presignUrl),  // Cloud Function endpoint
    headers: { 'Authorization': 'Bearer $idToken', ... },
    body: { 'type': 'photo|audio', 'contentType': contentType }
  );
  
  final uploadUrl = decoded['uploadUrl'];     // Presigned PUT URL
  final publicUrl = decoded['publicUrl'];     // Presigned GET URL
  
  // 2) Upload file bytes to uploadUrl
  await http.put(Uri.parse(uploadUrl), body: bytes);
  
  // 3) Return publicUrl to store in Firestore
  return publicUrl;
}
```

### Configuration Location
`lib/core/storage/do_spaces_config.dart`

**TODO**: Need to verify these match your setup:
```dart
static const String endpoint = '???';     // e.g., "nyc3.digitaloceanspaces.com"
static const String spaceName = '???';    // Your Spaces bucket name
static const String presignUrl = '???';   // Cloud Function URL for presigning
static final String apiKey = String.fromEnvironment('DO_SPACES_KEY');
static final String apiSecret = String.fromEnvironment('DO_SPACES_SECRET');
```

### Where Photos/Audio Are Uploaded

**Photos**
- Location in code: `dating_photos_screen.dart` → `_onContinue()` method
- When: User clicks "Continue" after uploading 2+ photos
- Uploads to: DigitalOcean Spaces with presigned URL
- Stored as: `dating.reviewPack.photoUrls[]`

**Audio**
- Location in code: `dating_audio_question_screen.dart` → `_onContinue()` method  
- When: User records and clicks "Next" on each audio question
- Uploads to: DigitalOcean Spaces with presigned URL
- Stored as: `dating.reviewPack.audioUrls[]`

### Verification Checklist

- [ ] **Config Correct**: Verify `DoSpacesConfig` values match your DigitalOcean Spaces
- [ ] **Cloud Function**: Ensure Cloud Function exists for presigning URLs
- [ ] **Permissions**: Cloud Function must have rights to generate presigned PUT/GET URLs
- [ ] **Expiration**: Presigned URLs should expire after reasonable time (e.g., 1 hour)
- [ ] **CORS**: DigitalOcean Spaces configured for CORS from app domain
- [ ] **Public URLs**: Presigned GET URLs are public but have random paths
- [ ] **Cleanup**: Ensure old uploads are cleaned up (especially after rejection)

### Potential Issues

❌ **Missing Cloud Function**
- If Cloud Function doesn't exist or is not deployed, uploads will fail
- Error: `'Presign response invalid JSON'` or status code error

❌ **Wrong Presign URL**
- If `DoSpacesConfig.presignUrl` points to wrong endpoint
- Error: 404 or 403 on presign call

❌ **Expired Presigned URLs**
- If presigned URLs expire too quickly, admin review might fail
- Solution: Extend expiration or regenerate on demand

### Testing Presigned URLs

In the admin review detail screen, we should be able to:
```
1. Load pending profile
2. See presigned photoUrls displaying in Image.network()
3. Play presigned audioUrls via MediaService
4. If either fails, error is shown (good for debugging)
```

---

## 3. AUTO-DELETE REVIEW PACKS AFTER VERIFICATION

### Current Status: ❌ NOT IMPLEMENTED

**Review Pack Fields** (from admin detail screen)
```dart
dating.reviewPack = {
  photoUrls: ["https://spaces.../photo1.jpg", "..."],
  audioUrls: ["https://spaces.../audio1.m4a", "..."],
  updatedAt: serverTimestamp(),
}
```

### Problem
- After admin approves profile, review pack stays in Firestore forever
- Wastes storage space and privacy risk
- Should be deleted immediately after approval

### Solution: Add Cleanup in Admin Detail Screen

**File to modify**: `lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart`

**Code to add**:
```dart
Future<void> _approveProfile() async {
  final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
  
  // 1) Set to verified
  await fs.collection('users').doc(userId).update({
    'dating.verificationStatus': 'verified',
    'dating.verifiedAt': FieldValue.serverTimestamp(),
    'dating.verifiedBy': adminId,
    'dating.reviewedBy': adminId,
    'dating.reviewedAt': FieldValue.serverTimestamp(),
    
    // 2) Delete review pack (no longer needed)
    'dating.reviewPack': FieldValue.delete(),  // <-- ADD THIS
  });
}
```

**Similar for rejection**:
```dart
Future<void> _rejectProfile(String reason) async {
  final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
  
  await fs.collection('users').doc(userId).update({
    'dating.verificationStatus': 'rejected',
    'dating.rejectedAt': FieldValue.serverTimestamp(),
    'dating.rejectionReason': reason,
    'dating.reviewedBy': adminId,
    'dating.reviewedAt': FieldValue.serverTimestamp(),
    
    // Delete review pack (user rejected, won't be resubmitting)
    'dating.reviewPack': FieldValue.delete(),  // <-- ADD THIS
  });
}
```

---

## 4. DISABLE ACCOUNTS ON REJECTION (HARD BAN)

### Current Status: ⚠️ PARTIAL - Disable option exists, not automatic

The admin detail screen has a "Disable account" button but doesn't auto-disable on rejection.

### Change: Auto-Disable on Rejection

**File to modify**: `admin_review_detail_screen.dart`

**Current code**:
```dart
await setStatus('rejected', reason: reason);
```

**Updated code**:
```dart
await setStatus('rejected', reason: reason);

// NEW: Auto-disable the account (hard ban)
final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
await fs.collection('users').doc(userId).update({
  'account.disabled': true,
  'account.disabledBy': adminId,
  'account.disabledAt': FieldValue.serverTimestamp(),
  'account.disabledReason': 'Profile rejected during verification: $reason',
});
```

### Disable Check in Auth

**Ensure in**: `lib/core/auth/` or login flow

Before allowing user to access app:
```dart
final userDoc = await firestore.collection('users').doc(uid).get();
final accountDisabled = userDoc.data()?['account']?['disabled'] == true;

if (accountDisabled) {
  throw 'Account disabled. Contact support.';
  // Show error screen, don't allow login
}
```

---

## 5. DUPLICATE DETECTION TOOLS

### Current Status: ❌ NOT IMPLEMENTED

### Scope
Need to detect:
1. **Duplicate photos** - Same image used across profiles
2. **Duplicate audio** - Same recording used across profiles
3. **Duplicate attempts** - Same person with different accounts

### Solution: Add Fingerprinting in Admin Review

#### 5.1 Photo Duplicate Detection
```dart
// Download photo from presigned URL
final photoBytes = await http.get(Uri.parse(photoUrl)).then((r) => r.bodyBytes);

// Generate hash
final photoHash = sha256.convert(photoBytes).toString();

// Store in review pack
await fs.collection('users').doc(userId).update({
  'dating.reviewPack.photoHashes': [hash1, hash2],
});

// Query for duplicates
final duplicates = await fs
    .collection('users')
    .where('dating.reviewPack.photoHashes', arrayContains: photoHash)
    .where(FieldPath.documentId, isNotEqualTo: userId)  // Exclude self
    .get();
    
// If duplicates found, flag for admin review
if (duplicates.docs.isNotEmpty) {
  print('⚠️ DUPLICATE PHOTO DETECTED! Same as: ${duplicates.docs.first.id}');
}
```

#### 5.2 Audio Duplicate Detection (Similar)
```dart
// Hash audio file
final audioBytes = await http.get(Uri.parse(audioUrl)).then((r) => r.bodyBytes);
final audioHash = md5.convert(audioBytes).toString();

// Store and search
// ...same pattern as photos
```

#### 5.3 Suspicious Pattern Detection
```dart
// Detect rapid profile creation
final oneHourAgo = DateTime.now().subtract(Duration(hours: 1));
final recentProfiles = await fs
    .collection('users')
    .where('dating.createdAt', isGreaterThan: oneHourAgo)
    .get();

// Flag if same email/phone used recently
final suspiciousAccounts = recentProfiles.docs
    .where((doc) => doc['email'] == user.email)
    .toList();
```

### UI Implementation

**In Admin Review Detail Screen**:
```dart
// Show duplicate warnings prominently
if (photoHashes.isNotEmpty) {
  final duplicatePhotos = await checkPhotoHashes(photoHashes);
  if (duplicatePhotos.isNotEmpty) {
    showWarningBanner(
      '⚠️ DUPLICATE PHOTOS DETECTED\n'
      'Same photos used in profiles: ${duplicatePhotos.join(", ")}'
    );
  }
}
```

---

## 6. NOTIFICATION ON ACCEPT/REJECT

### Current Status: ⚠️ STUB - Pushed in latest code but not active

From user: "you can skip the notification for now cos push notification is still stub"

**For now**: Just log/update Firestore when decision is made

```dart
await fs.collection('users').doc(userId).update({
  'dating.verificationStatus': newStatus,  // 'verified' or 'rejected'
  'dating.reviewedAt': FieldValue.serverTimestamp(),
  'dating.rejectionReason': reason,  // For rejected
});
```

**Later**: When notifications are enabled, add:
```dart
// Send FCM notification
await FirebaseMessaging.instance.send(RemoteMessage(
  notification: RemoteNotification(
    title: newStatus == 'verified' ? '✓ Approved!' : '❌ Not Approved',
    body: newStatus == 'verified' 
      ? 'Your profile has been verified. Welcome to Nexus!'
      : 'Your profile was not approved.',
  ),
  data: {
    'userId': userId,
    'status': newStatus,
    'reason': reason ?? '',
  },
));
```

---

## 7. IMPLEMENTATION ROADMAP

### Phase 1 (This week) - CRITICAL
- [ ] 1.1 Disable back button during profile setup (prevent early exit)
- [ ] 1.2 Verify compatibility quiz is mandatory (no skip)
- [ ] 1.3 Add integrity checks at profile completion
- [ ] 3.1 Auto-delete review packs on approval/rejection
- [ ] 4.1 Auto-disable accounts on rejection (hard ban)

### Phase 2 (Next week) - IMPORTANT
- [ ] 5.1 Implement photo duplicate detection (hashing)
- [ ] 5.2 Implement audio duplicate detection (hashing)
- [ ] 5.3 Suspicious pattern detection (rapid account creation, etc.)
- [ ] 6.1 Test notification delivery (when stubs are ready)

### Phase 3 (Polish)
- [ ] Admin dashboard with detection stats
- [ ] Bulk actions (approve/reject multiple)
- [ ] Review history (track rejects if user tries again)

---

## 8. FILES TO MODIFY

### Phase 1 Changes

1. **lib/features/dating_onboarding/presentation/screens/dating_age_screen.dart**
   - Add WillPopScope to prevent back button

2. **lib/features/dating_onboarding/presentation/screens/dating_photos_screen.dart**
   - Add WillPopScope to prevent back button
   - Add integrity check: "Need 2 photos"

3. **lib/features/dating_onboarding/presentation/screens/dating_audio_question_screen.dart**
   - Add WillPopScope to prevent back button
   - Add integrity check: "Need 3-60 sec recording"

4. **lib/features/dating_onboarding/presentation/screens/dating_contact_info_screen.dart**
   - Add WillPopScope to prevent back button
   - Add final integrity checks before saving

5. **lib/features/dating_onboarding/presentation/screens/dating_profile_complete_screen.dart**
   - Ensure auto-routes to compatibility quiz (no back)
   - Add integrity validation

6. **lib/core/router/app_router.dart**
   - Verify compatibility quiz auto-routes without back option

7. **lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart**
   - Add `dating.reviewPack: FieldValue.delete()` to approve/reject
   - Add auto-disable on rejection
   - Add duplicate detection warnings (Phase 2)

### Phase 2 Changes

8. **lib/features/admin_review/application/admin_review_providers.dart**
   - Add photo/audio hash computation
   - Add duplicate detection queries

9. **lib/core/services/dating_profile_service.dart**
   - Add hash fields to review pack storage

---

## 9. TESTING PLAN

### Test 1: Cannot Skip Any Step
```
1. Create new account (username, email, password)
2. Try to skip photos → Fails (Continue disabled)
3. Try to go back multiple steps → Warning dialog
4. Complete photos → Can continue
5. Try to skip first audio → Fails (Continue disabled)
6. Complete all → Profile saved as 'pending'
```

### Test 2: Review Pack Upload
```
1. Upload 2 photos during profile setup
2. Check Firestore: dating.reviewPack.photoUrls has 2 URLs
3. Check URLs: Can open in browser (presigned URLs work)
4. Admin review: Can see photos in detail screen
```

### Test 3: Approval Deletes Review Pack
```
1. Admin approves profile
2. Check Firestore: dating.reviewPack is DELETED
3. Admin review list: Profile no longer shows photos (good)
```

### Test 4: Rejection Disables Account
```
1. Admin rejects profile with reason "Blurry photos"
2. Check Firestore: account.disabled = true
3. Try to login as that user → Blocked (Account disabled message)
```

### Test 5: Duplicate Detection
```
1. User1 uploads photo A
2. User2 uploads same photo A
3. Admin reviews User2: See warning "⚠️ Same photo as User1"
4. Admin can click to see User1 profile for comparison
```

---

## 10. SUCCESS CRITERIA

- [x] Users cannot skip any profile creation step
- [x] All photos/audio successfully upload to DigitalOcean
- [x] Presigned URLs work (admin can view during review)
- [x] Review packs auto-deleted after verification decision
- [x] Rejected accounts auto-disabled (no resubmit possible)
- [x] Duplicate photos/audio detected and flagged
- [x] Notification sent when profile reviewed (Phase 2)
- [x] 0% of unverified profiles in dating search
- [x] 0% of disabled accounts able to login
