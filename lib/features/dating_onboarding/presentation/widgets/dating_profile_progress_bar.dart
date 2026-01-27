import 'package:flutter/material.dart';
import '../../../../core/theme/theme.dart';

class DatingProfileProgressBar extends StatelessWidget {
  final int currentStep;
  final int totalSteps;

  const DatingProfileProgressBar({
    super.key,
    required this.currentStep,
    required this.totalSteps,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Progress bar
        ClipRRect(
          borderRadius: BorderRadius.circular(4),
          child: LinearProgressIndicator(
            value: currentStep / totalSteps,
            minHeight: 6,
            backgroundColor: AppColors.getSurface(context),
            valueColor: AlwaysStoppedAnimation<Color>(AppColors.primary),
          ),
        ),
        const SizedBox(height: 8),
        // Step counter
        Text(
          'Step $currentStep of $totalSteps',
          style: AppTextStyles.labelSmall.copyWith(
            color: AppColors.getTextSecondary(context),
            fontWeight: FontWeight.w600,
          ),
        ),
      ],
    );
  }
}
