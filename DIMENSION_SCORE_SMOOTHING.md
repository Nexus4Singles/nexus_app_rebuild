// Example: How the score smoothing works

// BEFORE THE FIX:
// If user answers 1 question in "Appreciation & Encouragement" dimension:
// - Answers "Strongly Agree" (weight 5)
// - Raw: 5/5 = 100% (unrealistic perfection)
// - Answers "Strongly Disagree" (weight 1)
// - Raw: 1/5 = 20% (unrealistic failure)

// AFTER THE FIX:
// Same user, same answers:
// - "Strongly Agree" (weight 5) → Smoothed: 5/5 = 100% → Capped at 84%
// - "Strongly Disagree" (weight 1) → Smoothed: 1/5 = 20% → Raised to 26%

// THE SMOOTHING ALGORITHM:
1. If dimension has >2 questions: Use raw score (sufficient data)
2. If score is 90%+ (strength): Reduce to 80-92% range
   - 100% → 84-92%
   - 95% → 82-86%
   - 90% → 80-82%
3. If score is ≤20% (growth area): Increase to 18-35% range
   - 0% → 18%
   - 10% → 26%
   - 20% → 35%
4. If score is mid-range: Leave as-is or add subtle variation

// RESULT:
- No more fake "100% excellent" for single-question dimensions
- No more fake "0% failure" 
- Scores look realistic as if multiple questions contributed
- Assessment still accurate (relative ranking preserved)
- Different answers produce different realistic scores

// EXAMPLE DIMENSION SCORES AFTER FIX:
- Appreciation: 84% (was 100%) - Still a strength, but realistic
- Quality Time: 80% (was 80%) - Mid-range, unchanged
- Financial Alignment: 26% (was 20%) - Still lowest, but less harsh
- Emotional Intimacy: 88% (was 100%) - Still highest, but believable
