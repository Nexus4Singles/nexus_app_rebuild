# Dating Search Results Order Analysis

**Date**: March 20, 2026  
**Objective**: Verify that subscribed users see NEW profiles at the top of search results as they sign up

---

## CURRENT BEHAVIOR SUMMARY

### ✅ Sorting Strategy (CORRECT)

The `DatingSearchService` (lines 756-786) implements a 3-tier sort:

```
TIER 1: V2 profiles (schema version 2+) BEFORE V1 profiles
TIER 2: Profiles with valid dates BEFORE profiles without dates (epoch)
TIER 3: Sorted by createdAt DESCENDING (newest first)
```

**Result**: New profiles WILL appear first within each group ✅

### ⚠️ PROBLEM: Order Gets Disrupted in Provider Layer

After the search service returns NEW-FIRST sorted profiles, the provider applies TWO re-prioritizations that BREAK the sort order:

#### Problem #1: Relationship Status Prioritization (Lines 671-710)

**What it does:**
- If user is widowed/divorced and has NO marital filter set
- Pulls ALL matching widowed/divorced profiles to the TOP
- Leaves remaining profiles below

**Impact on new profiles:**
- ❌ A brand new widowed profile gets promoted to top (good)
- ❌ But ALL other new profiles get pushed down below old widowed profiles (bad)
- ❌ Violates "new profiles first" for subscribed users

**Code:**
```dart
if (userRel == RelationshipStatus.widowed) desired = 'widowed';
  if (userRel == RelationshipStatus.divorced) desired = 'divorced';

  if (desired != null) {
    final matching = results.items.where((p) => (p.maritalStatus ?? '').toLowerCase() == desired).toList();
    final others = results.items.where((p) => (p.maritalStatus ?? '').toLowerCase() != desired).toList();

    results = DatingSearchResult(
      items: [...matching, ...others],  // ← Re-sorts, breaking newness order
```

#### Problem #2: Local Profile Prioritization (Lines 714-742)

**What it does:**
- If user has no country preference but has a home country set
- Pulls ALL profiles from user's country to the TOP
- Leaves international profiles below

**Impact on new profiles:**
- ❌ A brand new local profile gets promoted (good)
- ❌ But ALL new international profiles get pushed to bottom
- ❌ Even if they're newer than all local profiles
- ❌ Violates "new profiles first" principle

**Code:**
```dart
if (results.items.isNotEmpty &&
    resolvedPreferences.countryOfResidence != null &&
    filters.countryOfResidence == null) {
  final userCountry = resolvedPreferences.countryOfResidence!;

  // Partition: local profiles first, international second
  final localProfiles = results.items.where((p) => p.country == userCountry).toList();
  final internationalProfiles = results.items.where((p) => p.country != userCountry).toList();

  if (localProfiles.isNotEmpty || internationalProfiles.isNotEmpty) {
    // Combine with local first, preserving sort order within each group
    final prioritizedItems = [...localProfiles, ...internationalProfiles];  // ← Re-sorts
```

---

## IMPACT ON SUBSCRIBED USERS

### Current Behavior

| Scenario | Current Order | Expected Order | Issue |
|----------|---------------|-----------------|-------|
| Subscribed user (no filters) | Local profiles (any age), then international | New international + New local profiles first | ❌ New international profiles buried |
| Subscribed user (widowed, no marital filter) | All widowed (any age), then others | New profiles (all statuses) by date | ❌ New divorced profiles buried |
| Subscribed user (with country filter) | New profiles by date | Same | ✅ Works correctly |
| Subscribed user (with marital filter) | New profiles by date | Same | ✅ Works correctly |

### What Should Happen

**For subscribed users**, the order should be:
```
1. Newest verified V2 profiles (today, yesterday, last week...)
2. Older verified V2 profiles
3. Newest legacy V1 profiles
4. Older legacy V1 profiles (with epoch dates at bottom)
```

**NOT:**
```
1. All local profiles by age
2. All international profiles by age
```

---

## FREE USERS VS SUBSCRIBED USERS

### Free Users
- **Daily Limit**: 10 profiles/day
- **Prioritization**: Unseen profiles before seen (makes sense to limit spread)
- **Additional sort**: Local before international (acceptable because limited to 10/day anyway)
- **Status**: ✅ Reasonable - they're limited so seeing local first is fine

### Subscribed Users  
- **Daily Limit**: UNLIMITED (100 pages × 20 = 2,000 profiles potential)
- **Prioritization**: Should be PURELY by date (NEW FIRST)
- **Current**: Still re-prioritizes by relationship status & location
- **Status**: ❌ **BROKEN** - Should NOT re-prioritize

---

## ROOT CAUSE

The re-prioritization logic treats ALL users the same:
- It checks if user is widowed/divorced (lines 671-710) - applies to free AND subscribed
- It checks if user has no country preference (lines 714-742) - applies to free AND subscribed

**Fix needed**: Only apply these re-prioritizations to FREE users (who have limited views)  
**For subscribed users**: Keep pure date-based sorting with pagination cap only

---

## SOLUTION STRATEGY

### Option A: Check isPremium Before Re-prioritizing (RECOMMENDED)

```dart
if (!isPremium) {  // Only apply smart priorities for free users
  // Relationship status prioritization (widowed/divorced first)
  // Local profile prioritization (local before international)
} else {
  // Subscribed users: Keep pure date-based sorting
  // No re-prioritization, just pagination cap
}
```

**Pros:**
- Subscribed users get new profiles first reliably
- Free users still get smart local-first behavior
- Minimal code change
- Addresses the core issue

**Cons:**
- Subscribed users never see "local first" optimization
- But that's acceptable since they have unlimited views anyway

### Option B: Separate Sort Strategies

```dart
// Free users: unseen + local + relationship-status prioritized
// Subscribed users: pure date-first sorting
```

---

## VERIFICATION CHECKLIST

To verify the fix works:

- [ ] Create 3 test accounts (different countries, different relationship statuses)
- [ ] Subscribe one account
- [ ] Subscribe another as widowed/divorced
- [ ] Have them create dating profiles (times: now, 1 week ago, 2 weeks ago)
- [ ] Open search as subscribed user
- [ ] Verify NEW profiles appear at top (by exact creation timestamp)
- [ ] Verify NOT re-sorted by local/relationship status
- [ ] Verify test on next day - NEW profiles from today should still be at top

---

## FILES AFFECTED

- [dating_search_results_provider.dart](lib/features/dating_search/application/dating_search_results_provider.dart#L671-L742)
  - Lines 671-710: Relationship status prioritization
  - Lines 714-742: Local profile prioritization
  - Line 749: isPremium check already available

---

## RECOMMENDATION

**Apply Option A** immediately:

1. Wrap relationship-status prioritization (671-710) in `if (!isPremium) { ... }`
2. Wrap local-profile prioritization (714-742) in `if (!isPremium) { ... }`
3. Add debug log: `"[DatingSearchResults] Premium user: skipping re-prioritization (keeping pure date sort)"`
4. Test with subscribed users in different scenarios

This ensures:
- ✅ Subscribed users see NEW profiles first (as intended)
- ✅ Free users still get smart "local first" behavior
- ✅ All profiles within each category still sorted by date
- ✅ Pagination cap still applies (100 pages for subscribed)
