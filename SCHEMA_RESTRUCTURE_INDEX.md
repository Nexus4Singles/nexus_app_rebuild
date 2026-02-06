# Schema Restructure - Complete Documentation Index

**Status:** 📋 Documentation Complete, Ready for Execution  
**Last Updated:** February 3, 2026  
**Phase:** 0 (Planning) ✅ Complete

---

## 📚 Documents Created (In Order)

### 1. **SCHEMA_RESTRUCTURE_SUMMARY.md** 👈 START HERE
   - **Purpose:** High-level overview
   - **Contains:** What's being done, why, timeline
   - **Read Time:** 5 minutes
   - **Action:** Read first to understand the plan

### 2. **DUPLICATE_REMOVAL_REFERENCE.md** 
   - **Purpose:** Exact fields being removed
   - **Contains:** Field-by-field removal list with reasons
   - **Read Time:** 5 minutes
   - **Action:** Review before executing removal script

### 3. **SCHEMA_RESTRUCTURE_EXECUTION_PLAN.md**
   - **Purpose:** Two-phase overview
   - **Contains:** Phase 1 (remove duplicates) and Phase 2 (restructure)
   - **Read Time:** 3 minutes
   - **Action:** Reference during execution

### 4. **SCHEMA_RESTRUCTURE_GUIDE.md** ⭐ MOST IMPORTANT
   - **Purpose:** Step-by-step execution guide
   - **Contains:** Pre-checks, dry-runs, verification, rollback
   - **Read Time:** 20 minutes
   - **Action:** Follow this during actual execution
   - **Includes:** Backup procedures, testing checklist, troubleshooting

### 5. **CODE_UPDATE_PLAN.md**
   - **Purpose:** Code changes needed after Firestore updates
   - **Contains:** File-by-file code updates, migration strategy
   - **Read Time:** 30 minutes
   - **Action:** Use after Phase 1 & 2 complete

### 6. **FIRESTORE_USER_SCHEMA_ANALYSIS.md**
   - **Purpose:** Original code audit findings
   - **Contains:** Which fields are actually used in code
   - **Read Time:** 15 minutes
   - **Action:** Reference if you have questions about why fields are kept/removed

---

## 🛠️ Scripts Created

### 1. scripts/remove_duplicate_fields.js
```bash
# Test first (no changes)
node scripts/remove_duplicate_fields.js --dry-run

# Actually remove duplicates
node scripts/remove_duplicate_fields.js
```
- Removes 7 unused duplicate fields
- Safe operation - only deletes confirmed unused fields
- ~5 minute execution time
- Includes progress logging

### 2. scripts/restructure_schema.js
```bash
# Test first (no changes)
node scripts/restructure_schema.js --dry-run

# Actually restructure
node scripts/restructure_schema.js
```
- Moves data to new organized structure
- Creates subcollections
- ~15 minute execution time
- Includes progress logging

---

## 📋 Execution Checklist

### Pre-Execution
- [ ] Read SCHEMA_RESTRUCTURE_SUMMARY.md
- [ ] Review DUPLICATE_REMOVAL_REFERENCE.md
- [ ] Create Firestore backup
- [ ] Get Firebase Admin credentials
- [ ] Clear schedule for ~1 hour

### Phase 1: Remove Duplicates
- [ ] Run dry-run: `node scripts/remove_duplicate_fields.js --dry-run`
- [ ] Review output looks correct
- [ ] Execute: `node scripts/remove_duplicate_fields.js`
- [ ] Verify in Firebase Console

### Phase 2: Restructure Schema
- [ ] Run dry-run: `node scripts/restructure_schema.js --dry-run`
- [ ] Review output looks correct
- [ ] Execute: `node scripts/restructure_schema.js`
- [ ] Verify new collection structure in Firebase Console

### Phase 3: Update Code (Later)
- [ ] Follow CODE_UPDATE_PLAN.md
- [ ] Update firestore_service.dart
- [ ] Update user_model.dart
- [ ] Test thoroughly
- [ ] Deploy to staging
- [ ] Deploy to production

---

## 🎯 Quick Reference

### What's Being Removed?
7 duplicate fields that aren't used:
- `photos[]` (top-level)
- `dating.gender`
- `dating.contactInfo.Instagram`
- `dating.contactInfo.countryOfResidence`
- `nexus.relationshipStatus`
- `nexus.gender`
- `nexus.photos`

### What's Staying?
All core fields:
- `maritalStatus` (used 6+ times)
- `dating.reviewPack.*` (verification audit trail)
- `gender`, `name`, `country`
- All identity and dating fields

### What's Reorganizing?
```
OLD: users/{uid} (flat structure)
NEW: users/{uid}/profile/data
     users/{uid}/dating/data
     users/{uid}/compatibility/data
     users/{uid}/verification/data
     users/{uid}/assessments/ (collection)
     users/{uid}/journeys/ (collection)
```

---

## ⏱️ Timeline

| Phase | Task | Duration |
|-------|------|----------|
| Pre | Backup | 10 min |
| 1 | Remove duplicates | 5 min |
| 2 | Restructure | 15 min |
| 2 | Update rules | 5 min |
| 3 | Code updates | 4-6 hours |
| 3 | Testing | 2-3 hours |
| Total | All phases | 7-9 hours |

---

## ❓ FAQ

**Q: What if I run the script and something breaks?**  
A: Firestore backup is available. Can restore instantly. See rollback section in SCHEMA_RESTRUCTURE_GUIDE.md

**Q: Will users notice anything?**  
A: No - they'll see the same data, just better organized.

**Q: How long until users can log in again?**  
A: Phase 1 & 2 take ~30 min. Code updates take 4-6 hours before production deploy.

**Q: Can I skip any phases?**  
A: No - they depend on each other. Must do: Phase 1 → Phase 2 → Phase 3 → Test → Deploy

**Q: What about maritalStatus - why not remove it?**  
A: It's used 6+ times in compatibility feature - not a duplicate.

**Q: What about reviewPack - why not remove it?**  
A: It's an immutable verification snapshot - different purpose from live data.

**Q: What if dry-run shows errors?**  
A: Check the error message. Most likely: permissions or duplicate field names. Fix and retry.

---

## 📞 Support

### If Something Goes Wrong

1. **Check logs** - See what exactly failed
2. **Consult troubleshooting** - See SCHEMA_RESTRUCTURE_GUIDE.md "Troubleshooting" section
3. **Restore backup** - `gcloud firestore backups restore BACKUP_NAME`
4. **Investigate root cause** - Why did script fail?
5. **Fix and retry** - Or contact support

### Common Issues

| Issue | Solution |
|-------|----------|
| Permission denied | Check serviceAccount.json has admin rights |
| Timeout | Large Firestore database - run in smaller batches |
| Document too large | Remove old data first, then restructure |
| Script crashes | Check for sufficient memory, retry |

---

## ✅ Success Indicators

After all phases complete, you should see:
- ✅ Firestore has new organized structure
- ✅ All old duplicate fields removed
- ✅ App updated to read from new paths
- ✅ All tests passing
- ✅ Users can log in and use app
- ✅ No errors in Cloud Logging

---

## 🚀 Ready to Start?

### Step 1: Understand the Plan
- Read SCHEMA_RESTRUCTURE_SUMMARY.md (5 min)
- Skim DUPLICATE_REMOVAL_REFERENCE.md (5 min)

### Step 2: Prepare Environment
- Backup Firestore database
- Get Firebase credentials
- Set aside ~1 hour

### Step 3: Execute Phase 1
- Follow SCHEMA_RESTRUCTURE_GUIDE.md
- Run removal script
- Verify results

### Step 4: Execute Phase 2  
- Run restructuring script
- Verify new structure

### Step 5: Update Code
- Follow CODE_UPDATE_PLAN.md
- Update all necessary files
- Test thoroughly

### Step 6: Deploy
- Merge code changes
- Deploy to staging
- Deploy to production

---

## 📎 Document Dependencies

```
Start Here:
  ↓
SCHEMA_RESTRUCTURE_SUMMARY.md (Overview)
  ↓
DUPLICATE_REMOVAL_REFERENCE.md (What's being removed)
  ↓
SCHEMA_RESTRUCTURE_GUIDE.md (How to execute) ⭐ MAIN GUIDE
  ├→ scripts/remove_duplicate_fields.js (Phase 1)
  └→ scripts/restructure_schema.js (Phase 2)
  ↓
CODE_UPDATE_PLAN.md (Code changes)
  ↓
FIRESTORE_USER_SCHEMA_ANALYSIS.md (Reference - why decisions made)
```

---

## 📅 Next Steps

1. ✅ **Review** - You're reading this
2. ⏳ **Decide** - Approve the plan
3. ⏳ **Prepare** - Backup Firestore
4. ⏳ **Execute** - Run Phase 1
5. ⏳ **Verify** - Check results
6. ⏳ **Execute** - Run Phase 2
7. ⏳ **Update Code** - Follow CODE_UPDATE_PLAN
8. ⏳ **Test** - Comprehensive testing
9. ⏳ **Deploy** - To production

---

**Questions?** Review the relevant document above or check troubleshooting section.

**Ready to proceed?** Confirm approval to start Phase 1.
