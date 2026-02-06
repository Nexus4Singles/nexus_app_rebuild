# Firestore Data Restructure Plan

## Current Structure (Mixed)
```
users/{uid}/
├── appdata
├── assessments/  ← Mixed with user data
│   └── {assessmentId}/
├── journeyProgress/  ← In separate collection (not ideal)
│   └── {uid}/progress/{journeyId}/
├── chat
├── messages
├── dating  ← Separated correctly!
└── ...
```

## Proposed Structure (Organized Collections)

```
users/
└── {uid}/
    ├── assessments/     ✅ Assessment results & history (NEW)
    │   ├── singles_readiness/
    │   │   ├── (latest result document)
    │   │   └── history/
    │   │       ├── {timestamp1}/
    │   │       ├── {timestamp2}/
    │   │       └── ...
    │   ├── marriage_health_check/
    │   │   ├── (latest result document)
    │   │   └── history/
    │   │       └── ...
    │   └── remarriage_readiness/
    │       ├── (latest result document)
    │       └── history/
    │           └── ...
    │
    ├── journeys/        ✅ Journey progress (NEW - reorganized)
    │   ├── journey1/
    │   │   ├── completedSessionIdsList: []
    │   │   ├── currentStreak: int
    │   │   ├── lastSessionAt: timestamp
    │   │   └── responses/  (subcollection for session responses)
    │   ├── journey2/
    │   │   └── ...
    │   └── ...
    │
    ├── dating/          (Already separated - good pattern!)
    ├── appdata
    ├── chat
    ├── messages
    └── ... (other user data)
```

---

## Benefits of Reorganization

### ✅ **Logical Organization**
- Each major feature (assessments, journeys, dating) has its own namespace
- User data not muddled together
- Easier to understand data hierarchy
- Follows Firebase best practices

### ✅ **Better Security Rules**
```dart
// Before: Complex rules to check multiple locations
match /users/{uid}/{document=**} {
  allow read/write: if request.auth.uid == uid;
}

// After: Clear, specific rules per collection
match /users/{uid}/assessments/{assessmentId}/{allChildren=**} {
  allow read/write: if request.auth.uid == uid;
}

match /users/{uid}/journeys/{journeyId}/{allChildren=**} {
  allow read/write: if request.auth.uid == uid;
}
```

### ✅ **Scalability**
- Easier to add new features without polluting user document
- Each collection can have its own indexing strategy
- Independent backup/export per feature

### ✅ **Query Efficiency**
- Faster queries on specific collections
- Better index utilization
- Reduced document size per collection

---

## Migration Path

### Phase 1: Infrastructure Setup
1. ✅ Keep current paths working (existing data)
2. ✅ Update Firestore service methods to read/write from NEW locations
3. ✅ Implement dual-write pattern (write to both old and new for period)

### Phase 2: Service Updates
**File:** `lib/core/services/firestore_service.dart`

**Journey Progress:**
```dart
// Current: journeyProgress/{uid}/progress/{journeyId}
// New: users/{uid}/journeys/{journeyId}

// Update methods:
_journeyProgressRef(uid) {
  return _db!.collection('users').doc(uid).collection('journeys');
}
```

**Assessment Results:**
```dart
// Current: users/{uid}/assessments/{assessmentId}
// Already in correct location! Just verify structure:

_assessmentRef(uid, assessmentId) {
  return _db!.collection('users')
    .doc(uid)
    .collection('assessments')
    .doc(assessmentId);
}

_assessmentHistoryRef(uid, assessmentId) {
  return _assessmentRef(uid, assessmentId)
    .collection('history');
}
```

### Phase 3: Firestore Rules Update
```
match /users/{uid} {
  match /assessments/{assessmentId} {
    match /history/{historyId} {
      allow read, write: if request.auth.uid == uid;
    }
    allow read, write: if request.auth.uid == uid;
  }

  match /journeys/{journeyId} {
    match /responses/{responseId} {
      allow read, write: if request.auth.uid == uid;
    }
    allow read, write: if request.auth.uid == uid;
  }

  match /dating/{document=**} {
    allow read, write: if request.auth.uid == uid;
  }
}
```

### Phase 4: Data Migration (Optional)
- For production, consider Cloud Functions to migrate existing data
- Can be done gradually without user impact
- Keep fallback queries during transition period

---

## Implementation Tasks

### Backend Services
- [ ] Update `_journeyProgressRef()` in firestore_service.dart
- [ ] Update `_journeySessionResponsesRef()` in firestore_service.dart
- [ ] Verify assessment ref already points to correct location
- [ ] Add dual-write during transition (optional)

### Firestore Rules
- [ ] Update firestore.rules with new collection paths
- [ ] Test rules with new structure
- [ ] Deploy updated rules

### Code Updates
- [ ] Update any hardcoded path references
- [ ] Update tests if any reference paths directly
- [ ] Update documentation

### Data Migration (Optional but recommended)
- [ ] Create migration Cloud Function
- [ ] Test migration on staging
- [ ] Run migration on production
- [ ] Verify data integrity
- [ ] Remove old data after migration

---

## Backward Compatibility

During transition period:

```dart
// Read from NEW location first, fall back to OLD
Future<JourneyProgress?> getJourneyProgress(String uid, String journeyId) async {
  try {
    // Try new location first
    final newPath = _db!.collection('users')
      .doc(uid)
      .collection('journeys')
      .doc(journeyId);
    
    final snap = await newPath.get();
    if (snap.exists) return JourneyProgress.fromJson(snap.data()!);
  } catch (e) {
    print('Error reading from new location: $e');
  }

  // Fallback to old location
  final oldPath = _db!.collection('journeyProgress')
    .doc(uid)
    .collection('progress')
    .doc(journeyId);
  
  final snap = await oldPath.get();
  if (snap.exists) return JourneyProgress.fromJson(snap.data()!);
  
  return null;
}

// Write to BOTH locations during transition
Future<void> saveJourneyProgress(String uid, String journeyId, Map<String, dynamic> data) async {
  final batch = _db!.batch();

  // Write to new location
  batch.set(_db!.collection('users')
    .doc(uid)
    .collection('journeys')
    .doc(journeyId), data);

  // Write to old location (for now)
  batch.set(_db!.collection('journeyProgress')
    .doc(uid)
    .collection('progress')
    .doc(journeyId), data);

  await batch.commit();
}
```

---

## Timeline

- **Week 1-2:** Dual-write implementation + testing
- **Week 3:** Staged rollout (new installations use new paths)
- **Week 4:** Data migration for existing users
- **Week 5:** Sunset old paths after verification

---

## Files to Modify

1. **`lib/core/services/firestore_service.dart`**
   - Update `_journeyProgressRef()` method
   - Update journey progress methods
   - Keep assessment paths as-is (already correct)

2. **`firestore.rules`**
   - Add new collection rules
   - Update existing rules if needed

3. **`lib/core/models/journey_model.dart`** (if needed)
   - No changes expected, just verify

4. **Documentation**
   - Update `FIRESTORE_STRUCTURE_SUMMARY.md`
   - Update this file with status

---

## Status

- ✅ Hardcoded colors fixed in assessment screens
- ⏳ Firestore restructure plan documented
- ⏳ Ready to implement when approved
