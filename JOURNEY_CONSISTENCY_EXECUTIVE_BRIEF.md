# 🔍 Journey JSON Consistency Analysis - Executive Brief

**Analysis Date:** February 20, 2026  
**Scope:** All 65 journey JSON files across 4 user categories  

---

## 📊 Quick Stats

| Metric | Count |
|--------|-------|
| **Total Journey Files** | 65 |
| **Total Activities** | 689 |
| **Total Cards** | 4,094 |
| **Total Issues Found** | 2,585 |
| **Critical Errors** | 1,054 |
| **Warnings** | 994 |
| **Info Notes** | 537 |

---

## 🎯 Journey Distribution

```
SINGLES:   21 journeys │ ████████████ │ 1,376 cards (33.6%)
MARRIED:   18 journeys │ ██████████   │ 1,134 cards (27.7%)
DIVORCED:  16 journeys │ █████████    │   960 cards (23.4%)
WIDOWED:   10 journeys │ ██████       │   624 cards (15.2%)
─────────────────────────────────────────────────────────
TOTAL:     65 journeys │ ██████████████████ │ 4,094 cards
```

---

## 🚨 Critical Issues Found

### Issue #1: Invalid Question Card Prompts (960 ERRORS)
**Severity:** 🔴 CRITICAL  
**Affected:** 254 question cards across all journeys  
**Problem:** Question cards store prompts as strings instead of dictionaries
```json
// ❌ Current (BROKEN)
"prompts": ["Question text 1", "Question text 2"]

// ✅ Expected
"prompts": [{"prompt": "Question text 1"}, {"prompt": "Question text 2"}]
```
**Impact:** May break question card rendering in the app  
**Journey Examples:**
- divorced_anniversaries_occasions (8+ errors)
- divorced_coparenting (8+ errors)
- divorced_dating_again (8+ errors)
- All question-type journey activities affected

---

### Issue #2: Missing Reflection Prompts (779 WARNINGS) 🔴 **BIGGEST UX IMPACT**
**Severity:** 🔴 CRITICAL  
**Affected:** 779 reflection cards (~88% of all reflection cards)  
**Problem:** Reflection cards are missing the `reflection` field entirely
```json
// ❌ Missing
{ "cardType": "reflection" }  // No reflection text!

// ✅ Should have
{ "cardType": "reflection", "reflection": "What did you learn from this?" }
```
**Impact:** Users see **completely blank** reflection cards in journeys  
**Visual Damage:** ⭐⭐⭐⭐⭐ This is SEVERE - breaks entire user experience  
**Journey Examples:**
- divorced_understanding_what_went_wrong (multiple activities)
- divorced_limiting_beliefs
- singles_identity_self_worth
- **EVERY journey affected**

---

### Issue #3: Excessive Line Breaks (158 WARNINGS)
**Severity:** 🟠 HIGH  
**Affected:** Teaching cards with 20+ line breaks  
**Problem:** Content formatting creates excessive white space
```
Teaching cards with excessive newlines:
├─ singles_identity_self_worth (act_4_enemy_tactics)
├─ singles_identity_self_worth (act_5_rebuilding_foundation)
├─ married_communication_conflict (act_3_speaking_heard)
└─ ... 155 more cards
```
**Visual Impact:** ⭐⭐ Cards appear sparse and fragmented on mobile  
**Recommendation:** Clean up paragraph formatting

---

### Issue #4: Broken Markdown Formatting (57 WARNINGS)
**Severity:** 🟠 MEDIUM  
**Types:**
- Unclosed bold markers `**` : 53 occurrences
- Unclosed italic markers `__` : 4 occurrences

**Examples:**
- married_communication_conflict (act_3_speaking_heard) - Card 2
- married_harmful_conflict_patterns (act_6_other_patterns) - Card 1
- singles_unhealthy_family_patterns (multiple cards)

**Visual Impact:** ⭐⭐ Text may not render bold/italic correctly

---

### Issue #5: Missing Icon Assets (531 INFO NOTES) 💡
**Severity:** 🟡 MEDIUM  
**Affected:** 531 cards (teaching, action, reflection types)  
**Problem:** Cards lack `icon` field for visual identification
**Visual Impact:** ⭐⭐ Reduced visual consistency and content scanning  
**Recommendation:** Add meaningful icons to improve visual appeal

---

## 📈 Issue Breakdown by Type

```
Invalid prompt format .................... 960 ERRORS  ████████████████████████████
Reflection card missing text ............. 779 WARNINGS ██████████████████████
Missing icon for card .................... 531 INFO  █████████████████
Excessive line breaks in text ........... 158 WARNINGS ████
Question card missing prompts ............ 94 ERRORS  ██
Unmatched markdown (asterisks) .......... 53 WARNINGS  ██
High special character density ........... 6 INFO  ─
Unmatched markdown (underscores) ........ 4 WARNINGS  ─
```

---

## 🏆 Most Affected Journeys

### By Errors
1. **divorced_emotional_readiness** - 90+ errors
2. **divorced_toxic_patterns** - 85+ errors
3. **singles_red_flags** - 80+ errors
4. **married_infidelity** - 75+ errors
5. All journeys with question cards affected

### By Warnings
1. **divorced_understanding_what_went_wrong** - 20+ warnings
2. **divorced_limiting_beliefs** - 18+ warnings
3. **singles_identity_self_worth** - 25+ warnings
4. **married_communication_conflict** - 22+ warnings
5. ALL journeys affected by missing reflection text

---

## ✅ Action Items Prioritized

### 🔴 URGENT (Fix Today)
- [ ] **Populate 779 missing reflection prompts** - This is a show-stopper UX issue
  - Users will see blank cards
  - Breaks the reflection activity completely
  - Suggested content: "What resonated with you?", "How does this apply to you?", etc.

### 🟠 HIGH (This Week)
- [ ] **Fix question card prompt format** (960 issues)
  - Verify app can handle both formats or standardize to dict format
  - May cause runtime errors if app expects dict structure
  
- [ ] **Fix markdown formatting** (53 asterisks, 4 underscores)
  - Search for "**" patterns and close them properly
  - Same for "__" patterns

### 🟡 MEDIUM (This Sprint)
- [ ] **Clean up excessive line breaks** (158 cards)
  - Consolidate paragraph breaks
  - Ensure proper spacing without gaps

- [ ] **Add missing icons** (531 cards)
  - Create icon mapping for common themes
  - Visual consistency across all card types

---

## 📁 Generated Files

1. **journey_consistency_report.csv** - Full detailed report (2,586 rows)
   - Filter by: Journey, Activity, Card Index, Card Type, Severity, Issue
   - Use for detailed investigation

2. **journey_consistency_analysis_summary.md** - Full analysis document
   - Comprehensive breakdown with recommendations

3. **analyze_journey_consistency.py** - Reusable scanner
   - Run again after fixes to verify improvements

---

## 🎯 Top 3 Recommendations

### 1. **Add 779 Reflection Prompts** (IMMEDIATE)
**Impact:** Fixes ~30% of all issues + dramatically improves UX  
**Effort:** Medium (data entry from template)  
**Example template:**
```json
"reflection": "Reflect on how this teaching connects to your journey. What's one thing you can take away?"
```

### 2. **Standardize Question Card Format** (THIS WEEK)
**Impact:** Fixes all 960 prompt format errors  
**Effort:** High if requires code changes, Medium if data fix  
**Check with dev team:** Does app need dict format or can it accept strings?

### 3. **Add Visual Icons** (THIS SPRINT)
**Impact:** Improves visual hierarchy + consistency  
**Effort:** Medium (create icon list, update JSON files)  
**Benefit:** Better user experience scanning cards

---

## 💡 Next Steps

1. **Open the CSV report** in Excel/Sheets for detailed exploration
2. **Sort by Severity** to focus on errors first
3. **Group by Issue Type** to batch-fix similar problems
4. **Create a fix script** for bulk updates where applicable
5. **Validate fixes** by running the analyzer again

---

**Last Updated:** February 20, 2026  
**Analyzer:** `scripts/analyze_journey_consistency.py`  
**Total Analysis Time:** < 1 minute for 4,094 cards
