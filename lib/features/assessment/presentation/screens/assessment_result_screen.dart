import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/providers/assessment_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/assessment_recommendation_bundle_provider.dart';
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

    // If no result in state, fetch the latest from async provider
    // Use .when() to properly handle loading/error/data states
    if (result == null) {
      final latestResultAsync = ref.watch(latestAnyAssessmentProvider);
      return latestResultAsync.when(
        loading:
            () => Scaffold(
              backgroundColor: Theme.of(context).scaffoldBackgroundColor,
              body: Center(
                child: CircularProgressIndicator(color: AppColors.primary),
              ),
            ),
        error: (_, __) => _buildNoResultScreen(context),
        data: (latestResult) {
          result = latestResult;
          print(
            '[AssessmentResultScreen] ✓ Loaded latest assessment result: ${latestResult?.assessmentId}',
          );
          return _buildResultScreenContent(
            context,
            ref,
            state,
            result,
            config,
            gender,
          );
        },
      );
    }

    return _buildResultScreenContent(
      context,
      ref,
      state,
      result,
      config,
      gender,
    );
  }

  Widget _buildResultScreenContent(
    BuildContext context,
    WidgetRef ref,
    AssessmentState state,
    AssessmentResult? result,
    AssessmentConfig? config,
    String? gender,
  ) {
    // If no result, show error
    if (result == null) {
      print('[AssessmentResultScreen] ❌ No result found');
      return _buildNoResultScreen(context);
    }

    print(
      '[AssessmentResultScreen] ✓ Building result screen for: ${result.assessmentId}, dimensionScores=${result.dimensionScores.length}, answers=${result.answers.length}',
    );

    // Fetch config if needed
    if (config == null) {
      // Use relationship-aware provider for remarriage assessments (divorced vs widowed)
      // This ensures the correct config loads for divorced/widowed-specific assessment IDs
      if (result.assessmentId.contains('divorced') ||
          result.assessmentId.contains('widowed') ||
          result.assessmentId == 'remarriage_readiness') {
        // For remarriage assessments, use relationship-aware provider
        final configAsync = ref.watch(relationshipAwareAssessmentProvider);
        return configAsync.when(
          loading:
              () => Scaffold(
                backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                body: Center(
                  child: CircularProgressIndicator(color: AppColors.primary),
                ),
              ),
          error: (_, __) {
            print(
              '[AssessmentResultScreen] ❌ Config load error for ${result.assessmentId}',
            );
            return _buildNoResultScreen(context);
          },
          data: (loadedConfig) {
            if (loadedConfig == null) {
              print(
                '[AssessmentResultScreen] ❌ Config is null for ${result.assessmentId}',
              );
              return _buildNoResultScreen(context);
            }
            print(
              '[AssessmentResultScreen] ✓ Loaded config: ${loadedConfig.assessmentId}',
            );
            return _buildResultDisplay(
              context,
              ref,
              state,
              result,
              loadedConfig,
              gender,
            );
          },
        );
      } else {
        // For non-remarriage assessments, use standard type-based lookup
        final assessmentType = AssessmentType.fromId(result.assessmentId);
        if (assessmentType != null) {
          final configAsync = ref.watch(
            assessmentConfigProvider(assessmentType),
          );
          return configAsync.when(
            loading:
                () => Scaffold(
                  backgroundColor: Theme.of(context).scaffoldBackgroundColor,
                  body: Center(
                    child: CircularProgressIndicator(color: AppColors.primary),
                  ),
                ),
            error: (_, __) => _buildNoResultScreen(context),
            data: (loadedConfig) {
              if (loadedConfig == null) {
                return _buildNoResultScreen(context);
              }
              return _buildResultDisplay(
                context,
                ref,
                state,
                result,
                loadedConfig,
                gender,
              );
            },
          );
        } else {
          return _buildNoResultScreen(context);
        }
      }
    }

    return _buildResultDisplay(context, ref, state, result, config, gender);
  }

  Widget _buildResultDisplay(
    BuildContext context,
    WidgetRef ref,
    AssessmentState state,
    AssessmentResult result,
    AssessmentConfig config,
    String? gender,
  ) {
    // Use async provider to get recommendations with proper journey loading
    final bundleAsync = ref.watch(
      assessmentRecommendationBundleProvider((
        result: result,
        config: config,
        gender: gender,
      )),
    );

    return bundleAsync.when(
      loading:
          () => Scaffold(
            backgroundColor: Theme.of(context).scaffoldBackgroundColor,
            body: Center(
              child: CircularProgressIndicator(color: AppColors.primary),
            ),
          ),
      error: (error, stack) {
        // DO NOT USE SYNC FALLBACK - it has no subtitles and uses hardcoded titles
        // Log the error for debugging but return empty result instead
        print('[AssessmentResultScreen] ❌ CRITICAL: buildAsync failed: $error');
        print('[AssessmentResultScreen] Stack: $stack');

        // Return error screen with ability to retake
        return Scaffold(
          backgroundColor: Theme.of(context).scaffoldBackgroundColor,
          body: Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 48, color: AppColors.primary),
                const SizedBox(height: 16),
                Text(
                  'Something went wrong loading your results',
                  style: Theme.of(context).textTheme.titleMedium,
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 32),
                ElevatedButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Retake Assessment'),
                ),
              ],
            ),
          ),
        );
      },
      data: (bundle) {
        return _buildResultContent(context, ref, state, result, bundle);
      },
    );
  }

  Widget _buildResultContent(
    BuildContext context,
    WidgetRef ref,
    AssessmentState state,
    AssessmentResult result,
    RecommendationBundle bundle,
  ) {
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            Text(
                              bundle.profileTitle,
                              style: AppTextStyles.titleLarge.copyWith(
                                fontWeight: FontWeight.w900,
                                fontSize: 20,
                              ),
                            ),
                            const SizedBox(height: 10),
                            _TierChip(tier: result.overallTier),
                          ],
                        ),
                      ),
                      const SizedBox(width: 12),
                      _ReadinessRing(
                        percentage: readinessPct,
                        tier: result.overallTier,
                        size: 115,
                        label: _ringLabel(result.assessmentId),
                      ),
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
                        if (Navigator.of(context).canPop()) {
                          Navigator.pop(context);
                        } else {
                          Navigator.pushReplacementNamed(context, '/home');
                        }
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
                    onTapJourney: (journeyId) {
                      print(
                        '[AssessmentResultScreen] ▶️ Tap recommended journey: id=$journeyId',
                      );
                      Navigator.pushNamed(context, '/journey/$journeyId');
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
                            onPressed:
                                () => Navigator.pushNamedAndRemoveUntil(
                                  context,
                                  AppRoutes.home,
                                  (_) => false,
                                ),
                          )
                          : _PrimaryButton(
                            label: 'Retake Assessment',
                            onPressed: () {
                              ref
                                  .read(assessmentNotifierProvider.notifier)
                                  .reset();
                              final assessmentType = AssessmentType.fromId(
                                result.assessmentId,
                              );
                              final typeId = assessmentType?.id ?? '';
                              Navigator.of(context).pushNamedAndRemoveUntil(
                                '${AppRoutes.assessmentIntro}?type=$typeId',
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

  static Widget _buildNoResultScreen(BuildContext context) {
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
              onPressed: () {
                if (Navigator.of(context).canPop()) {
                  Navigator.pop(context);
                } else {
                  Navigator.pushReplacementNamed(context, '/home');
                }
              },
              child: const Text('Go Back'),
            ),
          ],
        ),
      ),
    );
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
    // Convert outcome labels to full sentences and sort by length (shortest first)
    final sentences = labels.map(_convertToSentence).toList();
    final sortedLabels = [...sentences]
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
                    .map((label) => _TagPill(label: label, isError: true))
                    .toList(),
          ),
        ],
      ),
    );
  }

  /// Converts outcome label phrases to full grammatically correct sentences in sentence case
  String _convertToSentence(String label) {
    final normalized = label.trim().toLowerCase();

    final mapping = {
      // ═════════════════════════════════════════════════════════════════
      // SINGLES READINESS (single, never married users)
      // ═════════════════════════════════════════════════════════════════

      // Emotional Security & Stress Management
      'steady under pressure': 'You are steady under pressure',
      'opens up to process': 'You open up to process emotions',
      'suppresses emotions': 'You suppress emotions',
      'struggles to move past emotions': 'You struggle to move past emotions',
      'secure and grounded': 'You feel secure and grounded',

      // Attachment Patterns
      'anxious attachment pattern': 'You have an anxious attachment pattern',
      'avoidant attachment pattern': 'You have an avoidant attachment pattern',
      'conflicted but self-aware': 'You are conflicted but self-aware',

      // Feedback & Self-Correction
      'open to feedback and self-correction':
          'You are open to feedback and self-correction',
      'defensive first, reflective later':
          'You are defensive first, reflective later',
      'explains instead of truly listening':
          'You explain instead of truly listening',
      'shuts down under feedback': 'You shut down under feedback',

      // Resilience & Support
      'resilient with healthy support':
          'You are resilient with healthy support',
      'endures alone, rarely asks for help':
          'You endure alone, rarely asking for help',
      'avoidance-based survival': 'You rely on avoidance-based survival',
      'falls apart under pressure': 'You fall apart under pressure',

      // Faith & Spirituality
      'visible, integrated faith': 'You have visible, integrated faith',
      'genuine faith, inconsistent practice':
          'You have genuine faith but inconsistent practice',
      'private belief, rarely practiced':
          'You have private belief, rarely practiced',
      'faith identity in question': 'Your faith identity is in question',

      // Pattern Awareness & Family Patterns
      'real-time pattern interruption': 'You interrupt patterns in real-time',
      'slow to catch it, but learning':
          'You are slow to catch patterns but learning',
      'low pattern awareness': 'You have low pattern awareness',
      'family patterns you haven\'t examined':
          'You have family patterns you haven\'t examined',

      // Conflict & Forgiveness
      'approaches conflict with curiosity':
          'You approach conflict with curiosity',
      'forgives outwardly, builds resentment':
          'You forgive outwardly but build resentment',
      'silent withdrawal': 'You engage in silent withdrawal',
      'reactive confrontation': 'You engage in reactive confrontation',
      'speaks the pain without attacking':
          'You speak the pain without attacking',
      'goes quiet to process internally': 'You go quiet to process internally',
      'hides hurt, replays it alone': 'You hide hurt and replay it alone',
      'retaliates or shuts people out': 'You retaliate or shut people out',

      // Relationship Selection & Partner Evaluation
      'character-driven evaluation': 'You make character-driven evaluations',
      'patient but potentially passive':
          'You are patient but potentially passive',
      'led by feelings, overlooks red flags':
          'You are led by feelings and overlook red flags',
      'chemistry overrides discernment': 'Chemistry overrides your discernment',

      // Anger Management
      'feels the anger, chooses the response':
          'You feel the anger but choose the response',
      'steps away to protect the relationship':
          'You step away to protect the relationship',
      'emotionally shuts down when hurt': 'You shut down emotionally when hurt',
      'anger takes over': 'Anger takes over',

      // Forgiveness Processing
      'forgiveness with appropriate boundaries':
          'You practice forgiveness with appropriate boundaries',
      'past the anger but still guarded':
          'You are past the anger but still guarded',
      'verbal forgiveness, emotional retention':
          'You give verbal forgiveness but retain emotion',
      'honest about pain, stuck in unforgiveness':
          'You are honest about pain but stuck in unforgiveness',

      // Spiritual Leadership & Collaboration
      'mutual spiritual discernment':
          'You practice mutual spiritual discernment',
      'structured headship model': 'You follow a structured headship model',
      'each follows own spiritual path':
          'You each follow your own spiritual path',
      'hasn\'t considered long-term vision':
          'You haven\'t considered long-term vision',

      // Vulnerability & Acceptance
      'can share openly without being destabilized':
          'You can share openly without being destabilized',
      'tender but can manage it': 'You are tender but can manage it',
      'hides feelings, deflects attention':
          'You hide feelings and deflect attention',

      // ═════════════════════════════════════════════════════════════════
      // REMARRIAGE - DIVORCED (divorced users seeking remarriage)
      // ═════════════════════════════════════════════════════════════════
      'emotionally steady with minimal emotional charge':
          'You are emotionally steady with minimal emotional charge',
      'brief feelings surface, moves past them':
          'Brief feelings surface, but you move past them',
      'body tenses up, something unresolved':
          'Your body tenses up when something unresolved surfaces',
      'emotional flooding when triggered':
          'You experience emotional flooding when triggered',
      'integrated narrative with meaning':
          'You have an integrated narrative with meaning',
      'growing insight, still tends to blame':
          'You show growing insight but still tend to blame',
      'avoids making sense of the past': 'You avoid making sense of the past',
      'fragmented memories, unprocessed pain':
          'You have fragmented memories and unprocessed pain',
      'notices and returns to present':
          'You notice triggers and return to the present',
      'temporary disruption, self-corrects':
          'Brief disruptions occur but you self-correct',
      'memories override current emotional state':
          'Your memories override your current emotional state',
      'happiness triggers grief or fear':
          'Happiness triggers grief or fear in you',
      'healthy longing, not driven by it':
          'You have healthy longing but aren\'t driven by it',
      'driven by need to belong': 'You are driven by a need to belong',
      'drawn to familiarity and comfort':
          'You are drawn to familiarity and comfort',
      'rushing to avoid being alone':
          'You rush into relationships to avoid being alone',
      'holds both the good and the hard':
          'You hold both the good and the hard with clarity',
      'emotional response, recovers well':
          'You have emotional responses but recover well',
      'absorbed by memories, mood shifts quickly':
          'You are absorbed by memories and your mood shifts quickly',
      'active avoidance of past': 'You actively avoid your past',
      'names their part clearly': 'You name your part clearly',
      'partial ownership tangled with pain':
          'You take partial ownership tangled with pain',
      'primarily attributes outcomes to external factors':
          'You primarily attribute outcomes to external factors',
      'blames the other person entirely': 'You blame the other person entirely',
      'emotional self-awareness growth':
          'You show emotional self-awareness growth',
      'spiritual maturity growth': 'You show spiritual maturity growth',
      'communication and conflict skills':
          'You show growth in communication and conflict skills',
      'growing but direction is unclear':
          'You are growing but your direction is unclear',
      'deep, experience-earned wisdom':
          'You have deep, experience-earned wisdom',
      'pattern awareness growing': 'Your pattern awareness is growing',
      'partner-selection focused, limited depth':
          'You focus on partner-selection with limited depth',
      'experience unprocessed, no clear path forward':
          'Your experience is unprocessed with no clear path forward',
      'can point to real change': 'You can point to real change',
      'insight gained, not fully tested':
          'You have gained insight but haven\'t fully tested it',
      'believes they\'ve changed without real evidence':
          'You believe you\'ve changed without real evidence',
      'change attributed to partner change, not self':
          'You attribute change to your partner, not yourself',
      'real-time pattern correction': 'You correct patterns in real-time',
      'growing awareness, delayed correction':
          'You have growing awareness but delayed correction',
      'unaware of patterns from family of origin':
          'You are unaware of patterns from your family of origin',
      'repeats old patterns without realizing':
          'You repeat old patterns without realizing it',
      'trust is earned, not declared':
          'You believe trust is earned, not declared',
      'cautious hope with protective instinct':
          'You have cautious hope with protective instinct',
      'cynicism as self-protection': 'You use cynicism as self-protection',
      'words override wise judgment':
          'You let words override your wise judgment',
      'conflict normalized, not feared':
          'Conflict is normalized and not feared',
      'anxious but stays present': 'You feel anxious but stay present',
      'assumes worst will happen based on past hurt':
          'You assume the worst will happen based on past hurt',
      'emotional overwhelm causes withdrawal':
          'You experience emotional overwhelm that causes withdrawal',
      'did the work, seeing real results':
          'You did the work and are seeing real results',
      'mid-journey, clearly progressing':
          'You are mid-journey and clearly progressing',
      'relied on time, not intentional healing':
          'You relied on time instead of intentional healing',

      // ═════════════════════════════════════════════════════════════════
      // REMARRIAGE - WIDOWED (widowed users seeking remarriage)
      // ═════════════════════════════════════════════════════════════════
      'some self-awareness, grief shapes the story':
          'You have some self-awareness, and grief shapes your story',
      'holds the full picture with peace':
          'You hold the full picture with peace',
      'learning to be honest about the whole marriage':
          'You are learning to be honest about the whole marriage',
      'idealizing the marriage, avoiding the hard parts':
          'You idealize the marriage and avoid the hard parts',
      'stuck in regret and guilt': 'You are stuck in regret and guilt',
      'sees this person, not the past': 'You see this person, not the past',
      'aware of trigger, managing actively':
          'You are aware of triggers and manage them actively',
      'reacts before thinking, unaware of it':
          'You react before thinking, unaware of it',
      'overwhelmed by past intrusion': 'You are overwhelmed by past intrusion',
      'honors the memory, stays present':
          'You honor the memory and stay present',
      'feels the longing but redirects': 'You feel the longing but redirect it',
      'guilt about replacing late spouse':
          'You feel guilt about replacing your late spouse',
      'idealization blocks new love':
          'Idealization blocks your ability to love again',
      'visible behavior change others can confirm':
          'Others can confirm your visible behavior change',
      'improving but reverts under stress':
          'You are improving but revert under stress',
      'aware but untested in real relationship':
          'You are aware but untested in a real relationship',
      'understands the pattern but hasn\'t changed it':
          'You understand the pattern but haven\'t changed it',
      'honest even when it costs': 'You are honest even when it costs',
      'intends to be honest but keeps delaying':
          'You intend to be honest but keep delaying',
      'controls how others see them': 'You control how others see you',
      'habit of hiding, unsure how to change':
          'You have a habit of hiding and are unsure how to change',
      'can sit in unresolved tension': 'You can sit in unresolved tension',
      'anxious until resolved, may push too fast':
          'You feel anxious until resolved and may push too fast',
      'disagreement threatens the whole bond':
          'You feel disagreement threatens the whole bond',
      'gives in just to end the discomfort':
          'You give in just to end the discomfort',
      'honest and appropriate': 'You are honest and appropriate',
      'cautious but appropriate': 'You are cautious but appropriate',
      'shares everything or nothing at all':
          'You share everything or nothing at all',
      'shame-driven concealment': 'Shame drives your concealment',
      'open with wisdom and intention':
          'You are open with wisdom and intention',
      'willing but uncertain of own readiness':
          'You are willing but uncertain of your own readiness',
      'resists vulnerability out of fear':
          'You resist vulnerability out of fear',
      'seeks others\' approval while already moving':
          'You seek others\' approval while already moving forward',
      'grounded readiness': 'You have grounded readiness',
      'approaching readiness with self-awareness':
          'You are approaching readiness with self-awareness',
      'desire to remarry ahead of readiness':
          'Your desire to remarry is ahead of your readiness',
      'loneliness overriding wisdom': 'Loneliness overrides your wisdom',
      'holds past and present peacefully':
          'You hold the past and present peacefully',
      'bittersweet but stays in the moment':
          'Life is bittersweet but you stay in the moment',
      'struggling with guilt about happiness after loss':
          'You struggle with guilt about being happy after loss',
      'happiness triggers fear of loss': 'Happiness triggers your fear of loss',
      'daily reliance and peace': 'You have daily reliance and peace',
      'healing-oriented posture': 'You take a healing-oriented posture',
      'believes but God feels distant': 'You believe but God feels distant',
      'spiritual crisis from marital loss':
          'You experience a spiritual crisis from marital loss',
      'clear conscience, spiritual freedom':
          'You have a clear conscience and spiritual freedom',
      'mostly peaceful, lingering doubt about loyalty':
          'You are mostly peaceful with lingering doubt about loyalty',
      'uncertain whether remarriage honors their memory':
          'You are uncertain whether remarriage honors their memory',
      'spiritual paralysis from loyalty and grief':
          'You experience spiritual paralysis from loyalty and grief',
      'already living the vision': 'You are already living the vision',
      'clear vision, honest about the gap':
          'You have a clear vision and are honest about the gap',
      'has a vision but lacks a healthy model':
          'You have a vision but lack a healthy model',
      'fear of repeating family damage': 'You fear repeating family damage',
      'functioning around the pain, not through it':
          'You are functioning around the pain, not through it',

      // ═════════════════════════════════════════════════════════════════
      // MARRIAGE HEALTH CHECK (married couples)
      // ═════════════════════════════════════════════════════════════════

      // Connection & Enjoyment
      'natural enjoyment of each other': 'You naturally enjoy each other',
      'comfortable apart, low effort to connect':
          'You are comfortable apart with low effort to connect',
      'drifting into separate worlds': 'You are drifting into separate worlds',
      'uncomfortable with unplanned time together':
          'You are uncomfortable with unplanned time together',

      // Appreciation & Affirmation
      'specific, expressed appreciation':
          'You express specific, meaningful appreciation',
      'love felt but rarely expressed': 'Love is felt but rarely expressed',
      'marriage running on autopilot': 'Your marriage is running on autopilot',
      'negativity filter active': 'You have an active negativity filter',

      // Quality Time
      'established quality time rhythm':
          'You have an established quality time rhythm',
      'willing but out of practice': 'You are willing but out of practice',
      'avoids unplanned closeness': 'You avoid unplanned closeness',
      'spending time together creates tension':
          'Spending time together creates tension',

      // Emotional Safety
      'spouse is emotional safe harbor':
          'Your spouse is your emotional safe harbor',
      'opens up partially, holds back the rest':
          'You open up partially but hold back the rest',
      'protective isolation': 'You engage in protective isolation',
      'spouse is not the emotional safe person':
          'Your spouse is not your emotional safe person',

      // Intimacy
      'alive and mutual': 'Your intimacy is alive and mutual',
      'trying hard to stay connected': 'You are trying hard to stay connected',
      'tension or avoidance around intimacy':
          'There is tension or avoidance around intimacy',
      'faith absent or purely obligatory':
          'Faith is absent or purely obligatory',

      // Spiritual Life Together
      'faith woven into weekly rhythm':
          'Faith is woven into your weekly rhythm',
      'faith on Sunday, absent during the week':
          'Faith is present on Sunday but absent during the week',
      'only one spouse pursuing spiritual growth':
          'Only one spouse is pursuing spiritual growth',
      'faith absent from daily life together':
          'Faith is absent from your daily life together',

      // Conflict Management
      'productive tension management': 'You manage tension productively',
      'emotions take over': 'Emotions take over',
      'leaves conversations before resolution':
          'You leave conversations before resolution',
      'rapid escalation': 'Conflict escalates rapidly',

      // Respect During Conflict
      'holds the line on respect': 'You hold the line on respect',
      'respect slips under pressure': 'Respect slips under pressure',
      'mirrors partner\'s negative energy':
          'You mirror your partner\'s negative energy',
      'goes for the weak spot': 'You go for the weak spot',

      // Repair After Conflict
      'natural repair instinct': 'You have a natural repair instinct',
      'slowly warming toward reconciliation':
          'You are slowly warming toward reconciliation',
      'avoidance of repair': 'You avoid repair',
      'prolonged disconnection': 'There is prolonged disconnection',

      // Receiving Concerns
      'turns toward spouse\'s concern':
          'You turn toward your spouse\'s concern',
      'listens but guard goes up': 'You listen but your guard goes up',
      'braces for criticism before it comes':
          'You brace for criticism before it comes',
      'shuts down emotionally before conflict starts':
          'You shut down emotionally before conflict starts',

      // Forgiveness
      'active, practiced forgiveness': 'You practice active, lived forgiveness',
      'choosing forgiveness daily': 'You choose forgiveness daily',
      'said i forgive, but heart still guarded':
          'You said you forgive but your heart is still guarded',
      'justified bitterness': 'You hold onto justified bitterness',

      // Honesty & Transparency
      'addresses directly from a foundation of trust':
          'You address issues directly from a foundation of trust',
      'one lie opens a door of lasting doubt':
          'One lie opens a door of lasting doubt',
      'pattern of trust erosion': 'There is a pattern of trust erosion',
      'dishonesty has become normal': 'Dishonesty has become normal',

      // Responsiveness to Vulnerable Sharing
      'expects care and receptivity': 'You expect care and receptivity',
      'safe sometimes, defended against other times':
          'It is safe sometimes but defended against other times',
      'expects dismissal or reversal': 'You expect dismissal or reversal',
      'learned silence from repeated pain':
          'You learned silence from repeated pain',

      // Repair Process
      'structured, intentional repair process':
          'You have a structured, intentional repair process',
      'hoping for change without a plan': 'You hope for change without a plan',
      'apologizes without making real changes':
          'You apologize without making real changes',
      'cyclical breach pattern': 'There is a cyclical breach pattern',

      // Growth Openness
      'proactive growth mindset': 'You have a proactive growth mindset',
      'open but uncomfortable': 'You are open but uncomfortable',
      'gets defensive when growth is suggested':
          'You get defensive when growth is suggested',
      'closed to outside advice or growth':
          'You are closed to outside advice or growth',

      // Handling Recurring Issues
      'manages recurring issues with respect':
          'You manage recurring issues with respect',
      'slowly improving on hard topics':
          'You are slowly improving on hard topics',
      'avoids the recurring issue': 'You avoid the recurring issue',
      'unresolved issue poisons the relationship':
          'Unresolved issues poison the relationship',

      // Safety & Fear
      'feels safe even when spouse is angry':
          'You feel safe even when your spouse is angry',
      'walking on eggshells': 'You are walking on eggshells',
      'fear response activated': 'Your fear response is activated',
      'physical safety threat — urgent support needed':
          'Physical safety is a threat and urgent support is needed',

      // Transparency in Communication
      'chooses transparency over comfort':
          'You choose transparency over comfort',
      'truthful but filters the hard parts':
          'You are truthful but filter the hard parts',
      'withholds important truths': 'You withhold important truths',
      'controls the narrative to avoid conflict':
          'You control the narrative to avoid conflict',

      // Teamwork & Fairness
      'fluid, score-free teamwork': 'You have fluid, score-free teamwork',
      'unspoken imbalance in responsibilities':
          'There is an unspoken imbalance in responsibilities',
      'visible resentment from unfair division':
          'There is visible resentment from unfair division',
      'household duties keep causing conflict':
          'Household duties keep causing conflict',

      // Financial Partnership
      'clear shared financial framework':
          'You have a clear shared financial framework',
      'no shared plan for finances': 'You have no shared plan for finances',
      'avoids talking about money': 'You avoid talking about money',
      'ongoing conflict about money': 'There is ongoing conflict about money',

      // Emotional Attunement
      'initiates emotional check-in': 'You initiate emotional check-ins',
      'respects space but stays passive': 'You respect space but stay passive',
      'notices issues but avoids addressing them':
          'You notice issues but avoid addressing them',
      'emotionally unaware of spouse':
          'You are emotionally unaware of your spouse',

      // Confiding & Support
      'spouse is the first person they turn to':
          'Your spouse is the first person you turn to',
      'shares selectively for self-protection':
          'You share selectively for self-protection',
      'spouse is not the go-to person': 'Your spouse is not your go-to person',
      'emotional sharing has stopped': 'Emotional sharing has stopped',

      // Parenting Partnership
      'united parenting front': 'You present a united parenting front',
      'reactive then repair': 'You react then repair',
      'divided on who leads the home': 'You are divided on who leads the home',
      'parenting triggers marital conflict':
          'Parenting triggers marital conflict',

      // Faith in Crisis
      'shared faith activates under pressure':
          'Your shared faith activates under pressure',
      'faith lives side by side, not together':
          'Faith lives side by side, not together',
      'spiritual mismatch in crisis': 'There is a spiritual mismatch in crisis',
      'faith absent during hardship': 'Faith is absent during hardship',

      // Boundary Setting with Family
      'marriage-first boundary setting':
          'You prioritize marriage-first boundary setting',
      'avoids conflict with extended family':
          'You avoid conflict with extended family',
      'outside pressure pulling the marriage apart':
          'Outside pressure is pulling the marriage apart',
      'conflicting priorities between spouse and extended family':
          'You experience conflicting priorities between spouse and extended family',
    };

    return mapping[normalized] ?? _capitalizeProper(label);
  }

  /// Proper sentence case capitalization as fallback
  String _capitalizeProper(String s) {
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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
      ),
      alignment: Alignment.center,
      child: Text(
        label,
        style: AppTextStyles.labelSmall.copyWith(
          fontWeight: FontWeight.w600,
          color: textColor,
          fontSize: 12.0,
          height: 1.3,
        ),
        maxLines: 3,
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
                genderInsight: d.genderInsightText,
                microStep: d.bestMicroStep,
                genderMicroStep: d.genderMicroStep,
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
  final String? genderInsight;
  final String? microStep;
  final String? genderMicroStep;
  final Color barColor;

  const _DimensionCard({
    required this.name,
    required this.percentage,
    required this.insight,
    this.genderInsight,
    required this.microStep,
    this.genderMicroStep,
    required this.barColor,
  });

  @override
  Widget build(BuildContext context) {
    final insightText = (genderInsight ?? insight ?? '').trim();
    final microStepText = (genderMicroStep ?? microStep ?? '').trim();

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
            RichText(
              text: TextSpan(
                children: [
                  TextSpan(
                    text: '$percentage',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w800,
                      color: barColor,
                    ),
                  ),
                  TextSpan(
                    text: '%',
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight: FontWeight.w900,
                      color: barColor,
                    ),
                  ),
                ],
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
        if (microStepText.isNotEmpty) ...[
          const SizedBox(height: 8),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: barColor.withOpacity(0.06),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(
                  Icons.lightbulb_outline_rounded,
                  size: 14,
                  color: barColor,
                ),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    microStepText,
                    style: AppTextStyles.labelSmall.copyWith(
                      color: barColor,
                      height: 1.3,
                    ),
                  ),
                ),
              ],
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
