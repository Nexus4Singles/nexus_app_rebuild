# Schema Consolidation Analysis - V1/V2 Field Deduplication

**Date:** February 23, 2026  
**Status:** Investigation & Recommendations

---

## 1. EXECUTIVE SUMMARY

The Nexus v2 app currently maintains **massive field redundancy** across three schema levels:

| Level | Location | Purpose | Redundancy |
|-------|----------|---------|-----------|
| **V1 Root** | `users/{id}` root fields | Original v1 storage | ✗ Duplicated at v2 levels |
| **Dating** | `users/{id}.dating.*` | v1 dating data + archival | ✗ Some dups but needed for archives |
| **Nexus2** | `users/{id}.nexus2.*` | v2 extension fields | ✗ Duplicates root + dating |

**Result:** Same fields stored 2-3 times in the same document → Data consistency risks, increased document size, complex read logic

---

## 2. DETAILED FIELD REDUNDANCY MAPPING

### 2.1 Profile Fields (HIGHEST REDUNDANCY)

These fields appear at multiple levels:

```
Field              Root Level    dating.profile    nexus2.profile    Usage Pattern
─────────────────────────────────────────────────────────────────────────────────
age                ✓             ✓                 ✓                 Search (dating)
gender             ✓             ✓                 ✓                 Search (dating)
city               ✓             ✓                 ✓                 Location display
country            ✓             ✓                 ✓                 Location/filtering
countryCode        ✓             ✓                 ✓                 ISO codes
nationality        ✓             ✓                 ✓                 Filter/display
nationalityCode    ✓             ✓                 ✓                 ISO codes
profileUrl         ✓             ✓                 ✓                 Avatar display
photos             ✓             ✓                 ✓                 Profile images
hobbies            ✓             ✓                 ✓                 Interests display
name               ✓             ✓                 ✓                 Display name
username           ✓             ✓                 ✓                 Handle
email              ✓             ✓                 ✓                 Contact
phoneNumber        ✓             ✓                 ✓                 Contact
educationLevel     ✓             ✓                 ✓                 Filters
profession         ✓             ✓                 ✓                 Filters
churchName         ✓             ✓                 ✓                 Filters
```

**Impact:** 16 core fields × 3 levels = 48 storage redundancies

### 2.2 Behavior & Status Fields (MODERATE REDUNDANCY)

Fields with business logic implications:

```
Field                          Root Level    dating    nexus2    Notes
────────────────────────────────────────────────────────────────────────
isVerified / verificationStatus  ✓           ✓         N/A       Different semantics!
audioPrompts                      ✓           ✓         N/A       Complex merge logic
location (nested object)          ✓           ✓         N/A       Map object
```

### 2.3 List/Array Fields (HIGH CONSISTENCY RISK)

These lists must stay in sync or cause data inconsistency:

```
Field                 Root    dating    Purpose
─────────────────────────────────────────────────────
likeMe               ✓        N/A       Who likes this user
myLikes              ✓        N/A       Who this user likes
mySaves              ✓        N/A       Saved profiles
blocked              ✓        N/A       Blocked users
matchedUsers         ✓        N/A       Previous matches
unRecommendUsers     ✓        N/A       Hidden recommendations
usersChatWarning     ✓        N/A       Chat warnings
```

**Risk:** If moved to nested levels, read/write logic becomes inconsistent

### 2.4 Metadata & Subscription Fields (UNIQUE)

These should NOT be consolidated (v1 vs v2 specific):

```
Field                        Root Level    Location Notes
────────────────────────────────────────────────────────────────
fcmToken                      ✓            Service token
notificationToken             ✓            Legacy v1 token
isGuest / isAdmin            ✓            Account type
compatibilitySetted           ✓            Dating pref status
compatibility (Map)           ✓            Complex pref object
onPremium / prevSubscribed    ✓            Sub status
subExpDate / subscriberId     ✓            Sub tracking
usedOneFreeText               ✓            Feature flag
entitledUser                  ✓            Access control
```

---

## 3. CONSOLIDATION STRATEGY

### 3.1 TIER 1: ABSOLUTELY SAFE TO CONSOLIDATE

**These fields have NO special archive/restore requirements:**

```
CONSOLIDATION PLAN - TIER 1
═════════════════════════════════════════════════════════════════════

Profile Display Fields (Move to dating.profile for consistency):
  age, gender, city, country, countryCode, nationality, nationalityCode
  name, username, email, profileUrl, phoneNumber
  hobbies, educationLevel, profession, churchName

Action:
  1. Keep root-level fields for backward compatibility (3-6 months)
  2. New fields ONLY written to dating.profile sub-object
  3. Code reads: dating.profile first, falls back to root
  4. Later: Bulk migration script to consolidate root → dating.profile
  5. UPDATE Firestore indexes to use dating.profile.* paths
```

**Benefit:** 
- Single source of truth
- Smaller document size
- Clearer organization
- Consistent search queries

---

### 3.2 TIER 2: CONDITIONAL CONSOLIDATION

**These need testing before consolidation:**

```
CONSOLIDATION PLAN - TIER 2
════════════════════════════════════════════════════════════════════

Audio Prompts (Complex - has 3 source paths):
  Current: 
    - dating.reviewPack.audioUrls (main)
    - dating.audioPrompts (fallback)
    - root.audioPrompts (v1 compat)
    - root audio fields (v1 legacy)
  
  Plan:
  1. Standardize on: dating.reviewPack.audioUrls
  2. Review existing data for conflicts
  3. Test audio retrieval logic
  4. Migrate dating.audioPrompts → dating.reviewPack.audioUrls
  5. Keep root audioPrompts for 6-month compat

Photos:
  Current: photos at root, dating.photos, dating.profile.photos
  Plan:
  1. Consolidate to: dating.photos (not nested deeper)
  2. Read priority: dating.photos → root.photos
  3. Migrate root.photos → dating.photos
  4. Keep root for 6-month compat

Location Object:
  Current: root.location, dating.profile.location, nexus2.profile.location
  Plan:
  1. Consolidate to: dating.location (not profile sub-object)
  2. Read priority: dating.location → root.location
  3. Status: HOLD - verify no nested data conflicts first

Verification Status (⚠️ SPECIAL HANDLING):
  Current Duality:
    - root.isVerified (boolean) = v1 binary
    - dating.verificationStatus (enum) = v2 qualified state
  Plan:
  1. KEEP BOTH for now (different semantics)
  2. Code uses dating.verificationStatus as source of truth
  3. Root isVerified deprecated after v2 stabilization
  4. Document: "root.isVerified & dating.verificationStatus must stay in sync"
```

---

### 3.3 TIER 3: MUST PRESERVE FOR ARCHIVES

**DO NOT CONSOLIDATE - critical for dating profile archival/restoration:**

```
PRESERVATION PLAN - TIER 3
═════════════════════════════════════════════════════════════════════

Dating Collection Data:
  Location: users/{id}/dating/* (collection)
  Purpose: Archive v1 dating data, restore on profile reactivation
  Action: **LEAVE UNTOUCHED** ✓
  
Dating Sub-object (Full Profile Snapshot):
  Location: users/{id}.dating.profile = {all profile fields snapshot}
  Purpose: Quick restore without root-level reads
  Action: **PRESERVE** - keep as emergency snapshot ✓
  
  Reason: Archived users' documents may not have current root data
          Restoring user needs complete dating profile from nested object
          Moving to root would break restore logic

Example Restore Scenario:
  1. User archives dating profile (soft delete)
  2. dating.profile captures full snapshot at archive time
  3. Later: User restores (un-archives)
  4. Code restores from: dating.profile (pre-snapshot)
  5. Root-level fields updated from dating.profile snapshot
```

---

## 4. FIELD-BY-FIELD CONSOLIDATION RECOMMENDATION

### Profile Fields

| Field | Current Duplication | Safe to Consolidate? | Recommendation |
|-------|--------|---------|---|
| `age` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.age` (remove nexus2) |
| `gender` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.gender` (remove nexus2) |
| `city` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.city` (remove nexus2) |
| `country` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.country` (remove nexus2) |
| `countryCode` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.countryCode` |
| `nationality` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.nationality` |
| `nationalityCode` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.nationalityCode` |
| `name` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.name` |
| `username` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.username` |
| `email` | root, dating.profile | ✅ YES | → root.email (identity) |
| `profileUrl` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.profileUrl` |
| `phoneNumber` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.phoneNumber` |
| `hobbies` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.hobbies` |
| `educationLevel` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.educationLevel` |
| `profession` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.profession` |
| `churchName` | root, dating.profile, nexus2 | ✅ YES | → `dating.profile.churchName` |
| `bestQualitiesOrTraits` | root, nexus2 | ✅ YES | → `dating.profile.bestQualitiesOrTraits` |

### Collection/Array Fields

| Field | Consolidation Risk | Recommendation |
|-------|---------|---|
| `photos` | ⚠️ High - many dependencies | `dating.photos` (simpler path) |
| `audioPrompts` | ⚠️ High - 3 source paths | Standardize on `dating.reviewPack.audioUrls` |
| `location` | ⚠️ Medium - nested map | `dating.location` (migrate carefully) |
| `likeMe`, `myLikes`, `mySaves`, `blocked` | ✅ Safe - only at root | KEEP at root (no duplicates) |
| `matchedUsers`, `unRecommendUsers` | ✅ Safe - only at root | KEEP at root (no duplicates) |

### Metadata Fields

| Field | Type | Recommendation |
|-------|------|---|
| `fcmToken` | ✅ Unique to root | KEEP (service tokens) |
| `notificationToken` | ✅ Legacy v1 | KEEP for 6 months, then deprecate |
| `compatibility` | ✅ Complex pref map | KEEP at root (too large for profile sub-object) |
| `compatibilitySetted` | ✅ Metadata flag | KEEP at root |
| Subscription fields | ✅ Account-level | KEEP at root |
| Account flags | ✅ Identity-level | KEEP at root |

---

## 5. NEXUS2 NAMESPACE HANDLING

### Current Situation
```
nexus2 = {
  relationshipStatus
  gender (DUP!)
  primaryGoals
  onboardingCompleted
  onboardedAt
  schemaVersion
  lastActiveAt
  experiments
  hasSeenDatingPoolGuidelines
  profile: { age, gender, city, ... lots of dups }
}
```

### Recommendation: Slim Down Nexus2
```
nexus2 = {
  // ==== KEEP ====
  relationshipStatus (not at v1 level, unique to v2)
  primaryGoals (unique to v2)
  onboardingCompleted (v2 onboarding, not v1)
  onboardedAt (v2 onboarding, not v1)
  schemaVersion (metadata)
  lastActiveAt (activity tracking)
  experiments (a/b testing)
  hasSeenDatingPoolGuidelines (app state)
  
  // ==== REMOVE (MOVE TO dating.profile) ====
  gender → delete (already at dating.profile.gender)
  profile → flatten into dating.profile (detailed below)
}
```

### Profile Inside Nexus2: Flatten Strategy
```
CURRENT:
users/{id}.nexus2.profile.age
users/{id}.nexus2.profile.gender
... etc

NEW (after consolidation):
Just read from: users/{id}.dating.profile.*
Never write to: nexus2.profile.*
(Keep nexus2.profile for 6-month compat, then deletion migration)
```

---

## 6. IMPLEMENTATION PHASES

### Phase 0: Preparation (Week 1)
- ✅ Document all duplicate fields (this analysis)
- Create backup of production Firestore
- Analyze distribution of fields (which docs have dupes?)
- Create migration test suite

### Phase 1: Code Layer (Weeks 2-3)
- Update `UserModel.fromMap()` read logic:
  - Priority 1: `dating.profile.*`
  - Priority 2: `root.*`
  - Never read from `nexus2.profile.*`
- Update write paths:
  - New data → `dating.profile.*`
  - Keep root for 6-month compat
- Firestore rules: allow new structure

### Phase 2: Data Migration (Weeks 4-6)
- Test with sample documents first
- Dry-run: Move root→dating.profile
- Production batch: Root field copy→dating.profile
- Dry-run: Remove dupplicates from nexus2.profile
- Keep root/nexus2 for 3 months (compat)

### Phase 3: Code Cleanup (Weeks 7-8)
- Remove fallback to root-level fields
- Remove nexus2 duplication reads
- Update indexes to use dating.profile paths
- Performance testing

### Phase 4: Archive & Document (Week 9)
- Remove root/nexus2 duplicates completely
- Update schema docs
- Training docs for new developers

---

## 7. MIGRATION SCRIPT TEMPLATES

### Script 1: Identify Duplicate Documents
```javascript
// Count docs with root age AND dating.profile.age
db.collection('users').where('age', '>', 0)
  .where('dating.profile.age', '>', 0)
  .get()
  // Count = duplication extent
```

### Script 2: Migrate Root → Dating.Profile
```javascript
// Pseudo-code (test on sample first!)
db.collection('users').get().then(snap => {
  const batch = db.batch();
  snap.forEach(doc => {
    batch.update(doc.ref, {
      'dating.profile.age': doc.data().age || null,
      'dating.profile.gender': doc.data().gender || null,
      // ... all other TIER 1 fields
    });
  });
  return batch.commit();
});
```

### Script 3: Remove Nexus2.profile Duplicates
```javascript
// After Phase 2, remove redundant data
db.collection('users').get().then(snap => {
  const batch = db.batch();
  snap.forEach(doc => {
    const data = doc.data();
    const nexus2 = data.nexus2 || {};
    delete nexus2.profile; // Remove old snapshot
    delete nexus2.gender; // Remove dup
    batch.update(doc.ref, { nexus2 });
  });
  return batch.commit();
});
```

---

## 8. RISK ASSESSMENT & MITIGATION

| Risk | Severity | Mitigation |
|------|----------|-----------|
| Data loss during migration | 🔴 CRITICAL | Backup before each phase, test on sample docs first |
| Code reads old paths | 🟠 HIGH | Multi-phase fallback logic (read priority) |
| Indexes break | 🟠 HIGH | Update firestore.indexes.json before migration |
| Verification state divergence | 🟠 HIGH | Sync logic for `isVerified` ↔ `dating.verificationStatus` |
| Archive/restore breaks | 🟡 MEDIUM | Keep `dating.profile` snapshot intact |
| Search queries fail | 🟡 MEDIUM | Update search queries incrementally |
| Old v1 clients fail | 🟡 MEDIUM | API versioning, backward compat layer |

---

## 9. SUMMARY OF SAFE CONSOLIDATIONS

### ✅ IMMEDIATELY SAFE (Implement Now)

1. **Profile Fields to `dating.profile`** (16 fields)
   - Move: `age, gender, city, country, countryCode, nationality, nationalityCode, name, username, profileUrl, phoneNumber, educationLevel, profession, churchName, hobbies, bestQualitiesOrTraits`
   - Benefit: 50% reduction in duplication
   - Risk: Low (new writes only, keep root for compat)

2. **Remove `nexus2.profile` Duplication**
   - Delete: `nexus2.profile.age, .gender, .city, .country, etc.`
   - Keep: Only `nexus2` identity/onboarding fields
   - Benefit: Cleaner namespace, reduced storage
   - Risk: Low (migrated to dating.profile)

### ⚠️ CONDITIONAL (After Testing)

3. **Consolidate Photos & Audio**
   - Photos: `root.photos` + `dating.photos` → `dating.photos`
   - Audio: Multiple paths → `dating.reviewPack.audioUrls`
   - Risk: Medium (requires thorough compatibility testing)

### 🔒 MUST PRESERVE (Never Change)

4. **Dating Profile Snapshots**
   - Keep: `dating.profile` (for archive/restore)
   - Keep: `dating` collection (v1 data)
   - Reason: Required for dating profile archival workflows

---

## 10. NEXT STEPS

1. **Review this analysis** → Confirm consolidation strategy
2. **Create test suite** → Validate data consistency
3. **Backup Firestore** → Before any migrations
4. **Implement Phase 1** → Update code read/write logic
5. **Test migration script** → On sample documents
6. **Execute Phase 2** → Batch migrate data
7. **Monitor & verify** → Check indexes, queries, app behavior
8. **Schedule Phase 3** → Code cleanup timeline

---

## 11. APPENDIX: FIELD COUNT ANALYSIS

```
Current Schema Redundancy:

Total Unique Root-level Fields:    55
  - Profile fields (duplicated):   16
  - Behavior fields:               15
  - Metadata fields:               24

Duplication Locations:
  - Root level:                    55 (100%)
  - dating.profile:                20 (36%)
  - dating (sub-objects):          8 (15%)
  - nexus2.profile:                16 (29%)

Result: ~38 fields stored 2-3 times = 76-114 redundant storage instances

After Consolidation (Tier 1):
  - Root: 39 (metadata + compat)
  - dating.profile: 20 (primary)
  - Reduction: ~40% over time
```

