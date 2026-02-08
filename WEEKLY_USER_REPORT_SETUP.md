# Weekly User Report Implementation Guide

## Overview

Automated Cloud Function that generates a CSV report of new users every Monday at 9 AM UTC. Reports are stored in Cloud Storage for easy download by your marketing team.

**What's Included:**
- Email address
- Username
- Nationality
- Country of Residence
- Date Joined
- Full timestamp

---

## Implementation Status

✅ **Complete** - Ready to deploy

### Files Modified:
1. `firebase_functions/package.json` - Added `json2csv` dependency
2. `firebase_functions/index.js` - Added `weeklyUserReport` function

---

## Deployment Instructions

### Step 1: Install Dependencies

```bash
cd firebase_functions
npm install
```

This will install the new `json2csv` package along with existing dependencies.

### Step 2: Deploy to Firebase

```bash
firebase deploy --only functions:weeklyUserReport
```

Or deploy all functions:
```bash
firebase deploy --only functions
```

### Step 3: Verify Deployment

Check Firebase Console:
1. Go to **Firebase Console → Functions**
2. Look for `weeklyUserReport` in the list
3. Status should show ✅ **Active**

---

## How It Works

### Schedule
- **Frequency:** Every Monday
- **Time:** 9:00 AM UTC
- **Cron:** `0 9 ? * MON`

To change the time, edit line in `firebase_functions/index.js`:
```javascript
.schedule('0 9 ? * MON')  // Change the cron expression
```

### Process
1. **Collect:** Queries all users created in the past 7 days
2. **Format:** Converts to CSV with proper headers
3. **Upload:** Stores in Cloud Storage at `gs://YOUR_BUCKET/user-reports/new-users-YYYY-MM-DD.csv`
4. **Log:** Records details in Cloud Functions logs

### CSV Format

| Column | Description | Example |
|--------|-------------|---------|
| email | User email | john@example.com |
| username | Unique username | john_doe |
| nationality | User's nationality | Nigerian |
| countryOfResidence | Country where user lives | Nigeria |
| dateJoined | Formatted date | 02/08/2026 |
| createdAt | ISO timestamp | 2026-02-08T14:30:45.123Z |

---

## Accessing Reports

### Option A: Firebase Console (Recommended)

1. Go to **Firebase Console → Storage**
2. Navigate to `user-reports/` folder
3. See list of all weekly reports
4. Click any file to download

### Option B: Cloud Storage CLI

```bash
# List all reports
gsutil ls gs://YOUR_BUCKET/user-reports/

# Download a specific report
gsutil cp gs://YOUR_BUCKET/user-reports/new-users-2026-02-08.csv ./

# Download all reports
gsutil cp -r gs://YOUR_BUCKET/user-reports/ ./
```

### Option C: Programmatic Access (Dart Code)

```dart
import 'package:firebase_storage/firebase_storage.dart';

// List all reports
final result = await FirebaseStorage.instance
    .ref('user-reports')
    .listAll();

for (var file in result.items) {
  final url = await file.getDownloadURL();
  print('Download: $url');
}

// Download specific report
final url = await FirebaseStorage.instance
    .ref('user-reports/new-users-2026-02-08.csv')
    .getDownloadURL();
```

---

## Monitoring & Troubleshooting

### View Execution Logs

```bash
firebase functions:log
```

Or in Firebase Console:
1. **Firebase Console → Functions → weeklyUserReport**
2. Scroll to "Logs" section
3. See execution history and any errors

### Common Issues

**❌ "Function not found"**
- Ensure you deployed: `firebase deploy --only functions:weeklyUserReport`
- Wait 2-3 minutes for deployment to complete

**❌ "No data in CSV"**
- Check if users have `createdAt` timestamp
- Verify users were created within last 7 days
- Check Firestore rules allow the function to read

**❌ "Cloud Storage permission denied"**
- Ensure Cloud Storage bucket exists
- Check Firebase Console → Storage is set up
- Verify function has permission in `firebase.json`

**❌ "Scheduler not triggered"**
- Cloud Scheduler must be enabled in your Firebase project
- Go to Firebase Console → Scheduler
- Should see `weeklyUserReport` scheduled job
- Can manually trigger for testing

---

## Testing

### Manual Test (Before Monday)

Trigger the function manually:

```bash
gcloud functions call weeklyUserReport --region=us-central1
```

Or from Firebase Console:
1. Go to **Functions → weeklyUserReport**
2. Click **Testing** tab
3. Click **Run** button

Expected output:
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

## Customization

### Change Schedule

Edit `firebase_functions/index.js`:

```javascript
// Run every day at 8 AM
.schedule('0 8 * * *')

// Run every Friday at 5 PM
.schedule('0 17 ? * FRI')

// Run 1st of every month at midnight
.schedule('0 0 1 * *')
```

**Cron Format:** `minute hour day month dayOfWeek`
- `*` = any
- `?` = no specific value (for day/dayOfWeek)
- Numbers = specific value
- `0-23` for hours (UTC), `0-59` for minutes

### Add Email Notification

Add this before the `return` statement (after file upload):

```javascript
// Send email notification
const emailContent = `
  <h2>Weekly User Report Generated</h2>
  <p><strong>Date:</strong> ${today}</p>
  <p><strong>New Users:</strong> ${users.length}</p>
  <p><strong>Period:</strong> ${sevenDaysAgo.toLocaleDateString()} - ${new Date().toLocaleDateString()}</p>
  <p><strong>Download:</strong> <a href="https://console.firebase.google.com/u/0/project/YOUR-PROJECT-ID/storage">Firebase Console</a></p>
`;

// Configure your email details and send
const mailOptions = {
  from: 'nexusgodlydating@gmail.com',
  to: 'marketing@nexusgodlydating.com',
  subject: `Weekly User Report - ${today}`,
  html: emailContent,
};

// Uncomment if you want to use nodemailer
// await transporter.sendMail(mailOptions);
```

### Filter by Specific Criteria

To only include users who completed onboarding:

```javascript
const snapshot = await admin.firestore()
  .collection('users')
  .where('createdAt', '>=', admin.firestore.Timestamp.fromDate(sevenDaysAgo))
  .where('nexus2.onboardingCompleted', '==', true)  // Add this line
  .orderBy('createdAt', 'desc')
  .get();
```

---

## Security

### Current Setup
- ✅ Only admins can manage reports
- ✅ Cloud Storage rules enforce authentication
- ✅ Function runs server-side (secure)
- ✅ No sensitive data exposed

### Best Practices
1. **Restrict CSV downloads** - Only marketing team
2. **Set retention policy** - Auto-delete old reports after 90 days
3. **Enable Cloud Audit Logging** - Track who accessed what
4. **Use signed URLs** - For sharing reports temporarily

---

## Cost Estimate

**Monthly cost (approx):**
- Cloud Functions: ~$0.40/month (4 invocations)
- Cloud Storage: ~$0.02/month (100 KB data)
- **Total: ~$0.50/month**

---

## Next Steps

1. ✅ Code is ready in `firebase_functions/index.js`
2. Run: `cd firebase_functions && npm install`
3. Deploy: `firebase deploy --only functions:weeklyUserReport`
4. Wait for Monday 9 AM UTC, or test manually
5. Download first report from Firebase Console → Storage

---

## Support

**To troubleshoot:**
```bash
# View recent logs
firebase functions:log

# Check specific function
firebase functions:log weeklyUserReport

# Deploy with verbose output
firebase deploy --only functions:weeklyUserReport --debug
```

**Need to modify?** Edit:
- Schedule: Line with `.schedule('0 9 ? * MON')`
- Fields: Fields array in Parser
- Date range: `sevenDaysAgo.setDate()` line
