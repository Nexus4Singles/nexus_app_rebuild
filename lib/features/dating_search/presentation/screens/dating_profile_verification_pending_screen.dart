import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'dating_preferences_setup_screen.dart';

class DatingProfileVerificationPendingScreen extends ConsumerWidget {
  final String? verificationStatus;

  const DatingProfileVerificationPendingScreen({
    Key? key,
    required this.verificationStatus,
  }) : super(key: key);

  bool get _isRejected => verificationStatus == 'rejected';

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Verification Required',
          style: AppTextStyles.headlineSmall,
        ),
      ),
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Container(
                  width: 96,
                  height: 96,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: AppColors.primary.withOpacity(0.12),
                  ),
                  child: Icon(
                    _isRejected ? Icons.error_outline : Icons.hourglass_top,
                    color: AppColors.primary,
                    size: 48,
                  ),
                ),
                const SizedBox(height: 28),
                Text(
                  _isRejected
                      ? 'Your profile needs attention'
                      : 'Your account is under review',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineSmall.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  _isRejected
                      ? 'Your dating profile was rejected by our verification team. Please update your profile to continue and resubmit for review.'
                      : 'Your account is pending admin verification. Once approved, you will be able to view your daily profiles.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(context).pushNamed('/profile');
                    },
                    child: Text(
                      _isRejected ? 'Go to Profile' : 'View Profile Status',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: AppColors.textOnPrimary,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                if (!_isRejected)
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder:
                                (_) => const DatingPreferencesSetupScreen(),
                          ),
                        );
                      },
                      child: Text(
                        'Set Preferences',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: AppColors.primary,
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
}
