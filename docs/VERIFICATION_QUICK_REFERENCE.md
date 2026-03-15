# 🚀 Quick Reference - User Verification

**User to verify:** `arc.prosperchukwuka@gmail.com`

---

## ⚡ Ultra-Quick Start (Copy-Paste Commands)

### 1️⃣ Make Yourself Admin (Run Once)
```bash
cd /Users/aybaj/Documents/nexus_app_v2
node scripts/set-admin-claim.js your-email@example.com true
```

### 2️⃣ Verify the User (Option A: Instant CLI)
```bash
node scripts/admin-verify-user.js arc.prosperchukwuka@gmail.com
```

### 2️⃣ Verify the User (Option B: Cloud Function - Deploy Once, Use Forever)
```bash
# Deploy the function (one-time)
cd functions && firebase deploy --only functions:verifyUserProfile

# Then call it from app/JavaScript/Python when needed
```

### 2️⃣ Verify the User (Option C: Firebase Console)
1. https://console.firebase.google.com
2. Select `nexus-visibility-app`
3. Firestore → users → search email
4. Edit `dating.verificationStatus` → "verified"

---

## 📚 Full Documentation

- [USER_VERIFICATION_GUIDE.md](USER_VERIFICATION_GUIDE.md) - Complete guide with all methods
- [CLOUD_FUNCTION_FAQ.md](CLOUD_FUNCTION_FAQ.md) - Cloud Function details

---

## 🎯 Method Comparison

| Task | Command | Time |
|------|---------|------|
| Make yourself admin | `node scripts/set-admin-claim.js your-email@gmail.com true` | 1 min |
| Verify 1 user via CLI | `node scripts/admin-verify-user.js email@example.com` | 10 sec |
| Deploy Cloud Function | `firebase deploy --only functions:verifyUserProfile` | 5 min |
| Verify 1 user via Function | Call API endpoint | <1 sec |
| Verify 1 user via Console | Manual clicks | 2 min |

---

## ✨ What's New

✅ **Cloud Function `verifyUserProfile`** added to `functions/index.js`  
✅ **CLI Script `admin-verify-user.js`** for quick local verification  
✅ **CLI Script `set-admin-claim.js`** to grant yourself admin access  
✅ **Full documentation** in `docs/` folder  

---

## Need Help?

- **Setting up admin access?** → See [USER_VERIFICATION_GUIDE.md](USER_VERIFICATION_GUIDE.md#-step-1-give-yourself-admin-access)
- **Want to use Cloud Function?** → See [CLOUD_FUNCTION_FAQ.md](CLOUD_FUNCTION_FAQ.md)
- **Having issues?** → Check [USER_VERIFICATION_GUIDE.md#-troubleshooting](USER_VERIFICATION_GUIDE.md#-troubleshooting)
