# Schema Restructure Implementation Guide

**Status:** Ready for Execution  
**Last Updated:** February 3, 2026  
**Risk Level:** HIGH - Affects entire database structure

---

## ⚠️ Pre-Implementation Checklist

### MUST DO BEFORE EXECUTING SCRIPTS

- [ ] **Backup Firestore Database**
  ```bash
  gcloud firestore export gs://your-bucket/backup-$(date +%Y%m%d-%H%M%S)
  ```

- [ ] **Verify in Staging First**
  - Test scripts on staging Firestore first
  - Not on production!

- [ ] **Review Firestore Rules**
  - Update security rules for new collection paths
  - Test rule changes

- [ ] **Notify Team**
  - Let team know about planned changes
  - Expected downtime: ~30 minutes

- [ ] **Have Rollback Plan**
  - Can restore from backup if needed
  - Document rollback process

---

## Phase 1A: Backup & Test

### Step 1: Create Firestore Backup
```bash
# Create backup in Cloud Storage
gcloud firestore export gs://nexus-app-backups/pre-restructure-backup-$(date +%Y%m%d-%H%M%S)

# Or use Firebase Console:
# Firestore → Backups → Create Backup
```

### Step 2: Verify Backup Completed
```bash
# List backups
gcloud firestore backups list --location=us-central1
```

---

## Phase 1B: Remove Duplicate Fields (Safe Operation)

### Step 1: Dry Run First
```bash
# Test without making changes
cd /Users/aybaj/Documents/nexus_app_v2
node scripts/remove_duplicate_fields.js --dry-run
```

**Expected Output:**
```
🔄 Starting duplicate field removal...

📊 Found X user documents to process

   Processing: Remove top-level photos[] (use dating.photos[] instead)
      ✓ Will remove: photos
   ✅ Updated user [uid1]

...

📋 Summary:
   Total users processed: X
   Successfully updated: X
   Errors: 0
```

### Step 2: Execute Duplicate Removal
```bash
# This will actually remove the duplicate fields
node scripts/remove_duplicate_fields.js
```

**Monitor the output:**
- ✅ Each user should show "Updated user [uid]"
- ❌ If you see errors, STOP and investigate

### Step 3: Verify Duplicates Are Removed
```bash
# Check a specific user in Firebase Console:
# Firestore → users → [any uid]
# Verify these fields are GONE:
# - photos (top-level)
# - dating.gender
# - dating.contactInfo.Instagram
# - dating.contactInfo.countryOfResidence
# - nexus.* (all fields)
```

---

## Phase 2: Restructure Schema (Major Operation)

### ⚠️ Warning: This Changes Collection Paths

**Before:**
```
users/{uid}
├── name, gender, country, ... (flat)
├── dating { ... }
├── assessments (at root)
└── journeyProgress (at root)
```

**After:**
```
users/{uid}
├── profile/data { name, gender, country, ... }
├── dating/data { ... }
├── assessments/ (collection)
├── journeys/ (collection renamed from journeyProgress)
```

### Step 1: Dry Run on Sample User
```bash
# Test on a single user first
# Modify script to test with specific uid:
# 1. Open scripts/restructure_schema.js
# 2. Replace: for (const userDoc of usersSnapshot.docs) {
#    With: for (const userDoc of [{ id: 'YOUR_TEST_UID', data: ... }]) {
# 3. Run: node scripts/restructure_schema.js --dry-run
# 4. Verify output looks correct
```

### Step 2: Dry Run Full Database
```bash
# Test entire restructure without changes
node scripts/restructure_schema.js --dry-run
```

**Expected Output:**
```
🔍 DRY RUN MODE - No changes will be made

📝 Restructuring user: [uid1]
   Creating profile document
      ✓ Created profile document
   Verifying dating document
      ✓ Dating document ready
   ...
   ✅ User restructuring complete

📋 Restructure Summary:
   Total users processed: X
   Errors: 0

🔍 DRY RUN completed - no changes made
```

### Step 3: Execute Full Restructure
```bash
# Actually restructure the database
# ⚠️ Point of no return - ensure dry run looked good first
node scripts/restructure_schema.js
```

**Monitor the output:**
- Each user should complete successfully
- Total users processed should match total users
- Errors should be 0

### Step 4: Verify New Structure in Firebase Console
```
users/{uid}/
├── profile/data
├── dating/data
├── compatibility/data
├── verification/data
├── assessments/ (collection)
├── journeys/ (collection)
├── stories/ (collection)
└── [other collections]
```

---

## Phase 3: Update Firestore Security Rules

### Current Rules (Old Structure)
```javascript
// Old rule paths
match /users/{uid} {
  allow read, write: if request.auth.uid == uid;
}
```

### New Rules (Updated Structure)
```javascript
match /users/{uid} {
  // Access to user's own documents
  match /profile/data {
    allow read, write: if request.auth.uid == uid;
  }
  
  match /dating/data {
    allow read, write: if request.auth.uid == uid;
  }
  
  match /compatibility/data {
    allow read, write: if request.auth.uid == uid;
  }
  
  match /verification/data {
    allow read, write: if request.auth.uid == uid;
  }
  
  match /settings/data {
    allow read, write: if request.auth.uid == uid;
  }
  
  // Collections
  match /assessments/{assessmentId} {
    allow read, write: if request.auth.uid == uid;
  }
  
  match /journeys/{journeyId} {
    allow read, write: if request.auth.uid == uid;
  }
  
  match /stories/{storyId} {
    allow read, write: if request.auth.uid == uid;
  }
  
  match /polls/{pollId} {
    allow read, write: if request.auth.uid == uid;
  }
  
  // Admin verification access
  match /verification/data {
    allow read: if request.auth.token.isAdmin == true;
  }
}
```

### Deploy Updated Rules
```bash
firebase deploy --only firestore:rules
```

---

## Phase 4: Update Application Code

### Files That Need Updates

1. **lib/core/services/firestore_service.dart**
   - Update all user profile reads to use `users/{uid}/profile/data`
   - Update dating reads to use `users/{uid}/dating/data`
   - Update assessment reads to use `users/{uid}/assessments` collection
   - Update journey reads to use `users/{uid}/journeys` collection

2. **lib/core/models/user_model.dart**
   - Update `fromMap()` to read from new paths
   - Update field mapping for nested structure

3. **lib/features/dating_onboarding/presentation/screens/dating_contact_info_screen.dart**
   - Update to write to new dating document path

4. **lib/core/services/dating_profile_service.dart**
   - Update all dating profile reads/writes

5. **lib/core/services/journey_progress_service.dart**
   - Update journey collection path from `journeyProgress` to `journeys`

### Code Update Strategy

**Option A: Dual-Write (Safer)**
```dart
// During transition period:
// 1. Read from OLD path (journeyProgress)
// 2. Write to BOTH old and new paths
// 3. After verification, switch reads to new path
// 4. Remove old path writes
```

**Option B: Big Bang (Faster)**
```dart
// All at once:
// 1. Update all reads to new paths
// 2. Update all writes to new paths
// 3. Deploy to production
// 4. Monitor for errors
```

**Recommendation:** Option A is safer for existing users

---

## Phase 5: Testing Checklist

### Unit Tests
- [ ] UserModel.fromMap() works with new structure
- [ ] FirestoreService reads from new paths
- [ ] FirestoreService writes to new paths

### Integration Tests
- [ ] User can load profile
- [ ] User can edit dating profile
- [ ] Assessments load correctly
- [ ] Journeys load correctly
- [ ] Compatibility quiz works
- [ ] Search/filtering works
- [ ] Chat functionality works

### Smoke Tests (Production)
- [ ] Users can log in
- [ ] Home screen loads
- [ ] Profile screen loads
- [ ] Dating profile visible
- [ ] No errors in logs

---

## Rollback Procedure (If Needed)

### Step 1: Stop Production Traffic
- Pause app deployment
- Notify users of issue

### Step 2: Restore from Backup
```bash
# List available backups
gcloud firestore backups list

# Restore from specific backup
gcloud firestore backups restore BACKUP_NAME
```

### Step 3: Revert Code Changes
```bash
git revert [commit that updated for new structure]
```

### Step 4: Resume Service
- Redeploy old version
- Verify data is restored
- Notify users

---

## Success Criteria

✅ **All of these must be true:**
- [ ] No errors during script execution
- [ ] All users processed (count matches)
- [ ] New collection structure visible in Firebase Console
- [ ] Old duplicate fields are removed
- [ ] All app features still work
- [ ] No increase in error logs
- [ ] Users report no issues

---

## Timeline

- **Backup:** 5-10 min
- **Remove Duplicates:** 2-5 min
- **Restructure Schema:** 5-15 min
- **Update Rules:** 1-2 min
- **Deploy:** 2-5 min
- **Testing:** 15-30 min
- **Total:** ~30-60 min

---

## Support & Troubleshooting

### If Script Fails During Removal
```bash
# Check error messages
# Most likely: Permission denied
# Solution: Verify serviceAccount.json has correct permissions

# Rerun from scratch (safe operation):
node scripts/remove_duplicate_fields.js
```

### If Script Fails During Restructure
```bash
# Restore from backup
# DO NOT RERUN without fixing root cause

# Common issues:
# 1. Out of memory - use smaller batches
# 2. Permission denied - check Firebase rules
# 3. Document too large - remove old data first
```

### If Users Report Issues
```bash
# Check Firestore for expected data
# Firestore Console: users/{uid}/profile/data (should exist)
# Firestore Console: users/{uid}/dating/data (should exist)

# If missing:
# - Restore backup
# - Investigate script logs
# - Fix root cause
# - Try again
```

---

**Ready to Proceed?** 
Ensure all pre-checks are complete, then follow phases in order.
