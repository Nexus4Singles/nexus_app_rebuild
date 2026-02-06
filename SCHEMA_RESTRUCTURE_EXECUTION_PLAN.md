# Schema Restructure Execution Plan

**Status:** Ready for Implementation  
**Last Updated:** February 3, 2026

---

## Phase 1: Remove Duplicate Fields (NO CODE CHANGES - FIRESTORE ONLY)

### Safe Duplicates to Remove (Keep Primary Field)

| Duplicate | Primary | Action |
|-----------|---------|--------|
| `photos[]` | `dating.photos[]` | Remove from all user docs |
| `dating.gender` | `gender` | Remove from dating object |
| `dating.contactInfo.Instagram` | `instagramUsername` | Remove from dating.contactInfo |
| `dating.contactInfo.countryOfResidence` | `country` | Remove from dating.contactInfo |
| `nexus.relationshipStatus` | `dating.relationshipStatus` | Remove (legacy) |
| `nexus.gender` | `gender` | Remove (legacy) |
| `nexus.photos` | `dating.photos[]` | Remove (legacy) |

### Fields to KEEP (Not Duplicates)
- ✅ `maritalStatus` - Core feature, not a duplicate
- ✅ `dating.reviewPack.*` - Verification snapshot, different purpose
- ✅ `dating.audioPrompts[]` vs `dating.reviewPack.audioUrls[]` - Different purposes (live vs snapshot)

---

## Phase 2: Restructure Schema (AFTER Phase 1 Complete)

### Current Structure (Flat)
```
users/{uid}/
├── profile fields (name, gender, etc.)
├── dating { ... }
├── nexus { ... (legacy) }
├── nexus2 { ... }
├── compatibility { ... }
├── chat related fields
├── stories [ ... ]
├── polls [ ... ]
├── journeyProgress { ... }
├── assessments { ... }
└── [other fields]
```

### Target Structure (Organized)
```
users/{uid}/
├── profile/ (document with basic fields)
│   ├── name
│   ├── gender
│   ├── country
│   ├── dateOfBirth
│   └── ... other identity fields
├── dating/ (document with dating-specific data)
│   ├── relationshipStatus
│   ├── photos[]
│   ├── audioPrompts[]
│   ├── contactInfo {}
│   ├── reviewPack {}
│   └── ... other dating fields
├── compatibility/ (document)
│   └── maritalStatus
│   └── preferences {}
├── assessments/ (collection of assessment records)
│   ├── {assessmentId1}
│   └── {assessmentId2}
├── journeys/ (collection of journey records)
│   ├── {journeyId1}
│   └── {journeyId2}
├── verification/ (document)
│   ├── status
│   ├── reviewedAt
│   └── ... verification fields
├── stories/ (collection)
│   ├── {storyId1}
│   └── {storyId2}
├── polls/ (collection)
│   ├── {pollId1}
│   └── {pollId2}
└── settings/ (document)
    ├── privacy
    ├── notifications
    └── ... user settings
```

### Implementation Approach
1. **Data Migration:** Create Firestore functions to move data to new structure
2. **Code Updates:** Update all service methods to read from new paths
3. **Dual-Write:** Temporary support for old paths during transition
4. **Verification:** Test all features work with new paths
5. **Cleanup:** Remove old paths after verification

---

## Next Steps

1. ✅ Review and approve duplicate removal list
2. ⏳ Execute Phase 1: Firestore script to remove duplicates
3. ⏳ Execute Phase 2: Migration script to restructure
4. ⏳ Update lib/ code to read from new paths
5. ⏳ Testing in staging environment
6. ⏳ Gradual production rollout
