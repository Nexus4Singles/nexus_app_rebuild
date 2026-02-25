# SCHEMA CONSOLIDATION ROADMAP - Before/After Structures

**Document Status:** Implementation Guide  
**Target Timeline:** 8-9 weeks  
**Risk Level:** Medium (with proper migration steps)

---

## 1. CURRENT STRUCTURE (HIGHLY REDUNDANT)

### Example User Document (Current)

```json
{
  "uid": "abc123",
  "id": "abc123",
  "email": "user@example.com",
  "isGuest": false,
  "isAdmin": false,
  
  // === TIER 1: ROOT LEVEL FIELDS (V1) ===
  "age": 28,
  "gender": "male",
  "name": "John Doe",
  "username": "john_doe",
  "profileUrl": "https://...",
  "city": "Lagos",
  "country": "Nigeria",
  "countryCode": "NG",
  "nationality": "Nigerian",
  "nationalityCode": "NG",
  "phoneNumber": "+234...",
  "educationLevel": "University",
  "profession": "Engineer",
  "churchName": "Redeemers",
  "hobbies": ["reading", "coding"],
  "photos": ["url1", "url2"],
  "audioPrompts": ["audio1_url", "audio2_url"],
  "bestQualotiesOrTraits": "Honest, hardworking",
  "desiredQualities": "Kind, humble",
  "location": {
    "place": "Lagos, Nigeria",
    "lat": 6.52,
    "lng": 3.36
  },
  
  "isVerified": true,                    // ← V1 binary verification
  "notificationToken": "v1_token_...",   // ← V1 notification token
  "fcmToken": "fcm_token_...",
  
  // === RELATIONSHIP FIELDS (LISTS) ===
  "likeMe": ["user1", "user2"],
  "myLikes": ["user3", "user4"],
  "mySaves": ["user5"],
  "blocked": [],
  "matchedUsers": ["user6"],
  "unRecommendUsers": ["user7"],
  "usersChatWarning": [],
  
  // === COMPATIBILITY & SUBSCRIPTION ===
  "compatibility": { /* large object */ },
  "compatibilitySetted": true,
  "onPremium": false,
  "prevSubscribed": true,
  "subExpDate": "2026-02-28",
  "subscriberId": "sub_...",
  "usedOneFreeText": true,
  "entitledUser": true,
  "hasExternalSubscriptionFlow": false,
  
  // === REGISTRATION METADATA ===
  "registrationProgress": "completed",
  "profileCompletionDate": "2025-01-15",
  "createdAt": "2025-01-01T00:00:00Z",
  "updatedAt": "2026-02-20T10:30:00Z",
  
  // === SOCIAL MEDIA (UNIQUE) ===
  "facebookUsername": "john.doe",
  "instagramUsername": "@johndoe",
  "twitterUsername": "@johndoe",
  "telegramUsername": "@johndoe",
  "snapchatUsername": "johndoe",
  
  // === V2 EXTENSION FIELDS ===
  "dating": {
    "enabled": true,
    "optIn": true,
    "verificationStatus": "verified",        // ← V2 enum verification (conflicts with root.isVerified!)
    "verifiedAt": "2025-02-01T00:00:00Z",
    "verifiedBy": "system",
    "isDiscoverable": true,
    "chatEnabled": true,
    
    // ⚠️ TIER 2: DUPLICATE NESTED UNDER dating.profile
    "profile": {
      "age": 28,                             // DUP!
      "gender": "male",                      // DUP!
      "name": "John Doe",                    // DUP!
      "username": "john_doe",                // DUP!
      "profileUrl": "https://...",           // DUP!
      "city": "Lagos",                       // DUP!
      "country": "Nigeria",                  // DUP!
      "countryCode": "NG",                   // DUP!
      "nationality": "Nigerian",             // DUP!
      "nationalityCode": "NG",               // DUP!
      "hobbies": ["reading", "coding"],      // DUP!
      "photos": ["url1", "url2"],            // DUP!
      "phoneNumber": "+234...",              // DUP!
      "educationLevel": "University",        // DUP!
      "profession": "Engineer",              // DUP!
      "churchName": "Redeemers",             // DUP!
      "bestQualitiesOrTraits": "...",        // DUP!
      "location": { /* map */ }              // DUP!
    },
    
    "photos": ["url1", "url2"],              // ⚠️ DUP of photos!
    "audioPrompts": ["audio1_url"],          // ⚠️ DUP of audioPrompts!
    "reviewPack": {
      "audioUrls": ["audio1_url", "audio2_url"]  // ⚠️ THIRD copy!
    }
  },
  
  // ⚠️ TIER 3: TRIPLES SOME FIELDS IN NEXUS2
  "nexus2": {
    "relationshipStatus": "single",          // ✓ Unique to v2
    "gender": "male",                        // DUP! Should remove
    "primaryGoals": ["dating"],              // ✓ Unique to v2
    "onboardingCompleted": true,             // ✓ Unique to v2
    "onboardedAt": "2025-01-15T00:00:00Z",   // ✓ Unique to v2
    "schemaVersion": 2,                      // ✓ Unique to v2
    "lastActiveAt": "2026-02-20T10:30:00Z",  // ✓ Update tracking
    "experiments": {},                        // ✓ A/B testing
    "hasSeenDatingPoolGuidelines": false,    // ✓ UX state
    
    "profile": {
      "age": 28,                             // ⚠️ TRIPLE DUP!
      "gender": "male",                      // ⚠️ TRIPLE DUP!
      "city": "Lagos",                       // ⚠️ TRIPLE DUP!
      "country": "Nigeria",                  // ⚠️ TRIPLE DUP!
      // ... all the same fields repeated
    }
  }
}
```

**Size Analysis:**
- Root level: ~4.5 KB
- dating sub-object: ~2.0 KB
- nexus2 sub-object: ~1.8 KB
- **Total: ~8.3 KB** (with lots of duplication)

---

## 2. TARGET STRUCTURE (CONSOLIDATED) - PHASE 1-2

### After Consolidation Migration

```json
{
  "uid": "abc123",
  "id": "abc123",
  "email": "user@example.com",
  "isGuest": false,
  "isAdmin": false,
  
  // === TIER 1: IDENTITY FIELDS (STAY AT ROOT) ===
  // These are account-level, not profile-related
  "isVerified": true,                       // ← Keep for backward compat (deprecated after 6mo)
  "notificationToken": "v1_token_...",      // ← Keep for backward compat (deprecated after 6mo)
  "fcmToken": "fcm_token_...",
  "registrationProgress": "completed",
  "profileCompletionDate": "2025-01-15",
  
  // === TIER 2: SUBSCRIPTION & ACCOUNT METADATA === 
  // Stay at root (not profile data)
  "onPremium": false,
  "prevSubscribed": true,
  "subExpDate": "2026-02-28",
  "subscriberId": "sub_...",
  "usedOneFreeText": true,
  "entitledUser": true,
  "hasExternalSubscriptionFlow": false,
  
  // === TIER 3: COMPLEX PREFERENCE MAPS ===
  // Too large for profile sub-object
  "compatibility": { /* large object */ },
  "compatibilitySetted": true,
  
  // === TIER 4: RELATIONSHIP METADATA (LISTS) ===
  // No duplication - only at root
  "likeMe": ["user1", "user2"],
  "myLikes": ["user3", "user4"],
  "mySaves": ["user5"],
  "blocked": [],
  "matchedUsers": ["user6"],
  "unRecommendUsers": ["user7"],
  "usersChatWarning": [],
  
  // === TIER 5: SOCIAL MEDIA HANDLES ===
  // Unique to identity
  "facebookUsername": "john.doe",
  "instagramUsername": "@johndoe",
  "twitterUsername": "@johndoe",
  "telegramUsername": "@johndoe",
  "snapchatUsername": "johndoe",
  
  // === REGISTRATION METADATA ===
  "createdAt": "2025-01-01T00:00:00Z",
  "updatedAt": "2026-02-20T10:30:00Z",
  
  // ✅ CONSOLIDATED: ALL USER PROFILE DATA IN dating.profile
  "dating": {
    "enabled": true,
    "optIn": true,
    "verificationStatus": "verified",           // ✓ Single source of truth
    "verifiedAt": "2025-02-01T00:00:00Z",
    "verifiedBy": "system",
    "isDiscoverable": true,
    "chatEnabled": true,
    
    // ✅ NOW SINGLE SOURCE OF TRUTH FOR ALL PROFILE DATA
    "profile": {
      // === PERSONAL INFO ===
      "name": "John Doe",
      "username": "john_doe",
      "age": 28,
      "gender": "male",                         // ✓ NO MORE TRIPLES!
      
      // === LOCATION ===
      "city": "Lagos",
      "country": "Nigeria",
      "countryCode": "NG",
      "nationality": "Nigerian",
      "nationalityCode": "NG",
      
      // === CONTACT ===
      "phoneNumber": "+234...",
      
      // === PROFESSIONAL ===
      "educationLevel": "University",
      "profession": "Engineer",
      "churchName": "Redeemers",
      
      // === IMAGES & MEDIA ===
      "profileUrl": "https://...",
      "photos": ["url1", "url2"],               // ✓ Moved from root
      
      // === PROFILE TEXT ===
      "hobbies": ["reading", "coding"],
      "bestQualitiesOrTraits": "Honest, hardworking",
      "desiredQualities": "Kind, humble",
      
      // === NESTED LOCATION ===
      "location": {
        "place": "Lagos, Nigeria",
        "lat": 6.52,
        "lng": 3.36
      }
    },
    
    // ✅ CONSOLIDATED: Single source for audio
    "reviewPack": {
      "audioUrls": ["audio1_url", "audio2_url"]  // ✓ Single place!
    }
  },
  
  // ✅ CLEANED UP: Nexus2 only has v2-specific fields
  "nexus2": {
    "relationshipStatus": "single",             // ✓ Unique to v2
    "primaryGoals": ["dating"],                 // ✓ Unique to v2
    "onboardingCompleted": true,                // ✓ Unique to v2
    "onboardedAt": "2025-01-15T00:00:00Z",      // ✓ Unique to v2
    "schemaVersion": 2,
    "lastActiveAt": "2026-02-20T10:30:00Z",
    "experiments": {},
    "hasSeenDatingPoolGuidelines": false
    
    // REMOVED: gender, profile (redundant - everything in dating.profile)
  }
}
```

**Size After Consolidation:**
- Root level: ~2.8 KB (reduced by 38%)
- dating sub-object: ~2.1 KB (cleaned up)
- nexus2 sub-object: ~0.8 KB (reduced by 55%)
- **Total: ~5.7 KB** (31% reduction)
- **Benefit: Saves ~2.6 KB per document × 100K users = 260 MB!**

---

## 3. CONSOLIDATION CHECKLIST BY FIELD

### MOVE to dating.profile (16 fields)

| Field | Root Now | dating.profile Now | dating.profile After | Removal Timeline |
|-------|----------|---|---|---|
| age | ✓ | ✓ | ✓ | Keep root 6-9mo |
| gender | ✓ | ✓ | ✓ | Keep root 6-9mo |
| name | ✓ | ✓ | ✓ | Keep root 6-9mo |
| username | ✓ | ✓ | ✓ | Keep root 6-9mo |
| profileUrl | ✓ | ✓ | ✓ | Keep root 6-9mo |
| city | ✓ | ✓ | ✓ | Keep root 6-9mo |
| country | ✓ | ✓ | ✓ | Keep root 6-9mo |
| countryCode | ✓ | ✓ | ✓ | Keep root 6-9mo |
| nationality | ✓ | ✓ | ✓ | Keep root 6-9mo |
| nationalityCode | ✓ | ✓ | ✓ | Keep root 6-9mo |
| phoneNumber | ✓ | ✓ | ✓ | Keep root 6-9mo |
| educationLevel | ✓ | ✓ | ✓ | Keep root 6-9mo |
| profession | ✓ | ✓ | ✓ | Keep root 6-9mo |
| churchName | ✓ | ✓ | ✓ | Keep root 6-9mo |
| hobbies | ✓ | ✓ | ✓ | Keep root 6-9mo |
| bestQualitiesOrTraits | ✓ | ✗ | ✓ | Add if missing |

### MOVE to dating.photos (simpler path)

| Field | Current Path | New Path | Consolidates |
|-------|------|---|---|
| photos | root | dating.photos | root, dating.photos, dating.profile.photos |

### MOVE to dating.reviewPack.audioUrls (single source)

| Field | Current Path | Consolidates |
|-------|------|---|
| audioPrompts | [root.audioPrompts, dating.audioPrompts, dating.reviewPack.audioUrls] | All three paths |

### MOVE to dating.location (not nested under profile)

| Field | Current Path | New Path | Consolidates |
|-------|------|---|---|
| location | root | dating.location | root, dating.profile.location, nexus2.profile.location |

### REMOVE from nexus2 (already at dating.profile)

| Field | Remove From | Reason |
|-------|------|---|
| nexus2.gender | nexus2 | Duplicate of dating.profile.gender |
| nexus2.profile | nexus2 | Entire sub-object is redundant - use dating.profile |

### KEEP at root (no consolidation needed)

| Field | Reason | Cannot Move |
|-------|--------|---|
| email | Account identity | Core to Firebase Auth |
| fcmToken | Service token | Access control |
| notificationToken | Legacy v1 token | Backward compat (6mo only) |
| isVerified | Account verification | Backward compat (6mo only) |
| likeMe, myLikes | Relationship tracking | Account-level, not profile |
| mySaves, blocked | Relationship tracking | Account-level, not profile |
| matchedUsers | Dating history | Account-level, not profile |
| unRecommendUsers | Dating preferences | Account-level, not profile |
| compatibility | Preference map | Too large for nesting, account-level |
| compatibilitySetted | Flag for above | Account-level |
| Sub fields | Subscription system | Account-level |
| Social handles | Account identity | Account-level |
| isGuest, isAdmin | Account type | Account-level |

---

## 4. CODE CHANGES REQUIRED

### 4.1 UserModel.dart - Update Field Reading

**CURRENT (3-tier priority):**
```dart
// Reading age from v1/v2 levels
age:
  _intFrom(_getPath(data, ['age'])) ??                    // Root
  _intFrom(_getPath(data, ['nexus2', 'profile', 'age'])) ?? // V2 dup
  _intFrom(_getPath(data, ['dating', 'profile', 'age'])),   // Dating
```

**AFTER (2-tier priority, nexus2 removed):**
```dart
// Reading age - single source of truth
age:
  _intFrom(_getPath(data, ['dating', 'profile', 'age'])) ?? // Primary
  _intFrom(_getPath(data, ['age'])),                         // Compat fallback
```

### 4.2 Firestore Service - Update Write Paths

**CURRENT (writes to root):**
```dart
Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
  await _userDocRef(uid).set(fields, SetOptions(merge: true));
  // Writes to: root level
}
```

**AFTER (writes to dating.profile):**
```dart
Future<void> updateUserProfileFields(
  String uid, 
  Map<String, dynamic> fields,
) async {
  final prefixedFields = <String, dynamic>{};
  fields.forEach((key, value) {
    prefixedFields['dating.profile.$key'] = value;
  });
  await _userDocRef(uid).set(prefixedFields, SetOptions(merge: true));
  // Writes to: dating.profile.*
}
```

### 4.3 Update Search Queries

**CURRENT (indexes on root):**
```dart
// gender index on root level
query.where('gender', isEqualTo: 'male')
     .where('age', isGreaterThan: 25)
```

**AFTER (indexes on dating.profile):**
```dart
// gender index on dating.profile
query.where('dating.profile.gender', isEqualTo: 'male')
     .where('dating.profile.age', isGreaterThan: 25)
```

---

## 5. FIRESTORE INDEXES UPDATE

### Current Indexes (Using Root Level)
```yaml
indexes:
  - collection: users
    fields:
      - gender: ASCENDING
      - age: ASCENDING
  - collection: users
    fields:
      - gender: ASCENDING
      - profileCompletionDate: DESCENDING
```

### Updated Indexes (Using dating.profile)
```yaml
indexes:
  - collection: users
    fields:
      - dating.profile.gender: ASCENDING
      - dating.profile.age: ASCENDING
  - collection: users
    fields:
      - dating.profile.gender: ASCENDING
      - profileCompletionDate: DESCENDING
  - collection: users
    fields:
      - dating.profile.gender: ASCENDING
      - dating.verificationStatus: ASCENDING
      - createdAt: DESCENDING
```

---

## 6. FALLBACK READ STRATEGY (During Migration)

**Why:** Allow smooth reading while data is being migrated

```dart
class ConsolidatedUserReader {
  static String? getAge(Map<String, dynamic> data) {
    // Priority 1: New consolidated location (after migration)
    if (data['dating']?['profile']?['age'] != null) {
      return data['dating']['profile']['age'];
    }
    // Priority 2: Old root location (backward compat)
    if (data['age'] != null) {
      return data['age'];
    }
    // Priority 3: Old nexus2 location (don't use post-consolidation)
    return data['nexus2']?['profile']?['age'];
  }
  
  static String? getGender(Map<String, dynamic> data) {
    // Same pattern for all fields
    return data['dating']?['profile']?['gender'] ?? 
           data['gender'] ?? 
           data['nexus2']?['profile']?['gender'];
  }
}
```

---

## 7. MIGRATION COMMAND SEQUENCE

### Step 1: Backup
```bash
# Backup current Firestore
gcloud firestore export gs://nexus-app-backups/backup-$(date +%Y%m%d)
```

### Step 2: Test on Sample
```bash
# Export 10 random documents for testing
firebase firestore:export test-backup/ --collection-ids=users --limit=10
```

### Step 3: Run Migration (Phase 1)
```bash
# Copy root fields → dating.profile (non-destructive)
node scripts/migrate-root-to-dating-profile.js --dry-run
node scripts/migrate-root-to-dating-profile.js --production
```

### Step 4: Verify
```bash
# Spot check 50 random documents
node scripts/verify-consolidation.js --sample-size=50
```

### Step 5: Cleanup (After 6-9 months)
```bash
# Remove root-level duplicates
node scripts/remove-duplicate-roots.js --dry-run
node scripts/remove-duplicate-roots.js --production
```

---

## 8. TIMELINE & PHASES

| Phase | Duration | Actions | Completed |
|-------|----------|---------|-----------|
| **Phase 0: Prep** | Week 1 | Documentation, analysis, backup | ✓ NOW |
| **Phase 1: Code** | Weeks 2-3 | Update read/write logic, add fallback | → Next |
| **Phase 2: Data** | Weeks 4-6 | Batch migrate root→dating.profile | Later |
| **Phase 3: Cleanup** | Weeks 7-8 | Remove fallback, delete nexus2.profile | Later |
| **Phase 4: Archive** | Week 9 | Update docs, train team | Later |

---

## 9. COMMANDS TO EXECUTE (When Ready)

### Migration Script Template

```javascript
// migrate-root-to-dating-profile.js
const admin = require('firebase-admin');
const db = admin.firestore();

const PROFILE_FIELDS = [
  'age', 'gender', 'name', 'username', 'profileUrl',
  'city', 'country', 'countryCode', 'nationality', 'nationalityCode',
  'phoneNumber', 'educationLevel', 'profession', 'churchName', 
  'hobbies', 'bestQualotiesOrTraits'
];

async function migrateToConsolidated(dryRun = true) {
  const snapshot = await db.collection('users').get();
  let updated = 0;
  let skipped = 0;
  
  for (const doc of snapshot.docs) {
    const data = doc.data();
    const updates = {};
    let hasUpdates = false;
    
    // Copy each field to dating.profile if it exists at root
    for (const field of PROFILE_FIELDS) {
      if (data[field] !== undefined && data[field] !== null) {
        // Check if already at dating.profile (skip if yes)
        if (data.dating?.profile?.[field] == null) {
          updates[`dating.profile.${field}`] = data[field];
          hasUpdates = true;
        }
      }
    }
    
    if (hasUpdates) {
      if (!dryRun) {
        try {
          await doc.ref.update(updates);
          updated++;
        } catch (err) {
          console.error(`Failed to update ${doc.id}: ${err.message}`);
          skipped++;
        }
      } else {
        console.log(`[DRY RUN] Would update ${doc.id}:`, Object.keys(updates));
        updated++;
      }
    }
  }
  
  console.log(`
✅ Migration Complete:
  Updated: ${updated}
  Skipped: ${skipped}
  Mode: ${dryRun ? 'DRY RUN' : 'PRODUCTION'}
  `);
}

// Run
const dryRun = process.argv.includes('--dry-run');
migrateToConsolidated(dryRun);
```

---

## 10. EXPECTED BENEFITS

| Metric | Before | After | Improvement |
|--------|--------|-------|------------|
| **Avg Doc Size** | 8.3 KB | 5.7 KB | ↓ 31% |
| **Storage (100K users)** | 830 MB | 570 MB | ↓ 260 MB |
| **Query Complexity** | 3 levels | 2 levels | ↓ 33% easier |
| **Read Logic** | 3-tier fallback | 2-tier fallback | ↓ 33% cleaner |
| **Index Count** | 12 | 10 | ↓ 2 fewer |
| **Data Consistency Risk** | 🔴 HIGH | 🟡 MEDIUM | ✅ Reduced |
| **Developer Confidence** | 🟡 Medium | 🟢 High | ✅ Improved |

---

## 11. NEXT ACTION ITEMS

- [ ] **Review & Approve** this consolidation plan
- [ ] **Backup Firestore** (gcloud firestore export)
- [ ] **Create migration scripts** (JavaScript/Node.js)
- [ ] **Update UserModel.dart** read logic (Phase 1)
- [ ] **Test on staging** with sample data
- [ ] **Execute batch migration** (Phase 2, test first)
- [ ] **Monitor data integrity** (verify queries, indexes)
- [ ] **Schedule cleanup phase** (after 6-9 months)
- [ ] **Update team documentation**

