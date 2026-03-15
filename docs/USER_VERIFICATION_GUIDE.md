# 🔐 User Verification Guide - Nexus App V2

## Overview

The Nexus V2 app requires all dating profiles to be verified before users can be discovered in search. You have been provided with **3 ways** to verify users:

1. **[Easiest] Firebase Console** - Manual, instant, no setup
2. **[Fastest Recurring] Cloud Function** - API accessible, always available
3. **[Quick Script] Admin CLI Script** - Local, one-time commands

---

## User to Verify

**Email:** `arc.prosperchukwuka@gmail.com`

---

## ✅ Step 1: Give Yourself Admin Access

To use **any** of these verification methods, you need to be an admin.

### Option A: Via Firebase Console (2 minutes)

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: **nexus-visibility-app**
3. Go to **Authentication** → **Users**
4. Find **your user account** (the one you log in with)
5. Click the three dots (**⋯**) → **Edit user**
6. Scroll to **Custom claims** section at the bottom
7. Paste this:
   ```json
   {"admin": true}
   ```
8. Click **Save**
9. **Sign out and back in** to the app (claims update on next login)

### Option B: Via CLI Script (1 minute)

```bash
cd /Users/aybaj/Documents/nexus_app_v2
node scripts/set-admin-claim.js your-email@example.com true
```

Replace `your-email@example.com` with your email.

---

## ✅ Step 2: Verify the Target User

Now that you're an admin, choose your preferred method:

### Method 1: Firebase Console (Manual) ⭐ RECOMMENDED FOR RARE EDITS

**Fastest for one-off verification. Takes 2 minutes.**

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Select project: **nexus-visibility-app**
3. Go to **Firestore** → **Collection**
4. Search/navigate to **users** collection
5. Find the user document with `email: "arc.prosperchukwuka@gmail.com"`
6. Click on their document
7. Click **Edit** (pencil icon) next to **dating** field (or create it if missing)
8. Edit/create these fields:
   ```
   dating.verificationStatus: "verified"
   dating.verifiedAt: <current timestamp>
   dating.verifiedBy: "manual_admin"
   ```
9. Click **Update**

**That's it!** The user is now verified. They'll see the verified badge in their profile.

---

### Method 2: Cloud Function (API - Production-Ready) ⭐ RECOMMENDED FOR RECURRING

**Best for team workflows, integrations, and recurring usage.**

#### **Step 1: Deploy the Function**

```bash
cd /Users/aybaj/Documents/nexus_app_v2/functions
firebase deploy --only functions:verifyUserProfile
```

If you don't have Firebase CLI installed:
```bash
npm install -g firebase-tools
```

#### **Step 2: Call the Function**

Once deployed, call it like this:

**Using cURL:**
```bash
curl -X POST https://us-central1-nexus-visibility-app.cloudfunctions.net/verifyUserProfile \
  -H "Authorization: Bearer YOUR_ID_TOKEN" \
  -H "Content-Type: application/json" \
  -d '{
    "email": "arc.prosperchukwuka@gmail.com",
    "verificationStatus": "verified"
  }'
```

**Using JavaScript/Dart:**
```javascript
// Get ID token from Firebase Auth
const idToken = await firebase.auth().currentUser.getIdToken();

const response = await fetch(
  'https://us-central1-nexus-visibility-app.cloudfunctions.net/verifyUserProfile',
  {
    method: 'POST',
    headers: {
      'Authorization': `Bearer ${idToken}`,
      'Content-Type': 'application/json',
    },
    body: JSON.stringify({
      email: 'arc.prosperchukwuka@gmail.com',
      verificationStatus: 'verified',
    }),
  }
);

const result = await response.json();
console.log(result);
```

**Using Python (Admin Dashboard):**
```python
import requests
import json

def verify_user(id_token, email, status='verified'):
    response = requests.post(
        'https://us-central1-nexus-visibility-app.cloudfunctions.net/verifyUserProfile',
        headers={
            'Authorization': f'Bearer {id_token}',
            'Content-Type': 'application/json'
        },
        json={
            'email': email,
            'verificationStatus': status
        }
    )
    return response.json()

# Example usage
# result = verify_user(your_id_token, 'arc.prosperchukwuka@gmail.com')
# print(result)
```

**Response Example:**
```json
{
  "success": true,
  "userId": "abc123xyz",
  "userEmail": "arc.prosperchukwuka@gmail.com",
  "userName": "prosperchukwuka",
  "message": "User verified: arc.prosperchukwuka@gmail.com",
  "updated": {
    "verificationStatus": "verified",
    "verifiedAt": "2026-03-13T10:30:00Z",
    "verifiedBy": "admin:user123"
  }
}
```

#### **Advantages:**
✅ Always available (no need to deploy each time)  
✅ Can be called from app, admin panel, or external systems  
✅ Automatic audit logging  
✅ Batch-friendly for multiple users  
✅ Team-accessible  

---

### Method 3: Admin CLI Script (Local) ⭐ RECOMMENDED FOR BATCH OPERATIONS

**Great for local testing and script automation.**

```bash
# Verify a user
node /Users/aybaj/Documents/nexus_app_v2/scripts/admin-verify-user.js arc.prosperchukwuka@gmail.com

# Verify multiple users
node scripts/admin-verify-user.js user1@example.com
node scripts/admin-verify-user.js user2@example.com
node scripts/admin-verify-user.js user3@example.com

# Verify with specific status
node scripts/admin-verify-user.js users@example.com verified
node scripts/admin-verify-user.js users@example.com rejected    # Reject instead
node scripts/admin-verify-user.js users@example.com pending     # Mark as pending review
```

**Output Example:**
```
======================================================================
🔐 ADMIN USER VERIFICATION
======================================================================

📧 Step 1: Finding user with email: arc.prosperchukwuka@gmail.com
✅ User found!
   UID: abc123xyz789
   Email: arc.prosperchukwuka@gmail.com
   Username: prosperchukwuka
   Name: Arc Prosper Chukwuka

⏳ Step 2: Updating verification status to 'verified'...
✅ Verification updated!

📝 Updated verification fields:
   verificationStatus: verified
   verifiedBy: admin_cli_script
   verifiedAt: 2026-03-13T10:30:00Z

======================================================================
✅ SUCCESS! User verified with status: verified
======================================================================
```

#### **Advantages:**
✅ No API setup needed  
✅ Quick for local testing  
✅ Easy to automate with shell scripts  
✅ No network latency  

---

## 📊 Comparison Table

| Method | Setup Time | Call Time | Recurring | Team Access | Audit Log |
|--------|-----------|-----------|-----------|-------------|-----------|
| **Firebase Console** | 2 min | 2 min | Manual | ✓ (anyone with access) | ✓ (in Console) |
| **Cloud Function** | 5 min | <1 sec | ✓ Always | ✓ (API accessible) | ✓ (automatic) |
| **CLI Script** | 1 min | <1 sec | ✓ Local | ✗ (local only) | ✓ (logs to Firestore) |

---

## 🔍 Verification Status Explained

When verifying, you can set the status to:

- **`verified`** - User's dating profile is approved and visible in search
- **`pending`** - User submitted profile but awaiting review
- **`rejected`** - User's profile was rejected; they can resubmit

---

## ✅ How to Know It Worked

1. **In Firestore Console:**
   - Go to **users** → under that user → **dating** field
   - You should see:
     ```
     dating: {
       verificationStatus: "verified"
       verifiedAt: <timestamp>
       verifiedBy: "admin..." or "manual_admin"
       ...
     }
     ```

2. **In the App:**
   - User will see a **green checkmark** ✔️ on their profile
   - Their profile appears in search results
   - Others can match with them

3. **Audit Trail:**
   - Open Firestore → **users** → `{userId}` → **auditLog** collection
   - You'll see a log entry with the verification action

---

## ❌ Troubleshooting

### "Admin access required" Error
- You're not set as admin yet
- Run: `node scripts/set-admin-claim.js your-email@gmail.com true`
- Sign out and back in to the app

### "User not found" Error
- Double-check the email spelling
- Make sure the user account exists in Firestore
- Firebase is case-sensitive for emails

### Cloud Function Returns 404
- Function might not be deployed yet
- Run: `firebase deploy --only functions:verifyUserProfile`
- Make sure you ran it from the `/functions` directory

### Can't update user in Console (gets reverted)
- Firestore rules are blocking your edit
- You need the `admin: true` custom claim set
- See **Step 1** above

---

## 🎯 Quick Start (TL;DR)

**If you just want to verify `arc.prosperchukwuka@gmail.com` right now:**

### Option A: Fast (Firebase Console - 2 min)
```
1. Go to https://console.firebase.google.com
2. Select project 'nexus-visibility-app'
3. Give yourself admin access (Custom claims: {"admin": true})
4. Go to Firestore → users → find the email
5. Edit dating.verificationStatus to "verified"
```

### Option B: CLI (1 minute)
```bash
# Make yourself admin first
node /Users/aybaj/Documents/nexus_app_v2/scripts/set-admin-claim.js your-email@gmail.com

# Then verify the user
node /Users/aybaj/Documents/nexus_app_v2/scripts/admin-verify-user.js arc.prosperchukwuka@gmail.com
```

### Option C: Cloud Function (API - After 5 min setup)
```bash
# Deploy the function
cd /Users/aybaj/Documents/nexus_app_v2/functions
firebase deploy --only functions:verifyUserProfile

# Then call it from app/API/Dart code (see examples above)
```

---

## 📚 Additional Resources

- [Firebase Custom Claims Documentation](https://firebase.google.com/docs/auth/admin-setup#set_custom_claims_on_a_user_account)
- [Firestore Security Rules Guide](https://firebase.google.com/docs/firestore/security/start)
- [Cloud Functions HTTP Triggers](https://firebase.google.com/docs/functions/http-events)

---

## 🔒 Security Notes

✅ All verification methods require admin authentication  
✅ Changes are audit-logged to Firestore  
✅ Only admins with `admin: true` custom claim can verify users  
✅ Each verification is tied to the admin who performed it  

---

**Questions?** Check the inline code comments in:
- [functions/index.js](functions/index.js) - Cloud Function source
- [scripts/admin-verify-user.js](scripts/admin-verify-user.js) - CLI script
- [scripts/set-admin-claim.js](scripts/set-admin-claim.js) - Admin setup script
