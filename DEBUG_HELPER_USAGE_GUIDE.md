# Debug Helper - Grace Period Testing Guide

**Flag Location:** `dating_clicked_profiles_provider.dart` line 269  
**Status:** Currently = `false` (all debug methods disabled)  

---

## Quick Start

### Step 1: Enable Debug Mode
Change line 269 from:
```dart
const bool DEBUG_CLICKED_PROFILES_TESTING = false;
```
To:
```dart
const bool DEBUG_CLICKED_PROFILES_TESTING = true;  // ← ENABLE FOR TESTING
```

This enables all 3 debug methods. Debug logs will now appear in console.

---

### Step 2: Use the Debug Helpers

#### Method A: Add Profile Simulating Old Click
```dart
final userId = FirebaseAuth.instance.currentUser?.uid;
if (userId != null) {
  // Simulate a profile clicked 25 hours ago
  await ref.read(clickedProfilesProvider.notifier)
      .debugAddOldClickedProfile(userId, "test_profile_123", 25);
}
```

**Expected Logs:**
```
[DEBUG-CLICKED] ✓ Added test_profile_123 (simulated 25 hours ago)
[DEBUG-CLICKED] Timestamp: 2026-03-24T13:30:45.123Z
[DEBUG-CLICKED] Total in state: 1
```

Then navigate back to search screen:
```
[CachedResults] Premium user: filtered 1 clicked profiles | 12 → 11 total
```

**Verification:** Profile should be hidden from grid ✅

---

#### Method B: View All Clicked Profiles
```dart
await ref.read(clickedProfilesProvider.notifier)
    .debugPrintAllClicked(userId);
```

**Expected Output:**
```
[DEBUG-CLICKED] ========== CLICKED PROFILES DUMP ==========
[DEBUG-CLICKED] Total profiles: 3
[DEBUG-CLICKED] - test_profile_123 | 25h ago | PERMANENT
[DEBUG-CLICKED] - recent_profile_456 | 2h ago | GRACE
[DEBUG-CLICKED] - boundary_789 | 24h ago | PERMANENT
[DEBUG-CLICKED] =============================================
```

---

#### Method C: Clear All Clicked Profiles
```dart
await ref.read(clickedProfilesProvider.notifier)
    .debugClearAllClicked(userId);
```

**Expected Log:**
```
[DEBUG-CLICKED] ✓ Cleared all 3 profiles
```

---

## Testing Flow

### Test 1: Single Old Profile Hiding

```
1. Call: debugAddOldClickedProfile(userId, "jane", 25)
   ├─ Logs:
   │  ├─ [DEBUG-CLICKED] ✓ Added jane (simulated 25 hours ago)
   │  ├─ [DEBUG-CLICKED] Timestamp: ...
   │  └─ [DEBUG-CLICKED] Total in state: 1
   │
2. Navigate/Refresh search screen
   ├─ Expected Log: [CachedResults] Premium user: filtered 1 clicked | 12 → 11
   ├─ Visual: Jane NOT in grid
   └─ Count: 11 profiles shown (not 12) ✅
   
3. Call: debugPrintAllClicked(userId)
   ├─ Expected: jane shows "25h ago | PERMANENT"
   └─ Verify: Data persisted correctly ✅
```

### Test 2: Multiple Profiles at Grace Period Boundary

```
1. Call: debugAddOldClickedProfile(userId, "alex", 23)   // <24h (grace)
2. Call: debugAddOldClickedProfile(userId, "maria", 24)  // =24h (boundary)
3. Call: debugAddOldClickedProfile(userId, "john", 25)   // >24h (permanent)
   
   Logs:
   ├─ [DEBUG-CLICKED] ✓ Added alex (simulated 23 hours ago)
   ├─ [DEBUG-CLICKED] ✓ Added maria (simulated 24 hours ago)
   └─ [DEBUG-CLICKED] ✓ Added john (simulated 25 hours ago)

4. Navigate/Refresh
   ├─ Expected: [CachedResults] Premium user: filtered 3 clicked | 12 → 9
   ├─ Visual: All 3 hidden (current implementation hides all)
   └─ Grid shows 9 profiles ✅

5. Call: debugPrintAllClicked(userId)
   ├─ Expected output:
   │  ├─ alex | 23h ago | GRACE
   │  ├─ maria | 24h ago | PERMANENT  
   │  └─ john | 25h ago | PERMANENT
   └─ Verify: Grace period tracking accurate ✅ (ready for future feature: auto-unhide)
```

### Test 3: Persistence After App Restart

```
1. Call: debugAddOldClickedProfile(userId, "test_profile", 10)
   ├─ Log: [DEBUG-CLICKED] ✓ Added test_profile (simulated 10 hours ago)
   
2. CLOSE APP COMPLETELY
   ├─ Terminate simulator
   
3. REOPEN APP
   ├─ Boot logs should include: [ClickedProfiles] Loaded 1 clicked profiles
   ├─ (No DEBUG log, that happens before debug flag check)
   
4. Navigate to search screen
   ├─ Expected: test_profile still hidden
   ├─ Expected: [CachedResults] Premium user: filtered 1 clicked profiles
   └─ Visual: Profile not visible ✅
   
5. Verify: debugPrintAllClicked(userId)
   ├─ Should show test_profile with now ~10-11 hours ago
   └─ PERSISTENCE VERIFIED ✅
```

---

## Cleaning Up After Testing

### Option 1: Quick Toggle (Recommended)
Set debug flag back to `false`:
```dart
const bool DEBUG_CLICKED_PROFILES_TESTING = false;
```

This immediately:
- ❌ Silences ALL debug methods (they return early)
- ✅ Keeps code in place for future testing
- ✅ No commits of debug code to repo (just toggle)

**Benefit:** Can re-enable later without re-adding code

---

### Option 2: Complete Removal
Delete the entire debug section:

**Removal Time:** 2 minutes  
**Lines to Delete:** 269-353 (approximately)

Search for these markers:
```dart
// ========================================================================
// DEBUG SECTION - TESTING ONLY
```
And:
```dart
// ========================================================================
// DEBUG FLAG - CONTROLS ALL DEBUG OUTPUT
// ============================================================================
```

Delete everything between (inclusive).

**Result:**
- ✅ Code completely removed from file
- ✅ Zero debug overhead
- ✅ Clean production code
- ✅ Easy to accidentally forget completion

---

### Option 3: Version Control Clean
```bash
# Stage only non-debug changes
git add lib/features/dating_search/application/dating_search_results_provider.dart
git add lib/features/dating_search/presentation/screens/search_screen.dart

# Reset debug file (removes all debug code)
git checkout lib/features/dating_search/application/dating_clicked_profiles_provider.dart

# Or if you want to keep it, just revert the debug toggle:
# Edit: DEBUG_CLICKED_PROFILES_TESTING = false (was true)
```

---

## Log Format Explained

All debug logs start with `[DEBUG-CLICKED] ` for easy filtering:

```bash
# To see ONLY debug logs in console:
flutter logs | grep DEBUG-CLICKED

# To suppress debug logs and see only main logs:
flutter logs | grep -v DEBUG-CLICKED
```

---

## What to Look For When Testing

### ✅ Good Signs
```
[DEBUG-CLICKED] ✓ Added profile_123 (simulated 25 hours ago)
  → Profile stored with old timestamp
  
[CachedResults] Premium user: filtered 1 clicked profiles | 12 → 11 total
  → Filtering worked, grid has 1 less profile
  
Grid shows 11 profiles (not 12)
  → UI correctly updated
  
[ClickedProfiles] Loaded 1 clicked profiles for userId
  → Persistence working after restart
```

### ❌ Problem Signs
```
No [CachedResults] filtered message
  → isPremium might be false, check subscription status
  → Or no clicked profiles in state (check debugPrintAllClicked output)

Grid still shows 12 profiles
  → Filtering not applied
  → Premium check failing
  → Watch not triggering

[DEBUG-CLICKED] ✗ Error: ...
  → Exception in debug method (check message)
  → Usually means prefs is null or parse failed
```

---

## Timeline

| Time | Action | Logs |
|------|--------|------|
| 0-1m | Toggle DEBUG flag to true | (no logs) |
| 1-2m | Call debugAddOldClickedProfile() | [DEBUG-CLICKED] ✓ Added... |
| 2-3m | Navigate back to search | [CachedResults] filtered 1... |
| 3-4m | Verify grid | Visual check |
| 4-5m | Call debugPrintAllClicked() | [DEBUG-CLICKED] DUMP output |
| 5-6m | Close/reopen app | [ClickedProfiles] Loaded... |
| 6-7m | Verify persistence | [CachedResults] still filters |
| 7-8m | Reset: Toggle DEBUG flag to false | (logs stop) |

**Total Test Time: ~8 minutes** ✅

---

## Important Notes

⚠️ **Debug methods only work if:**
- `DEBUG_CLICKED_PROFILES_TESTING = true`
- `_prefs != null` (SharedPreferences initialized)
- User is logged in with valid userId

⚠️ **Debug logs are filtered:**
- All start with `[DEBUG-CLICKED] ` prefix
- Easy to distinguish from regular logs
- Don't affect production logs when flag is false

⚠️ **Storage is real:**
- Debug methods use actual SharedPreferences
- Profiles will persist across app restarts
- Call `debugClearAllClicked()` to clean up after testing
- Or just run `flutter clean` to reset app data

---

## Removing Debug Code Permanently

When you're done testing and ready to commit:

### Option A: Via Editor
1. Open `dating_clicked_profiles_provider.dart`
2. Find line "// ======== DEBUG SECTION"
3. Delete lines 270-353 (approximate, may vary)
4. Save file

### Option B: Via Command Line
```bash
# Navigate to file and show line numbers
sed -n '265,360p' lib/features/dating_search/application/dating_clicked_profiles_provider.dart | cat -n

# Then manually delete in editor, or:
# Just toggle the flag and commit with DEBUG_CLICKED_PROFILES_TESTING = false
```

### Option C: Keep For Future Testing
```dart
// Leave flag as is:
const bool DEBUG_CLICKED_PROFILES_TESTING = false;

// Methods are inert when false, no performance impact
// Can re-enable anytime for future testing
```

---

## Summary

✅ **To Enable Testing:**
```dart
DEBUG_CLICKED_PROFILES_TESTING = true;  // Line 269
```

✅ **To Run Tests:**
Use the 3 debug methods shown above

✅ **To See Logs:**
All start with `[DEBUG-CLICKED]` - easy to identify

✅ **To Clean Up:**
```dart
DEBUG_CLICKED_PROFILES_TESTING = false;  // Turn off
```

✅ **No Permanent Impact:** Flag gates everything, no dead code when disabled
