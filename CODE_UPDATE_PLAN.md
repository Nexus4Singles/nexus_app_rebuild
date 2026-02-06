# Code Updates for Schema Restructure

**Status:** Ready for Implementation (AFTER Phase 1 & 2 complete)  
**Last Updated:** February 3, 2026

---

## Overview

After duplicates are removed and schema is restructured in Firestore, the app code needs to be updated to read from the new paths.

### Timeline
1. ✅ Phase 1: Remove duplicates (scripts/remove_duplicate_fields.js)
2. ✅ Phase 2: Restructure schema (scripts/restructure_schema.js)
3. ⏳ Phase 3: Update app code (THIS DOCUMENT)
4. ⏳ Phase 4: Test and deploy

---

## File-by-File Updates Needed

### 1. lib/core/services/firestore_service.dart

**Current Paths:**
```dart
// Load user profile - flat structure
final user = await db.collection('users').doc(uid).get();
final name = user.data()?['name'];
```

**New Paths:**
```dart
// Load user profile - organized structure
final profileDoc = await db.collection('users').doc(uid)
    .collection('profile').doc('data').get();
final name = profileDoc.data()?['name'];

// Load dating profile
final datingDoc = await db.collection('users').doc(uid)
    .collection('dating').doc('data').get();
```

**Changes Required:**
- [ ] `loadUser()` - Read from profile/data instead of root
- [ ] `updateUserProfile()` - Write to profile/data
- [ ] `loadUserDating()` - Read from dating/data
- [ ] `updateUserDating()` - Write to dating/data
- [ ] `loadAssessments()` - Query assessments collection (was at root)
- [ ] `loadJourneyProgress()` - Query journeys collection (was journeyProgress)

### 2. lib/core/models/user_model.dart

**Current:**
```dart
factory UserModel.fromMap(String id, Map<String, dynamic> data) {
  final name = data['name'];
  final gender = data['gender'];
  final dating = data['dating'];
  // ... flat structure
}
```

**New:**
```dart
factory UserModel.fromMap(String id, Map<String, dynamic> profileData, 
    Map<String, dynamic> datingData) {
  final name = profileData['name'];
  final gender = profileData['gender'];
  final dating = datingData; // Entire dating document
  // ... organized structure
}
```

**Changes Required:**
- [ ] Update `fromMap()` signature to accept separate profile/dating docs
- [ ] Update all `fromMap()` calls throughout the app
- [ ] Update fallback logic for nested fields

### 3. lib/core/providers/user_provider.dart

**Current:**
```dart
final userProvider = FutureProvider<UserModel?>((ref) async {
  final user = await firestore.collection('users').doc(uid).get();
  return UserModel.fromMap(uid, user.data() ?? {});
});
```

**New:**
```dart
final userProvider = FutureProvider<UserModel?>((ref) async {
  final profileDoc = await firestore.collection('users').doc(uid)
      .collection('profile').doc('data').get();
  final datingDoc = await firestore.collection('users').doc(uid)
      .collection('dating').doc('data').get();
  return UserModel.fromMap(uid, 
    profileDoc.data() ?? {}, 
    datingDoc.data() ?? {});
});
```

**Changes Required:**
- [ ] Update to load both profile and dating documents
- [ ] Handle missing documents gracefully
- [ ] Update error handling

### 4. lib/features/dating_onboarding/presentation/screens/dating_contact_info_screen.dart

**Current:**
```dart
await db.collection('users').doc(uid).update({
  'dating.reviewPack': {...}
});
```

**New:**
```dart
await db.collection('users').doc(uid)
    .collection('dating').doc('data').update({
  'reviewPack': {...}
});
```

**Changes Required:**
- [ ] Update all writes to dating/ subcollection
- [ ] Update path for reviewPack
- [ ] Verify audio/photo upload paths

### 5. lib/core/services/dating_profile_service.dart

**Current:**
```dart
final dating = data['dating'];
final reviewPack = dating?['reviewPack'];
```

**New:**
```dart
final datingDoc = await db.collection('users').doc(uid)
    .collection('dating').doc('data').get();
final dating = datingDoc.data();
final reviewPack = dating?['reviewPack'];
```

**Changes Required:**
- [ ] Update all profile reads
- [ ] Update audio/photo URL retrieval
- [ ] Update duplicate detection queries

### 6. lib/core/services/duplicate_detection_service.dart

**Current:**
```dart
.where('dating.reviewPack.photoHashes', arrayContains: hash)
```

**New:**
```dart
// Query needs to search in subcollection
db.collectionGroup('dating')
    .where('data.reviewPack.photoHashes', arrayContains: hash)
    // OR use collection-scoped query
db.collection('users').doc(uid)
    .collection('dating').doc('data')
    .get().then((doc) => doc.data()?['reviewPack']['photoHashes'])
```

**Changes Required:**
- [ ] Update query paths for subcollection
- [ ] May need to use collectionGroup for cross-user queries
- [ ] Verify hash field paths

### 7. lib/core/services/journey_progress_service.dart

**Current:**
```dart
// journeyProgress stored at root of user doc
final completedIds = await firestore
    .collection('users').doc(uid)
    .get()
    .then((doc) => List<String>.from(doc['journeyProgress']['completedIds'] ?? []));
```

**New:**
```dart
// journeyProgress now in journeys collection
final completedIds = await firestore
    .collection('users').doc(uid)
    .collection('journeys').doc('progress')
    .get()
    .then((doc) => List<String>.from(doc?['completedIds'] ?? []));
```

**Changes Required:**
- [ ] Change from user document field to collection
- [ ] Update all progress tracking methods
- [ ] Update streak calculations

### 8. lib/features/challenges/providers/journeys_providers.dart

**Current:**
```dart
final completedIds = await service.loadCompletedMissionIds(uid);
```

**New:**
```dart
// Same interface, but service reads from new path
final completedIds = await service.loadCompletedMissionIds(uid);
// Service internally uses: users/{uid}/journeys/progress
```

**Changes Required:**
- [ ] No changes needed if service interface stays same
- [ ] Only update underlying service implementation

### 9. Assessment-Related Files

**lib/core/services/assessment_service.dart** (if exists)

**Current:**
```dart
await db.collection('users').doc(uid).update({
  'assessments': results
});
```

**New:**
```dart
await db.collection('users').doc(uid)
    .collection('assessments').doc(assessmentId).set(results);
```

**Changes Required:**
- [ ] Change from field to collection
- [ ] Update assessment save/load methods
- [ ] May need to query assessments collection

### 10. lib/features/profile/presentation/screens/profile_screen.dart

**Current:**
```dart
final displayName = currentUser.displayName ?? currentUser.name;
```

**New:**
```dart
final displayName = currentUser.name; // After consolidation
```

**Changes Required:**
- [ ] Remove fallback to displayName (already deprecated)
- [ ] Use name directly

---

## Migration Strategy

### Option A: Dual-Write (Recommended - Safer)

**Phase 3A: Read from OLD, Write to BOTH**
1. Keep reading from old paths (journeyProgress, etc.)
2. When saving, write to BOTH old and new paths
3. Test thoroughly
4. Monitor for errors

```dart
// Example: Journal progress dual-write
Future<void> markMissionCompleted(String uid, String missionId) async {
  // OLD PATH - still read from here
  final oldData = await firestore.collection('users').doc(uid).get();
  
  // NEW PATH - write to new path
  await firestore.collection('users').doc(uid)
      .collection('journeys').doc('progress').update({...});
  
  // OLD PATH - also write to old path (for fallback)
  await firestore.collection('users').doc(uid).update({...});
}
```

**Phase 3B: Switch Reads to NEW**
1. Update all reads to use new paths
2. Deploy and monitor
3. Keep writes to both paths

**Phase 3C: Remove Dual-Write**
1. Remove old path writes
2. Deploy with new paths only
3. Done

### Option B: Big Bang (Faster - Higher Risk)

1. Update ALL reads and writes to new paths
2. Deploy to staging
3. Extensive testing
4. Deploy to production
5. Monitor closely

**Risk:** If something breaks, affects all users at once

---

## Testing Checklist

### Unit Tests
- [ ] UserModel.fromMap() with new structure
- [ ] Profile document parsing
- [ ] Dating document parsing
- [ ] Journey collection queries
- [ ] Assessment collection queries

### Integration Tests
- [ ] User login loads profile correctly
- [ ] Profile update saves to correct path
- [ ] Dating profile loads/updates
- [ ] Journey progress tracked
- [ ] Assessments saved/loaded

### Feature Tests
- [ ] Onboarding flow works
- [ ] Dating profile complete
- [ ] Assessment submission works
- [ ] Journey tracking works
- [ ] Compatibility calculations work
- [ ] Search filters work
- [ ] Admin verification works

### Smoke Tests (Production)
- [ ] Users can log in
- [ ] Home screen loads
- [ ] Profile visible
- [ ] Dating profile visible
- [ ] No errors in Cloud Logging

---

## Firestore Rules Updates

### NEW RULES for Restructured Schema

```javascript
rules_version = '2';
service cloud.firestore {
  match /databases/{database}/documents {
    
    // User profile documents
    match /users/{uid} {
      allow read, write: if request.auth.uid == uid;
      
      // Profile subcollection
      match /profile/{document=**} {
        allow read, write: if request.auth.uid == uid;
      }
      
      // Dating subcollection
      match /dating/{document=**} {
        allow read, write: if request.auth.uid == uid;
        allow read: if request.auth.token.isAdmin == true; // For verification
      }
      
      // Compatibility subcollection
      match /compatibility/{document=**} {
        allow read, write: if request.auth.uid == uid;
      }
      
      // Verification subcollection
      match /verification/{document=**} {
        allow read: if request.auth.uid == uid || request.auth.token.isAdmin == true;
        allow write: if request.auth.uid == uid;
      }
      
      // Settings subcollection
      match /settings/{document=**} {
        allow read, write: if request.auth.uid == uid;
      }
      
      // Assessments collection
      match /assessments/{assessmentId} {
        allow read, write: if request.auth.uid == uid;
      }
      
      // Journeys collection (renamed from journeyProgress)
      match /journeys/{journeyId} {
        allow read, write: if request.auth.uid == uid;
      }
      
      // Stories collection
      match /stories/{storyId} {
        allow read, write: if request.auth.uid == uid;
      }
      
      // Polls collection
      match /polls/{pollId} {
        allow read, write: if request.auth.uid == uid;
      }
    }
  }
}
```

---

## Deploy Steps

1. **Update Firestore Rules**
   ```bash
   firebase deploy --only firestore:rules
   ```

2. **Create Feature Branch**
   ```bash
   git checkout -b feat/schema-restructure
   ```

3. **Update Code Files** (following section by section)
   - Update firestore_service.dart
   - Update user_model.dart
   - Update providers
   - Update services

4. **Run Tests**
   ```bash
   flutter test
   ```

5. **Deploy to Staging**
   ```bash
   flutter run --flavor staging
   ```

6. **Comprehensive Testing**

7. **Merge to Main**
   ```bash
   git merge feat/schema-restructure
   ```

8. **Deploy to Production**

---

## Rollback Plan

If code breaks production:

1. **Revert Code Changes**
   ```bash
   git revert [commit]
   git push
   ```

2. **Redeploy Previous Version**
   ```bash
   flutter pub get
   flutter build apk --release
   # Deploy via Firebase Distribution
   ```

3. **Investigate Root Cause**
   - Check logs
   - Find breaking change
   - Test fix in staging
   - Redeploy

---

## Timeline

- Code updates: 4-6 hours
- Testing: 2-3 hours
- Staging validation: 2-4 hours
- Production deploy: 1-2 hours
- Monitoring: Ongoing

---

## Success Criteria

✅ **All of these must be true:**
- [ ] All tests pass
- [ ] No errors in staging
- [ ] Users can load profiles
- [ ] Users can edit dating profile
- [ ] Journey progress tracked correctly
- [ ] Assessments save correctly
- [ ] No increase in production errors
- [ ] Users report no issues

---

**Ready for implementation?** Confirm once Phases 1 & 2 are complete.
