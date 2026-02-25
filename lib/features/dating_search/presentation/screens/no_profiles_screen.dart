import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';

class NoProfilesScreen extends StatelessWidget {
  final VoidCallback onRetry;
  final VoidCallback? onEditPreferences;
  final bool noProfilesInCountry;
  final String? countryName;

  const NoProfilesScreen({
    Key? key,
    required this.onRetry,
    this.onEditPreferences,
    this.noProfilesInCountry = false,
    this.countryName,
  }) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final displayCountry = countryName ?? 'this location';
    final heading =
        noProfilesInCountry
            ? 'No Profiles Found'
            : 'No profiles match your preferences';
    final description =
        noProfilesInCountry
            ? 'There are no active profiles in $displayCountry at the moment.'
            : 'Try adjusting your filters to find more matches.';
    final primaryMessage =
        noProfilesInCountry
            ? 'New members join every day - check back soon!'
            : 'Expand your preferences to see more profiles.';

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Icon
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

              // Main heading
              Text(
                heading,
                style: AppTextStyles.headlineMedium.copyWith(
                  color: AppColors.getTextPrimary(context),
                  fontWeight: FontWeight.w700,
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 16),

              // Description
              Text(
                description,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),

              const SizedBox(height: 32),

              // Feature highlights
              Container(
                padding: const EdgeInsets.all(20),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(context)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(
                          Icons.star_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'New users join every day',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.refresh_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            primaryMessage,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Icon(
                          Icons.notifications_rounded,
                          color: AppColors.primary,
                          size: 20,
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            'Come back soon for more matches',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextPrimary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 48),

              // Action buttons
              Column(
                children: [
                  // Edit Preferences button (if callback provided)
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
                          'Edit Preferences',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.textOnPrimary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  /// Helper method to extract country name from preferences
  /// This can be used when creating the screen from context
  static String? extractCountryName(String? countryCode) {
    if (countryCode == null || countryCode.isEmpty) return null;
    // Return the country code as-is; can be enhanced with full country names
    return countryCode;
  }
}
