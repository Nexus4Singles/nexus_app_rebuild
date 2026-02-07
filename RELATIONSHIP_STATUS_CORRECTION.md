# Relationship Status Correction - 4 Statuses, Not 5

## Issue Identified
The relationship status feature was initially documented and implemented with 5 options:
- `'Single'`
- `'Never Married'`
- `'Divorced'`
- `'Widowed'`
- `'Married'`

However, the actual `RelationshipStatus` enum only has 4 values:
1. `singleNeverMarried` → stored as `'single_never_married'` or `'never_married'`
2. `married` → stored as `'married'`
3. `divorced` → stored as `'divorced'`
4. `widowed` → stored as `'widowed'`

## Root Cause
The dialog was incorrectly showing both `'Single'` and `'Never Married'` as separate options when they should be one: `singleNeverMarried`.

## Corrections Applied

### 1. **relationship_status_editor.dart** - Dialog Updated
**File:** `/Users/aybaj/Documents/nexus_app_v2/lib/features/profile/presentation/widgets/relationship_status_editor.dart`

**Changes:**
- **Line 87-95** - Updated `_getStatusLabel()` to handle all mappings correctly
  - `'single'`, `'single_never_married'`, `'never_married'`, `'never married'` → `'Never Married'`
  - `'divorced'` → `'Divorced'`
  - `'widowed'` → `'Widowed'`
  - `'married'` → `'Married'`

- **Line 112-117** - Updated `statusOptions` array to 4 values
  ```dart
  final statusOptions = [
    'never_married',   // NOT 'Single' + 'Never Married'
    'married',
    'divorced',
    'widowed',
  ];
  ```

- **Line 142-143** - Display label mapping for user-friendly names
  ```dart
  final displayLabel = _getStatusLabel(status);
  ```

- **Line 90-99** - Moved `_getStatusLabel()` outside widget class for reuse

### 2. **relationship_status_provider.dart** - Archiving Logic Updated
**File:** `/Users/aybaj/Documents/nexus_app_v2/lib/core/providers/relationship_status_provider.dart`

**Changes:**
- **Line 46-48** - Updated eligible status check to include all variations
  ```dart
  if (['single', 'divorced', 'widowed', 'never_married', 'single_never_married', 'never married']
      .contains(newStatus.toLowerCase())) {
  ```
  This ensures `'never_married'` (what we now send) correctly triggers profile reactivation.

### 3. **RELATIONSHIP_STATUS_FEATURE.md** - Documentation Updated
**File:** `/Users/aybaj/Documents/nexus_app_v2/RELATIONSHIP_STATUS_FEATURE.md`

**Changes:**
- **Line 47** - Corrected option count from 5 to 4
  - **Before:** `5 options: Single, Never Married, Divorced, Widowed, Married`
  - **After:** `4 options: Never Married, Married, Divorced, Widowed`

## Verification - No Breaking Changes

### Existing Code Compatibility
All existing code continues to work because:

1. **Dialog Output** → Firestore stores `'never_married'` (instead of `'single'`)
   - Parser in `effective_relationship_status_provider.dart` handles this: 
     ```dart
     case 'never_married':
       return RelationshipStatus.singleNeverMarried;
     ```
   - ✓ Correctly maps to enum

2. **Profile Archiving** → Now accepts all variations
   - Check for `'never_married'` in addition to existing checks
   - ✓ Dating profile reactivation works

3. **Enum Usage** → All code uses `RelationshipStatus.singleNeverMarried`
   - UI renders correctly regardless of stored string value
   - Assessments/journeys load correctly based on enum
   - ✓ No impact on business logic

### Files NOT Affected (Verified)
These files continue to work without modification:
- `lib/core/constants/app_constants.dart` - Enum definitions correct
- `lib/core/session/effective_relationship_status_provider.dart` - Parser handles 'never_married'
- `lib/features/presurvey/presentation/screens/presurvey_relationship_status_screen.dart` - Shows 4 options
- `lib/features/guest/relationship_status_picker_screen.dart` - Shows 4 options
- `lib/core/services/journeys_service.dart` - Uses enum, not strings
- `lib/core/models/user_model.dart` - Uses enum, not strings

### Analysis Results
- `relationship_status_editor.dart` - ✅ No issues
- `relationship_status_provider.dart` - ✅ No issues  
- `effective_relationship_status_provider.dart` - ✅ No issues
- `profile_screen.dart` - ✅ No issues

## Status Change Scenarios - All Working

### Scenario 1: Never Married → Married
1. User selects `'never_married'` → Married
2. Dialog passes `'married'` to updater
3. Firestore: `nexus2.relationshipStatus = 'married'`
4. Dating profile: `isActive = false` (archived)
5. Parser reads `'married'` → `RelationshipStatus.married`
6. Profile switches to basic, shows marriage journeys/assessments
✅ **Working**

### Scenario 2: Married → Divorced
1. User selects Married → `'divorced'`
2. Dialog passes `'divorced'` to updater
3. Firestore: `nexus2.relationshipStatus = 'divorced'`
4. Dating profile: `isActive = true` (reactivated)
5. Parser reads `'divorced'` → `RelationshipStatus.divorced`
6. Profile switches to dating, shows divorce/remarriage journeys
✅ **Working**

### Scenario 3: Widowed → Never Married
1. User selects Widowed → `'never_married'`
2. Dialog passes `'never_married'` to updater
3. Firestore: `nexus2.relationshipStatus = 'never_married'`
4. Dating profile: `isActive = true` (reactivated)
5. Parser reads `'never_married'` → `RelationshipStatus.singleNeverMarried`
6. Profile switches to dating, shows singles journeys
✅ **Working**

## Data Integrity
- Existing users with `'single_never_married'` in Firestore: ✅ Unaffected (parser handles both)
- Existing users with `'never_married'` in Firestore: ✅ Now correctly parsed
- New updates use `'never_married'`: ✅ Parser handles it
- All archived profiles stay archived: ✅ Logic unchanged
- All reactivation logic works: ✅ Updated to check `'never_married'`

## Summary
✅ Dialog now shows correct 4 options
✅ Status values consistent with enum
✅ Parser handles all variations
✅ Archiving logic updated
✅ No breaking changes to existing data
✅ All status transitions working correctly
✅ All related files compile without errors
✅ Complete provider cascade working end-to-end
