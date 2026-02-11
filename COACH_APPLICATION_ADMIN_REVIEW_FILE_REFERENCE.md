# Coach Application Admin Review - Complete File Reference

## New Files Created

### 1. Provider & Model Layer
**File:** `lib/features/admin_review/application/coach_application_providers.dart` (264 lines)

**Content:**
- `CoachApplicationReviewItem` - Data model for queue display
  - Fields: applicationId, fullName, email, gender, yearsOfExperience, profilePhotoUrl, submittedAt, status
  - Factory: `fromFirestore()` - Constructs from Firestore document
  
- `CoachApplicationDetail` - Full data model for detail screen
  - Fields: All application fields including personalizations, social media, attachments
  - Factory: `fromFirestore()` - Constructs from Firestore document
  
- `_asDate()` - Utility function to handle Firestore timestamp conversion

- **Providers:**
  - `pendingCoachApplicationsProvider` - StreamProvider<List<CoachApplicationReviewItem>>
    - Watches: coachApplications where status == 'pending'
    - Ordered by: submittedAt DESC
    - Limit: 200
    - Real-time updates via snapshots()
    
  - `coachApplicationDetailProvider` - FutureProvider<CoachApplicationDetail>
    - Loads full application details by applicationId
    - Used by detail screen
    
  - `updateCoachApplicationStatusProvider` - FutureProvider<void>
    - Updates application status (approve/reject)
    - Updates: status, reviewedAt, rejectionReason
    - Invalidates queue provider to trigger refresh

---

### 2. Coach Review Queue Screen
**File:** `lib/features/admin_review/presentation/screens/coach_review_queue_screen.dart` (82 lines)

**Content:**
- `CoachReviewQueueScreen` - Main queue display widget
  - Shows pending applications in real-time list
  - Empty state: "No pending applications" message
  - Error state: "Error loading applications" message
  - Loading state: CircularProgressIndicator
  
- `_CoachApplicationListTile` - Individual application item
  - Leading: CircleAvatar with profile photo or person icon
  - Title: Full name
  - Subtitle: "{yearsOfExperience} years exp. • {gender}"
  - Trailing: ChevronRight icon
  - onTap: Navigate to detail screen

**Navigation:**
- Uses Material Navigator (consistent with dating review system)
- Pushes CoachReviewDetailScreen with applicationId

---

### 3. Coach Review Detail Screen
**File:** `lib/features/admin_review/presentation/screens/coach_review_detail_screen.dart` (451 lines)

**Content:**
- `CoachReviewDetailScreen` - Full application detail view
  - StatefulWidget (handles approve/reject states)
  
- **Display Sections:**
  1. Profile Photo (large preview, 300px height)
  2. Personal Information (name, email, phone, gender)
  3. Professional Information (title, exp, location, status)
  4. Qualifications (credentials, specializations, philosophy)
  5. Social Media (Instagram, LinkedIn - clickable links)
  6. Attachments (Download credentials PDF button)
  7. Submission Info (timestamps, status)
  
- **Action Buttons:**
  - Approve: Updates status to "approved", shows success snackbar
  - Reject: Shows dialog for reason, updates status to "rejected"
  - Both buttons show loading state during operation
  
- **Helper Methods:**
  - `_buildSectionTitle()` - Styled section headers
  - `_buildInfoRow()` - Label/value pairs
  - `_buildExpandableText()` - Long text in boxes
  - `_buildLinkRow()` - Clickable links
  - `_buildAttachmentButton()` - Download buttons
  - `_formatDateTime()` - Timestamp formatting

---

### 4. Updated Admin Review Queue Screen (Tabbed)
**File:** `lib/features/admin_review/presentation/screens/admin_review_queue_screen.dart` (UPDATED - 106 lines)

**Changes Made:**
- Added `DefaultTabController` with 2 tabs
- Created `_DatingProfilesTab` widget for Tab 1
- Imported `coach_application_providers` and `CoachReviewQueueScreen`
- Tab 1: "Dating Profiles" - Shows existing dating profile reviews
- Tab 2: "Coach Applications" - Shows new coach application reviews

**New Imports:**
```dart
import '../../application/coach_application_providers.dart';
import 'coach_review_queue_screen.dart';
```

---

## Updated Files

### 5. Cloud Function Update
**File:** `firebase_functions/index.js` (Line 630-633)

**Change Made:**
```javascript
// OLD: Only set emailSentAt
await snapshot.ref.update({
  emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
});

// NEW: Also set status for admin review queue
await snapshot.ref.update({
  emailSentAt: admin.firestore.FieldValue.serverTimestamp(),
  status: 'pending', // NEW: Set status to pending for admin review queue
});
```

**Impact:**
- When email is sent, status field is set to 'pending'
- This makes application immediately appear in admin queue
- Critical for real-time queue functionality

---

## Unchanged Files (But Important)

### 6. Coach Application Form
**File:** `lib/features/subscription/presentation/screens/coach_application_screen.dart`
- Location: Subscription feature (unchanged)
- Purpose: 4-page application form
- Still works as before, submits to coachApplications collection

### 7. Coach Application Service
**File:** `lib/features/subscription/application/coach_application_service.dart`
- Location: Subscription feature (unchanged)
- Purpose: Handles form submission and Firestore writes
- Creates documents with correct schema for admin review

### 8. Book Marriage Coach Screen
**File:** `lib/features/subscription/presentation/screens/book_marriage_coach_screen.dart`
- Location: Subscription feature (unchanged)
- Purpose: "Call for Applications" recruitment card
- Navigates to coach application form

### 9. Dating Profile Review Detail Screen
**File:** `lib/features/admin_review/presentation/screens/admin_review_detail_screen.dart`
- Location: Admin review feature (unchanged)
- Purpose: Full review of dating profiles
- Now shown in Tab 1 of tabbed admin dashboard

### 10. Admin Review Providers (Dating)
**File:** `lib/features/admin_review/application/admin_review_providers.dart`
- Location: Admin review feature (unchanged)
- Purpose: Providers for dating profile reviews
- Still provides pendingReviewUsersProvider

---

## Documentation Files Created

### 11. Firestore Schema Documentation
**File:** `COACH_APPLICATION_ADMIN_REVIEW_SCHEMA.md`

**Sections:**
- Overview
- Collection structure
- Admin review fields
- Cloud Storage paths
- Firestore indexes (required composite index)
- Security rules
- Querying patterns
- Retention policy

### 12. Implementation Guide
**File:** `COACH_APPLICATION_ADMIN_REVIEW_IMPLEMENTATION.md`

**Sections:**
- Architecture overview
- File structure
- Key components (Firestore, Riverpod, UI)
- Data flow (submission → review → action)
- Cloud Function integration
- Providers list
- Screens overview
- Admin dashboard design
- Email notifications
- Testing checklist
- Troubleshooting
- Future enhancements

### 13. Integration Summary
**File:** `COACH_APPLICATION_INTEGRATION_COMPLETE.md`

**Sections:**
- What was done (7 items)
- File locations and status
- Architecture diagram
- Data flow
- Key features
- Testing procedures
- Cloud function verification
- Code quality checklist
- Dependencies
- Next steps
- Final verification
- Summary

### 14. Deployment Checklist
**File:** `COACH_APPLICATION_DEPLOYMENT_CHECKLIST.md`

**Sections:**
- Pre-deployment verification
- Testing steps (11 detailed procedures)
- Deployment steps
- Monitoring & verification
- Rollback plan
- Performance monitoring
- Security verification
- Success criteria
- Troubleshooting guide
- Sign-off section

---

## Directory Structure

### Before (Subscription Feature Only)
```
lib/features/subscription/
├── application/
│   └── coach_application_service.dart
└── presentation/screens/
    ├── coach_application_screen.dart
    └── book_marriage_coach_screen.dart
```

### After (Admin Review Integration)
```
lib/features/admin_review/
├── application/
│   ├── admin_review_providers.dart        (dating reviews - unchanged)
│   └── coach_application_providers.dart   (NEW - coach reviews)
│
└── presentation/screens/
    ├── admin_review_queue_screen.dart      (UPDATED - tabbed interface)
    ├── admin_review_detail_screen.dart     (dating - unchanged)
    ├── coach_review_queue_screen.dart      (NEW - coach queue)
    └── coach_review_detail_screen.dart     (NEW - coach detail)

lib/features/subscription/
├── application/
│   └── coach_application_service.dart     (form submission - unchanged)
└── presentation/screens/
    ├── coach_application_screen.dart      (application form - unchanged)
    └── book_marriage_coach_screen.dart    (recruitment card - unchanged)
```

---

## Code Statistics

### New Code
- `coach_application_providers.dart`: 264 lines
- `coach_review_queue_screen.dart`: 82 lines
- `coach_review_detail_screen.dart`: 451 lines
- **Total new code: 797 lines**

### Updated Code
- `admin_review_queue_screen.dart`: +95 lines (tabbed interface)
- `firebase_functions/index.js`: +1 line (status field)
- **Total changed: 96 lines**

### Documentation
- 4 new documentation files (~2000 lines total)

---

## Imports Summary

### New Provider File Imports
```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_v2/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';
```

### Queue Screen Imports
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/features/admin_review/application/coach_application_providers.dart';
import 'coach_review_detail_screen.dart';
```

### Detail Screen Imports
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:nexus_app_v2/features/admin_review/application/coach_application_providers.dart';
```

### Updated Admin Queue Screen Imports
```dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/user/is_admin_provider.dart';
import '../../application/admin_review_providers.dart';      // Existing
import '../../application/coach_application_providers.dart'; // NEW
import 'admin_review_detail_screen.dart';                   // Existing
import 'coach_review_queue_screen.dart';                    // NEW
```

---

## Key Features by File

### coach_application_providers.dart
✅ Real-time streaming provider for pending applications
✅ Two data models (queue + detail)
✅ Firestore conversion utilities
✅ Status update functionality
✅ Provider invalidation for refreshes

### coach_review_queue_screen.dart
✅ Real-time list display
✅ Empty state handling
✅ Error state handling
✅ Loading state
✅ Navigation to detail screen

### coach_review_detail_screen.dart
✅ Full application display
✅ Organized sections
✅ Clickable social media links
✅ Downloadable attachments
✅ Approve functionality
✅ Reject with reason functionality
✅ Async error handling
✅ Loading indicators

### admin_review_queue_screen.dart (Updated)
✅ Tabbed interface
✅ Dating profiles in Tab 1
✅ Coach applications in Tab 2
✅ Complete separation of concerns
✅ Maintains existing functionality

### firebase_functions/index.js (Updated)
✅ Sets status='pending' when email sent
✅ Enables admin queue to work
✅ Maintains existing email functionality

---

## Configuration References

### Required Firestore Index
```
Collection: coachApplications
Fields:
  - status (Ascending)
  - submittedAt (Descending)
```

### Required Cloud Storage Paths
```
coachApplications/{applicationId}/profilePhoto
coachApplications/{applicationId}/credentials.pdf
```

### Required Firestore Rules
```firestore
match /coachApplications/{document=**} {
  allow read: if request.auth.uid in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles;
  allow write: if request.auth.uid != null;
  allow delete: if request.auth.uid in get(/databases/$(database)/documents/users/$(request.auth.uid)).data.roles;
}
```

---

## Deployment Files

All files are ready to deploy:
- ✅ `lib/features/admin_review/application/coach_application_providers.dart`
- ✅ `lib/features/admin_review/presentation/screens/coach_review_queue_screen.dart`
- ✅ `lib/features/admin_review/presentation/screens/coach_review_detail_screen.dart`
- ✅ `lib/features/admin_review/presentation/screens/admin_review_queue_screen.dart` (updated)
- ✅ `firebase_functions/index.js` (updated)

## Next Steps

1. Review all files in the editor
2. Deploy Cloud Function update first
3. Run tests locally
4. Deploy app to production
5. Monitor logs and email delivery
6. Follow deployment checklist in detail

---

## File Locations for Quick Reference

```
NEW FILES:
- lib/features/admin_review/application/coach_application_providers.dart
- lib/features/admin_review/presentation/screens/coach_review_queue_screen.dart
- lib/features/admin_review/presentation/screens/coach_review_detail_screen.dart

UPDATED FILES:
- lib/features/admin_review/presentation/screens/admin_review_queue_screen.dart
- firebase_functions/index.js

DOCUMENTATION:
- COACH_APPLICATION_ADMIN_REVIEW_SCHEMA.md
- COACH_APPLICATION_ADMIN_REVIEW_IMPLEMENTATION.md
- COACH_APPLICATION_INTEGRATION_COMPLETE.md
- COACH_APPLICATION_DEPLOYMENT_CHECKLIST.md
- COACH_APPLICATION_ADMIN_REVIEW_FILE_REFERENCE.md (this file)
```
