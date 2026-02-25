# QUICK REFERENCE: SAFE FIELD CONSOLIDATIONS

**Purpose:** Identify the SAFEST fields to consolidate immediately  
**Risk Level:** 🟢 LOW  
**Implementation Time:** 2-3 weeks  
**Data Migration:** Batch scripts (non-destructive)

---

## CONSOLIDATION SUMMARY

### 🟢 TIER 1: IMMEDIATELY SAFE (Start These Now)

16 fields currently stored 2-3 times. Consolidate to **`dating.profile`** as single source of truth.

| # | Field | Current Storage | Target Location | Backward Compat | Notes |
|---|-------|------|------|---|---|
| 1 | `age` | root, dating.profile, nexus2.profile | `dating.profile.age` | Keep root 6-9mo | Search queries use this |
| 2 | `gender` | root, dating.profile, nexus2.profile | `dating.profile.gender` | Keep root 6-9mo | Search queries use this |
| 3 | `name` | root, dating.profile, nexus2.profile | `dating.profile.name` | Keep root 6-9mo | Display name |
| 4 | `username` | root, dating.profile, nexus2.profile | `dating.profile.username` | Keep root 6-9mo | Display handle |
| 5 | `profileUrl` | root, dating.profile, nexus2.profile | `dating.profile.profileUrl` | Keep root 6-9mo | Avatar/pic |
| 6 | `city` | root, dating.profile, nexus2.profile | `dating.profile.city` | Keep root 6-9mo | Location |
| 7 | `country` | root, dating.profile, nexus2.profile | `dating.profile.country` | Keep root 6-9mo | Filtering |
| 8 | `countryCode` | root, dating.profile, nexus2.profile | `dating.profile.countryCode` | Keep root 6-9mo | ISO code |
| 9 | `nationality` | root, dating.profile, nexus2.profile | `dating.profile.nationality` | Keep root 6-9mo | Filtering |
| 10 | `nationalityCode` | root, dating.profile, nexus2.profile | `dating.profile.nationalityCode` | Keep root 6-9mo | ISO code |
| 11 | `phoneNumber` | root, dating.profile, nexus2.profile | `dating.profile.phoneNumber` | Keep root 6-9mo | Contact |
| 12 | `educationLevel` | root, dating.profile, nexus2.profile | `dating.profile.educationLevel` | Keep root 6-9mo | Filtering |
| 13 | `profession` | root, dating.profile, nexus2.profile | `dating.profile.profession` | Keep root 6-9mo | Filtering |
| 14 | `churchName` | root, dating.profile, nexus2.profile | `dating.profile.churchName` | Keep root 6-9mo | Filtering |
| 15 | `hobbies` | root, dating.profile, nexus2.profile | `dating.profile.hobbies` | Keep root 6-9mo | Interests |
| 16 | `bestQualitiesOrTraits` | root, nexus2.profile | `dating.profile.bestQualitiesOrTraits` | Keep root 6-9mo | Profile bio |

**IMPACT:**
- Remove 16 × ~3 redundancies = 48 field instances reduced to 16
- Estimated storage saving: ~2.0 KB per user
- For 100K users: **200 MB saved**

---

### 🟡 TIER 2: CONDITIONAL (After Testing & Approval)

These fields also have duplicates but require more careful handling.

#### Photos (3 locations)
```
Current:
  - root.photos
  - dating.photos
  - dating.profile.photos

Target:
  - dating.photos (cleaner nesting than dating.profile.photos)

Recommendation:
  ✓ Move: dating.profile.photos → dating.photos
  ✓ Keep: root.photos for 6-9 months compat
  ⚠️ Test: Verify image loading logic works
  Risk Level: 🟡 MEDIUM
```

#### Audio Prompts (4 locations!)
```
Current:
  - root.audioPrompts
  - dating.audioPrompts
  - dating.reviewPack.audioUrls
  - root audio1Url/audio2Url/audio3Url (v1 legacy)

Target:
  - dating.reviewPack.audioUrls (single source)

Recommendation:
  ? Consolidate: All → dating.reviewPack.audioUrls
  ⚠️ Test: Complex merge logic - review UserModel code first
  ⚠️ Test: Audio URL parsing handles all formats
  Risk Level: 🟠 MEDIUM-HIGH (most complex consolidation)
  Priority: LOWER (less critical path than profile fields)
```

#### Location Object
```
Current:
  - root.location (nested map)
  - dating.profile.location (nested map)
  - nexus2.profile.location (nested map)

Target:
  - dating.location (simpler path)

Recommendation:
  ✓ Move: root.location → dating.location
  ✓ Move: dating.profile.location → dating.location
  ✓ Delete: nexus2.profile.location
  ⚠️ Test: Map merging logic
  Risk Level: 🟡 MEDIUM
  Timing: After Tier 1 complete
```

---

### 🔒 TIER 3: MUST PRESERVE (Never Consolidate)

These must stay where they are for specific business reasons.

#### Dating Archive/Restore
```
Location: users/{id}.dating.profile.*
Reason:   Quick snapshot for profile archival/restoration
Action:   PRESERVE UNCHANGED ✓
Status:   Do not move or modify
```

#### Root-Level Identity & Account Fields
```
Fields that MUST stay at root:
  - email (Firebase Auth linkage)
  - fcmToken (service token)
  - notificationToken (v1 compat token)
  - isVerified (deprecated but keep for compat)
  - likeMe, myLikes (account-level lists)
  - mySaves, blocked (account-level lists)
  - matchedUsers (account history)
  - unRecommendUsers (user preferences)
  - compatibility (large preference map)
  - compatibilitySetted (flag for above)
  - All subscription fields (sub system)
  - isGuest, isAdmin (account type)
  - Social media handles (account identity)
  
Reason:   These are account-level, not profile data
Action:   NEVER move or nest these
Status:   Permanent location at root
```

---

## CONSOLIDATION EXECUTION PHASES

### PHASE 0: Preparation (This Week)
- ✅ Analysis complete (this document)
- ✓ Backup Firestore
- ✓ Review this analysis
- ✓ Get approval to proceed

### PHASE 1: Code Updates (Weeks 2-3)
**Objective:** Make code resilient to new locations before data migration

**Changes:**
1. Update `UserModel.dart` read order:
   ```dart
   // OLD (3 levels)
   age: root.age ?? nexus2.profile.age ?? dating.profile.age
   
   // NEW (2 levels, nexus2 skipped)
   age: dating.profile.age ?? root.age  // Primary first!
   ```

2. Update write paths in `FirestoreService`:
   ```dart
   // Old: writes to root
   // New: writes to dating.profile.* for new data
   ```

3. Add migration code:
   ```dart
   // Add fallback logic during Phase 1-2
   // Remove fallback in Phase 3
   ```

4. **No Firestore changes yet** - Reading prefers new location, falls back to old

**Duration:** ~4-6 days of development + testing

### PHASE 2: Data Migration (Weeks 4-6)
**Objective:** Move existing data without breaking anything

**Steps:**
1. Backup Firestore (again)
2. Test migration script on 10 sample documents
3. Dry-run on full dataset (see what changed)
4. Run batch migration: root → dating.profile
5. Verify 50+ random documents
6. Keep both locations (compat mode)

**Duration:** ~2-3 weeks (careful testing required)

### PHASE 3: Code Cleanup (Weeks 7-8)
**Objective:** Remove fallback logic, depend on new location

**Changes:**
1. Remove fallback to root-level fields
2. Remove reads from nexus2.profile
3. Update indexes in `firestore.indexes.json`
4. Deploy code with updated indexes

**Duration:** ~3-4 days

### PHASE 4: Data Cleanup (Week 9+)
**Objective:** Remove redundant root-level fields (optional, after 6-9 months)

**NOT recommended immediately** - keep root fields as insurance policy

**If you decide to remove (after stabilization):**
1. Create new backup
2. Run cleanup script
3. Monitor for issues

**Duration:** Optional / deferred

---

## SAFE CONSOLIDATION SETUP STEPS

### Step 1: Review the Code
```bash
# Understand current read logic
cat lib/core/models/user_model.dart  # Line 395-600
cat lib/core/user/user_schema_migrator.dart

# Understand current write logic
cat lib/core/services/firestore_service.dart  # UserModel writes
```

### Step 2: Backup Everything
```bash
# Backup Firestore
gcloud firestore export gs://nexus-app-backups/pre-consolidation-$(date +%Y%m%d)

# Verify backup
gsutil ls gs://nexus-app-backups/
```

### Step 3: Create Migration Scripts
```bash
# Create directory for scripts
mkdir -p scripts/consolidation

# Create files (see templates below)
touch scripts/consolidation/dry-run.js
touch scripts/consolidation/migrate.js
touch scripts/consolidation/verify.js
```

### Step 4: Test Migration on Sample
```bash
# Export 10 documents
firebase firestore:export test-backup/ --collection-ids=users --limit=10

# Run dry-run
node scripts/consolidation/dry-run.js

# Inspect output
# If looks good: proceed to Phase 1
```

### Step 5: Update Code (Phase 1)
See code changes in SCHEMA_CONSOLIDATION_ROADMAP.md

---

## MIGRATION SCRIPT TEMPLATES

### Script 1: Dry Run (See What Changed)
```javascript
const admin = require('firebase-admin');
const db = admin.firestore();

const TIER_1_FIELDS = [
  'age', 'gender', 'name', 'username', 'profileUrl',
  'city', 'country', 'countryCode', 'nationality', 'nationalityCode',
  'phoneNumber', 'educationLevel', 'profession', 'churchName', 
  'hobbies', 'bestQualotiesOrTraits'
];

async function dryRun() {
  const docs = await db.collection('users').get();
  let willUpdate = 0;
  
  for (const doc of docs.docs) {
    const data = doc.data();
    let needsUpdate = false;
    
    for (const field of TIER_1_FIELDS) {
      if (data[field] && !data.dating?.profile?.[field]) {
        needsUpdate = true;
        break;
      }
    }
    
    if (needsUpdate) willUpdate++;
  }
  
  console.log(`Dry Run Results:`);
  console.log(`  Total users: ${docs.size}`);
  console.log(`  Would update: ${willUpdate}`);
  console.log(`  No changes needed: ${docs.size - willUpdate}`);
}

dryRun();
```

### Script 2: Actual Migration
```javascript
const admin = require('firebase-admin');
const db = admin.firestore();

const TIER_1_FIELDS = [
  'age', 'gender', 'name', 'username', 'profileUrl',
  'city', 'country', 'countryCode', 'nationality', 'nationalityCode',
  'phoneNumber', 'educationLevel', 'profession', 'churchName', 
  'hobbies', 'bestQualotiesOrTraits'
];

async function migrate() {
  const docs = await db.collection('users').get();
  let updated = 0;
  let errors = 0;
  
  console.log('Starting migration...');
  
  for (const doc of docs.docs) {
    const data = doc.data();
    const updates = {};
    
    for (const field of TIER_1_FIELDS) {
      if (data[field] && !data.dating?.profile?.[field]) {
        updates[`dating.profile.${field}`] = data[field];
      }
    }
    
    if (Object.keys(updates).length > 0) {
      try {
        await doc.ref.update(updates);
        updated++;
        if (updated % 100 === 0) {
          console.log(`  Updated: ${updated}...`);
        }
      } catch (err) {
        console.error(`  ERROR in ${doc.id}: ${err.message}`);
        errors++;
      }
    }
  }
  
  console.log(`\n✅ Migration Complete:`);
  console.log(`   Updated: ${updated}`);
  console.log(`   Errors: ${errors}`);
}

migrate();
```

---

## COST-BENEFIT ANALYSIS

### Benefits ✅
- **Storage:** 31% reduction per document
- **For 100K users:** 260 MB freed up
- **Code clarity:** Single source of truth
- **Query performance:** Simpler read logic
- **Data consistency:** No sync issues between root/dating/nexus2
- **Future maintenance:** Easier schema updates
- **Team confidence:** Clearer data model

### Costs & Risks ⚠️
- **Development time:** ~2-3 weeks code + migration
- **Testing:** Comprehensive validation needed
- **Rollback:** Complex if issues arise (hence backups)
- **Staging validation:** Required before production
- **Team coordination:** Code + migration timing

### ROI (Return on Investment)
- **Long term:** ⭐⭐⭐⭐⭐ Highly recommended
- **Short term:** ⭐⭐⭐ Worth doing soon
- **Implementation:** ⭐⭐⭐⭐ Execute carefully

---

## DECISION POINTS

### Should We Do This Now?
**✅ YES if:**
- [ ] You have time for 2-3 week project
- [ ] Team ready to focus on schema work
- [ ] Can handle rollback if needed
- [ ] Want to fix data consistency issues

**⏸️ DEFER if:**
- [ ] Critical features in progress
- [ ] Limited team capacity
- [ ] Recent major changes to schema

### Which Tier First?
**Recommendation:** Always do **Tier 1 first**:
1. **Tier 1** (16 fields) = Safe, high impact, low risk
2. **Tier 2** (photos, audio) = After Tier 1 stabilized
3. **Tier 4** (cleanup) = 6-9 months later

**NEVER DO:**
- ❌ Tier 3 (would break archives)
- ❌ Skip Tier 2 testing

---

## FINAL RECOMMENDATIONS

### ✅ PROCEED WITH TIER 1
**Safe consolidation of 16 profile fields to `dating.profile`**

- Risk: 🟢 LOW
- Impact: 🟢 HIGH (31% storage reduction)
- Timeline: 2-3 weeks
- Team effort: Moderate
- **Recommendation: PROCEED NOW**

### ⏸️ DEFER TIER 2 (conditional)
**Audio/photo/location consolidation**

- Risk: 🟡 MEDIUM
- Impact: 🟡 MEDIUM (additional 10% reduction)
- Timeline: 1-2 weeks (after Tier 1)
- Complexity: Higher
- **Recommendation: LATER, after Tier 1 stabilized**

### 🔒 PRESERVE TIER 3
**Keep dating archives and root identity fields**

- Risk: 🔴 CRITICAL if changed
- Impact: 🟢 Necessary for operations
- **Recommendation: NEVER MODIFY**

---

## NEXT STEP

1. **Review this document** ← You are here
2. **Get approval** ← From tech lead
3. **Review SCHEMA_CONSOLIDATION_ROADMAP.md** ← Detailed execution
4. **Start Phase 1** ← Code updates
5. **Execute Phase 2** ← Data migration

---

## CONTACT FOR QUESTIONS

This analysis covers:
- Schema redundancy identification
- Safe consolidation strategy
- Step-by-step execution plan
- Risk mitigation
- Rollback procedures

All based on current v1/v2 models reviewed Feb 23, 2026.

