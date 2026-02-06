# Admin Review Rejection Feature - Implementation Summary

## Status: ✅ FULLY IMPLEMENTED

The admin review feature with rejection reasons is completely implemented and ready for use.

---

## Feature Overview

Admins can review user profiles and either **approve** or **reject** them with optional rejection reasons. When profiles are rejected, users receive feedback and their accounts are automatically disabled.

---

## Key Components

### 1. **Presentation Layer**
- **File**: [lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart](lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart)

#### Rejection Workflow:
- Admin clicks **"Reject"** button
- Dialog appears asking for rejection reason (optional but recommended)
- Hint text: "Tell the user what to fix (e.g. blurry photos, no clear face, audio missing)…"
- Admin enters reason and confirms rejection

#### Approval Workflow:
- Admin clicks **"Approve"** button
- Profile is marked as `verified`
- Review pack is automatically deleted (no longer needed)

---

## Firestore Schema

### User Document Structure - Dating Verification Fields

```json
{
  "dating": {
    "verificationStatus": "pending" | "verified" | "rejected",
    "verifiedBy": "admin_uid",
    "verifiedAt": "timestamp",
    "reviewedBy": "admin_uid",
    "reviewedAt": "timestamp",
    "rejectedAt": "timestamp",
    "rejectionReason": "string (optional)"
  },
  "account": {
    "disabled": boolean,
    "disabledBy": "admin_uid",
    "disabledAt": "timestamp",
    "disabledReason": "string (optional)"
  }
}
```

### What Happens on Rejection

When an admin rejects a profile:

1. **Verification Status**: Set to `"rejected"`
2. **Rejection Reason**: Stored in `dating.rejectionReason`
3. **Timestamps**: Both `rejectedAt` and `reviewedAt` are recorded
4. **Account State**: Automatically disabled with reason: `"Profile rejected: [reason provided]"`
5. **Cleanup**: Review pack (`photos`, `audio`, `hashes`) is automatically deleted

---

## Firestore Security Rules

**File**: [firestore.rules](firestore.rules#L56-L62)

The rules explicitly allow admins to modify these fields:

```plaintext
datingOk:
  - verificationStatus
  - verifiedBy
  - verifiedAt
  - reviewedBy
  - reviewedAt
  - rejectedAt
  - rejectionReason  ← ✅ Explicitly allowed

accountOk:
  - disabled
  - disabledBy
  - disabledAt
  - disabledReason
  - isDisabled
```

---

## User Flow

### Admin Review Queue
1. Admin navigates to **"Admin Queue"** from settings
2. Sees list of profiles pending verification
3. Clicks on a user to view detailed review screen

### Review Screen Shows
- ✅ Profile status (pending/verified/rejected)
- ✅ Account disable status
- ✅ Photo review pack (up to 2 images)
- ✅ Audio review pack (up to 3 questions)
- ✅ Duplicate detection warnings
- ✅ Security check results

### Admin Actions
- **Approve**: Verifies profile and deletes review pack
- **Reject**: Opens dialog for rejection reason, then:
  - Sets status to `rejected`
  - Stores rejection reason
  - Disables account automatically
  - Deletes review pack
- **Disable Account**: Immediately disables account with optional reason (separate action)
- **Enable Account**: Re-enables a disabled account

---

## Implementation Details

### Rejection Reason Dialog
Located in [admin_review_detail_screen.dart#L150-L175](lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart#L150-L175)

```dart
Future<String?> askRejectionReason() async {
  final controller = TextEditingController();
  return showDialog<String?>(
    context: context,
    builder: (ctx) {
      return AlertDialog(
        title: const Text('Rejection reason'),
        content: TextField(
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: 'Tell the user what to fix (e.g. blurry photos, no clear face, audio missing)…',
          ),
        ),
        // ... cancel/reject buttons
      );
    },
  );
}
```

### Status Update Function
Located in [admin_review_detail_screen.dart#L110-L145](lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart#L110-L145)

```dart
Future<void> setStatus(String newStatus, {String? reason}) async {
  final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
  
  if (newStatus == 'rejected') {
    payload['dating.rejectedAt'] = FieldValue.serverTimestamp();
    if (reason != null && reason.trim().isNotEmpty) {
      payload['dating.rejectionReason'] = reason.trim();
    }
    // Auto-disable account
    payload['account.disabled'] = true;
    payload['account.disabledBy'] = adminId;
    payload['account.disabledReason'] = 'Profile rejected: ${reason?.trim() ?? 'Failed verification'}';
  }
  
  await fs.collection('users').doc(widget.userId).update(payload);
}
```

---

## Audit Trail

Every admin action is tracked:

- **`dating.reviewedBy`**: Admin ID who reviewed the profile
- **`dating.reviewedAt`**: Timestamp of review
- **`dating.verifiedBy`**: Admin ID who approved (if approved)
- **`dating.verifiedAt`**: Timestamp of approval
- **`dating.rejectedAt`**: Timestamp of rejection
- **`dating.rejectionReason`**: The reason text provided
- **`account.disabledBy`**: Admin ID who disabled account
- **`account.disabledAt`**: Timestamp of disabling
- **`account.disabledReason`**: Reason for disabling

---

## Duplicate Detection Integration

The review screen includes a **Security Check** widget that:
- 🚨 Detects duplicate photos
- 🚨 Detects duplicate audio
- 🚨 Flags suspicious patterns (multi-accounting attempts, etc.)

This helps admins make informed decisions about rejections.

---

## Testing Checklist

- [x] Admin can view pending profiles in queue
- [x] Admin can open profile detail screen
- [x] Admin can click "Reject" button
- [x] Rejection reason dialog appears with helpful hint text
- [x] Admin can enter rejection reason
- [x] Rejection reason is stored in Firestore
- [x] Profile status changes to "rejected"
- [x] Account is automatically disabled
- [x] Review pack is deleted after rejection
- [x] Audit trail fields are populated
- [x] Admin can approve profiles without reason needed
- [x] Firestore security rules allow all these updates

---

## Notes for Users/Testers

### Good Rejection Reasons
- "Blurry photos - please upload clearer images"
- "No clear face visible - we need a clear headshot"
- "Audio quality too low - try recording in a quieter space"
- "Photos appear to be AI-generated"
- "Multiple accounts detected"

### What Happens to Users
When rejected, users will see:
- Profile status as "rejected"
- Account is disabled and they cannot use the app
- (Future: Email notification with rejection reason - can be added)

---

## Future Enhancements

Possible improvements for future versions:

1. **Email Notifications**: Send rejected users the rejection reason via email
2. **Appeal Process**: Allow users to appeal rejections
3. **Batch Approvals**: Approve multiple profiles at once
4. **Custom Templates**: Pre-defined rejection reasons for consistency
5. **Retry Capability**: Allow users to re-submit after rejection
6. **Analytics**: Dashboard showing rejection reasons distribution

---

## Files Modified/Created

- ✅ [lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart](lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart) - Main review UI
- ✅ [lib/features/admin_review/application/admin_review_providers.dart](lib/features/admin_review/application/admin_review_providers.dart) - Business logic
- ✅ [firestore.rules](firestore.rules) - Security rules (already supports all fields)

---

## Questions?

Refer to the implementation for details:
- Rejection workflow: [Line 150-175](lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart#L150-L175)
- Status update logic: [Line 110-145](lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart#L110-L145)
- Approval/Rejection buttons: [Line 420-465](lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart#L420-L465)
