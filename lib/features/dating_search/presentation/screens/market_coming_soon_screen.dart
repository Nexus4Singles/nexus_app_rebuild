import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import '../../domain/dating_preferences.dart';
import 'dating_preferences_setup_screen.dart';

class MarketComingSoonScreen extends StatelessWidget {
  final DatingPreferences? existingPreferences;

  const MarketComingSoonScreen({super.key, this.existingPreferences});

  void _openPreferences(BuildContext context) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder:
            (_) => DatingPreferencesSetupScreen(
              existingPreferences: existingPreferences,
            ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          tooltip: 'Back to preferences',
          icon: const Icon(Icons.arrow_back),
          onPressed: () => _openPreferences(context),
        ),
        actions: [
          IconButton(
            tooltip: 'Edit preferences',
            icon: const Icon(Icons.settings),
            onPressed: () => _openPreferences(context),
          ),
        ],
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.public_rounded, size: 72, color: AppColors.primary),
                const SizedBox(height: 28),
                Text(
                  'Coming To Your Country Soon',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Join the waitlist by creating your profile and kindly tell your friends about Nexus',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyLarge.copyWith(
                    color: AppColors.getTextSecondary(context),
                    height: 1.5,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
