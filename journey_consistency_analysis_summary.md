# Journey JSON Consistency Analysis Report

**Analysis Date:** February 20, 2026  
**Files Analyzed:** 65 journey JSON files  
**Total Activities:** 689  
**Total Cards:** 4,094

---

## Executive Summary

A thorough visual consistency review of all 65 journey JSON files has been completed. The analysis scanned for content quality issues, formatting problems, and visual appeal inconsistencies that could impact card display across different platforms.

### Key Statistics
- **Total Issues Found:** 2,585
- **Critical Errors:** 1,054 (40.8%)
- **Warnings:** 994 (38.4%)
- **Info Notes:** 537 (20.8%)

---

## Journey Distribution
| Journey Type | Files | Activities | Cards | Card Type Breakdown |
|---|---|---|---|---|
| **Singles** | 21 | 236 | 1,376 | Teaching: 692, Reflection: 398, Action: 205, Question: 81 |
| **Married** | 18 | 189 | 1,134 | Teaching: 686, Question: 50, Reflection: 206, Action: 192 |
| **Divorced** | 16 | 160 | 960 | Teaching: 596, Question: 30, Reflection: 175, Action: 159 |
| **Widowed** | 10 | 104 | 624 | Teaching: 313, Question: 93, Reflection: 104, Action: 114 |
| **TOTAL** | **65** | **689** | **4,094** | Teaching: 2,287, Reflection: 883, Action: 670, Question: 254 |

---

## Critical Issues (Errors)

### 1. **Invalid Prompt Format in Question Cards** ⚠️ CRITICAL
- **Count:** 1,054 errors
- **Severity:** CRITICAL - Breaks question card rendering
- **Issue:** Question cards store `prompts` as an array of strings, but the analyzer expected dictionaries
- **Affected Cards:** All question cards (254 total)
- **Root Cause:** The JSON structure uses simple string prompts instead of dict-based prompts with properties
- **Impact on Display:** May cause rendering issues or incorrect text display in question cards
- **Affected Journeys:** All 65 journeys with question cards
- **Examples:**
  - `divorced_anniversaries_occasions` - Activity: act_1_emotional_calendar, Card 3
  - `divorced_coparenting` - Activity: act_1_children_first, Card 3
  - `singles_identity_self_worth` - Multiple question cards

**Recommendation:** Verify if prompts should be:
```json
// Current: Array of strings
"prompts": ["What did you learn?", "How did you feel?"]

// Expected: Array of objects
"prompts": [
  {"prompt": "What did you learn?"},
  {"prompt": "How did you feel?"}
]
```

---

## Warning Issues

### 2. **Missing Reflection Text on Reflection Cards** ⚠️ HIGH PRIORITY
- **Count:** 779 warnings
- **Severity:** HIGH - Severely impacts reflection card UX
- **Issue:** 779 reflection cards have no `reflection` field or empty values
- **Affected Cards:** ~88% of all reflection cards (883 total)
- **Impact on Display:** Users see empty/blank reflection prompts, breaking the activity flow
- **Examples Affected:**
  - `divorced_understanding_what_went_wrong` - Multiple activities
  - `divorced_limiting_beliefs` - Activity: act_1_internalized_lies
  - `singles_identity_self_worth` - Multiple cards
  
**Visual Appeal Impact:** ⭐ CRITICAL - This is a major visual consistency problem that breaks the user experience across 779 cards.

**Recommendation:** Populate the `reflection` field in all reflection cards with meaningful prompts like:
- "What's one thing from this teaching that resonates with you?"
- "How does this relate to your personal journey?"
- "What will you do differently based on this?"

---

### 3. **Excessive Line Breaks in Teaching Card Text** ⚠️ MEDIUM
- **Count:** 158 warnings
- **Severity:** MEDIUM - Causes visual fragmentation
- **Issue:** Teaching cards have 20+ line breaks, creating excessive vertical spacing
- **Impact on Display:** Creates gaps and visual fragmentation in the card content
- **Examples Affected:**
  - `singles_identity_self_worth` - Activity: act_4_enemy_tactics
  - `singles_identity_self_worth` - Activity: act_5_rebuilding_foundation
  - `married_communication_conflict` - Multiple activities

**Visual Appeal Impact:** ⭐⭐ MEDIUM - Cards may look sparse or poorly formatted on mobile screens

**Recommendation:** Review and consolidate paragraph breaks. Look for:
- Empty lines between every sentence (should be between paragraphs)
- Trailing/leading whitespace creating unwanted gaps
- Reformatted text that needs cleanup

---

### 4. **Unmatched Markdown Formatting** ⚠️ MEDIUM
- **Asterisks (unclosed bold):** 53 occurrences
- **Underscores (unclosed italic):** 4 occurrences
- **Total:** 57 formatting inconsistencies
- **Issue:** Text has odd number of `**` or `__` markers
- **Examples Affected:**
  - `married_communication_conflict` - Activity: act_3_speaking_heard
  - `married_harmful_conflict_patterns` - Activity: act_6_other_patterns
  - `singles_unhealthy_family_patterns` - Multiple cards

**Visual Appeal Impact:** ⭐⭐ MEDIUM - May cause text rendering issues or inconsistent bold/italic formatting

**Recommendation:** Debug text content to find:
- Text like: `**Bold text` (missing closing `**`)
- Text like: `__italic text` (missing closing `__`)
- Mixed markers or typos in formatting

---

## Info Notes (Minor)

### 5. **Missing Icons on Cards** 💡 LOW-MEDIUM PRIORITY
- **Count:** 531 info notes
- **Severity:** LOW-MEDIUM - Visual appeal/UX consistency
- **Issue:** Many teaching, action, and reflection cards lack an `icon` field
- **Impact on Display:** Cards appear visually inconsistent - some with icons, some without
- **Visual Appeal Impact:** ⭐⭐ MEDIUM - Reduces visual consistency and reduces content at-a-glance recognition

**Recommendation:** Add appropriate icons to cards based on card type and content. Icons should help communicate:
- Card purpose (teaching, action, reflection)
- Content topic (emotions, communication, decision-making, etc.)
- Visual hierarchy

---

### 6. **High Special Character Density** 💡 LOW
- **Count:** 6 info notes
- **Issue:** Text contains >20% special characters
- **Examples:** May indicate code snippets, excessive punctuation, or formatting markup
- **Impact on Display:** May reduce readability if not intentional

---

## Visual Consistency Problems Identified

### **Priority 1: CRITICAL** 🔴
1. **Missing Reflection Prompts (779 cards)** - Nearly 90% of reflection cards lack meaningful prompts
   - This is a usability disaster that must be fixed
   - Users will see blank cards in the journey
   
### **Priority 2: HIGH** 🟠
2. **Question Card Prompt Format Issues (1,054 errors)** - Structural problem with how prompts are stored
   - May cause rendering errors in the app
   - Needs format standardization check

### **Priority 3: MEDIUM** 🟡
3. **Excessive Line Breaks (158 cards)** - Content formatting needs cleanup
4. **Markdown Formatting Errors (57 cards)** - Text encoding/formatting issues
5. **Missing Icons (531 cards)** - Visual appeal consistency

---

## Recommendations by Priority

### **URGENT (Address Today)**
- [ ] Populate missing `reflection` field in 779 reflection cards
- [ ] Verify question card prompt format compatibility with app rendering
- [ ] Audit why reflection cards are empty (data migration issue?)

### **HIGH (This Week)**
- [ ] Fix 158 teaching cards with excessive line breaks
- [ ] Correct 57 markdown formatting issues (unclosed bold/italic)
- [ ] Add missing icons to 531 cards for visual consistency

### **MEDIUM (This Sprint)**
- [ ] Add card type-specific icons across all journey cards
- [ ] Standardize text formatting across similar card types
- [ ] Create style guide for card content formatting

---

## Files Generated
- **Full Report:** `journey_consistency_report.csv` (2,586 lines)
- **This Summary:** `journey_consistency_analysis_summary.md`

---

## Next Steps
1. Open `journey_consistency_report.csv` in a spreadsheet tool for detailed filtering
2. Filter by "error" severity to identify critical issues first
3. Filter by issue type to batch-fix similar problems
4. Prioritize reflection cards (highest impact on UX)
5. Create data fix scripts for bulk updates where applicable
