# Duplicate Fields - Removal Reference

**Last Updated:** February 3, 2026  
**Status:** Ready for Execution  
**Operation:** Remove only - Keep primary field

---

## Fields to REMOVE (Duplicate)

### 1. Top-Level Photos Array
```
REMOVE: users/{uid}.photos[]
KEEP:   users/{uid}.dating.photos[]
REASON: App only uses dating.photos[]
IMPACT: None - not referenced in code
```

### 2. Dating Gender Field
```
REMOVE: users/{uid}.dating.gender
KEEP:   users/{uid}.gender
REASON: Top-level is source of truth
IMPACT: None - not referenced in code
```

### 3. Dating Contact Info - Instagram
```
REMOVE: users/{uid}.dating.contactInfo.Instagram
KEEP:   users/{uid}.instagramUsername
REASON: Top-level is source of truth
IMPACT: None - not referenced in code
```

### 4. Dating Contact Info - Country
```
REMOVE: users/{uid}.dating.contactInfo.countryOfResidence
KEEP:   users/{uid}.country
REASON: Top-level is source of truth
IMPACT: None - verified in backup script only
```

### 5. Legacy Nexus Relationship Status
```
REMOVE: users/{uid}.nexus.relationshipStatus
KEEP:   users/{uid}.dating.relationshipStatus
REASON: Nexus is legacy v1, dating is v2
IMPACT: None - nexus is deprecated
```

### 6. Legacy Nexus Gender
```
REMOVE: users/{uid}.nexus.gender
KEEP:   users/{uid}.gender
REASON: Nexus is legacy v1
IMPACT: None - not referenced
```

### 7. Legacy Nexus Photos
```
REMOVE: users/{uid}.nexus.photos
KEEP:   users/{uid}.dating.photos[]
REASON: Nexus is legacy v1
IMPACT: None - deprecated
```

### 8. Legacy Review Pack Audio URLs
```
REMOVE: users/{uid}.dating.reviewPack.audioUrls (CONDITIONAL)
KEEP:   users/{uid}.dating.audioPrompts[] (live) AND dating.reviewPack.audioUrls (snapshot)
REASON: reviewPack is immutable verification snapshot, not a duplicate
IMPACT: DO NOT REMOVE - needed for verification audit trail
```

### 9. Legacy Review Pack Photo URLs
```
REMOVE: users/{uid}.dating.reviewPack.photoUrls (CONDITIONAL)
KEEP:   users/{uid}.dating.photos[] (live) AND dating.reviewPack.photoUrls (snapshot)
REASON: reviewPack is immutable verification snapshot, not a duplicate
IMPACT: DO NOT REMOVE - needed for verification audit trail
```

---

## Fields to KEEP (NOT Duplicates)

### Core Identity Fields
```
✅ users/{uid}.name
✅ users/{uid}.gender
✅ users/{uid}.country
✅ users/{uid}.dateOfBirth
✅ users/{uid}.displayName (used 2x, will consolidate to name later)
```

### Dating Fields
```
✅ users/{uid}.dating.relationshipStatus (source of truth for maritalStatus)
✅ users/{uid}.dating.photos[] (live dating profile photos)
✅ users/{uid}.dating.audioPrompts[] (live audio responses)
✅ users/{uid}.dating.contactInfo (remaining fields)
```

### Verification Fields
```
✅ users/{uid}.dating.reviewPack.* (entire structure)
   - Immutable snapshot for fraud detection
   - Different purpose from live data
   - Contains hashes for duplicate detection
```

### Compatibility Fields
```
✅ users/{uid}.compatibility.* (all fields)
✅ users/{uid}.maritalStatus (used 6+ times, kept for compatibility feature)
```

### Other Core Fields
```
✅ users/{uid}.stories[]
✅ users/{uid}.polls[]
✅ users/{uid}.assessments (to become collection)
✅ users/{uid}.journeyProgress (to become collection)
✅ users/{uid}.verification
✅ users/{uid}.settings
```

---

## Execution Checklist

### Before Running Scripts
- [ ] Backup Firestore database
- [ ] Confirm you have Firebase Admin credentials
- [ ] Review this document one more time
- [ ] Ensure no users logged in (optional but safer)

### Running Remove Duplicates Script
```bash
# Navigate to project directory
cd /Users/aybaj/Documents/nexus_app_v2

# Test first (no changes)
node scripts/remove_duplicate_fields.js --dry-run

# Then execute
node scripts/remove_duplicate_fields.js
```

### Expected Results After Execution
- Total users processed: [your number]
- Successfully updated: [should match total]
- Errors: 0

### Verification in Firebase Console
Go to: Firestore → users → [any user document]

**Fields that should be GONE:**
- ❌ photos (top-level)
- ❌ dating.gender
- ❌ dating.contactInfo.Instagram
- ❌ dating.contactInfo.countryOfResidence
- ❌ nexus.relationshipStatus
- ❌ nexus.gender
- ❌ nexus.photos

**Fields that should STILL EXIST:**
- ✅ dating.photos[]
- ✅ gender
- ✅ country
- ✅ instagramUsername
- ✅ dating.relationshipStatus
- ✅ dating.reviewPack (entire structure)
- ✅ maritalStatus
- ✅ All other fields

---

## Quick FAQ

**Q: Will this break the app?**  
A: No - we're only removing unused duplicates. Primary fields stay.

**Q: What if something goes wrong?**  
A: We have a Firestore backup. Can restore instantly.

**Q: How long does it take?**  
A: ~5 minutes for all users.

**Q: Can I stop it mid-way?**  
A: No - let it complete. If there's an error, restore from backup and fix.

**Q: Will users lose data?**  
A: No - we keep the primary field, only remove the duplicate.

**Q: What about maritalStatus - why keep it?**  
A: It's used 6+ times in compatibility code - it's NOT a duplicate.

**Q: What about reviewPack - why keep it?**  
A: It's an immutable verification snapshot - different purpose from live data.

---

**Status:** Ready to execute  
**Approval Needed:** Confirm before running remove_duplicate_fields.js
