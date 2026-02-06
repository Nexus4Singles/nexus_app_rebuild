# Rejected User Experience & Account Restrictions

## Overview

When an admin rejects a user's profile, the account is **automatically disabled**. This document explains what the user can and cannot do after rejection.

---

## 🚫 What Rejected Users CANNOT Do

### 1. **Cannot Login** ❌
- Account is disabled immediately upon rejection
- Users will see an "Account Disabled" gate screen when they try to access any screen
- The gate displays: "Your account has been disabled by Admin."
- Plus the specific rejection reason provided by the admin

### 2. **Cannot Use Any Features**
- ❌ Browse matches
- ❌ Send or receive messages
- ❌ View other profiles  
- ❌ Update their profile
- ❌ Search for users
- ❌ Access challenges or journeys
- ❌ Participate in any app functionality

### 3. **The Disabled Account Gate**
File: [lib/core/widgets/disabled_account_gate.dart](lib/core/widgets/disabled_account_gate.dart)

When a rejected user tries to access any protected screen, they see:

```
🚫 Account disabled

Your account has been disabled by Admin.
[Reason: e.g., "Profile rejected: Blurry photos - please upload clearer images"]

Contact support if you have questions
[Support Contact Info]
```

This gate is wrapped around all main screens:
- Chat screens
- Profile views
- Search screens
- Settings
- Dashboard

### 4. **No Data Deletion**
- User account remains in Firestore (for audit purposes)
- All messages and interactions remain (not deleted)
- But the user cannot access any of them

---

## ✅ What Rejected Users CAN Do

### 1. **Can Still Login Technically** ⚠️
- They can authenticate successfully with Firebase (their Firebase auth is NOT deleted)
- BUT they immediately hit the `DisabledAccountGate` widget
- So while the auth exists, they cannot use the app

### 2. **Can Contact Support** 📧
- The disabled screen provides a support contact link
- Users can reach out via email or support channels to:
  - Appeal the rejection
  - Ask questions about the rejection reason
  - Request account re-enablement

### 3. **Can Have Account Re-enabled** 🔄
- Admins can re-enable accounts via the admin review detail screen
- There's an "Enable account" button
- This clears the `account.disabled` flag

---

## Technical Implementation

### Firestore Schema After Rejection

```json
{
  "account": {
    "disabled": true,
    "disabledBy": "admin_uid_123",
    "disabledAt": "2026-02-04T10:30:00Z",
    "disabledReason": "Profile rejected: Blurry photos - please upload clearer images"
  },
  "dating": {
    "verificationStatus": "rejected",
    "rejectionReason": "Blurry photos - please upload clearer images",
    "rejectedAt": "2026-02-04T10:30:00Z",
    "reviewedBy": "admin_uid_123",
    "reviewedAt": "2026-02-04T10:30:00Z"
  }
}
```

### Where Account Disabled Status is Checked

**File**: [lib/core/widgets/disabled_account_gate.dart](lib/core/widgets/disabled_account_gate.dart)

The app checks `currentUserDisabledProvider` which reads:
- `account.disabled` (boolean)
- `account.disabledReason` (string, shown to user)

**Usage Pattern**:
```dart
DisabledAccountGate(
  child: YourScreen(),  // Only shown if account is NOT disabled
  message: customMessage,  // Optional custom message
)
```

When wrapped:
1. Checks if user's `account.disabled == true`
2. If true → Shows disabled screen with reason
3. If false → Shows the wrapped child screen

### Firestore Security Rules

File: [firestore.rules](firestore.rules#L75-L82)

Admins can modify these fields:
- `account.disabled`
- `account.disabledBy`
- `account.disabledAt`
- `account.disabledReason`

---

## User Flow on Rejection

### 1. User is Using App → Admin Rejects Profile

```
User browsing → Admin clicks "Reject" 
                 → Admin provides reason
                 → Database updated
                 → Account disabled
```

### 2. User Tries to Use App After Rejection

```
User opens app
  ↓
Firebase Auth login (works)
  ↓
App loads main screens
  ↓
DisabledAccountGate checks account.disabled == true
  ↓
Shows "Account Disabled" screen
  ↓
User sees rejection reason
  ↓
Can only view support contact info
```

### 3. User Tries to Navigate Anywhere

```
Every navigation attempt hits DisabledAccountGate
  ↓
If disabled, shows disabled screen
  ↓
Prevents access to all features
```

---

## Chat Service Checks

File: [lib/core/services/chat_service.dart](lib/core/services/chat_service.dart)

The chat service also has guards that prevent disabled users from:
- Sending messages
- Receiving messages  
- Creating conversations

These throw a `ChatException('Account disabled by admin')`

---

## What About Re-appeal Process?

Currently **NOT IMPLEMENTED** - but could be added:

Potential features:
1. **Appeal Form**: User can submit appeal explaining why they should be re-enabled
2. **Appeal Review**: Admins see appeals in a queue
3. **Re-submission**: User can fix issues and resubmit profile
4. **Automatic Re-enable**: For certain rejection reasons (e.g., photos - user could re-submit new photos)

---

## Admin Actions for Disabled Accounts

Admins can:

1. **Re-enable Account**
   - Click "Enable account" button
   - Account becomes usable immediately
   - Optional note cleared

2. **Update Disable Reason**
   - Disable with new reason
   - Previous reason overwritten

3. **Audit Trail**
   - See who disabled account
   - When it was disabled
   - Why it was disabled

---

## Email Notifications (Future)

**NOT CURRENTLY IMPLEMENTED** but could send:

```
Subject: Your Nexus Account Has Been Disabled

Dear [User],

Your account has been disabled due to the following reason:

"Blurry photos - please upload clearer images"

If you believe this is an error, please contact support.

[Support Link]

Best regards,
Nexus Team
```

---

## Summary Table

| Action | Rejected User | Notes |
|--------|---------------|-------|
| **Login** | ❌ Cannot access app | Auth works, but gate blocks it |
| **Browse** | ❌ Cannot browse | Gate blocks all screens |
| **Message** | ❌ Cannot message | Chat service blocks it |
| **Update Profile** | ❌ Cannot update | Gate blocks profile screen |
| **View Messages** | ❌ Cannot view | Gate blocks chat screens |
| **Contact Support** | ✅ Can contact | Link provided on disabled screen |
| **Appeal** | ⚠️ Can request via support | Manual process, no in-app form yet |
| **Re-enable** | ✅ Admin can re-enable | Clears `account.disabled` flag |
| **Account Deletion** | ❌ Not deleted | Account persists for audit |

---

## Code References

- **Disabled Account Gate**: [lib/core/widgets/disabled_account_gate.dart](lib/core/widgets/disabled_account_gate.dart)
- **Firestore Security Rules**: [firestore.rules#L75-L82](firestore.rules#L75-L82)
- **Chat Service Checks**: [lib/core/services/chat_service.dart](lib/core/services/chat_service.dart)
- **Admin Review Detail Screen**: [lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart#L310-L320](lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart#L310-L320)

---

## Testing

To test rejection flow:

1. **As Admin**:
   - Go to Admin Queue
   - Click on a user profile
   - Click "Reject"
   - Enter a reason: "Blurry photos - please upload clearer images"

2. **As Rejected User** (different device/account):
   - Try to login
   - Should see "Account Disabled" screen
   - Should see the rejection reason

3. **As Admin (Re-enable)**:
   - Go back to that user in Admin Queue
   - Click "Enable account"
   - User should now be able to login again

---

## Questions?

See related documentation:
- [ADMIN_REVIEW_REJECTION_FEATURE.md](ADMIN_REVIEW_REJECTION_FEATURE.md) - Admin rejection workflow
- [firestore.rules](firestore.rules) - Security rules
- [lib/core/widgets/disabled_account_gate.dart](lib/core/widgets/disabled_account_gate.dart) - Gate implementation
