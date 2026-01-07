from pathlib import Path
import re

RESULT_FILE = Path("lib/features/assessment/presentation/screens/assessment_result_screen.dart")
ROUTES_FILE = Path("lib/core/router/app_routes.dart")

LOCKED_COPY = (
    "You don’t have to work through these areas alone.\n"
    "Our challenges offer structured, faith-grounded guidance designed around growth patterns like yours."
)

def detect_challenges_route() -> str:
    # Prefer AppRoutes.challenges if it exists; else fall back to '/challenges'
    if ROUTES_FILE.exists():
        s = ROUTES_FILE.read_text(encoding="utf-8")
        if re.search(r"\bstatic\s+const\s+String\s+challenges\b", s):
            return "AppRoutes.challenges"
    return "'/challenges'"

def main():
    if not RESULT_FILE.exists():
        raise SystemExit(f"❌ Not found: {RESULT_FILE}")

    s = RESULT_FILE.read_text(encoding="utf-8")

    route_expr = detect_challenges_route()

    # 1) Inject a CTA card widget if missing
    if "_ExploreChallengesCtaCard" not in s:
        insert_after = "class _TopBar extends StatelessWidget {"
        idx = s.find(insert_after)
        if idx == -1:
            raise SystemExit("❌ Could not find insertion point (class _TopBar).")

        cta_widget = f"""
class _ExploreChallengesCtaCard extends StatelessWidget {{
  final VoidCallback onTap;
  const _ExploreChallengesCtaCard({{required this.onTap}});

  @override
  Widget build(BuildContext context) {{
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended Next Steps',
            style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          Text(
            {LOCKED_COPY!r}.replaceAll('\\\\n', '\\n'),
            style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted, height: 1.35),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                side: BorderSide(color: AppColors.primary.withOpacity(0.35)),
              ),
              child: Text(
                'Explore Challenges',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }}
}}

"""
        s = s[:idx] + cta_widget + s[idx:]

    # 2) Replace the existing next-steps block in build() with our CTA card.
    # We’ll replace these two blocks (both are in your file):
    #   if (bundle.nextSteps.isNotEmpty) _NextStepsCard(...)
    #   if (bundle.nextSteps.isNotEmpty) const SizedBox(...)
    #
    # with:
    #   _ExploreChallengesCtaCard(...)
    #   const SizedBox(...)
    #
    # This keeps structure stable and avoids “random microstep” UX.
    pattern = re.compile(
        r"""
        \s*if\s*\(\s*bundle\.nextSteps\.isNotEmpty\s*\)\s*
        _NextStepsCard\(\s*steps:\s*bundle\.nextSteps\s*\)\s*,\s*
        \s*if\s*\(\s*bundle\.nextSteps\.isNotEmpty\s*\)\s*const\s+SizedBox\(height:\s*16\)\s*,\s*
        """,
        re.VERBOSE,
    )

    replacement = f"""
            _ExploreChallengesCtaCard(
              onTap: () => Navigator.pushNamed(context, {route_expr}),
            ),

            const SizedBox(height: 16),

"""

    if pattern.search(s):
        s = pattern.sub(replacement, s, count=1)
    else:
        # If your file has drifted, do a safer fallback: insert after Growth Areas block.
        anchor = "if (bundle.growthAreas.isNotEmpty) const SizedBox(height: 16),"
        if anchor in s and "_ExploreChallengesCtaCard(" not in s:
            s = s.replace(
                anchor,
                anchor + replacement,
                1,
            )
        else:
            # As last resort, just insert before the Done button
            done_anchor = "SizedBox(\n              width: double.infinity,"
            if done_anchor in s and "_ExploreChallengesCtaCard(" not in s:
                s = s.replace(done_anchor, replacement + "            " + done_anchor, 1)
            else:
                raise SystemExit("❌ Could not locate nextSteps block or fallback anchors to insert CTA.")

    RESULT_FILE.write_text(s, encoding="utf-8")
    print("✅ Patched AssessmentResultScreen: replaced microStep NextSteps with Explore Challenges CTA")

if __name__ == "__main__":
    main()
