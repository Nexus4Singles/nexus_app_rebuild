import 'package:flutter/material.dart';
import '../../../../../core/theme/theme.dart';
import '../../../../../core/models/recommendation_bundle.dart';

class AssessmentResultJourneyCard extends StatelessWidget {
  final List<JourneyRecommendationData> journeys;
  final VoidCallback onTapJourney;

  const AssessmentResultJourneyCard({
    super.key,
    required this.journeys,
    required this.onTapJourney,
  });

  @override
  Widget build(BuildContext context) {
    if (journeys.isEmpty) return const SizedBox.shrink();

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
              Icon(Icons.route_rounded, size: 18, color: AppColors.primary),
              const SizedBox(width: 8),
              Text(
                'Recommended For You',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Journeys tailored to your growth areas',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          ...journeys.map((j) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 10),
              child: _JourneyTile(
                title: j.journeyTitle,
                dimension: j.relevantDimension,
                dimensionScore: j.dimensionScore,
                rationale: j.rationale,
                onTap: onTapJourney,
              ),
            );
          }),
        ],
      ),
    );
  }
}

class _JourneyTile extends StatelessWidget {
  final String title;
  final String dimension;
  final int dimensionScore;
  final String rationale;
  final VoidCallback onTap;

  const _JourneyTile({
    required this.title,
    required this.dimension,
    required this.dimensionScore,
    required this.rationale,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.04),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.primary.withOpacity(0.15)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Expanded(
                  child: Text(
                    title,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: AppColors.getTextPrimary(context),
                    ),
                  ),
                ),
                Icon(
                  Icons.arrow_forward_ios_rounded,
                  size: 14,
                  color: AppColors.primary,
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              rationale,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
                height: 1.4,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '${dimension} • ${dimensionScore}% readiness',
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
