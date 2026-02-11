# Coach Application Form - Firestore Schema

## Collection Path
```
coachApplications/{applicationId}
```

## Document Structure

```
coachApplications/
├── {applicationId}/
│   ├── applicationId: string (auto-generated)
│   ├── applicantUid: string (user making application, if logged in)
│   ├── status: string (pending, approved, rejected)
│   ├── submittedAt: timestamp
│   ├── reviewedAt: timestamp (nullable)
│   ├── reviewedBy: string (admin uid who reviewed, nullable)
│   │
│   ├── // Personal Information
│   ├── fullName: string
│   ├── email: string (required, for contact)
│   ├── phoneNumber: string
│   ├── gender: string (enum: Male, Female, Other)
│   │
│   ├── // Location
│   ├── nationality: string
│   ├── residenceLocation: string (City, Country)
│   │
│   ├── // Professional Background
│   ├── title: string (enum: Dr., Mr., Mrs., Ms., Prof.)
│   ├── yearsOfExperience: integer
│   ├── maritalStatus: string (enum: Single, Married, Divorced, Widowed, Separated)
│   │
│   ├── // Qualifications
│   ├── credentials: string (free text - certifications, degrees, licenses)
│   ├── specializations: array<string> (counseling areas they focus on)
│   ├── coachingPhilosophy: string (textarea - their approach to coaching)
│   │
│   ├── // Media Attachments
│   ├── profilePhoto: object
│   │   ├── url: string (Firebase Storage URL)
│   │   ├── filename: string
│   │   └── uploadedAt: timestamp
│   ├── credentials: object (optional)
│   │   ├── url: string (Firebase Storage URL - PDF)
│   │   ├── filename: string
│   │   └── uploadedAt: timestamp
│   │
│   ├── // Social Media (optional)
│   ├── instagramHandle: string
│   ├── linkedinProfile: string
│   │
│   ├── // Metadata
│   ├── ipAddress: string
│   ├── userAgent: string
│   ├── submissionNotes: string (internal admin notes)
│   └── tags: array<string> (for filtering: "verified", "priority", etc.)
```

## Storage Paths for Attachments

```
gs://nexus4singles.appspot.com/coachApplications/
└── {applicationId}/
    ├── profilePhoto.{ext}
    └── credentials.pdf
```

## Indexes Required

For efficient querying, create composite indexes on:
- `status` + `submittedAt` (for admin dashboard)
- `email` (for uniqueness checking)
- `maritalStatus` + `status` (for filtering married coach applicants)

## Email Workflow

When an application is submitted:
1. Document created in Firestore with `status: "pending"`
2. Cloud Function triggered on write
3. Cloud Function:
   - Retrieves all document data
   - Downloads attachments from Storage
   - Sends email to `contact@nexus4singles.com` with:
     - All form data as structured email body
     - Profile photo as inline attachment
     - Credentials PDF as email attachment
   - Optionally updates doc with `emailSentAt: timestamp`

## Privacy & Security

- PII (names, emails, phone numbers) encrypted in transit (HTTPS)
- Firestore security rules restrict access to:
  - Users can read/write own applications only
  - Admin dashboard has full access (authenticated admins only)
- Storage files have time-limited signed URLs (1-week expiry)
- Sensitive fields (IP address) logged but not exposed to frontend

## Data Retention

- Pending applications: Retained for 6 months
- Approved applications: Retained indefinitely
- Rejected applications: Retained for 3 months, then deleted
- Automatic cleanup via Cloud Tasks or scheduled Cloud Function
