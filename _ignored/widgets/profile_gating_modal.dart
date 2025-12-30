import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../theme/app_colors.dart';
import '../theme/app_spacing.dart';
import '../models/dating_profile_model.dart';
import '../providers/search_provider.dart';
import 'app_button.dart';

/// Modal shown when user tries to view profile or message without complete dating profile
class ProfileGatingModal extends ConsumerWidget {
  final String title;
  final String message;
  final VoidCallback? onLater;

  const ProfileGatingModal({
    super.key,
    this.title = 'Complete Your Profile',
    this.message = 'Complete your dating profile to unlock viewing profiles and messaging.',
    this.onLater,
  });

  /// Show the gating modal
  static Future<bool?> show(BuildContext context, {
    String? title,
    String? message,
  }) {
    return showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ProfileGatingModal(
        title: title ?? 'Complete Your Profile',
        message: message ?? 'Complete your dating profile to unlock viewing profiles and messaging.',
      ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missingSteps = ref.watch(missingDatingStepsProvider);
    final completionPercent = ref.watch(datingProfileCompletionPercentProvider);

    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: const EdgeInsets.all(AppSpacing.xl),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Handle
            Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: AppColors.surfaceDark,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
            const SizedBox(height: AppSpacing.xl),

            // Icon
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.secondary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.lock_outline,
                size: 40,
                color: AppColors.secondary,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Title
            Text(
              title,
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),

            // Message
            Text(
              message,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.xl),

            // Progress indicator
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
              ),
              child: Column(
                children: [
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Text(
                        'Profile Completion',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                      ),
                      Text(
                        '$completionPercent%',
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                      ),
                    ],
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(AppSpacing.radiusFull),
                    child: LinearProgressIndicator(
                      value: completionPercent / 100,
                      backgroundColor: AppColors.surfaceDark,
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                      minHeight: 8,
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.lg),

            // Missing steps (first 3)
            if (missingSteps.isNotEmpty) ...[
              Text(
                'What\'s needed:',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.textMuted,
                    ),
              ),
              const SizedBox(height: AppSpacing.sm),
              ...missingSteps.take(3).map((step) => Padding(
                padding: const EdgeInsets.only(bottom: AppSpacing.xs),
                child: Row(
                  children: [
                    Icon(Icons.circle_outlined, size: 16, color: AppColors.textMuted),
                    const SizedBox(width: AppSpacing.sm),
                    Text(
                      step.title,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ],
                ),
              )),
              if (missingSteps.length > 3) ...[
                Padding(
                  padding: const EdgeInsets.only(top: AppSpacing.xs),
                  child: Text(
                    '+${missingSteps.length - 3} more',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: AppColors.textMuted,
                        ),
                  ),
                ),
              ],
            ],
            const SizedBox(height: AppSpacing.xl),

            // CTA
            AppButton.primary(
              label: 'Complete Profile',
              onPressed: () {
                Navigator.pop(context, true);
                context.push('/dating-profile/setup');
              },
              isExpanded: true,
              trailingIcon: Icons.arrow_forward,
            ),
            const SizedBox(height: AppSpacing.md),

            // Later button
            TextButton(
              onPressed: () {
                Navigator.pop(context, false);
                onLater?.call();
              },
              child: Text(
                'Maybe Later',
                style: TextStyle(color: AppColors.textSecondary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Inline gating banner for profile completion prompt
class ProfileCompletionBanner extends ConsumerWidget {
  final VoidCallback? onComplete;

  const ProfileCompletionBanner({super.key, this.onComplete});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isComplete = ref.watch(datingProfileCompleteProvider);
    final completionPercent = ref.watch(datingProfileCompletionPercentProvider);

    if (isComplete) return const SizedBox.shrink();

    return Container(
      margin: const EdgeInsets.all(AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.secondary,
            AppColors.secondary.withOpacity(0.8),
          ],
        ),
        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.sm),
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.2),
              shape: BoxShape.circle,
            ),
            child: const Icon(Icons.person_add, color: Colors.white, size: 20),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Complete your profile',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                Text(
                  '$completionPercent% complete',
                  style: TextStyle(
                    color: Colors.white.withOpacity(0.8),
                    fontSize: 12,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            onPressed: () {
              onComplete?.call();
              context.push('/dating-profile/setup');
            },
            style: TextButton.styleFrom(
              backgroundColor: Colors.white,
              foregroundColor: AppColors.secondary,
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
            ),
            child: const Text('Complete'),
          ),
        ],
      ),
    );
  }
}

/// Helper extension for gating checks
extension GatingExtension on BuildContext {
  /// Check if action is allowed, show modal if not
  Future<bool> checkProfileGating(WidgetRef ref, {
    String? title,
    String? message,
  }) async {
    final isComplete = ref.read(datingProfileCompleteProvider);
    if (isComplete) return true;

    final result = await ProfileGatingModal.show(
      this,
      title: title,
      message: message,
    );
    return result == true;
  }
}
