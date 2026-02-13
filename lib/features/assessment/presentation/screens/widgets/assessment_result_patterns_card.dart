import 'package:flutter/material.dart';
import '../../../../../core/theme/theme.dart';
import '../../../../../core/models/recommendation_bundle.dart';

class AssessmentResultPatternsCard extends StatelessWidget {
  final List<CompoundPattern> patterns;

  const AssessmentResultPatternsCard({super.key, required this.patterns});

  @override
  Widget build(BuildContext context) {
    if (patterns.isEmpty) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(
                Icons.lightbulb_rounded,
                size: 18,
                color: AppColors.tierDeep,
              ),
              const SizedBox(width: 8),
              Text(
                'Breakthrough Insights',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Patterns detected across multiple areas',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          ...patterns.map((p) => _PatternTile(pattern: p)),
        ],
      ),
    );
  }
}

class _PatternTile extends StatelessWidget {
  final CompoundPattern pattern;
  const _PatternTile({required this.pattern});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.tierDeep.withOpacity(0.06),
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.tierDeep.withOpacity(0.15)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  pattern.patternDescription,
                  style: AppTextStyles.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextPrimary(context),
                    height: 1.5,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        pattern.dimensionNames.join(' + '),
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.tierDeep,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.tierDeep.withOpacity(0.12),
                        borderRadius: BorderRadius.circular(6),
                      ),
                      child: Text(
                        '${pattern.averageScore}% avg',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: AppColors.tierDeep,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.info.withOpacity(0.04),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.check_circle_outline_rounded,
                  size: 16,
                  color: AppColors.info,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    pattern.recommendedFocus,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.info,
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
