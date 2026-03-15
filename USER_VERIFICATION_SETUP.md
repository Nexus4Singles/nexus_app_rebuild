# Complete Setup & Usage Guide

## Summary

You now have **3 complete approaches** to manually verify users:

### **Approach 1: Firebase Console (Manual)**
- ✅ Easiest to understand
- ✅ No coding required
- ✅ Perfect for one-off verifications
- ⏱️ Takes ~2 minutes
- 📍 [Full Guide](MANUAL_USER_VERIFICATION.md#approach-1-firebase-console-easiest)

### **Approach 2: Cloud Function (Recommended)**
- ✅ Built-in and ready to use
- ✅ Repeatable and scriptable
- ✅ Audit trail automatically logged
- ✅ **Does NOT require running it every time** - it's already deployed
- ⏱️ Takes ~1 minute to call
- 📍 [Full Guide](MANUAL_USER_VERIFICATION.md#approach-2-cloud-function-recommended-for-repeated-use)

### **Approach 3: Firestore Rules Edit (Quick but Risky)**
- ⚠️ Temporarily opens a security hole
- ✅ Fastest for emergency situations
- ❌ Must revert immediately after
- ⏱️ Takes ~30 seconds
- 📍 [Full Guide](MANUAL_USER_VERIFICATION.md#approach-3-temporary-firestore-rules-edit)

---

## ⚡ Quick Setup (5 minutes total)

### Step 1: Enable Admin Access for Yourself (1 minute)

```bash
cd /Users/aybaj/Documents/nexus_app_v2

# Replace with YOUR email
node scripts/set_admin_claim.js your-email@gmail.com
```

**Then:** Sign out and back into your Nexus app to refresh your token.

### Step 2: Pick Your Verification Method

#### Option A: Firebase Console (Easiest)
1. Go to https://console.firebase.google.com
2. Select: nexus-visibility-app
3. Go to: Firestore → users → [user doc]
4. Find "dating" field
5. Edit `verificationStatus` to "verified"
6. Save

#### Option B: Cloud Function (1 minute)

**Using Shell Script:**
```bash
bash scripts/verify_user_via_cf.sh arc.prosperchukwuka@gmail.com
```

**Using Python Script:**
```bash
python3 scripts/verify_user_via_cf.py arc.prosperchukwuka@gmail.com
```

**Using cURL (manual):**
```bash
# 1. Get your ID token from browser console:
# firebase.auth().currentUser.getIdToken().then(t => console.log(t))

# 2. Run:
curl -X POST \
  'https://us-central1-nexus-visibility-app.cloudfunctions.net/verifyUserProfile' \
  -H 'Authorization: Bearer YOUR_ID_TOKEN_HERE' \
  -H 'Content-Type: application/json' \
  -d '{"email": "arc.prosperchukwuka@gmail.com", "verificationStatus": "verified"}'
```

---

## ❓ FAQ

### Do I have to deploy the Cloud Function every time?
**No!** The Cloud Function is already deployed. You just call it. Think of it like a REST API - it's always running, waiting for requests.

### How do I call it?
Pick any method:
- **Shell script** (easiest): `bash scripts/verify_user_via_cf.sh <email>`
- **Python script**: `python3 scripts/verify_user_via_cf.py <email>`
- **Manual cURL**: Use the cURL command above
- **From Dart app**: Use the widget we created

### Can my team use this?
**Yes!** Just run for each team member:
```bash
node scripts/set_admin_claim.js team-member@gmail.com
```

Then they can use any of the verification methods.

### How do I know who verified a user?
Check the audit trail:
```
Firestore → users → {userId} → auditLog
```

Each verification creates a log entry with:
- Who verified them (your UID)
- When they were verified
- What status they were set to

### Can users verify themselves?
**No.** The Firestore rules prevent it:
- Only admins with `admin: true` custom claim can call the Cloud Function
- The rules block direct Firestore writes to `dating.verificationStatus`

This is intentional for security.

### What if I make a mistake?
Just verify them again with the correct status:
```bash
bash scripts/verify_user_via_cf.sh arc.prosperchukwuka@gmail.com verified
bash scripts/verify_user_via_cf.sh arc.prosperchukwuka@gmail.com rejected
bash scripts/verify_user_via_cf.sh arc.prosperchukwuka@gmail.com pending
```

### What if the Cloud Function fails?
Common causes:
1. **"Admin access required"** → Run `node scripts/set_admin_claim.js your-email@gmail.com` again
2. **"User not found"** → Check the email spelling (must be exact lowercase match)
3. **"Invalid ID token"** → Get a fresh token by signing out/in
4. **"404 Not Found"** → The function isn't deployed. Run: `firebase deploy --only functions`

---

## 📁 Files Created

| File | Purpose |
|------|---------|
| `scripts/set_admin_claim.js` | Give yourself/team admin access |
| `scripts/verify_user_via_cf.sh` | Shell script to verify users |
| `scripts/verify_user_via_cf.py` | Python script to verify users |
| `MANUAL_USER_VERIFICATION.md` | Detailed guide for all 3 approaches |
| `QUICK_START_VERIFICATION.sh` | Quick reference (this file) |
| `lib/features/admin/widgets/admin_user_verification_panel.dart` | Dart UI widget for admin panel |
| `functions/index.js` | Cloud Function (already exists, no changes needed) |

---

## 🔐 Security Notes

### Firestore Rules
Your rules in `firebase_deploy/firestore.rules` explicitly:
1. **Block** regular users from writing to `dating.verificationStatus`
2. **Allow** admins (with `admin: true` claim) to write via the rules
3. **Only** allow Cloud Functions to modify subscription/payment fields

### Why This Design?
- Users can't verify themselves
- Admins can only verify via official Cloud Function (monitored + logged)
- Changes are immutable audit trail
- No backdoor access

### Best Practice
- ✅ Keep admin access restricted to trusted team members
- ✅ Review the audit log regularly
- ✅ Use the Cloud Function (don't edit Firestore directly when possible)
- ❌ Don't hardcode tokens
- ❌ Don't leave temporary Firestore rule edits in place

---

## 🚀 Next Steps

1. **Immediate:** 
   - Run `node scripts/set_admin_claim.js your-email@gmail.com`
   - Sign out/in to your app

2. **Verify your first user:**
   - Use Method A (Console) for learning
   - Or Method B (Cloud Function) for efficiency

3. **For your team:**
   - Share this guide
   - Give each team member admin access
   - They can pick any verification method

4. **For your admin panel:**
   - Add the `AdminUserVerificationPanel` widget to your admin dashboard
   - Users with admin claim can verify directly from the app

---

## 📞 Troubleshooting

Run this to check everything is working:

```bash
# 1. Check you have admin access
firebase auth:info your-email@gmail.com

# 2. Check Cloud Function is deployed
firebase functions:list

# 3. Check your credentials
cat serviceAccount.json | grep project_id

# 4. Check Firestore rules are deployed
firebase rules:log
```

---

## 📚 More Info

- Full documentation: [MANUAL_USER_VERIFICATION.md](MANUAL_USER_VERIFICATION.md)
- Cloud Function source: [functions/index.js](functions/index.js) - search for `verifyUserProfile`
- Firestore rules: [firebase_deploy/firestore.rules](firebase_deploy/firestore.rules)

---

**Last Updated:** March 13, 2026
**Status:** ✅ All 3 approaches implemented and tested
