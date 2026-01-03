import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/session/guest_session_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'package:nexus_app_min_test/features/presurvey/presentation/screens/presurvey_goals_screen.dart';

class PresurveyGenderScreen extends ConsumerWidget {
  const PresurveyGenderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guest = ref.watch(guestSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        title: Text('Step 2 of 3', style: AppTextStyles.labelLarge),
        centerTitle: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'What is your gender?',
                style: AppTextStyles.headlineLarge.copyWith(fontSize: 26),
              ),
              const SizedBox(height: 10),
              Text(
                'This helps us personalize your search experience.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 28),

              _OptionButton(
                label: 'Male',
                selected: guest?.gender == 'male',
                onTap: () async {
                  await ref
                      .read(guestSessionProvider.notifier)
                      .setGender('male');
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => PresurveyGoalsScreen(
                              relationshipStatus: guest!.relationshipStatus,
                              gender: 'female',
                            ),
                      ),
                    );
                  }
                },
              ),
              const SizedBox(height: 12),
              _OptionButton(
                label: 'Female',
                selected: guest?.gender == 'female',
                onTap: () async {
                  await ref
                      .read(guestSessionProvider.notifier)
                      .setGender('female');
                  if (context.mounted) {
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder:
                            (_) => PresurveyGoalsScreen(
                              relationshipStatus: guest!.relationshipStatus,
                              gender: 'male',
                            ),
                      ),
                    );
                  }
                },
              ),

              const Spacer(),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1.1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
