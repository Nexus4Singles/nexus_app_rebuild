# Dating Search Results: 24-Hour Refresh Analysis

## Summary
The 24-hour refresh logic is **CORRECTLY IMPLEMENTED** but with an important qualification: new profiles will only appear if **new profile objects are created in Firestore**. If the user pool is stable, the same profiles may repeat.

---

## How the 24-Hour Reset Works

### STEP 1: Timer Detection Logic
**File:** `daily_limit_provider.dart` (lines 18-45)

```dart
Future<DateTime?> getDailyLimitFirstHit(String uid) async {
  final dt = datetime.toDate();
  final now = DateTime.now();
  final hoursSince = now.difference(dt).inHours;
  
  // ✅ THIS IS THE KEY CHECK
  if (hoursSince >= 24) {
    print('[DailyLimitManager] ⏰ 24+ hours passed - clearing daily limit');
    await clearDailyLimit(uid);  // Clears Firestore data
    return null;  // Signals reset
  }
}
```

**How it works:**
- Stores `dating.dailyLimitFirstHit` timestamp in Firestore when user first views 10 profiles
- On next search, checks if `now - storedTime ≥ 24 hours`
- If YES: calls `clearDailyLimit()` → DELETES both timestamp AND shown profile IDs
- Returns `null` to signal reset

### STEP 2: Data Clearing (Firestore Deletion)
**File:** `daily_limit_provider.dart` (lines 104-121)

```dart
Future<void> clearDailyLimit(String uid) async {
  await _fs.collection('users').doc(uid).update({
    'dating.dailyLimitFirstHit': FieldValue.delete(),        // ✅ Delete timestamp
    'dating.shownProfileIds': FieldValue.delete(),           // ✅ Delete shown IDs
    'dating.clientClearedAt': FieldValue.serverTimestamp(),  // Track reset
  });
}
```

**Critical:** Both fields are **DELETED**, not just reset. This is important.

### STEP 3: Fresh Results Logic
**File:** `dating_search_results_provider.dart` (lines 649-668)

After 24 hours, when user searches again:

```dart
// After getDailyLimitFirstHit() and getShownProfileIds()
persistedLimitHit = null     // ← 24-hour check returned null
shownIds = []               // ← Field was deleted, returns []

// SAFEGUARD: Double-check if reset happened
if (persistedLimitHit == null && shownIds.isNotEmpty) {
  await manager.setShownProfileIds(uid, []); // Extra safety
  shownIds = [];
}

// Flow to Case 2 (see below)
```

---

## The Four Cases After Reset

### CASE 2: Fresh Start After Reset (After 24 Hours) ✅
**File:** `dating_search_results_provider.dart` (lines 685-707)

```dart
else if (shownIds.isEmpty && newProfiles.isNotEmpty) {
  // ✅ Shows first 10 profiles from search results (newest first)
  final profilesToShow = newProfiles.take(10).toList();
  await manager.setDailyLimitFirstHit(uid);
  await manager.setShownProfileIds(uid, allIds);
  
  results = DatingSearchResult(
    items: profilesToShow,  // ← Fresh 10 profiles
    ...
  );
}
```

**What happens:**
- `newProfiles = results.items.where((p) => !shownIds.contains(p.uid))` 
- Since `shownIds = []` after reset, **ALL profiles in results are "new"**
- Takes first 10 (sorted by `createdAt` newest first)
- Saves their UIDs for today's deduplication

---

## The Critical Question: Are They DIFFERENT Profiles?

### YES ✅ IF:
1. **New user profiles were created in Firestore in the last 24 hours**
   - Example: 3 new users joined → top 10 includes those 3 new ones
   - Different from yesterday's top 10

2. **Profiles from yesterday are now outside top 10**
   - Example: If you had profiles [A, B, C, D, E, F, G, H, I, J]
   - New profiles [K, L, M] were created (now newest)
   - Today's top 10: [K, L, M, A, B, C, D, E, F, G] (different from yesterday)

### NO ❌ IF:
1. **No new user profiles were created in Firestore**
   - User base is stable or shrinking
   - Same "top 10 newest" profiles appear again
   - User sees the SAME profiles they saw yesterday
   - **Result:** "No new profiles" situation despite 24-hour reset ⚠️

2. **Profile pool is very small**
   - Example: Only 5 total profiles in user's search radius
   - After 24 hours, still shows the same 5 profiles
   - **Result:** Same profiles, limited variety ⚠️

---

## Edge Cases & Behaviors

### CASE 1: Daily Limit Hit, Still Within 24 Hours
**File:** `dating_search_results_provider.dart` (lines 664-677)

```dart
if (shownIds.length >= 10) {
  results = DatingSearchResult(
    items: profilesAlreadySeen,  // ← Shows previously seen profiles
    emptyHint: 'You've completed your 10 profiles for today! 🎉 Swipe again or check back tomorrow.',
    ...
  );
}
```

**Behavior:**
- Shows the 10 profiles they already saw
- Message: "check back tomorrow"
- Not showing new profiles because 24 hours haven't passed yet

---

### CASE 3: Mid-Session (Fewer than 10 shown)
**File:** `dating_search_results_provider.dart` (lines 709-734)

```dart
else if (shownIds.isNotEmpty && shownIds.length < 10) {
  final remaining = 10 - shownIds.length;
  final profilesToShow = newProfiles.take(remaining).toList();
  // ... fill up to 10 total
}
```

**Behavior:**
- User has seen 5 profiles (e.g.)
- Shows remaining 5 new ones to reach 10
- Saves all 10 UIDs

---

### CASE 4: All Profiles in Pool Exhausted
**File:** `dating_search_results_provider.dart` (lines 736-746)

```dart
else if (newProfiles.isEmpty) {
  // newProfiles is empty = all search results already shown
  results = DatingSearchResult(
    items: profilesAlreadySeen,  // Show old ones again
    emptyHint: profilesAlreadySeen.isNotEmpty
        ? 'No more new profiles today. Re-swipe or come back tomorrow!'
        : 'All available profiles for your preferences have been shown today.',
    ...
  );
}
```

**Behavior:**
- User scrolled through all profiles matching their filters
- No new profiles available today
- Shows: "No more new profiles today. Re-swipe or come back tomorrow!"
- Tomorrow after 24 hours:
  - ✅ If new profiles created → Case 2 (fresh profiles)
  - ❌ If no new profiles created → Case 4 again (same old profiles)

---

## Verification Summary

### ✅ CONFIRMED WORKING:
1. **24-hour timer:** Correctly checks `hoursSince >= 24`
2. **Data clearing:** Both `dailyLimitFirstHit` and `shownProfileIds` are deleted
3. **Reset trigger:** When limit expires, `getDailyLimitFirstHit()` triggers `clearDailyLimit()`
4. **Fresh search:** After reset, system treats all profiles as "new"
5. **Safeguard logic:** Double-checks that `shownIds` is truly empty after reset
6. **Dual guarantee:** Comment mentions CloudFunction + client-side backup (line 107-110)

### ⚠️ POTENTIAL ISSUES:

**Issue 1: Same Profiles If User Base Is Stable**
- If few/no new profiles created in 24 hours
- The "top 10 newest" list won't change
- User sees identical profiles as yesterday
- **Severity:** Could impact engagement and UX

**Issue 2: No Randomization**
- No logic to shuffle or randomly select from available pool
- Always shows "newest first" 
- Predictable, can feel repetitive for users with small search results

**Issue 3: No Freshness Check**
- System doesn't check if profiles are actually "new" (created in last 24 hours)
- Just checks if different from user's "shown list"
- Profiles from 6 months ago could be shown as "new" if they're in top 10

---

## Data Flow Diagram

```
USER SEARCHES (After 24 hours have passed)
         ↓
   getDailyLimitFirstHit(uid)
         ↓
   Check: hoursSince >= 24?
         ↓ YES
   clearDailyLimit(uid)  [DELETE both fields from Firestore]
         ↓ Returns null
   getShownProfileIds(uid)  [Returns [] because field was deleted]
         ↓
   shownIds = []
   persistedLimitHit = null
         ↓
   Flow to Case 2
         ↓
   newProfiles = ALL profiles (since !shownIds.contains(p.uid) is true for all)
         ↓
   Show first 10 (sorted newest first)
         ↓
   IF new profiles created yesterday: ✅ DIFFERENT profiles
   IF no new profiles created:        ❌ SAME profiles as yesterday
```

---

## Conclusion

**The 24-hour refresh mechanism WORKS CORRECTLY** in terms of:
- ✅ Timer detection
- ✅ Data clearing 
- ✅ Reset trigger
- ✅ Fresh profile selection

However, whether **truly new different profiles appear** depends entirely on **whether new profile objects are created in Firestore**. The app lacks:
- Smart profile diversity logic
- Randomization
- Guarantee of "freshly created" profiles

The messaging ("New users join Nexus every day") suggests the app expects steady new profile creation to power the refresh experience.
