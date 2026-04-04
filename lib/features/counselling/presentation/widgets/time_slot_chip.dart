import 'package:flutter/material.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/counselling_models.dart';

class TimeSlotChip extends StatelessWidget {
  final TimeSlotModel slot;
  final bool isSelected;
  final VoidCallback onTap;

  const TimeSlotChip({
    super.key,
    required this.slot,
    required this.isSelected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primary
              : AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : AppColors.getTextSecondary(context).withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.3),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  )
                ]
              : [],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              slot.formattedStart,
              style: AppTextStyles.labelLarge.copyWith(
                color: isSelected
                    ? Colors.white
                    : AppColors.getTextPrimary(context),
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              '${slot.durationMinutes}min',
              style: AppTextStyles.bodySmall.copyWith(
                fontSize: 10,
                color: isSelected
                    ? Colors.white.withOpacity(0.85)
                    : AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
