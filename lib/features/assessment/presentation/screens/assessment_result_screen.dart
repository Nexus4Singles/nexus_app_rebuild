import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/providers/assessment_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/services/assessment_recommendation_service.dart';
import '../../../../core/models/recommendation_bundle.dart';
import '../../../../core/models/assessment_model.dart';
import '../../../../core/constants/app_constants.dart';
import 'widgets/assessment_result_journey_card.dart';
import 'widgets/assessment_result_patterns_card.dart';

class AssessmentResultScreen extends ConsumerWidget {
  const AssessmentResultScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final state = ref.watch(assessmentNotifierProvider);
    final gender = ref.watch(userGenderProvider);
    var result = state.result;
    var config = state.config;

    if (result == null) {
      final latestResultAsync = ref.watch(latestAnyAssessmentProvider);
      if (latestResultAsync.isLoading) {
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: CircularProgressIndicator(color: AppColors.primary),
          ),
        );
      }
      result = latestResultAsync.valueOrNull;
    }

    if (config == null && result != null) {
      final assessmentType = AssessmentType.fromId(result.assessmentId);
      if (assessmentType != null) {
        final configAsync = ref.watch(assessmentConfigProvider(assessmentType));
        config = configAsync.valueOrNull;
      }
    }

    if (result == null || config == null) {
      return Scaffold(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.info_outline,
                size: 64,
                color: AppColors.getTextSecondary(context),
              ),
              const SizedBox(height: 12),
              const Text('No assessment result available'),
              const SizedBox(height: 16),
              ElevatedButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Go Back'),
              ),
            ],
          ),
        ),
      );
    }

    final bundle = AssessmentRecommendationService().build(
      result: result,
      config: config,
      gender: gender,
    );

    final readinessPct = (result.overallPercentage * 100).round();

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: Column(
        children: [
          // ── Fixed hero header ──
          Stack(
            children: [
              // Hero header content with much more top padding
              Container(
                width: double.infinity,
                color: _tierColor(result.overallTier).withOpacity(0.08),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 60, 24, 18),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.end,
                    children: [
                      const SizedBox(width: 40), // space for back button
                      // ...existing code...
                    ],
                  ),
                ),
              ),
              // Fixed back button (not moving with content) - moved to last so it's on top
              Positioned(
                top: 0,
                left: 0,
                child: SafeArea(
                  bottom: false,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 4, top: 10),
                    child: IconButton(
                      icon: const Icon(Icons.arrow_back_ios_new_rounded),
                      padding: EdgeInsets.zero,
                      constraints: const BoxConstraints(),
                      onPressed: () {
                        ref.read(assessmentNotifierProvider.notifier).reset();
                        Navigator.pop(context);
                      },
                    ),
                  ),
                ),
              ),
            ],
          ),
          // ── Scrollable body ──
          Expanded(
            child: ListView(
              padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
              children: [
                if (bundle.isSafetyAlert) ...[
                  const SizedBox(height: 12),
                  _Banner(
                    icon: Icons.shield_outlined,
                    text:
                        'Your responses suggest safety may be a concern. '
                        'Emotional and physical safety come first.',
                    color: AppColors.error,
                  ),
                ],
                const SizedBox(height: 16),
                _NarrativeCard(
                  summary: bundle.profileSummary,
                  narrativeFrame: bundle.narrativeFrame,
                ),
                if (bundle.outcomeLabels.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _WhatWeNoticedSection(labels: bundle.outcomeLabels),
                ],
                if (bundle.compoundPatterns.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  AssessmentResultPatternsCard(
                    patterns: bundle.compoundPatterns,
                  ),
                ],
                if (bundle.strengths.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  _DimensionSection(
                    title: 'Your Strengths',
                    subtitle:
                        'These areas are working well — protect and nurture them',
                    icon: Icons.emoji_events_outlined,
                    iconColor: AppColors.success,
                    items: bundle.strengths.take(3).toList(),
                    barColor: AppColors.success,
                  ),
                ],
                if (bundle.growthAreas.isNotEmpty) ...[
                  const SizedBox(height: 20),
                  _DimensionSection(
                    title: 'Growth Areas',
                    subtitle:
                        'Focused attention here will make the biggest difference',
                    icon: Icons.trending_up_rounded,
                    iconColor: AppColors.warning,
                    items: bundle.growthAreas.take(3).toList(),
                    barColor: AppColors.warning,
                  ),
                ],
                if (bundle.recommendedJourneys.isNotEmpty) ...[
                  const SizedBox(height: 24),
                  AssessmentResultJourneyCard(
                    journeys: bundle.recommendedJourneys,
                    onTapJourney: () {
                      Navigator.pushNamed(context, AppRoutes.challenges);
                    },
                  ),
                ],
                const SizedBox(height: 28),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child:
                      state.isNewlySubmitted
                          ? _PrimaryButton(
                            label: 'Go to Homepage',
                            onPressed: () {
                              Navigator.of(context).popUntil((route) => route.isFirst);
                            },
                          )
                          : _PrimaryButton(
                            label: 'Retake Assessment',
                            onPressed: () {
                              ref
                                  .read(assessmentNotifierProvider.notifier)
                                  .reset();
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                AppRoutes.assessment,
                                (route) =>
                                    route.settings.name == AppRoutes.home,
                              );
                            },
                          ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  static String _ringLabel(String assessmentId) {
    final type = AssessmentType.fromId(assessmentId);
    switch (type) {
      case AssessmentType.singlesReadiness:
        return 'Marriage\nReadiness';
      case AssessmentType.remarriageReadiness:
        return 'Remarriage\nReadiness';
      case AssessmentType.marriageHealthCheck:
        return 'Marriage\nHealth';
      default:
        return 'Overall\nReadiness';
    }
  }

  static Color _tierColor(SignalTier tier) {
    switch (tier) {
      case SignalTier.strong:
        return AppColors.success;
      case SignalTier.developing:
        return AppColors.info;
      case SignalTier.guarded:
        return AppColors.warning;
      case SignalTier.atRisk:
        return AppColors.error;
      default:
        return AppColors.primary;
    }
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final VoidCallback onPressed;
  const _PrimaryButton({required this.label, required this.onPressed});

  @override
  Widget build(BuildContext context) {
    return ElevatedButton(
      onPressed: onPressed,
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.primary,
        foregroundColor: Theme.of(context).colorScheme.onPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        elevation: 0,
      ),
      child: Text(
        label,
        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    );
  }
}

class _TierChip extends StatelessWidget {
  final SignalTier tier;
  const _TierChip({required this.tier});

  @override
  Widget build(BuildContext context) {
    final color = AssessmentResultScreen._tierColor(tier);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.auto_awesome_outlined, size: 14, color: color),
          const SizedBox(width: 6),
          Text(
            tier.displayName,
            style: AppTextStyles.labelSmall.copyWith(
              color: color,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _NarrativeCard extends StatelessWidget {
  final String summary;
  final String? narrativeFrame;
  const _NarrativeCard({required this.summary, this.narrativeFrame});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
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
                Icons.auto_stories_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'Assessment Summary',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            summary,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
              height: 1.55,
            ),
          ),
        ],
      ),
    );
  }
}

class _ReadinessRing extends StatelessWidget {
  final int percentage;
  final SignalTier tier;
  final double size;
  final String? label;
  const _ReadinessRing({
    required this.percentage,
    required this.tier,
    this.size = 160,
    this.label,
  });

  @override
  Widget build(BuildContext context) {
    final color = AssessmentResultScreen._tierColor(tier);
    final strokeW = size >= 120 ? 10.0 : 7.0;
    final pctFont = size >= 120 ? 32.0 : 22.0;
    final labelFont = size >= 120 ? 11.0 : 9.5;
    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            width: size,
            height: size,
            child: TweenAnimationBuilder<double>(
              tween: Tween(begin: 0.0, end: percentage / 100.0),
              duration: const Duration(milliseconds: 1200),
              curve: Curves.easeOutCubic,
              builder: (context, value, _) {
                return CircularProgressIndicator(
                  value: value,
                  strokeWidth: strokeW,
                  strokeCap: StrokeCap.round,
                  backgroundColor: color.withOpacity(0.10),
                  valueColor: AlwaysStoppedAnimation<Color>(color),
                );
              },
            ),
          ),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TweenAnimationBuilder<int>(
                tween: IntTween(begin: 0, end: percentage),
                duration: const Duration(milliseconds: 1200),
                curve: Curves.easeOutCubic,
                builder: (context, value, _) {
                  return Text(
                    '$value%',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w900,
                      fontSize: pctFont,
                      color: color,
                    ),
                  );
                },
              ),
              if (label != null) ...[
                const SizedBox(height: 1),
                Text(
                  label!,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontWeight: FontWeight.w700,
                    fontSize: labelFont,
                    height: 1.2,
                  ),
                ),
              ],
            ],
          ),
        ],
      ),
    );
  }
}

class _WhatWeNoticedSection extends StatelessWidget {
  final List<String> labels;
  const _WhatWeNoticedSection({required this.labels});

  @override
  Widget build(BuildContext context) {
    // Sort labels by length (shortest first)
    final sortedLabels = [...labels]
      ..sort((a, b) => a.length.compareTo(b.length));
    final cardHPadding = 8.0;
    return Container(
      padding: EdgeInsets.fromLTRB(cardHPadding, 18, cardHPadding, 18),
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
                Icons.psychology_outlined,
                size: 18,
                color: AppColors.primary,
              ),
              const SizedBox(width: 8),
              Text(
                'What We Noticed',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            'Patterns we identified across multiple areas',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children:
                sortedLabels
                    .map(
                      (label) =>
                          _TagPill(label: _capitalize(label), isError: true),
                    )
                    .toList(),
          ),
        ],
      ),
    );
  }

  String _capitalize(String s) {
    if (s.isEmpty) return s;
    return s[0].toUpperCase() + s.substring(1);
  }
}

class _TagPill extends StatelessWidget {
  final String label;
  final bool isError;
  const _TagPill({required this.label, this.isError = false});

  @override
  Widget build(BuildContext context) {
    final bgColor =
        isError ? AppColors.primary : AppColors.primary.withOpacity(0.10);
    final borderColor =
        isError
            ? AppColors.primary.withOpacity(0.18)
            : AppColors.primary.withOpacity(0.18);
    final textColor =
        isError ? AppColors.getTextOnPrimary(context) : AppColors.primary;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 7),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w700,
          color: textColor,
          fontSize: 11.0,
        ),
        maxLines: 2,
        overflow: TextOverflow.ellipsis,
        softWrap: true,
        textAlign: TextAlign.center,
      ),
    );
  }
}

class _DimensionSection extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconColor;
  final List<DimensionRecommendation> items;
  final Color barColor;

  const _DimensionSection({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.iconColor,
    required this.items,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
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
              Icon(icon, size: 18, color: iconColor),
              const SizedBox(width: 8),
              Text(
                title,
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 16),
          ...items.map(
            (d) => Padding(
              padding: const EdgeInsets.only(bottom: 16),
              child: _DimensionCard(
                name: d.dimensionName,
                percentage: d.percentage,
                insight: d.bestInsight,
                microStep: d.bestMicroStep,
                barColor: barColor,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DimensionCard extends StatelessWidget {
  final String name;
  final int percentage;
  final String? insight;
  final String? microStep;
  final Color barColor;

  const _DimensionCard({
    required this.name,
    required this.percentage,
    required this.insight,
    required this.microStep,
    required this.barColor,
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
            Text(
              '$percentage%',
              style: AppTextStyles.bodyMedium.copyWith(
                fontWeight: FontWeight.w800,
                color: barColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        TweenAnimationBuilder<double>(
          tween: Tween(begin: 0.0, end: percentage / 100.0),
          duration: const Duration(milliseconds: 900),
          curve: Curves.easeOutCubic,
          builder: (context, value, _) {
            return ClipRRect(
              borderRadius: BorderRadius.circular(6),
              child: LinearProgressIndicator(
                value: value,
                minHeight: 6,
                backgroundColor: barColor.withOpacity(0.10),
                valueColor: AlwaysStoppedAnimation<Color>(barColor),
              ),
            );
          },
        ),
        if (insightText.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            insightText,
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
              height: 1.45,
            ),
          ),
        ],
      ],
    );
  }
}

class _Banner extends StatelessWidget {
  final IconData icon;
  final String text;
  final Color color;

  const _Banner({required this.icon, required this.text, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withOpacity(0.20)),
      ),
      child: Row(
        children: [
          Icon(icon, size: 20, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodySmall.copyWith(
                height: 1.4,
                color: color,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
