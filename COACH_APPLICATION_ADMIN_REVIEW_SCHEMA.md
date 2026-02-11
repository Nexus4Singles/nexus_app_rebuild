# Coach Application Admin Review Schema

## Overview
This document describes the Firestore structure for coach applications integrated into the admin review system. Coach applications are separate from dating profile reviews but stored in the same admin framework with similar admin review fields.

## Collection: `coachApplications`

### Document Structure
Each document in `coachApplications` represents one coach application submission.

```
coachApplications/
├── {applicationId}
│   ├── applicationId: string (unique identifier)
│   ├── status: string (pending | approved | rejected)
│   ├── submittedAt: timestamp (when application was submitted)
│   ├── emailSentAt: timestamp (when confirmation email was sent to admin)
│   ├── reviewedAt: timestamp (when admin reviewed the application)
│   │
│   ├── # Personal Information
│   ├── fullName: string
│   ├── email: string
│   ├── phoneNumber: string
│   ├── gender: string (Male | Female | Other)
│   │
│   ├── # Professional Information
│   ├── nationality: string
│   ├── residenceLocation: string
│   ├── title: string (e.g., "Licensed Marriage Counselor")
│   ├── yearsOfExperience: integer
│   ├── maritalStatus: string
│   │
│   ├── # Qualifications
│   ├── credentials: string (detailed credentials/certifications)
│   ├── specializations: array (list of specialization strings)
│   ├── coachingPhilosophy: string (coaching approach and philosophy)
│   │
│   ├── # Social Media
│   ├── instagramHandle: string (optional)
│   ├── linkedinProfile: string (URL, optional)
│   │
│   ├── # Attachments
│   ├── profilePhoto: map
│   │   ├── url: string (Cloud Storage URL)
│   │   ├── filename: string
│   │   └── uploadedAt: timestamp
│   │
│   ├── credentialsPdf: map
│   │   ├── url: string (Cloud Storage URL)
│   │   ├── filename: string
│   │   └── uploadedAt: timestamp
```

## Admin Review Fields

### Status Values
- **pending**: Application received and awaiting review
- **approved**: Approved by admin - coach can proceed
- **rejected**: Rejected by admin

### Review Tracking
- `reviewedAt`: Timestamp when admin action was taken
- `reviewedBy`: Admin user ID who made the decision (optional, for future expansion)
- `rejectionReason`: string (optional, only if status is "rejected")

## Cloud Storage Structure

Attachments are stored in Cloud Storage under:

```
coachApplications/{applicationId}/
├── profilePhoto
├── credentials.pdf
```

## Firestore Indexes

Required composite index for the admin queue:
- Collection: `coachApplications`
- Fields:
  - `status` (Ascending)
  - `submittedAt` (Descending)
  - `applicationId` (Ascending)

Query pattern: `where('status', '==', 'pending').orderBy('submittedAt', descending: true).limit(200)`

## Security Rules

```firestore
match /coachApplications/{document=**} {
  allow read: if request.auth.uid in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles;
  allow write: if request.auth.uid != null;
  allow delete: if request.auth.uid in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles;
}
```

## Integration with Admin Review System

### Providers (Riverpod)
- `pendingCoachApplicationsProvider`: StreamProvider that watches `coachApplications` where `status == 'pending'`
- `coachApplicationDetailProvider`: FutureProvider for full application details
- `updateCoachApplicationStatusProvider`: FutureProvider for approval/rejection

### Screens
- **Coach Review Queue Screen** (`coach_review_queue_screen.dart`):
  - Displays list of pending applications
  - Shows: applicant photo, name, years of experience, gender
  - Real-time updates via StreamProvider

- **Coach Review Detail Screen** (`coach_review_detail_screen.dart`):
  - Displays full application details
  - Shows profile photo, all form fields
  - Allows approve/reject actions
  - Download credentials PDF

### Admin Dashboard
- **Tabbed Interface** (`admin_review_queue_screen.dart`):
  - Tab 1: Dating Profile Reviews (existing)
  - Tab 2: Coach Application Reviews (new)
  - Keeps the two review types separated

## Email Notifications

### Application Submission
When a coach submits an application:
1. Document created in `coachApplications` collection
2. Cloud Function triggered: `onCoachApplicationSubmitted`
3. Email sent to `contact@nexus4singles.com` with:
   - Full application details
   - Profile photo as attachment
   - Credentials PDF as attachment
4. `emailSentAt` timestamp set
5. `status` field set to `pending`

### Review Completion
When an admin approves or rejects:
1. Status updated in Firestore
2. `reviewedAt` timestamp set
3. For rejections: `rejectionReason` field populated

## Data Validation

### Required Fields (at submission)
- fullName
- email
- phoneNumber
- gender
- title
- yearsOfExperience
- credentials
- coachingPhilosophy
- profilePhoto

### Optional Fields
- instagramHandle
- linkedinProfile
- credentialsPdf
- nationality
- residenceLocation
- specializations

## Querying Patterns

### Get pending applications (for queue)
```dart
firestore
  .collection('coachApplications')
  .where('status', isEqualTo: 'pending')
  .orderBy('submittedAt', descending: true)
  .limit(200)
  .snapshots()
```

### Get single application
```dart
firestore
  .collection('coachApplications')
  .doc(applicationId)
  .get()
```

### Get approved applications (for admin records)
```dart
firestore
  .collection('coachApplications')
  .where('status', isEqualTo: 'approved')
  .orderBy('reviewedAt', descending: true)
  .snapshots()
```

## Retention Policy

- **Pending applications**: Kept until review (typically 7-30 days)
- **Approved applications**: Kept for reference
- **Rejected applications**: Kept for 90 days, then can be archived
- **Attachments**: Kept per application retention
