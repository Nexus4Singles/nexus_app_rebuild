# Firebase Setup Guide for Nexus App

## Overview

Nexus uses Firebase for:
- **Authentication**: Email/password, Google Sign-In
- **Firestore**: User profiles, chats, messages, stories, polls
- **Storage**: Profile photos, audio recordings
- **Cloud Functions**: (optional) For notifications, aggregations

---

## Step 1: Create Firebase Project

1. Go to [Firebase Console](https://console.firebase.google.com)
2. Click "Add Project"
3. Name it `nexus-app` (or your preferred name)
4. Enable Google Analytics (optional)
5. Click "Create Project"

---

## Step 2: Add Apps to Firebase

### iOS App
1. Click "Add app" → iOS
2. Bundle ID: `com.nexus.app` (must match your Xcode project)
3. Download `GoogleService-Info.plist`
4. Place in `ios/Runner/GoogleService-Info.plist`

### Android App
1. Click "Add app" → Android
2. Package name: `com.nexus.app` (must match `android/app/build.gradle`)
3. Download `google-services.json`
4. Place in `android/app/google-services.json`

---

## Step 3: Enable Authentication

1. Go to **Authentication** → **Sign-in method**
2. Enable:
   - Email/Password
   - Google (configure OAuth consent screen)

---

## Step 4: Set Up Firestore

### Create Database
1. Go to **Firestore Database**
2. Click "Create database"
3. Choose **production mode** (we'll add rules)
4. Select your preferred location (e.g., `us-central1`)

### Deploy Security Rules
```bash
# Install Firebase CLI if not already installed
npm install -g firebase-tools

# Login to Firebase
firebase login

# Initialize Firebase in project directory
cd nexus_app
firebase init firestore

# Deploy rules
firebase deploy --only firestore:rules
```

Or manually copy the rules from `firestore.rules` into the Firebase Console.

### Deploy Indexes (IMPORTANT!)
```bash
# Deploy indexes
firebase deploy --only firestore:indexes
```

Or create them manually in Firebase Console → Firestore → Indexes:

#### Required Composite Indexes

| Collection | Fields | Order |
|------------|--------|-------|
| `users` | `gender` (ASC) + `profileCompletionDate` (DESC) | Composite |
| `users` | `gender` (ASC) + `age` (ASC) | Composite |
| `chats` | `participantIds` (ARRAY_CONTAINS) + `lastMessageAt` (DESC) | Composite |
| `messages` | `chatId` (ASC) + `sentAt` (DESC) | Composite |

**To create manually:**
1. Go to Firestore → Indexes
2. Click "Create Index"
3. Select Collection ID: `users`
4. Add fields:
   - `gender` - Ascending
   - `profileCompletionDate` - Descending
5. Query scope: Collection
6. Click "Create Index"
7. Wait for index to build (can take a few minutes)

Repeat for other indexes.

---

## Step 5: Set Up Firebase Storage

1. Go to **Storage**
2. Click "Get Started"
3. Choose your security rules:

```javascript
rules_version = '2';
service firebase.storage {
  match /b/{bucket}/o {
    // User profile photos and audio
    match /users/{userId}/{allPaths=**} {
      // Anyone can read profile photos
      allow read: if request.auth != null;
      // Only owner can write
      allow write: if request.auth != null && request.auth.uid == userId;
    }
    
    // Chat media (images, audio messages)
    match /chats/{chatId}/{allPaths=**} {
      // Authenticated users can read/write chat media
      // More restrictive rules can check chat membership
      allow read, write: if request.auth != null;
    }
  }
}
```

---

## Step 6: Configure Flutter App

### Install FlutterFire CLI
```bash
dart pub global activate flutterfire_cli
```

### Configure Firebase
```bash
cd nexus_app
flutterfire configure
```

This will:
- Generate `lib/firebase_options.dart`
- Update platform-specific files automatically

### Verify Configuration
Your `lib/main.dart` should have:
```dart
import 'package:firebase_core/firebase_core.dart';
import 'firebase_options.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const NexusApp());
}
```

---

## Step 7: Verify Indexes Are Working

After deploying indexes, test the search:

1. Run the app
2. Complete profile setup (make sure `profileCompletionDate` is set)
3. Go to Search/Discover
4. Search should return results sorted by newest first

**If you see this error:**
```
The query requires an index. You can create it here: https://...
```

Click the link to create the missing index automatically.

---

## Firestore Data Structure

```
firestore/
├── users/
│   └── {userId}/
│       ├── name, email, age, gender, ...
│       ├── profileUrl, photos[], ...
│       ├── profileCompletionDate (Timestamp) ← IMPORTANT for sorting
│       ├── compatibility: {...}
│       └── nexus2: {...}
│
├── chats/
│   └── {chatId}/
│       ├── participantIds: [uid1, uid2]
│       ├── lastMessage, lastMessageAt
│       ├── unreadCounts: {uid1: 0, uid2: 2}
│       └── messages/
│           └── {messageId}/
│               ├── senderId, receiverId
│               ├── content, type
│               └── sentAt, readAt
│
├── stories/
│   └── {storyId}/
│       └── ... (loaded from JSON config)
│
├── polls/
│   └── {pollId}/
│       └── ... (loaded from JSON config)
│
├── pollVotes/
│   └── {pollId}/
│       └── votes/
│           └── {oderId}/
│               ├── selectedOptionId
│               └── votedAt
│
└── pollAggregates/
    └── {pollId}/
        ├── totalVotes
        └── optionCounts: {option1: 10, option2: 15}
```

---

## Gender Filtering (Dating Feature)

Nexus 1.0 compatibility:
- Male users only see Female profiles
- Female users only see Male profiles

This is enforced in `SearchService`:
```dart
if (currentUserGender != null && currentUserGender.isNotEmpty) {
  final targetGender = currentUserGender.toLowerCase() == 'male' ? 'Female' : 'Male';
  query = query.where('gender', isEqualTo: targetGender);
}
```

**Make sure:**
1. User's gender is saved during profile setup
2. Gender values are consistent: `Male` or `Female` (capitalized)
3. The composite index `gender + profileCompletionDate` is created

---

## Troubleshooting

### "Missing or insufficient permissions"
- Check Firestore security rules
- Verify user is authenticated
- Check if user ID matches document path

### "The query requires an index"
- Click the link in the error to create the index
- Or deploy indexes: `firebase deploy --only firestore:indexes`

### Search returns no results
- Check if users have `gender` field set
- Check if users have `profileCompletionDate` set
- Verify opposite gender users exist in database

### Slow queries
- Ensure indexes are created and built
- Check index status in Firebase Console → Firestore → Indexes

---

## Quick Commands

```bash
# Deploy everything
firebase deploy

# Deploy only rules
firebase deploy --only firestore:rules

# Deploy only indexes
firebase deploy --only firestore:indexes

# Deploy only storage rules
firebase deploy --only storage

# View deployed rules
firebase firestore:rules:get

# Check index status
firebase firestore:indexes
```
