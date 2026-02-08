# Deployment Steps - Weekly User Report

## Prerequisites Check

✅ Firebase project initialized
✅ Cloud Storage bucket exists
✅ `firebase_functions/` folder present

---

## Step 1: Install Dependencies

```bash
cd firebase_functions
npm install
```

**Output should show:**
```
added 1 package (json2csv)
up to date, X packages in Y seconds
```

---

## Step 2: Verify Configuration

Check that your `package.json` has:
```json
"json2csv": "^6.0.0"
```

Check that `index.js` imports:
```javascript
const { Parser } = require('json2csv');
```

---

## Step 3: Deploy to Firebase

```bash
firebase deploy --only functions:weeklyUserReport
```

**You should see:**
```
✔  functions[weeklyUserReport]: Successful
```

**Full output example:**
```
i  deploying functions
i  functions: preparing functions directory for uploading...
i  functions: packaged functions (X KB) for uploading
✔  functions[weeklyUserReport]: Successful
i  functions: cleaning up build files from previous deploys

Deploy complete!
```

---

## Step 4: Verify in Firebase Console

1. Open Firebase Console
2. Go to **Functions**
3. Look for `weeklyUserReport` in the list
4. Status should show ✅ (Green checkmark)

---

## Step 5: Test Manually

**Test via Firebase Console:**
1. Click `weeklyUserReport` function
2. Go to **Testing** tab
3. Click **Run** button
4. Check **Logs** for execution details

**Test via CLI:**
```bash
gcloud functions call weeklyUserReport --region=us-central1
```

**Expected success response:**
```json
{
  "success": true,
  "message": "Weekly user report generated successfully",
  "usersCount": 15,
  "filename": "user-reports/new-users-2026-02-08.csv",
  "period": "02/01/2026 - 02/08/2026"
}
```

---

## Step 6: View Generated Report

**Location:** Firebase Console → Storage → `user-reports/` folder

**Download:** Click the file, then **Download** button

---

## Step 7: Schedule Verification (Optional)

Verify Cloud Scheduler is set up:
1. Firebase Console → Cloud Scheduler
2. Look for `weeklyUserReport`
3. Should show: "Every Monday 9:00 AM (UTC)"

---

## Troubleshooting Deployment

**❌ Error: "json2csv not found"**
```bash
cd firebase_functions
npm install json2csv
```

**❌ Error: "Function deployment failed"**
```bash
firebase deploy --only functions:weeklyUserReport --debug
```

**❌ No files in user-reports/**
- Manually trigger the function (Step 5)
- Check logs for errors

**❌ "Module not found: Parser"**
- Verify `index.js` line 3: `const { Parser } = require('json2csv');`
- Verify `package.json` has `"json2csv": "^6.0.0"`
- Run `npm install` again

---

## Verify It Works

### Option 1: Wait for Next Monday
- Function runs automatically at 9 AM UTC (Monday)
- Check Storage at that time

### Option 2: Test Now (Recommended)
1. Manual test from Firebase Console (Step 5)
2. Report appears in `user-reports/` folder
3. Download and verify CSV

### Option 3: Check Logs
```bash
firebase functions:log
```

Look for lines like:
```
🚀 Starting weekly user report generation...
✅ Found 15 new users
✅ Report successfully uploaded: user-reports/new-users-2026-02-08.csv
📊 Total new users: 15
```

---

## Success Indicators

✅ Function appears in Firebase Console
✅ Manual test succeeds
✅ CSV file appears in Cloud Storage
✅ CSV has correct columns and data
✅ Logs show no errors

---

## You're Done! 🎉

Your weekly user reports are now automated and ready to download.

**Next steps:**
- Set up your marketing team to access Cloud Storage
- Download weekly reports for analysis
- (Optional) Add email notifications
- (Optional) Set up retention policy to auto-delete old reports

---

## Support

- Full docs: `WEEKLY_USER_REPORT_SETUP.md`
- Quick reference: `WEEKLY_USER_REPORT_QUICK_START.md`
- Function code: `firebase_functions/index.js` (lines 370+)
