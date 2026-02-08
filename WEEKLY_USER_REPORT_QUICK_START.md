# Quick Reference: Weekly User Report

## What Was Added

✅ **Cloud Function:** `weeklyUserReport`
- Scheduled: Monday 9 AM UTC
- Generates CSV of new users from past 7 days
- Auto-uploads to Cloud Storage

✅ **Dependency:** `json2csv` package
- Converts user data to CSV format

---

## Deploy Now

```bash
cd firebase_functions
npm install
firebase deploy --only functions:weeklyUserReport
```

**Time to deploy:** ~2-3 minutes

---

## Get Your Reports

**Firebase Console → Storage → user-reports/**

Files stored as: `new-users-YYYY-MM-DD.csv`

Example:
```
new-users-2026-02-08.csv
new-users-2026-02-15.csv
new-users-2026-02-22.csv
```

---

## CSV Columns

| Column | Content |
|--------|---------|
| email | User's email address |
| username | Login username |
| nationality | Country of origin |
| countryOfResidence | Where they live |
| dateJoined | Formatted date (02/08/2026) |
| createdAt | ISO timestamp |

---

## Monitor Execution

```bash
firebase functions:log
```

Or: Firebase Console → Functions → weeklyUserReport → Logs

---

## Test It Now

**Option A - Firebase Console:**
1. Go to Functions → weeklyUserReport
2. Click "Testing" tab
3. Click "Run"

**Option B - CLI:**
```bash
gcloud functions call weeklyUserReport --region=us-central1
```

---

## Customize (if needed)

**Change schedule:**
Edit `firebase_functions/index.js` line with `.schedule('0 9 ? * MON')`

**Change fields:**
Edit `fields` array in Parser

**Change date range:**
Edit `sevenDaysAgo.setDate()` line

---

## Documentation

Full guide: `WEEKLY_USER_REPORT_SETUP.md`

---

## Done! ✅

- Code is ready
- Dependencies added
- Just run `npm install && firebase deploy`
- Reports auto-generate every Monday
