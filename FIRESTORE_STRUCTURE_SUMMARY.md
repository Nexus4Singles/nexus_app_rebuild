# Firestore Data Structure & Integration Summary

## 🗂️ Journey Progress Storage

### Collection Path
```
journeyProgress/{uid}/progress/{journeyId}
```

### Structure
```
journeyProgress/
├── {uid1}/
│   └── progress/
│       ├── journey-1/
│       │   ├── visitorId: string
│       │   ├── visitorUid: string
│       │   ├── productId: string
│       │   ├── productName: string
│       │   ├── purchased: boolean
│       │   ├── purchasedAt: timestamp
│       │   ├── completedSessionCount: integer
│       │   ├── totalSessions: integer
│       │   ├── currentStreak: integer
│       │   ├── longestStreak: integer
│       │   ├── lastSessionAt: timestamp
│       │   ├── startedAt: timestamp
│       │   ├── isCompleted: boolean
│       │   ├── completedAt: timestamp
│       │   ├── earnedBadges: array
│       │   ├── completedSessionIdsList: array<string>  ✅ SYNCED BY JourneyProgressService
│       │   ├── metadata: object
│       │   ├── updatedAt: string
│       │   └── responses/ (subcollection)
│       │       └── {responseId}/
│       │           ├── sessionId: string
│       │           ├── stepId: string
│       │           ├── choices: object
│       │           ├── timestamp: timestamp
│       │           └── ...
│       └── journey-2/
│           └── ...
├── {uid2}/
│   └── progress/
│       └── ...
```

### Key Fields for Sync
- **`completedSessionIdsList`** (array) - List of completed mission/session IDs
- **`currentStreak`** (integer) - Current consecutive day streak
- **`lastSessionAt`** (timestamp) - When last session was completed
- **`updatedAt`** (string) - ISO8601 timestamp of last update

### Service Implementation
📄 **File:** [lib/core/services/journey_progress_service.dart](lib/core/services/journey_progress_service.dart)

**Key Methods:**
- `loadCompletedMissionIds(journeyId, uid)` - Loads from Firestore, falls back to SharedPreferences
- `markMissionCompleted(journeyId, missionId, uid)` - Updates locally, syncs to Firestore async
- `loadStreak(journeyId, uid)` - Loads from Firestore, falls back to SharedPreferences
- `resetMission(journeyId, missionId, uid)` - Removes mission, syncs to Firestore

**Sync Strategy:**
- Firestore-first: Always load from Firestore first (source of truth)
- Fallback: Use SharedPreferences cache if Firestore unavailable
- Non-blocking: Sync updates to Firestore asynchronously (fire-and-forget)

---

## 📋 Assessment Progress Storage

### Collection Path (v2 - Current)
```
users/{uid}/assessments/{assessmentId}  ← Latest result
users/{uid}/assessments/{assessmentId}/history/{historyId}  ← Historical results
```

### Collection Path (Legacy - Backward Compatible)
```
assessmentResults/{uid}_{timestamp}  ← For migration
```

### Structure
```
users/
├── {uid1}/
│   └── assessments/  ← Latest results per assessment
│       ├── singles-readiness/
│       │   ├── id: string
│       │   ├── userId: string
│       │   ├── assessmentId: string
│       │   ├── totalScore: integer
│       │   ├── maxScore: integer
│       │   ├── percentage: double (0.0-1.0)
│       │   ├── overallTier: object
│       │   │   ├── value: string (e.g., "LOW", "MEDIUM", "HIGH")
│       │   │   └── ...
│       │   ├── dimensionScores: object
│       │   ├── answers: array<object>
│       │   │   ├── questionNumber: integer
│       │   │   ├── dimension: string
│       │   │   ├── selectedOptionId: string
│       │   │   ├── signalTier: string
│       │   │   └── weight: integer
│       │   ├── completedAt: timestamp
│       │   ├── updatedAt: string (ISO8601)
│       │   └── history/ (subcollection)  ← All historical attempts
│       │       ├── {timestamp1}/
│       │       │   ├── ... (same structure as parent)
│       │       │   └── createdAt: string (ISO8601)
│       │       ├── {timestamp2}/
│       │       │   └── ...
│       │       └── ...
│       ├── marriage-health-check/
│       │   └── ...
│       └── remarriage-readiness/
│           └── ...
├── {uid2}/
│   └── assessments/
│       └── ...
```

### Key Fields
- **`assessmentId`** (string) - Identifier of the assessment type
- **`totalScore`** (integer) - Score achieved
- **`percentage`** (double) - 0.0 to 1.0 score
- **`overallTier`** (object) - Result tier (LOW/MEDIUM/HIGH/etc)
- **`answers`** (array) - All user responses
- **`updatedAt`** (string) - ISO8601 timestamp
- **`history/`** (subcollection) - Historical results archived here

### Service Implementation
📄 **File:** [lib/core/services/firestore_service.dart](lib/core/services/firestore_service.dart)

**Key Methods (firestore_service.dart):**
- `saveAssessmentResult(uid, result)` - Saves to latest + history + legacy
- `getLatestAssessmentResult(uid, assessmentId)` - Gets latest result
- `getAllAssessmentResults(uid)` - Gets all latest assessments
- `watchAssessmentResults(uid)` - Streams all latest assessments

**Storage Pattern:**
1. ✅ Save to `users/{uid}/assessments/{assessmentId}` (latest)
2. ✅ Save to `users/{uid}/assessments/{assessmentId}/history/{timestamp}` (historical)
3. ✅ Save to `assessmentResults/{uid}_{timestamp}` (legacy, for backward compatibility)

**Read Pattern:**
1. First check new v2 storage path
2. Fallback to legacy storage if needed
3. Stream watches use v2 storage

---

## 🔄 Similar Implementation for Assessments

### Current State
✅ **Assessments ALREADY sync to Firestore!**

The assessment system already follows a similar pattern:
- **Sync On Submit:** When user completes assessment, `submitAssessment()` calls `saveAssessmentResult()`
- **Firestore-First Read:** `getLatestAssessmentResult()` loads from Firestore first
- **Automatic History:** All submissions automatically saved to `history/` subcollection
- **Real-time Streaming:** `watchAssessmentResults()` provides live updates

### Differences vs Journey Progress

| Aspect | Journey Progress | Assessment |
|--------|------------------|------------|
| **Local Storage** | SharedPreferences (cache) | N/A (only Firestore) |
| **Sync Timing** | On each session completion (async, non-blocking) | On assessment submission (immediate) |
| **Granularity** | Per-mission updates | Per-assessment submission |
| **History** | Not tracked (only latest state) | Full history in subcollection |
| **Source of Truth** | Firestore | Firestore |
| **Offline Support** | SharedPreferences as fallback | None (online-only) |

---

## 📊 Proposed Assessment Progress Service

If you want **explicit offline support for assessments** similar to Journey Progress, here's the pattern:

### Structure
```
assessmentProgress/
├── {uid1}/
│   └── progress/
│       ├── singles-readiness/
│       │   ├── inProgress: boolean
│       │   ├── questionsAnswered: integer
│       │   ├── totalQuestions: integer
│       │   ├── currentAnswers: object<int, AssessmentAnswer>
│       │   ├── lastSavedAt: string (ISO8601)
│       │   └── ...
│       └── ...
```

### Benefits
- Resume incomplete assessments
- Sync draft answers to Firestore
- Multi-device assessment continuity
- Offline draft support

### Implementation (Similar to JourneyProgressService)
```dart
class AssessmentProgressService {
  final FirestoreService _firestore;

  Future<Map<String, dynamic>?> loadDraftAssessment(
    String assessmentId, 
    String uid
  ) async {
    // Try Firestore first
    // Fallback to SharedPreferences
  }

  Future<void> saveDraftAnswers(
    String assessmentId,
    Map<int, AssessmentAnswer> answers,
    String uid
  ) async {
    // Save locally immediately
    // Sync to Firestore async (non-blocking)
  }

  Future<void> clearDraft(String assessmentId, String uid) async {
    // Remove draft
  }
}
```

---

## 🚀 Next Steps

### ✅ Already Implemented
- [x] Journey progress synced to Firestore
- [x] Assessment results synced to Firestore
- [x] Both have historical tracking
- [x] Both have real-time streaming

### ⏳ Optional Enhancements
- [ ] Add offline draft support for assessments
- [ ] Add assessment progress tracking (for in-progress saves)
- [ ] Implement cross-device assessment resume
- [ ] Add assessment draft analytics

---

## 📋 Firestore Rules Considerations

### Journey Progress Access
```
allow read: if request.auth.uid == resource.data.visitorUid;
allow write: if request.auth.uid == resource.data.visitorUid;
```

### Assessment Access
```
allow read: if request.auth.uid == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.id;
allow write: if request.auth.uid == get(/databases/$(database)/documents/users/$(request.auth.uid)).data.id;
```

---

## 🔗 Related Files

- **Journey Progress Service:** [lib/core/services/journey_progress_service.dart](lib/core/services/journey_progress_service.dart)
- **Assessment Provider:** [lib/core/providers/assessment_provider.dart](lib/core/providers/assessment_provider.dart)
- **Firestore Service:** [lib/core/services/firestore_service.dart](lib/core/services/firestore_service.dart)
- **Journey Providers:** [lib/features/challenges/providers/journeys_providers.dart](lib/features/challenges/providers/journeys_providers.dart)
