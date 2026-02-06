# Firestore User Schema Analysis & Deduplication Plan

## 🔍 Identified Duplications

### **1. PHOTOS (CRITICAL - 3 LOCATIONS)**

| Location | Content | Status |
|----------|---------|--------|
| `dating.photos[]` | Dating profile photos | ⚠️ KEEP |
| `photos[]` | Top-level photos array | ⚠️ DUPLICATE |
| `reviewPack.photoUrls[]` | Review/verification pack photos | ⚠️ DUPLICATE |

**Analysis:**
- `dating.photos[]` - Photos specific to dating profile (verified, part of dating pack)
- `photos[]` - Appears to be backup/general profile photos
- `reviewPack.photoUrls[]` - Photos submitted for verification process

**Recommendation:** 
❌ **REMOVE `photos[]` top-level** - Use `dating.photos[]` as source of truth  
✅ **KEEP `reviewPack.photoUrls[]`** - This is specifically for verification audit trail

**Risk Level:** ⚠️ **MEDIUM** - Need to check where `photos[]` is read

---

### **2. AUDIO PROMPTS (CRITICAL - 2 LOCATIONS)**

| Location | Content | Status |
|----------|---------|--------|
| `dating.audioPrompts[]` | Dating profile audio prompts | ⚠️ KEEP |
| `reviewPack.audioUrls[]` | Review pack audio submissions | ⚠️ DUPLICATE |

**Analysis:**
- `dating.audioPrompts[]` - Current audio prompts for dating profile
- `reviewPack.audioUrls[]` - Snapshot of audios submitted for verification

**Recommendation:**
❌ **REMOVE `reviewPack.audioUrls[]`** - Source of truth should be `dating.audioPrompts[]`  
✅ **KEEP `dating.audioPrompts[]`** - Single source of truth

**Risk Level:** ⚠️ **MEDIUM** - Need to verify reviewPack logic

---

### **3. RELATIONSHIP STATUS (CRITICAL - 4 LOCATIONS)**

| Location | Value | Status |
|----------|-------|--------|
| `maritalStatus` | "Never Married" | ⚠️ DUPLICATE |
| `dating.relationshipStatus` | "single_never_married" | ⚠️ DUPLICATE |
| `nexus.relationshipStatus` | "single_never_married" | ⚠️ DUPLICATE |
| `nexus2.relationshipStatus` | "single_never_married" | ⚠️ DUPLICATE |

**Analysis:**
- `maritalStatus` - User-friendly format ("Never Married")
- `dating.relationshipStatus` - Standardized enum format (used in code)
- `nexus.relationshipStatus` - Old Nexus v1 data
- `nexus2.relationshipStatus` - Migration intermediate state

**Recommendation:**
✅ **KEEP** `dating.relationshipStatus` - This is what the app uses (from code)  
❌ **REMOVE** `maritalStatus` - Derived from relationshipStatus  
❌ **REMOVE** `nexus.relationshipStatus` - Legacy v1 data  
❌ **REMOVE** `nexus2.relationshipStatus` - Migration residue  

**Risk Level:** 🔴 **HIGH** - Check all code references to `maritalStatus`

---

### **4. GENDER (DUPLICATE - 2 LOCATIONS)**

| Location | Value | Status |
|----------|-------|--------|
| `gender` | "male" | ⚠️ DUPLICATE |
| `dating.gender` | "male" | ⚠️ DUPLICATE |

**Analysis:**
- `gender` - Top-level field
- `dating.gender` - Gender in dating profile context

**Recommendation:**
✅ **KEEP** `gender` - Top-level is more accessible  
❌ **REMOVE** `dating.gender` - This is redundant when we have top-level  

**Risk Level:** ⚠️ **MEDIUM** - Check dating profile reads

---

### **5. CONTACT INFO SOCIAL HANDLES (DUPLICATION PATTERN)**

| Location | Fields | Status |
|----------|--------|--------|
| Top-level | `instagramUsername`, `facebookUsername`, `twitterUsername`, `snapchatUsername`, `telegramUsername` | ⚠️ KEEP |
| `dating.contactInfo` | `Instagram`, `countryOfResidence` | ⚠️ PARTIAL DUPLICATE |

**Analysis:**
- Top-level handles - Complete social media handles
- `dating.contactInfo.Instagram` - Only Instagram is duplicated here

**Recommendation:**
✅ **KEEP** all top-level social handles  
❌ **REMOVE** `dating.contactInfo.Instagram` - Use `instagramUsername` instead  
✅ **KEEP** `dating.contactInfo.countryOfResidence` - This is dating profile specific  

**Risk Level:** ⚠️ **MEDIUM** - Check dating profile contact handling

---

### **6. COUNTRY/LOCATION FIELDS (DUPLICATION - 3 LOCATIONS)**

| Location | Value | Status |
|----------|-------|--------|
| `country` | "Japan" | ⚠️ KEEP |
| `dating.contactInfo.countryOfResidence` | "Japan" | ⚠️ DUPLICATE |
| `city` | "Tokyo" | ⚠️ KEEP |

**Analysis:**
- `country` - User's country (top-level)
- `dating.contactInfo.countryOfResidence` - Same country nested in dating
- `city` - User's city (top-level)

**Recommendation:**
✅ **KEEP** `country` - Top-level primary  
❌ **REMOVE** `dating.contactInfo.countryOfResidence` - Use `country` instead  
✅ **KEEP** `city` - Additional location specificity  

**Risk Level:** ⚠️ **MEDIUM** - Check dating profile location reads

---

### **7. DISPLAY/PROFILE INFO (DUPLICATION)**

| Location | Value | Status |
|----------|-------|--------|
| `name` | "Ayo" | ⚠️ KEEP |
| `displayName` | "Ayo" | ⚠️ DUPLICATE |
| `username` | "Ayo" | ⚠️ KEEP (different) |
| `profileUrl` | photo URL | ⚠️ KEEP |

**Analysis:**
- `name` - User's name
- `displayName` - Display name (appears identical)
- `username` - Username handle (different from name)

**Recommendation:**
✅ **KEEP** `name` - Primary name field  
❌ **REMOVE** `displayName` - Identical to `name`, unnecessary  
✅ **KEEP** `username` - Different field (handle)  
✅ **KEEP** `profileUrl` - Primary photo reference  

**Risk Level:** ⚠️ **MEDIUM** - Check profile display logic

---

### **8. PROFILE STATUS FLAGS (STRUCTURE ISSUE)**

| Location | Fields | Status |
|----------|--------|--------|
| `dating` | `profileCompleted`, `enabled`, `verificationStatus` | ⚠️ STRUCTURE |
| Top-level | (none for dating profile status) | ⚠️ MISSING |

**Analysis:**
- Dating profile has completion/verification status nested within
- Makes it hard to query all profiles needing verification

**Recommendation:**
✅ **KEEP** in dating (profile-specific)  
💡 **CONSIDER** top-level flag: `datingProfileEnabled: false` - Quick query

**Risk Level:** 🟡 **LOW** - This is structural, not duplication

---

## ✅ Proposed Schema After Deduplication

```
users/{uid}/
├── # AUTHENTICATION & IDENTITY (Don't Touch)
├── uid: string
├── email: string
├── phoneNumber: string
├── username: string
├── name: string  (keep)
├── profileUrl: string
├── 
├── # BASIC PROFILE (Don't Touch)
├── age: number
├── gender: string (not in dating)
├── nationality: string
├── educationLevel: string
├── profession: string
├── city: string
├── country: string
├── 
├── # SOCIAL & COMMUNITY
├── instagramUsername: string
├── twitterUsername: string
├── facebookUsername: string
├── snapchatUsername: string
├── telegramUsername: string
├── hobbies: array
├── desiredQualities: string
├── 
├── # RELATIONSHIP & FAITH
├── dating.relationshipStatus: "single_never_married"
├── compatibility: { ...all fields }
├── churchName: string
├── 
├── # CHAT & SOCIAL
├── freeChatPartnerIds: array
├── savedProfiles: array
├── chat: map
├── 
├── # DATING PROFILE (if applicable)
├── dating/
│   ├── enabled: boolean
│   ├── profileCompleted: boolean
│   ├── photos: array  (keep)
│   ├── audioPrompts: array  (keep)
│   ├── desiredQualities: string (if different from top-level)
│   ├── verificationStatus: string
│   ├── verificationQueuedAt: timestamp
│   ├── contactInfo: { Instagram removed }
│   └── reviewPack: { removed audio/photo dupes }
│
├── # TIMESTAMPS
├── createdAt: timestamp
├── updatedAt: timestamp
├── 
├── # CONFIG
├── schemaVersion: number
├── isAdmin: boolean
├── isGuest: boolean
└── nexus.onboarding: { ...keep for now }
```

---

## 🗑️ Fields to Remove (Summary)

| Field | Reason | Risk |
|-------|--------|------|
| `displayName` | Identical to `name` | 🟡 MEDIUM |
| `maritalStatus` | Duplicate of `dating.relationshipStatus` | 🔴 HIGH |
| `photos[]` (top-level) | Duplicate of `dating.photos[]` | 🟡 MEDIUM |
| `nexus.relationshipStatus` | Legacy v1 data | 🟢 LOW |
| `nexus2.relationshipStatus` | Migration residue | 🟢 LOW |
| `dating.gender` | Duplicate of top-level `gender` | 🟡 MEDIUM |
| `dating.contactInfo.Instagram` | Duplicate of `instagramUsername` | 🟡 MEDIUM |
| `dating.contactInfo.countryOfResidence` | Duplicate of `country` | 🟡 MEDIUM |
| `reviewPack.audioUrls[]` | Duplicate of `dating.audioPrompts[]` | 🟡 MEDIUM |
| `reviewPack.photoUrls[]` | Duplicate of `dating.photos[]` | 🟡 MEDIUM |

---

## 📊 Impact Assessment

### HIGH RISK FIELDS (Check Code First)
1. **`maritalStatus`** - May be used in queries or display logic
2. **`photos[]` top-level** - May be used for profile display

### MEDIUM RISK FIELDS (Check Usage)
1. **`displayName`** - Check profile screens
2. **`dating.gender`** - Check dating profile reads
3. **Social handles in `dating.contactInfo`** - Check dating contact display
4. **`reviewPack` audio/photo dupes** - Check verification workflow

### LOW RISK FIELDS (Safe to Remove)
1. **`nexus.relationshipStatus`** - Old v1 data
2. **`nexus2.relationshipStatus`** - Migration data

---

## 🔍 Code Analysis Needed

Before removing any fields, need to search for:

1. **`displayName`** usage in code
2. **`maritalStatus`** usage in code
3. **`photos[]`** (top-level array) usage
4. **`dating.gender`** usage
5. **`dating.contactInfo.Instagram`** usage
6. **`reviewPack.audioUrls`** usage
7. **`reviewPack.photoUrls`** usage

---

## 📋 Execution Plan

### Phase 1: Code Audit ✅ (REQUIRED FIRST)
- [ ] Search all `.dart` files for field usage
- [ ] Document where each duplicate is used
- [ ] Identify safe removals vs. needed refactors

### Phase 2: Firestore Service Updates
- [ ] Update `userModelFromJson()` to handle missing fields
- [ ] Update any direct Firestore queries using these fields
- [ ] Add migration function (optional)

### Phase 3: Safe Removal
- [ ] Remove from UserModel definition
- [ ] Remove from document creation logic
- [ ] Update verification/review workflows if needed

### Phase 4: Testing
- [ ] Test existing user profile loads
- [ ] Test new user creation
- [ ] Test dating profile flows
- [ ] Test verification workflows

---

## ⚠️ Important Notes

1. **DO NOT remove `reviewPack` entirely** - It's needed for verification audit trail
2. **Keep timestamps** - `submittedAt`, `verificationQueuedAt` are audit-important
3. **Keep compatibility map** - It's a separate concern from relationship status
4. **nexus.onboarding** - Keep for now, may be used for migration logic

---

## Recommendations for Proper Structure

### Current Issues:
1. ✅ `dating` collection is good pattern - keep it
2. ❌ `compatibility` should possibly be separate like `dating` is
3. ❌ Multiple versions of data (nexus, nexus2, top-level)
4. ❌ Review/verification state mixed with active profile

### Future Improvements:
```
users/{uid}/
├── profile/           (basic identity, age, location, etc.)
├── compatibility/     (all compatibility preferences - separate collection)
├── dating/           (dating profile - only if relationship status allows)
├── assessments/      (per-category assessments)
├── journeys/         (per-category journeys)
├── chat/             (chat metadata)
└── verification/     (verification workflow state)
```

But for now, focus on removing duplicates within current structure.

---

## ✅ CODE AUDIT RESULTS

**Audit Completed:** Searched entire lib/ directory for all duplicate field references  
**Methodology:** grep_search for maritalStatus, reviewPack, dating.gender, displayName, etc.

### High Risk Fields - ACTIVE USAGE FOUND

#### 1. maritalStatus (6+ Active Usages)
**Files Using:**
- `compatibility_quiz_screen.dart:308` - Sets maritalStatus in quiz answers
- `compatibility_quiz_answers.dart` - Model stores/serializes maritalStatus
- `search_screen.dart:37-356` - UI state for marital status filter (6 usages)
- `profile_screen.dart:4842` - Compatibility calculation check
- `profile_screen.dart:5147` - Displays compatibility['maritalStatus']

**Code Flow:**
```
CompatibilityQuizScreen → Sets maritalStatus
    ↓ (stored to Firestore)
compatibility.maritalStatus
    ↓ (read from)
profile_screen & search_screen → Display/Filter
```

**Verdict:** 🔴 **CANNOT REMOVE** - Core feature dependency

#### 2. dating.reviewPack (Core Verification Workflow)
**Files Using:**
- `dating_profile_service.dart:81` - Builds dating.reviewPack.photoUrls
- `duplicate_detection_service.dart` - Uses reviewPack hashes (lines 60, 78, 97, 136)
- `user_model.dart:376-385` - Reads audioUrls and photoUrls from reviewPack
- `dating_contact_info_screen.dart:376` - Builds reviewPack for submission

**Why It's Different:**
- `dating.audioPrompts[]` = Live, changeable user audio
- `dating.reviewPack.audioUrls[]` = Immutable verification snapshot
- Admin verification uses reviewPack hashes to detect fraud

**Verdict:** 🔴 **CANNOT CONSOLIDATE** - Verification audit trail requires immutable snapshot

### Medium Risk Fields - LIMITED USAGE

#### 3. displayName (2 Usages)
**Files Using:**
- `profile_screen.dart:1360-1377` - Helper function returns displayName ?? name

**Code:**
```dart
String _displayName() {
  final name = currentUser.displayName ?? currentUser.name ?? '';
  return name;
}
```

**Verdict:** 🟡 **Can migrate gradually** - Only used as fallback for name

### Low/No Risk Fields - NOT FOUND IN LIB

#### 4. photos[] (Top-level)
**Search Result:** Not found in lib/ - only in docs and scripts
**Verdict:** 🟢 **Safe to remove** - Not used in app code

#### 5. dating.gender
**Search Result:** Not found in lib/ - only in migration scripts
**Verdict:** 🟢 **Safe to remove** - App uses top-level gender

#### 6. dating.contactInfo.Instagram
**Search Result:** Not found in lib/ - not used anywhere
**Verdict:** 🟢 **Safe to remove** - Use instagramUsername instead

#### 7. dating.contactInfo.countryOfResidence
**Search Result:** Not found in lib/ (only in backup script)
**Verdict:** 🟢 **Safe to remove** - Use country instead

#### 8. nexus.relationshipStatus
**Search Result:** Not found in lib/ - legacy field
**Verdict:** 🟢 **Safe to remove** - Deprecated v1 field

---

## 📊 DEDUPLICATION RECOMMENDATIONS (Based on Code Audit)

### ✅ DEFINITELY KEEP
- `maritalStatus` - Core to compatibility feature (6+ usages)
- `dating.audioPrompts[]` - Live user audio
- `dating.reviewPack.*` - Verification audit trail (immutable)
- `dating.photos[]` - Dating profile photos
- `gender` - User profile field
- `name` - User identity
- `country` - User location
- `instagramUsername` - Social identity

### 🟡 GRADUAL MIGRATION (Low Risk)
- `displayName` → Consolidate to `name` (2 usages, can update safely)

### 🗑️ SAFE TO REMOVE (No Code Usage Found)
- `photos[]` - Top-level duplicate
- `dating.gender` - Only in scripts
- `dating.contactInfo.Instagram` - Not used
- `dating.contactInfo.countryOfResidence` - Not used
- `nexus.relationshipStatus` - Legacy
- `nexus.gender` - Legacy
- `nexus.photos` - Legacy

---

## 🎯 NEXT STEPS (User Approval Required)

### HOLD ON ALL CHANGES
- Do NOT remove fields yet
- Do NOT modify code yet
- Verification workflow too critical

### Required Actions Before Proceeding
1. ✅ This code audit confirms field usage
2. ⏳ Review verification workflow for any hidden dependencies
3. ⏳ Test removing `photos[]` and `dating.gender` in staging
4. ⏳ Validate `reviewPack` immutability is working as expected

### Recommended Phase Plan
**Phase 1 (Safe):** Remove unused legacy fields (nexus.*)  
**Phase 2 (Review):** Remove unmatched duplicates (photos[], dating.gender)  
**Phase 3 (Testing):** Consolidate displayName to name  
**Phase 4 (Future):** Consider reviewPack structure cleanup

**DO NOT START until Phase review complete**

