# Coach Application Admin Review - Deployment Checklist

## Pre-Deployment Verification

### Code Quality
- [x] All imports correct and no unused imports
- [x] Null safety implemented throughout
- [x] Error handling for all async operations
- [x] Loading states for StreamProviders and FutureProviders
- [x] Proper use of Riverpod patterns
- [x] Consistent naming conventions

### Files Created
- [x] `lib/features/admin_review/application/coach_application_providers.dart`
- [x] `lib/features/admin_review/presentation/screens/coach_review_queue_screen.dart`
- [x] `lib/features/admin_review/presentation/screens/coach_review_detail_screen.dart`

### Files Updated
- [x] `lib/features/admin_review/presentation/screens/admin_review_queue_screen.dart` (added TabBar)
- [x] `firebase_functions/index.js` (added status='pending' field)

### Documentation
- [x] `COACH_APPLICATION_ADMIN_REVIEW_SCHEMA.md` - Firestore schema
- [x] `COACH_APPLICATION_ADMIN_REVIEW_IMPLEMENTATION.md` - Implementation guide
- [x] `COACH_APPLICATION_INTEGRATION_COMPLETE.md` - Summary

## Testing Steps

### 1. Local Testing
```bash
# Build and run the app
flutter pub get
flutter run

# Or run on specific platform
flutter run -d chrome  # For web testing
```

### 2. Submit Coach Application
- Navigate to Counselling section
- Click "Book Marriage Coach"
- Click "Call for Applications" card
- Fill out 4-page form:
  - Page 1: Personal info (name, email, phone, gender)
  - Page 2: Professional info (title, experience, location)
  - Page 3: Qualifications (credentials, philosophy)
  - Page 4: Attachments (profile photo, PDF)
- Submit application

### 3. Verify Firestore Document
```
Firebase Console → Firestore Database → coachApplications collection
Look for new document with:
✓ fullName, email, phoneNumber, gender
✓ title, yearsOfExperience, nationality, residenceLocation
✓ credentials, coachingPhilosophy
✓ profilePhoto: { url, filename, uploadedAt }
✓ credentialsPdf: { url, filename, uploadedAt }
✓ status: "pending"
✓ submittedAt: [timestamp]
✓ emailSentAt: [timestamp]
```

### 4. Verify Cloud Function Email
- Check email inbox: contact@nexus4singles.com
- Should receive formatted email with:
  ✓ All applicant details
  ✓ Profile photo attachment
  ✓ Credentials PDF attachment
  ✓ Application ID and submission timestamp

### 5. Test Admin Dashboard
```
Steps:
1. Log in with admin account
2. Go to Settings or Profile screen
3. Click "Admin Reviews" button
4. See tabbed interface with:
   - Tab 1: "Dating Profiles" (existing reviews)
   - Tab 2: "Coach Applications" (new reviews)
5. Click "Coach Applications" tab
6. Should see submitted application in queue
```

### 6. Test Coach Queue Display
✓ Application displays with:
- Profile photo (circular avatar)
- Full name
- Years of experience
- Gender
✓ Tap application navigates to detail screen

### 7. Test Detail Screen
✓ Full application displays with sections:
- Personal Information (name, email, phone, gender)
- Professional Information (title, exp, location, status)
- Qualifications (credentials, specializations, philosophy)
- Social Media (Instagram, LinkedIn with links)
- Attachments (profile photo, downloadable PDF)
- Submission Info (dates, status)

✓ Links work:
- Click Instagram handle → opens Instagram
- Click LinkedIn → opens LinkedIn
- Click PDF download → downloads file

### 8. Test Approve Action
```
Steps:
1. Click "Approve" button
2. Should see loading indicator
3. Operation completes, snackbar shows success
4. Navigate back to queue
5. Application should be gone (no longer pending)
6. Verify Firestore status changed to "approved"
7. Verify reviewedAt timestamp set
```

### 9. Test Reject Action
```
Steps:
1. Click "Reject" button
2. Dialog appears asking for reason
3. Enter rejection reason
4. Click "Reject" in dialog
5. Loading indicator shows
6. Operation completes, snackbar shows success
7. Navigate back to queue
8. Application should be gone (no longer pending)
9. Verify Firestore status changed to "rejected"
10. Verify rejectionReason stored
11. Verify reviewedAt timestamp set
```

### 10. Test Real-Time Updates
```
Steps:
1. Open admin dashboard on Device A
2. Open admin dashboard on Device B
3. On Device A: Approve an application
4. On Device B: Application should disappear from queue automatically
5. No manual refresh needed
6. Vice versa: Test from Device B to Device A
```

### 11. Test Error Handling
```
Test network failure:
- Disable internet
- Try to view coach application detail
- Should show "Error loading application"
- Re-enable internet, can retry

Test invalid application ID:
- Manually navigate to non-existent app ID
- Should show "Application not found" error
```

## Deployment Steps

### Step 1: Deploy Cloud Function
```bash
cd firebase_functions
npm install
firebase deploy --only functions
```

Wait for deployment to complete. Check logs:
```bash
firebase functions:log
```

### Step 2: Deploy Firestore Rules (if needed)
```bash
firebase deploy --only firestore:rules
```

### Step 3: Verify Firestore Indexes
```
Firebase Console → Firestore Database → Indexes
Should have (or create):
- Collection: coachApplications
- Fields: status (Asc), submittedAt (Desc)
```

### Step 4: Build and Deploy App
```bash
flutter build ios    # For iOS
flutter build apk    # For Android
flutter build web    # For Web
# Upload to respective stores
```

### Step 5: Post-Deployment Testing
Repeat testing steps 1-11 above in production environment

## Monitoring & Verification

### Cloud Function Health
```bash
firebase functions:log
# Look for successful executions
# Should see: "✅ Application email sent for [Name]"
```

### Firestore Queries
```
Check that query works:
db.collection('coachApplications')
  .where('status', '==', 'pending')
  .orderBy('submittedAt', descending: true)
  .limit(200)
```

### Email Delivery
- Monitor contact@nexus4singles.com inbox
- Check email arrives within 1-2 minutes of submission
- Verify attachments are present
- Verify HTML formatting is correct

### Admin Access Logs
Monitor who's reviewing applications:
```
Firebase Console → Functions → Logs
Search for: "Processing coach application"
Should show which admin reviewed what
```

## Rollback Plan (If Needed)

### Issue: Cloud Function not sending emails
```bash
# Revert to previous version
firebase functions:list  # Get version ID
firebase functions:delete onCoachApplicationSubmitted
# Then redeploy previous working version
```

### Issue: Admin screens not showing queue
```bash
# Check Firestore rules haven't changed
# Restart app and clear cache
# Or redeploy specific screens file
```

### Issue: Firestore migration issues
```bash
# If schema changed, update documents manually or via script
# Use provided migration script if available
```

## Performance Monitoring

### Key Metrics to Monitor
- Queue load time (should be <2 seconds)
- Detail screen load time (should be <1 second)
- Real-time update latency (should be <3 seconds)
- Email delivery time (should be <5 minutes)

### Database Queries to Optimize
Monitor in Firestore:
- coachApplications index on (status, submittedAt)
- Composite index queries are efficient

## Security Verification

### Firestore Rules
```bash
# Verify rules allow admin read/write only
firebase deploy --only firestore:rules
```

### Cloud Function Security
- Email sent only to hardcoded address (contact@nexus4singles.com)
- No user input used in system commands
- File downloads validated before processing

### Admin Access
- Only users with `admin` role can access dashboard
- ✓ Verified in isAdminProvider

## Success Criteria

Deployment is successful when:
- ✅ Coach applications can be submitted via form
- ✅ Email received at contact@nexus4singles.com with attachments
- ✅ Applications appear in admin dashboard "Coach Applications" tab within 1 minute
- ✅ Admin can view full application details
- ✅ Admin can approve/reject applications
- ✅ Firestore status updates reflect admin actions
- ✅ Real-time updates work across multiple admin sessions
- ✅ No errors in Cloud Function logs
- ✅ All navigation works correctly
- ✅ UI displays properly on all screen sizes

## Support & Troubleshooting

### Issue: Applications not appearing in queue
**Diagnosis:**
- Check Firestore: document exists in `coachApplications`?
- Check status field: is it `'pending'`?
- Check admin role: does user have admin role?
- Check browser cache: hard refresh?

**Solution:**
```
1. Hard refresh browser (Cmd+Shift+R on Mac)
2. Restart app
3. Check Firestore Console for document
4. Verify status field is exactly 'pending'
```

### Issue: Email not received
**Diagnosis:**
- Check Cloud Function logs: `firebase functions:log`
- Check attachment downloads succeeded
- Check Gmail not blocked emails

**Solution:**
```
1. Check function logs for errors
2. Verify attachments exist in Cloud Storage
3. Test email address is correct
4. Check Gmail spam folder
```

### Issue: Detail screen won't load
**Diagnosis:**
- Check network connection
- Check Firestore rules allow admin read
- Check application document exists

**Solution:**
```
1. Check internet connection
2. Try refreshing the page
3. Check Firestore rules in Console
4. Verify document ID is correct
```

## Documentation Reference
- `COACH_APPLICATION_ADMIN_REVIEW_SCHEMA.md` - Full schema details
- `COACH_APPLICATION_ADMIN_REVIEW_IMPLEMENTATION.md` - Architecture & flows
- `COACH_APPLICATION_INTEGRATION_COMPLETE.md` - Summary & checklist

## Sign-Off

Once all testing is complete and successful:
- [ ] All code deployed
- [ ] All tests passing
- [ ] No errors in logs
- [ ] Email delivery confirmed
- [ ] Admin dashboard verified working
- [ ] Ready for production use

---

**Deployment Status:** Ready for production
**Last Updated:** [Timestamp]
**Tested By:** [Name]
**Approved By:** [Name]
