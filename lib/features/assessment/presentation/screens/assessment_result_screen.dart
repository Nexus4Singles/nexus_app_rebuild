import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/providers/assessment_provider.dart';
import '../../../../core/services/assessment_recommendation_service.dart';
import '../../../../core/models/recommendation_bundle.dart';

class AssessmentResultScreen extends ConsumerWidget {
  const AssessmentResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assessmentNotifierProvider);
    final result = state.result;
    final config = state.config;

    if (result == null || config == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(
                Icons.info_outline,
                size: 64,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 12),
              const Text('No assessment result available'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed:
                    () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.home,
                      (_) => false,
                    ),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    final bundle = AssessmentRecommendationService().build(
      result: result,
      config: config,
    );

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
          children: [
            _TopBar(
              onClose: () {
                ref.read(assessmentNotifierProvider.notifier).reset();
                Navigator.pushNamedAndRemoveUntil(
                  context,
                  AppRoutes.home,
                  (_) => false,
                );
              },
            ),

            const SizedBox(height: 10),

            _ProfileCard(
              title: bundle.profileTitle,
              summary: bundle.profileSummary,
              tierLabel: result.overallTier.displayName,
              readinessPct: (result.overallPercentage * 100).round(),
              showSafetyBanner: bundle.isSafetyAlert,
            ),

            const SizedBox(height: 16),

            if (bundle.strengths.isNotEmpty)
              _DimensionSection(
                title: 'Strengths',
                subtitle: 'Areas you’re doing well in right now',
                items: bundle.strengths.take(2).toList(),
                pillColor: AppColors.success,
              ),

            if (bundle.strengths.isNotEmpty) const SizedBox(height: 14),

            if (bundle.growthAreas.isNotEmpty)
              _DimensionSection(
                title: 'Growth Areas',
                subtitle: 'Where focusing next will help the most',
                items: bundle.growthAreas.take(2).toList(),
                pillColor: AppColors.warning,
              ),

            const SizedBox(height: 16),
            _ExploreChallengesCtaCard(
              onTap: () => Navigator.pushNamed(context, '/challenges'),
            ),

            const SizedBox(height: 16),

            if ((bundle.recommendedJourneyId ?? '').trim().isNotEmpty)
              _JourneyCtaCard(
                journeyId: bundle.recommendedJourneyId!.trim(),
                onTap: () {
                  // TODO: wire to journey screen once ready.
                  // For now route to home; home can surface journeys.
                  Navigator.pushNamedAndRemoveUntil(
                    context,
                    AppRoutes.home,
                    (_) => false,
                  );
                },
              ),

            const SizedBox(height: 20),

            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed:
                    () => Navigator.pushNamedAndRemoveUntil(
                      context,
                      AppRoutes.home,
                      (_) => false,
                    ),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Done',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ExploreChallengesCtaCard extends StatelessWidget {
  final VoidCallback onTap;
  const _ExploreChallengesCtaCard({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recommended Next Steps',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'You don’t have to work through these areas alone.\nOur challenges offer structured, faith-grounded guidance designed around growth patterns like yours.'
                .replaceAll('\\n', '\n'),
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 14),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: OutlinedButton(
              onPressed: onTap,
              style: OutlinedButton.styleFrom(
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(color: AppColors.primary.withOpacity(0.35)),
              ),
              child: Text(
                'Explore Challenges',
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w800,
                  color: AppColors.primary,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onClose;
  const _TopBar({required this.onClose});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        const Spacer(),
        IconButton(onPressed: onClose, icon: const Icon(Icons.close)),
      ],
    );
  }
}

class _ProfileCard extends StatelessWidget {
  final String title;
  final String summary;
  final String tierLabel;
  final int readinessPct;
  final bool showSafetyBanner;

  const _ProfileCard({
    required this.title,
    required this.summary,
    required this.tierLabel,
    required this.readinessPct,
    required this.showSafetyBanner,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (showSafetyBanner) ...[
            _Banner(
              icon: Icons.shield_outlined,
              text:
                  'Safety may be a concern. Prioritize emotional and physical safety first.',
            ),
            const SizedBox(height: 12),
          ],

          Text(
            title.trim().isEmpty ? 'Your Profile' : title,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),

          const SizedBox(height: 8),

          if (summary.trim().isNotEmpty)
            Text(
              summary,
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),

          const SizedBox(height: 14),

          Row(
            children: [
              _Pill(
                label: tierLabel,
                icon: Icons.auto_awesome_outlined,
                backgroundColor: AppColors.primary.withOpacity(0.10),
                textColor: AppColors.primary,
              ),
              const SizedBox(width: 10),
              _Pill(
                label: '$readinessPct% readiness',
                icon: Icons.insights_outlined,
                backgroundColor: AppColors.border.withOpacity(0.45),
                textColor: AppColors.textPrimary,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _DimensionSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final List<DimensionRecommendation> items;
  final Color pillColor;

  const _DimensionSection({
    required this.title,
    required this.subtitle,
    required this.items,
    required this.pillColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 14),
          ...items.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _DimensionRow(
                name: d.dimensionName,
                percentage: d.percentage,
                tier: d.tier,
                insight: d.insightText,
                pillColor: pillColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DimensionRow extends StatelessWidget {
  final String name;
  final int percentage;
  final String tier;
  final String? insight;
  final Color pillColor;

  const _DimensionRow({
    required this.name,
    required this.percentage,
    required this.tier,
    required this.insight,
    required this.pillColor,
  });

  @override
  Widget build(BuildContext context) {
    final insightText = (insight ?? '').trim();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                name,
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
            ),
            _Pill(
              label: '$percentage%',
              icon: Icons.bolt_outlined,
              backgroundColor: pillColor.withOpacity(0.12),
              textColor: pillColor,
            ),
          ],
        ),
        const SizedBox(height: 6),
        if (insightText.isNotEmpty)
          Text(
            insightText,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.textMuted,
              height: 1.35,
            ),
          ),
      ],
    );
  }
}

class _JourneyCtaCard extends StatelessWidget {
  final String journeyId;
  final VoidCallback onTap;

  const _JourneyCtaCard({required this.journeyId, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        padding: const EdgeInsets.all(18),
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.08),
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        ),
        child: Row(
          children: [
            const Icon(Icons.flag_outlined, color: AppColors.primary),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Recommended Journey',
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'Journey ID: $journeyId',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.primary),
          ],
        ),
      ),
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;

  const _Banner({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.warning.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.warning.withOpacity(0.25)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.warning),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(height: 1.3),
            ),
          ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;

  const _Pill({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}
