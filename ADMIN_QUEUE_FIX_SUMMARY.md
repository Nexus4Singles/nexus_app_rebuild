# Admin Review Queue Fix - Complete Implementation

## Problem Summary
Users completing their dating profiles weren't appearing in the admin review queue, even though their `verificationStatus` was set to `'pending'`. This affected the ability for admins to review and verify new profiles.

## Root Cause
When profiles were initially saved as "pending", two critical fields were missing:
1. **`verificationQueuedAt`** - Timestamp required by the Firestore query's `.orderBy()` clause
2. **`reviewPack`** - Object containing photos and audio URLs needed by the admin UI

### Why Profiles Were Hidden
Firestore's `.orderBy('dating.verificationQueuedAt')` query silently excludes documents that don't have this field, meaning profiles without a timestamp never appeared in the queue results.

## Solution Implemented

### 1. Fixed Profile Creation (Going Forward)
**File:** `lib/features/dating_onboarding/presentation/screens/dating_contact_info_screen.dart`

When a user completes their dating profile (Step 7 - Contact Info), the system now:

1. **Fetches uploaded photos** from existing Firestore data
   ```dart
   final userDoc = await fs.collection('users').doc(uid).get();
   final photoUrls = (datingData?['photos'] as List<dynamic>?)?.cast<String>() ?? [];
   ```

2. **Collects audio URLs** from the draft provider
   ```dart
   final audioUrls = <String>[];
   if (d.audio1Url?.isNotEmpty ?? false) audioUrls.add(d.audio1Url!);
   if (d.audio2Url?.isNotEmpty ?? false) audioUrls.add(d.audio2Url!);
   if (d.audio3Url?.isNotEmpty ?? false) audioUrls.add(d.audio3Url!);
   ```

3. **Gets gender and relationship status** for filtering
   ```dart
   final nexus2 = userData?['nexus2'] as Map<String, dynamic>?;
   final gender = nexus2?['gender'] as String?;
   final relationshipStatus = nexus2?['relationshipStatus'] as String?;
   ```

4. **Saves complete payload** with all required fields:
   ```dart
   'verificationStatus': 'pending',
   'verificationQueuedAt': FieldValue.serverTimestamp(),
   'reviewPack': {
     'photoUrls': photoUrls,
     'audioUrls': audioUrls,
     'submittedAt': FieldValue.serverTimestamp(),
   },
   'gender': gender,
   'relationshipStatus': relationshipStatus,
   ```

### 2. Fixed Existing Profiles (Retroactive)
**File:** `scripts/fix_all_pending_profiles.js`

Created a Node.js script that:
- Finds all profiles with `dating.verificationStatus == 'pending'`
- Checks if they have `verificationQueuedAt` and `reviewPack`
- For profiles missing these fields:
  - Adds `verificationQueuedAt` server timestamp
  - Creates `reviewPack` with collected photos/audio
  - Mirrors `gender` and `relationshipStatus` for query convenience
- Reports summary of fixes applied

### 3. Enhanced Admin Provider
**File:** `lib/features/admin_review/application/admin_review_providers.dart`

Added filter to prevent admins from reviewing their own profiles:
```dart
final currentUserId = ref.watch(currentUserIdProvider);
return stream.map((snapshot) {
  return snapshot.docs
      .where((d) => d.id != currentUserId) // Exclude self
      .map((d) { ... })
```

## Verification

### Before Fix
```
User ID: yjXNtVfxyraQBmD2LEvvaiGWrJo1
Verification Status: pending
Queued At: null  ❌
Has Review Pack: false  ❌
Found 0 pending profile(s)  ❌
```

### After Fix
```
✅ Found 1 pending profile(s) in queue
1. Ayo (yjXNtVfxyraQBmD2LEvvaiGWrJo1)
   Photos: 2, Audio: 3
   Queued: 2026-01-26T20:41:26.161Z
```

## Testing

### For Future Profiles
1. Create a test account
2. Complete the dating profile onboarding (all 7 steps)
3. Profile should automatically appear in admin review queue with:
   - Server-generated timestamp
   - reviewPack with photos and audio
   - Gender and relationship status mirrored

### For Admin Self-Review Prevention
1. Log in with admin account
2. Complete your own dating profile
3. Your profile will be in the queue (visible via script)
4. But you won't see it in your admin UI (filtered out)

## Files Modified

1. **lib/features/dating_onboarding/presentation/screens/dating_contact_info_screen.dart**
   - Added verificationQueuedAt timestamp
   - Added reviewPack creation
   - Added gender/relationshipStatus mirroring
   
2. **lib/features/admin_review/application/admin_review_providers.dart**
   - Added currentUserId filter to prevent self-review

3. **scripts/fix_verification_queue.js** (one-time use)
   - Fixed specific profile (nexus4singles)

4. **scripts/check_verification_status.js** (diagnostic)
   - Checks profile verification fields

5. **scripts/fix_all_pending_profiles.js** (batch fix)
   - Fixes all existing pending profiles

## Production Readiness

✅ **Code Changes:** All changes committed and formatted  
✅ **Existing Data:** Fixed with script  
✅ **Future Data:** Fixed at source  
✅ **Admin Safety:** Self-review prevention implemented  
✅ **Verified:** Script confirms 1 profile in queue  

## Impact

- **All future profiles** completing onboarding will appear in admin queue immediately
- **Existing pending profiles** have been fixed (if any existed)
- **Admins cannot review** their own profiles (good UX pattern)
- **No manual intervention** needed going forward

## Related Files

- Admin queue screen: `lib/features/admin_review/presentation/screens/admin_review_queue_screen.dart`
- Admin review providers: `lib/features/admin_review/application/admin_review_providers.dart`
- User model: `lib/core/models/user_model.dart`
- Firestore rules: `firebase_deploy/firestore.rules`

---

**Date Fixed:** January 26, 2026  
**Issue:** Admin review queue not showing pending profiles  
**Status:** ✅ Resolved (code + data)
