# Dating Profile Reactivation - User Choice Flow

## Summary
When users switch their relationship status FROM married back to an eligible dating status (single, divorced, widowed), they are **explicitly asked** whether they want to reactivate their dating profile. This maintains consistency with the dating opt-in philosophy - **no automatic enrollment**.

## User Flow

### Scenario: User Changes Married → Divorced

**Step 1: User Opens Status Dialog**
- Current status: "Married" (basic profile)
- Dialog shows 4 options: Never Married, Married, Divorced, Widowed

**Step 2: User Selects "Divorced"**
- System detects this is a transition FROM married
- Status update sent to Firestore

**Step 3: Dating Profile Reactivation Prompt Appears**
```
┌─────────────────────────────────────┐
│  Reactivate Dating Profile?         │
├─────────────────────────────────────┤
│  You previously had a dating        │
│  profile. Would you like to         │
│  reactivate it now?                 │
│                                     │
│  ℹ️ Your profile data has been      │
│  kept safe. You can reactivate     │
│  it anytime.                        │
│                                     │
│  [Keep as Basic Profile] [Reactivate] │
└─────────────────────────────────────┘
```

**Step 4: User Chooses**

**Option A: "Keep as Basic Profile"**
- Dating profile stays archived (`isActive = false`)
- User stays on basic profile
- Can reactivate later from profile settings
- Success: "Relationship status updated to Divorced ✓"

**Option B: "Reactivate Dating Profile"**
- Sets `dating.profile.isActive = true`
- Firestore updated atomically
- Provider cascade invalidated
- UI updates to show dating profile
- Success: "Dating profile reactivated! Your profile is now visible. ✓"

## Implementation Details

### Files Modified

#### 1. `relationship_status_provider.dart`
**Change:** Removed automatic reactivation logic
```dart
// OLD: Automatically reactivated dating profiles
if (['single', 'divorced', 'widowed', 'never_married']
    .contains(newStatus.toLowerCase())) {
  batch.set(datingProfileRef, {'isActive': true}, SetOptions(merge: true));
}

// NEW: No auto-reactivation - user is asked explicitly
// NOTE: Do NOT auto-reactivate dating profiles when switching from married.
// User will be prompted to explicitly opt-in via showRelationshipStatusDialog().
```

#### 2. `relationship_status_editor.dart`
**Changes:**
- Detect transition FROM married to eligible status
- Show reactivation prompt instead of auto-reactivating
- Call `_showReactivateDatingProfileDialog()` function
- Handle both user choices (YES/NO)

```dart
// Detect if transitioning from married to dating-eligible status
final isReactivatingDating = oldStatus == 'married' &&
    ['single', 'divorced', 'widowed', 'never_married']
        .contains(newStatus);

if (isReactivatingDating) {
  // Show prompt instead of auto-reactivating
  _showReactivateDatingProfileDialog(...);
}
```

### New Function: `_showReactivateDatingProfileDialog()`
**Location:** End of `relationship_status_editor.dart`

**Responsibilities:**
1. Display user-friendly dialog
2. Handle "Keep as Basic Profile" → Close dialog, show success
3. Handle "Reactivate Dating Profile" → Set `isActive = true`, invalidate providers, show success

**Firestore Operations:**
```dart
// Reactivation is just one atomic operation:
await datingProfileRef.set(
  {'isActive': true},
  SetOptions(merge: true),  // Only updates isActive, preserves all other fields
);
```

## Provider Cascade on Reactivation

When user clicks "Reactivate Dating Profile":
1. `dating.profile.isActive` set to `true` in Firestore
2. `currentUserDocProvider` invalidated (reads from Firestore)
3. `effectiveRelationshipStatusProvider` refreshes (now reads new status + reactivated profile)
4. `journeyCatalogProvider` refreshes (loads dating journeys if eligible status)
5. `recommendedAssessmentTypeProvider` refreshes (may load dating assessments)
6. UI updates immediately to show dating profile

## Scenarios Covered

### ✅ Single → Married (Archive Profile)
- Dialog shows message about archiving
- Profile archived with `isActive = false`
- Profile moved to basic profile tab
- **No reactivation prompt** (archiving, not reactivating)

### ✅ Married → Divorced (Prompt for Reactivation)
- Status updated to divorced
- **Reactivation prompt shown**
- User chooses: Keep basic OR reactivate dating
- Profile data preserved either way

### ✅ Married → Single (Prompt for Reactivation)
- Status updated to single
- **Reactivation prompt shown**
- User chooses: Keep basic OR reactivate dating
- Profile data preserved either way

### ✅ Married → Widowed (Prompt for Reactivation)
- Status updated to widowed
- **Reactivation prompt shown**
- User chooses: Keep basic OR reactivate dating
- Profile data preserved either way

### ✅ Single → Divorced (No Prompt)
- Both are dating-eligible statuses
- Status changes but profile stays active
- **No reactivation prompt** (already dating)
- Seamless transition

### ✅ Divorced → Widowed (No Prompt)
- Both are dating-eligible statuses
- Status changes but profile stays active
- **No reactivation prompt** (already dating)
- Seamless transition

## Firestore Cost Impact

### Minimal Firestore Operations
- **Status update:** 1 write operation
- **Archive:** 1 update operation (if married)
- **Reactivation (if user chooses YES):** 1 update operation
- **No cascading deletes or complex queries**

### Cost Per Status Change
- Married → Divorced (then choose YES): ~2 write operations
- Married → Divorced (then choose NO): ~1 write operation
- Single → Divorced: ~1 write operation

**Efficiency:** Optimized for minimal writes ✓

## User Experience Benefits

1. **Explicit Opt-In** - Respects user choice, consistent with dating opt-in philosophy
2. **Data Safety** - Users see message that profile is preserved
3. **Flexible** - Can choose to stay basic or reactivate
4. **Non-Destructive** - Profile data never lost
5. **Easy Recovery** - Can reactivate anytime from profile settings

## Technical Safeguards

✅ Detection logic confirms transition FROM married
✅ Only prompts for eligible dating statuses
✅ Firestore batch operations keep data consistent
✅ Provider cascade ensures UI updates immediately
✅ Error handling for reactivation failures
✅ User feedback via SnackBars for all outcomes
