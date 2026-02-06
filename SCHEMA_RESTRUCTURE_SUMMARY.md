# Schema Restructure - Complete Plan Summary

**Status:** ✅ Ready for Execution  
**Last Updated:** February 3, 2026  
**Prepared By:** Code Audit & Analysis

---

## What's Being Done

### Phase 1: Remove Duplicates (NO CODE CHANGES)
**Files Being Removed from Firestore:**
- `photos[]` top-level ➜ keep `dating.photos[]`
- `dating.gender` ➜ keep `gender`
- `dating.contactInfo.Instagram` ➜ keep `instagramUsername`
- `dating.contactInfo.countryOfResidence` ➜ keep `country`
- `nexus.relationshipStatus` ➜ keep `dating.relationshipStatus`
- `nexus.gender` ➜ keep `gender`
- `nexus.photos` ➜ keep `dating.photos[]`

**Script:** `scripts/remove_duplicate_fields.js`
- Safe operation - only removes unused duplicates
- Dry-run available: `node scripts/remove_duplicate_fields.js`
- Execute: `node scripts/remove_duplicate_fields.js`

### Phase 2: Restructure Schema (REQUIRES CODE UPDATES)
**New Organized Structure:**

```
users/{uid}/
├── profile/data
│   ├── name
│   ├── gender
│   ├── country
│   └── [identity fields]
├── dating/data
│   ├── relationshipStatus
│   ├── photos[]
│   ├── audioPrompts[]
│   ├── reviewPack {}
│   └── contactInfo {}
├── compatibility/data
│   ├── maritalStatus
│   └── preferences
├── verification/data
├── settings/data
├── assessments/ (collection)
├── journeys/ (collection)
├── stories/ (collection)
└── polls/ (collection)
```

**Script:** `scripts/restructure_schema.js`
- Moves data to new structure
- Creates subcollections
- Dry-run available: `node scripts/restructure_schema.js --dry-run`
- Execute: `node scripts/restructure_schema.js`

---

## What Stays the Same (No Removal)

✅ **NOT Duplicates - These Are Core Features:**
- `maritalStatus` - Used 6+ times in compatibility feature
- `dating.reviewPack.*` - Immutable verification audit trail
- `dating.audioPrompts[]` - Live user audio
- All other fields needed by features

---

## Step-by-Step Execution

### 1. Backup Firestore
```bash
gcloud firestore export gs://nexus-app-backups/backup-$(date +%Y%m%d)
```

### 2. Remove Duplicates
```bash
# Test first
node scripts/remove_duplicate_fields.js --dry-run

# Execute
node scripts/remove_duplicate_fields.js
```

### 3. Restructure Schema
```bash
# Test first
node scripts/restructure_schema.js --dry-run

# Execute
node scripts/restructure_schema.js
```

### 4. Update Firestore Rules
- Update security rules for new paths
- Deploy: `firebase deploy --only firestore:rules`

### 5. Update App Code (Next Phase)
- Update `firestore_service.dart`
- Update `user_model.dart`
- Update path references throughout

### 6. Test Everything
- Unit tests
- Integration tests
- Smoke tests in staging
- Deploy to production

---

## Documents Created

1. **SCHEMA_RESTRUCTURE_EXECUTION_PLAN.md**
   - Overview of phases
   - Field removal list
   - Target structure

2. **SCHEMA_RESTRUCTURE_GUIDE.md**
   - Detailed execution steps
   - Pre-checks
   - Verification procedures
   - Rollback process
   - Troubleshooting

3. **scripts/remove_duplicate_fields.js**
   - Removes unused duplicate fields
   - Safe operation (dry-run option)
   - Progress logging

4. **scripts/restructure_schema.js**
   - Moves data to new structure
   - Creates subcollections
   - Dry-run option

---

## Risk Assessment

| Risk | Level | Mitigation |
|------|-------|-----------|
| Data loss | HIGH | Backup before running |
| App breaks | HIGH | Use dual-write during transition |
| User locks | MEDIUM | Run at low-traffic time |
| Rollback needed | MEDIUM | Backup available |

---

## Estimated Timeline

- Backup: 10 min
- Remove duplicates: 5 min
- Restructure: 15 min
- Update rules: 5 min
- Total: ~35 min + code updates

---

## Next Actions (User Approval Required)

1. ✅ **Review this plan** - Ensure you agree with approach
2. ⏳ **Approve duplicate removal list** - Confirm fields to remove
3. ⏳ **Backup Firestore** - Create backup before starting
4. ⏳ **Execute Phase 1** - Run remove_duplicate_fields.js
5. ⏳ **Execute Phase 2** - Run restructure_schema.js
6. ⏳ **Update app code** - Modify service layer for new paths
7. ⏳ **Test thoroughly** - Unit + integration + smoke tests
8. ⏳ **Deploy to production** - Roll out gradually

---

## Questions?

- **Which fields are being removed?** See "Phase 1: Remove Duplicates" section
- **Why keep maritalStatus?** It's used 6+ times - not a duplicate
- **Why keep reviewPack?** It's for verification audit trail - different purpose from live data
- **Can I roll back?** Yes - we backup first, can restore if needed
- **Will users notice?** No - same data, just better organized

**Ready to proceed?** Confirm approval for Phase 1 execution.
