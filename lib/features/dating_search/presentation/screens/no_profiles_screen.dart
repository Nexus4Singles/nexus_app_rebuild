import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import '../../domain/dating_search_result.dart';

class NoProfilesScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback? onEditPreferences;
  final bool noProfilesInCountry;
  final String? countryName;
  final String? emptyHint;
  final NoProfilesBreakdown? breakdown;

  const NoProfilesScreen({
    Key? key,
    required this.onRetry,
    this.onEditPreferences,
    this.noProfilesInCountry = false,
    this.countryName,
    this.emptyHint,
    this.breakdown,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    // If a custom emptyHint is provided AND no structured breakdown,
    // use the simple hint layout (e.g. "no new profiles today").
    if (emptyHint != null &&
        emptyHint!.isNotEmpty &&
        breakdown == null &&
        !noProfilesInCountry) {
      return _buildSimpleHintLayout(context);
    }

    // Use structured breakdown for specific, helpful messaging
    return _buildDiagnosticLayout(context);
  }

  // ---------------------------------------------------------------------------
  // Simple layout — used for non-diagnostic hints (daily limit, pagination, etc.)
  // ---------------------------------------------------------------------------
  Widget _buildSimpleHintLayout(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 100,
                  height: 100,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.hourglass_empty_rounded,
                    color: AppColors.primary,
                    size: 56,
                  ),
                ),
                const SizedBox(height: 32),
                Text(
                  emptyHint!,
                  style: AppTextStyles.headlineSmall.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w600,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onRetry,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      padding: const EdgeInsets.symmetric(vertical: 16),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: Text(
                      'Refresh',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Diagnostic layout — specific reasons why no profiles were found
  // ---------------------------------------------------------------------------
  Widget _buildDiagnosticLayout(BuildContext context) {
    final diagnostics = _buildDiagnostics();

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Icon — contextual based on reason
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    diagnostics.icon,
                    color: AppColors.primary,
                    size: 44,
                  ),
                ),

                const SizedBox(height: 20),

                // Headline
                Text(
                  diagnostics.headline,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w700,
                  ),
                  textAlign: TextAlign.center,
                ),

                const SizedBox(height: 16),

                // Suggestion box — specific actionable advice first
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withOpacity(0.15),
                    ),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.lightbulb_outline_rounded,
                        color: AppColors.primary,
                        size: 20,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: RichText(
                          text: TextSpan(
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                            children: diagnostics.suggestionSpans,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 16),

                // Diagnostic reason cards
                ...diagnostics.reasons.map(
                  (reason) => _DiagnosticReasonCard(reason: reason),
                ),

                const SizedBox(height: 24),

                // Action button
                if (onEditPreferences != null)
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: onEditPreferences,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child: Text(
                        diagnostics.buttonLabel,
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.textOnPrimary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Diagnostics engine — maps data to user-friendly messages
  // ---------------------------------------------------------------------------
  _Diagnostics _buildDiagnostics() {
    final b = breakdown;
    final country = countryName ?? 'your selected country';

    // ------ Scenario 1: Structured breakdown available ------
    if (b != null) {
      // Use eliminatingFilter as the primary discriminator — it's the
      // authoritative signal from the search engine about what happened.

      // 1a) Country filter was the bottleneck
      if (b.eliminatingFilter == 'country') {
        // Sub-case: Firestore returned 0 docs with server-side country
        // filter active (totalFetched == 0). We can't compare age ranges
        // because there was nothing to age-filter.
        if (b.totalFetched == 0) {
          return _Diagnostics(
            icon: Icons.location_off_rounded,
            headline: 'No Profiles in $country Yet',
            description:
                'There are no profiles in $country at the moment. '
                'The community in $country is still growing.',
            reasons: [
              _Reason(
                icon: Icons.group_add_rounded,
                label:
                    'New users join everyday, check frequently for new profiles',
              ),
              _Reason(
                icon: Icons.public_rounded,
                label: 'Expand your search beyond your country of residence',
              ),
            ],
            suggestionSpans: [
              TextSpan(
                text:
                    'The community in $country is still growing. Consider expanding your search beyond your ',
              ),
              TextSpan(
                text: 'country of residence',
                style: TextStyle(fontWeight: FontWeight.w800),
              ),
              TextSpan(text: ' or checking back in a few days.'),
            ],
            buttonLabel: 'Update Location Preference',
          );
        }

        // Sub-case: Profiles exist in the age bracket but none in country
        // (in-memory country filter eliminated everything).
        return _Diagnostics(
          icon: Icons.location_off_rounded,
          headline: 'No Profiles in $country Yet',
          description:
              'We found ${b.afterAgeFilter} profile${b.afterAgeFilter == 1 ? '' : 's'} '
              'in your age range (${b.minAge}–${b.maxAge}), but none '
              '${b.countryName != null ? 'in $country' : 'in your selected location'}.',
          reasons: [
            _Reason(
              icon: Icons.check_circle_outline_rounded,
              label:
                  '${b.afterAgeFilter} profile${b.afterAgeFilter == 1 ? '' : 's'} '
                  'available in ages ${b.minAge}–${b.maxAge}',
            ),
            _Reason(
              icon: Icons.location_off_rounded,
              label: 'None of them are in $country',
            ),
            _Reason(
              icon: Icons.group_add_rounded,
              label:
                  'New users join everyday, check frequently for new profiles',
            ),
          ],
          suggestionSpans: [
            TextSpan(
              text:
                  'Your age range has matches, but not in $country yet. Consider expanding your search beyond your ',
            ),
            TextSpan(
              text: 'country of residence',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(
              text:
                  ' to connect with profiles in other locations, or check back as new users join.',
            ),
          ],
          buttonLabel: 'Update Location Preference',
        );
      }

      // 1b) Age bracket eliminated everything (profiles exist but not in range)
      if (b.eliminatingFilter == 'age' && b.totalFetched > 0) {
        return _Diagnostics(
          icon: Icons.calendar_today_rounded,
          headline: 'No Profiles in This Age Range',
          description:
              'There are no profiles between ages ${b.minAge} and ${b.maxAge} '
              '${b.countryName != null ? 'in $country ' : ''}right now.',
          reasons: [
            _Reason(
              icon: Icons.people_rounded,
              label:
                  '${b.totalFetched} profile${b.totalFetched == 1 ? '' : 's'} '
                  'found outside your age range',
            ),
            _Reason(
              icon: Icons.tune_rounded,
              label: 'Your current range: ${b.minAge} – ${b.maxAge} years old',
            ),
          ],
          suggestionSpans: [
            TextSpan(text: 'Try widening your '),
            TextSpan(
              text: 'age range',
              style: TextStyle(fontWeight: FontWeight.w800),
            ),
            TextSpan(
              text:
                  ' to see more profiles. Even a small adjustment (e.g. ±5 years) could reveal new matches.',
            ),
          ],
          buttonLabel: 'Adjust Age Range',
        );
      }

      // 1c) No profiles at all for this gender (no country filter active,
      //     or country set to "Any" — truly nobody in the system).
      if (b.noProfilesAtAll) {
        return _Diagnostics(
          icon: Icons.people_outline_rounded,
          headline: 'No Profiles Available Yet',
          description:
              'We haven\'t found any profiles to show you at the moment. '
              'The community is growing every day.',
          reasons: [
            _Reason(
              icon: Icons.group_add_rounded,
              label:
                  'New users join everyday, check frequently for new profiles',
            ),
            _Reason(
              icon: Icons.notifications_active_rounded,
              label: 'Check back soon for new matches',
            ),
          ],
          suggestionSpans: [
            TextSpan(
              text:
                  'This is a brand new community and new profiles are being added regularly. Check back in a day or two!',
            ),
          ],
          buttonLabel: 'Edit Preferences',
        );
      }
    }

    // ------ Scenario 2: Legacy path (no breakdown, use flags) ------
    if (noProfilesInCountry) {
      return _Diagnostics(
        icon: Icons.location_off_rounded,
        headline: 'No Profiles in $country Yet',
        description: 'There are no active profiles in $country at the moment.',
        reasons: [
          _Reason(
            icon: Icons.group_add_rounded,
            label: 'New users join everyday, check frequently for new profiles',
          ),
          _Reason(
            icon: Icons.public_rounded,
            label: 'Expand your search beyond your country of residence',
          ),
        ],
        suggestionSpans: [
          TextSpan(
            text:
                'The community in $country is still growing. Consider expanding your search beyond your ',
          ),
          TextSpan(
            text: 'country of residence',
            style: TextStyle(fontWeight: FontWeight.w800),
          ),
          TextSpan(text: ' or checking back in a few days.'),
        ],
        buttonLabel: 'Update Location Preference',
      );
    }

    // ------ Scenario 3: Generic / unknown reason ------
    return _Diagnostics(
      icon: Icons.search_off_rounded,
      headline: 'No Matches Found',
      description:
          'No profiles match your current preferences. '
          'Try adjusting your filters to find more matches.',
      reasons: [
        _Reason(
          icon: Icons.star_rounded,
          label: 'New users join every day, always check frequently',
        ),
        _Reason(
          icon: Icons.tune_rounded,
          label:
              'Adjusting your preferences can help with better search results',
        ),
        _Reason(
          icon: Icons.notifications_active_rounded,
          label: 'Don\'t limit your search to your current location',
        ),
      ],
      suggestionSpans: [
        TextSpan(text: 'Try expanding your '),
        TextSpan(
          text: 'age range',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
        TextSpan(text: ' or expanding your search beyond your '),
        TextSpan(
          text: 'country of residence.',
          style: TextStyle(fontWeight: FontWeight.w800),
        ),
      ],
      buttonLabel: 'Edit Preferences',
    );
  }

  /// Helper method to extract country name from preferences
  static String? extractCountryName(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return null;
    return countryCode;
  }
}

// ---------------------------------------------------------------------------
// Internal view-models
// ---------------------------------------------------------------------------
class _Diagnostics {
  final IconData icon;
  final String headline;
  final String description;
  final List<_Reason> reasons;
  final List<InlineSpan> suggestionSpans;
  final String buttonLabel;

  const _Diagnostics({
    required this.icon,
    required this.headline,
    required this.description,
    required this.reasons,
    required this.suggestionSpans,
    required this.buttonLabel,
  });
}

class _Reason {
  final IconData icon;
  final String label;

  const _Reason({required this.icon, required this.label});
}

// ---------------------------------------------------------------------------
// Diagnostic reason card widget
// ---------------------------------------------------------------------------
class _DiagnosticReasonCard extends StatelessWidget {
  final _Reason reason;

  const _DiagnosticReasonCard({required this.reason});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.getBorder(context)),
        ),
        child: Row(
          children: [
            Icon(reason.icon, color: AppColors.primary, size: 20),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                reason.label,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
