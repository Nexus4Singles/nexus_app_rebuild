import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/session/guest_session_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import 'presurvey_gender_screen.dart';

class PresurveyRelationshipStatusScreen extends ConsumerWidget {
  const PresurveyRelationshipStatusScreen({super.key});

  Future<void> _selectStatus(
    BuildContext context,
    WidgetRef ref,
    RelationshipStatus status,
  ) async {
    await ref.read(guestSessionProvider.notifier).setRelationshipStatus(status);

    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PresurveyGenderScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guest = ref.watch(guestSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text('Relationship Status', style: AppTextStyles.headlineLarge),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What is your relationship status?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),

              _OptionButton(
                label: 'Never Married',
                selected:
                    guest?.relationshipStatus ==
                    RelationshipStatus.singleNeverMarried,
                onTap:
                    () => _selectStatus(
                      context,
                      ref,
                      RelationshipStatus.singleNeverMarried,
                    ),
              ),
              const SizedBox(height: 12),

              _OptionButton(
                label: 'Married',
                selected:
                    guest?.relationshipStatus == RelationshipStatus.married,
                onTap:
                    () =>
                        _selectStatus(context, ref, RelationshipStatus.married),
              ),
              const SizedBox(height: 12),

              _OptionButton(
                label: 'Divorced',
                selected:
                    guest?.relationshipStatus == RelationshipStatus.divorced,
                onTap:
                    () => _selectStatus(
                      context,
                      ref,
                      RelationshipStatus.divorced,
                    ),
              ),
              const SizedBox(height: 12),

              _OptionButton(
                label: 'Widowed',
                selected:
                    guest?.relationshipStatus == RelationshipStatus.widowed,
                onTap:
                    () =>
                        _selectStatus(context, ref, RelationshipStatus.widowed),
              ),
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
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Text(label, style: AppTextStyles.labelLarge),
      ),
    );
  }
}
