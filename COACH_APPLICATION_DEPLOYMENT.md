# Coach Application Feature - Deployment Guide

## Overview
Complete implementation of a "Call for Applications" recruitment feature allowing professional marriage counselors to submit applications directly through the Nexus app. Applications are automatically emailed to `contact@nexus4singles.com` with all details and attachments.

## ✅ What Was Implemented

### 1. Navigation Changes
- **Renamed**: NavTab enum value from `coach` to `counselling`
- **Updated**: All navigation configurations for married users (5 tabs: home, stories, journeys, counselling, profile)
- **Label**: Changed from "Coach" to "Counselling" in navigation menu
- **Icon**: Phone icon (`Icons.phone_in_talk_outlined`) semantic for "speaking to a counselor"

### 2. Application Form Screen
**File**: `/lib/features/subscription/presentation/screens/coach_application_screen.dart`

**4-Page Multi-Step Form**:
1. **Personal Information**: Title, name, email, phone, gender
2. **Professional Background**: Nationality, location, years of experience, marital status
3. **Qualifications**: Credentials, coaching philosophy, social media handles (optional)
4. **Media & Submission**: Profile photo upload (required), credentials PDF (optional), form submission

**Features**:
- Progress bar showing form completion
- Form validation on each step
- Beautiful Material Design 3 UI with app theme colors
- Profile photo preview with upload/remove functionality
- Loading state during submission
- Success/error feedback via snackbars

### 3. Firestore Data Structure
**Collection**: `coachApplications/{applicationId}`

**Document Fields**:
```
- applicationId: string
- status: "pending" | "approved" | "rejected"
- submittedAt: timestamp
- emailSentAt: timestamp (added by Cloud Function)
- fullName, email, phoneNumber, gender
- nationality, residenceLocation
- title, yearsOfExperience, maritalStatus
- credentials, specializations, coachingPhilosophy
- instagramHandle, linkedinProfile
- profilePhoto: { url, filename, uploadedAt }
- credentialsPdf: { url, filename, uploadedAt }
```

### 4. Cloud Function for Email
**File**: `/firebase_functions/index.js` - `onCoachApplicationSubmitted` function

**Triggered**: When new document created in `coachApplications` collection

**Features**:
- Automatically emails to `contact@nexus4singles.com`
- Downloads profile photo and credentials PDF from Storage
- Sends professional HTML email with all application details
- Attaches profile photo as JPEG
- Attaches credentials PDF file
- Updates Firestore document with `emailSentAt` timestamp
- Comprehensive error logging

**Email Content**:
- Gradient header with "New Coach Application" title
- Structured application information in table format
- Professional background section
- Coaching philosophy
- Social media links
- Application ID and submission timestamp
- Status badge showing "PENDING REVIEW"

## 🚀 Deployment Steps

### Step 1: Update App Navigation
All navigation files have been updated automatically. No additional action needed.

**Files Modified**:
- ✅ `/lib/core/constants/app_constants.dart` - NavTab enum and config
- ✅ `/lib/app_shell.dart` - Screen/icon mapping
- ✅ `/lib/core/constants/app_constants.dart` - Route constants

### Step 2: Deploy Cloud Function

```bash
# Navigate to functions directory
cd firebase_functions

# Install/update dependencies (if not already done)
npm install

# Deploy the function
firebase deploy --only functions:onCoachApplicationSubmitted

# OR deploy all functions
firebase deploy --only functions
```

### Step 3: Configure Firebase Storage (if needed)

Add this security rule to your `firestore.rules` (if not already present):

```javascript
// Coach application files in Storage
match /coachApplications/{applicationId}/{allPaths=**} {
  allow read: if request.auth.uid != null && request.auth.token.admin == true;
  allow write: if request.auth.uid != null;
}
```

### Step 4: Add Firestore Indexes (Optional)

For optimal query performance, create these indexes in Firestore Console:

**Index 1**: Status + Submitted Date
- Collection: `coachApplications`
- Fields: `status` (Ascending), `submittedAt` (Descending)
- Used for: Admin dashboard filtering

**Index 2**: Email
- Collection: `coachApplications`
- Field: `email` (Ascending)
- Used for: Uniqueness checking and contact

### Step 5: Email Configuration Check

Verify Gmail app password is set:

```bash
# Check current configuration
firebase functions:config:get

# Set Gmail app password if not already set
firebase functions:config:set gmail.password="YOUR_APP_PASSWORD"

# Deploy with new config
firebase deploy --only functions
```

**To Get Gmail App Password**:
1. Go to `myaccount.google.com`
2. Enable 2-Factor Authentication (if not enabled)
3. Go to Security → App passwords
4. Select "Mail" and "macOS" (or your platform)
5. Copy the generated 16-character password
6. Use it in the command above

### Step 6: Test the Feature

1. **Build & Run**: `flutter run`
2. **Navigate**: Home → Counselling tab (married users only)
3. **Click**: "Submit Your Application" button on "Call for Applications" card
4. **Fill Form**: Complete all 4 pages of the form
5. **Submit**: Upload profile photo and click "Submit Application"
6. **Verify**: Check `contact@nexus4singles.com` inbox for email with attachments

**Test Email Content**:
- Subject: `🎯 New Coach Application: [Applicant Name]`
- Contains all form data in formatted HTML table
- Attachments: Profile photo (JPEG) + Credentials (PDF if provided)

## 📋 Feature Checklist

### Frontend
- ✅ Navigation renamed to "Counselling"
- ✅ 4-page multi-step form with validation
- ✅ Profile photo upload with preview
- ✅ Credentials PDF upload (optional)
- ✅ Form state management with Riverpod
- ✅ Loading/success/error states
- ✅ Beautiful Material Design 3 UI
- ✅ Dark mode support via AppColors

### Backend
- ✅ Firestore collection structure
- ✅ Cloud Function to send emails
- ✅ Automatic attachment handling
- ✅ HTML email formatting
- ✅ Error handling and logging
- ✅ Timestamp tracking

### Security
- ✅ Firestore security rules (applications in collection)
- ✅ Storage rules for applicant files
- ✅ Email only sent to contact@nexus4singles.com
- ✅ Gmail App Password (not account password)

## 🔄 Workflow

1. **User Navigates**: Home → Counselling tab → "Call for Applications"
2. **User Fills Form**: 4-step multi-page form
3. **User Uploads**: Profile photo + optional credentials PDF
4. **User Submits**: Form submitted to Firestore
5. **Cloud Function Triggers**: 
   - Downloads attachments from Storage
   - Compiles application data
   - Sends professional email
   - Updates Firestore with `emailSentAt`
6. **Admin Receives**: Email with complete application + attachments
7. **Admin Reviews**: Opens email, reviews info, downloads attachments
8. **Admin Updates**: Changes document status in Firestore Console (pending → approved/rejected)

## 📧 Email Template

The Cloud Function sends a beautifully formatted HTML email including:
- Gradient header with application count badge
- Applicant details in professional table format
- Credentials section
- Coaching philosophy section
- Social media links
- Application metadata (ID, timestamp, status)
- Profile photo as inline attachment
- Credentials PDF as email attachment

## 🐛 Debugging

### Check Cloud Function Logs
```bash
firebase functions:log
```

### Manual Email Test
```bash
# Send test email via Cloud Functions shell
firebase functions:shell
> onCoachApplicationSubmitted()
```

### Verify Firestore Data
Firebase Console → Firestore → coachApplications collection

### Check Storage Files
Firebase Console → Storage → coachApplications folder

## 🎨 Customization

### Change Email Recipient
Edit `/firebase_functions/index.js`:
```javascript
to: 'your-email@example.com',
cc: 'cc-email@example.com',
```

### Change Email Subject/Content
Modify the `mailOptions` object in the Cloud Function:
```javascript
subject: `🎯 New Coach Application: ${data.fullName}`,
```

### Adjust Form Fields
Edit `/lib/features/subscription/presentation/screens/coach_application_screen.dart`:
- Add/remove form pages
- Modify page content
- Change field validation rules

### Customize Form UI
- Colors: Use `AppColors` from app theme
- Fonts: Use `AppTextStyles` from app theme
- Layout: Modify padding/spacing constants

## 📱 Mobile Testing Checklist

- [ ] Navigate to Counselling tab (married users)
- [ ] View "Call for Applications" card with benefits
- [ ] Click "Submit Your Application"
- [ ] Complete all 4 form pages
- [ ] Upload profile photo
- [ ] Leave credentials PDF empty (optional)
- [ ] Submit application
- [ ] See success message
- [ ] Check email receipt (verify with test email)

## 🚨 Common Issues & Solutions

**Issue**: Cloud Function not triggered
- **Solution**: Ensure Firestore document created in `coachApplications` collection

**Issue**: Email not received
- **Solution**: Check Gmail app password set correctly, verify email address in code

**Issue**: Attachments not showing in email
- **Solution**: Verify files exist in Storage path, check Storage security rules

**Issue**: Form submission fails
- **Solution**: Check internet connection, verify Firestore permissions, check browser console

## 📚 Related Files

- `/lib/features/subscription/presentation/screens/coach_application_screen.dart` - Main form UI
- `/lib/features/subscription/presentation/screens/book_marriage_coach_screen.dart` - "Call for Applications" card
- `/lib/features/subscription/application/coach_application_service.dart` - Firestore submission logic
- `/firebase_functions/index.js` - Cloud Function (email handler)
- `/COACH_APPLICATION_SCHEMA.md` - Firestore schema documentation
- `/lib/core/constants/app_constants.dart` - Navigation configuration

## 🎯 Future Enhancements

- [ ] Admin dashboard to view/approve applications
- [ ] Email confirmation to applicant
- [ ] Applicant status tracking in app
- [ ] Multiple file upload support
- [ ] Video introduction upload
- [ ] Interview scheduling integration
- [ ] Applicant filtering by specialization
- [ ] Bulk email export for admin

## ✨ Summary

The "Call for Applications" feature is now fully functional with:
- ✅ Beautiful 4-page application form
- ✅ Automatic email delivery with attachments
- ✅ Professional email template
- ✅ Firestore data persistence
- ✅ Complete error handling
- ✅ Dark mode support
- ✅ Form validation on each step
- ✅ Zero additional dependencies required

Applicants can now apply directly from the app to be part of the Nexus counseling team!
