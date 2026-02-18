import 'package:flutter/material.dart';
import '../../../../../core/theme/theme.dart';
import '../../../../../core/models/recommendation_bundle.dart';

class AssessmentResultJourneyCard extends StatelessWidget {
  final List<JourneyRecommendationData> journeys;
  final Function(String journeyId) onTapJourney;

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
                subtitle: j.journeySubtitle,
                journeyId: j.journeyId,
                onTap: () => onTapJourney(j.journeyId),
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
  final String subtitle;
  final String journeyId;
  final VoidCallback onTap;

  const _JourneyTile({
    required this.title,
    required this.subtitle,
    required this.journeyId,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.03),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.getBorder(context), width: 1),
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
              subtitle,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
                height: 1.4,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
