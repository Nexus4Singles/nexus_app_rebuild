# Manual User Verification Guide

This guide explains the 3 approaches to manually verify users in your Nexus app:
1. **Firebase Console (Manual, takes 2 minutes)**
2. **Cloud Function (Recommended, reusable)**
3. **Temporary Firestore Rules Edit (Quick, less secure)**

---

## Approach 1: Firebase Console (Easiest)

### Step 1: Enable Admin Access for Yourself

```bash
# From your project root, run:
node scripts/set_admin_claim.js your-email@gmail.com
```

This sets `admin: true` custom claim on your Firebase account.

**Then sign out of your app and back in** to refresh your token.

### Step 2: Verify User in Firebase Console

1. Go to https://console.firebase.google.com
2. Select project: **nexus-visibility-app**
3. Go to **Firestore Database** → Collection **users**
4. Find the user (search by email or scroll)
5. Click on their document
6. Find the **dating** subcollection/field
7. Edit `verificationStatus` to `"verified"`
8. Set `verifiedAt` to current timestamp (click "Server timestamp")
9. Set `verifiedBy` to your admin email
10. Save

**Changes take effect immediately** ✓

---

## Approach 2: Cloud Function (Recommended for Repeated Use)

The Cloud Function `verifyUserProfile` is already deployed. You can call it to verify users programmatically.

### Prerequisites

You must first set up admin access:

```bash
node scripts/set_admin_claim.js your-email@gmail.com
```

Then sign out and back in to your app.

### Method A: Using Shell Script (Easiest)

```bash
# Make script executable
chmod +x scripts/verify_user_via_cf.sh

# Verify a user
bash scripts/verify_user_via_cf.sh arc.prosperchukwuka@gmail.com

# Reject a user
bash scripts/verify_user_via_cf.sh arc.prosperchukwuka@gmail.com rejected

# Mark as pending
bash scripts/verify_user_via_cf.sh arc.prosperchukwuka@gmail.com pending
```

### Method B: Manual cURL (For scripting)

First, get your ID token:

**Option 1: From your browser app**
```javascript
// Open browser DevTools Console while signed in as admin, then run:
firebase.auth().currentUser.getIdToken().then(t => {
  console.log("ID_TOKEN=" + t);
  console.log("Copy the value above");
});
```

**Option 2: Using Firebase CLI**
```bash
firebase login  # if not already logged in
# Then use the token from CI flow or manually extract
```

**Once you have the token, use cURL:**

```bash
TOKEN="your-id-token-here"
EMAIL="arc.prosperchukwuka@gmail.com"

curl -X POST \
  "https://us-central1-nexus-visibility-app.cloudfunctions.net/verifyUserProfile" \
  -H "Authorization: Bearer $TOKEN" \
  -H "Content-Type: application/json" \
  -d "{
    \"email\": \"$EMAIL\",
    \"verificationStatus\": \"verified\"
  }"
```

**Response (success):**
```json
{
  "success": true,
  "userId": "user-id-here",
  "userEmail": "arc.prosperchukwuka@gmail.com",
  "userName": "prosper",
  "message": "User verified: arc.prosperchukwuka@gmail.com",
  "updated": {
    "verificationStatus": "verified",
    "verifiedAt": "2026-03-13T12:34:56.789Z",
    "verifiedBy": "admin:your-uid"
  }
}
```

### Method C: From Your Dart App

Add this to your admin panel or settings screen:

```dart
import 'package:firebase_auth/firebase_auth.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';

Future<void> verifyUserViaCloud(String targetEmail) async {
  final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
  if (idToken == null) {
    print('❌ Not authenticated');
    return;
  }

  final response = await http.post(
    Uri.parse('https://us-central1-nexus-visibility-app.cloudfunctions.net/verifyUserProfile'),
    headers: {
      'Authorization': 'Bearer $idToken',
      'Content-Type': 'application/json',
    },
    body: jsonEncode({
      'email': targetEmail,
      'verificationStatus': 'verified',
    }),
  );

  print('Status: ${response.statusCode}');
  print('Body: ${response.body}');
}
```

---

## Approach 3: Temporary Firestore Rules Edit

**⚠️ Only use this if you need to make manual edits immediately**

**This opens a security hole - revert after you're done**

### Step 1: Modify Rules

Edit [firebase_deploy/firestore.rules](../firebase_deploy/firestore.rules):

Find this section (around line 120):

```firestore
allow update: if isSignedIn() && (
  request.auth.uid == uid && 
  !request.resource.data.diff(resource.data).changedKeys().hasAny([
    'subscription',
    'onPremium',
    'subExpDate',
    'purchasedJourneys',
    'lastPurchaseAt',
    'lastPurchaseJourney',
    'entitledUser',
    'prevSubscribed',
    'lastFlutterwaveTransactionId',
    'lastPaymentMethod',
    'lastPaymentDate',
    'hasExternalSubscriptionFlow'
  ])
  ||
  (isAdmin() && adminUserUpdateAllowed())
);
```

**Change to:**

```firestore
allow update: if isSignedIn() && (
  // TEMPORARY: Allow any authenticated user to edit dating fields for testing only
  request.resource.data.diff(resource.data).changedKeys().hasOnly([
    'dating'
  ])
  ||
  (request.auth.uid == uid && 
   !request.resource.data.diff(resource.data).changedKeys().hasAny([
    'subscription',
    'onPremium',
    'subExpDate',
    'purchasedJourneys',
    'lastPurchaseAt',
    'lastPurchaseJourney',
    'entitledUser',
    'prevSubscribed',
    'lastFlutterwaveTransactionId',
    'lastPaymentMethod',
    'lastPaymentDate',
    'hasExternalSubscriptionFlow'
  ]))
  ||
  (isAdmin() && adminUserUpdateAllowed())
);
```

### Step 2: Deploy

```bash
firebase deploy --only firestore:rules
```

### Step 3: Make Your Edits in Firestore Console

Now you can manually edit `dating.verificationStatus` fields.

### Step 4: REVERT IMMEDIATELY

After you're done, revert the changes:

```bash
git checkout firebase_deploy/firestore.rules
firebase deploy --only firestore:rules
```

---

## Recommendations

| Situation | Approach | Time | Security |
|-----------|----------|------|----------|
| **One-off verification** | Approach 1 (Console) | 2 min | ✓ Good |
| **Regular verification** | Approach 2 (Cloud Function) | 1 min | ✓✓ Best |
| **Quick emergency fix** | Approach 3 (Edit rules) | 30 sec | ⚠️ Risky |

**For your team:**
- Set up admin access for team members via `node scripts/set_admin_claim.js`
- They can then use Approach 1 or Approach 2

## Audit Trail

All verifications are logged in:
```
users/{userId}/auditLog
```

Each log entry contains:
- `action`: 'dating_profile_verified_manually'
- `performedBy`: admin UID
- `performedByEmail`: admin email
- `verificationStatus`: what they were set to
- `timestamp`: when it happened

---

## Troubleshooting

### Error: "Admin access required"
- Run: `node scripts/set_admin_claim.js your-email@gmail.com`
- Sign out and back in to your app

### "User not found"
- Check the email is spelled correctly
- Make sure it's lowercase
- Verify user exists in your Firestore database

### Cloud Function not found (404)
- Make sure it's deployed: `firebase deploy --only functions`
- Check project ID is correct in script

### CORS errors
- The function has CORS enabled, but double-check function URL
- In `functions/index.js`, look for CORS headers in `verifyUserProfile`
