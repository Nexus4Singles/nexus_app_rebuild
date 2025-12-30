import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/assessment_provider.dart';
import '../../../../core/models/assessment_model.dart';

/// Premium Assessment Result Screen
/// Features:
/// - Animated score reveal
/// - Beautiful tier display
/// - Dimension breakdown with progress bars
/// - Personalized insights
/// - Recommended journey
class AssessmentResultScreen extends ConsumerStatefulWidget {
  const AssessmentResultScreen({super.key});

  @override
  ConsumerState<AssessmentResultScreen> createState() =>
      _AssessmentResultScreenState();
}

class _AssessmentResultScreenState extends ConsumerState<AssessmentResultScreen>
    with TickerProviderStateMixin {
  late AnimationController _scoreController;
  late AnimationController _fadeController;
  late Animation<double> _scoreAnimation;

  @override
  void initState() {
    super.initState();
    
    _scoreController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    );
    
    _fadeController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    
    _scoreAnimation = Tween<double>(begin: 0, end: 1).animate(
      CurvedAnimation(parent: _scoreController, curve: Curves.easeOutCubic),
    );
    
    // Start animations with delay
    Future.delayed(const Duration(milliseconds: 300), () {
      if (mounted) {
        _scoreController.forward();
        _fadeController.forward();
      }
    });
  }

  @override
  void dispose() {
    _scoreController.dispose();
    _fadeController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(assessmentNotifierProvider);
    final result = state.result;

    if (result == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.error_outline,
                size: 64,
                color: AppColors.textMuted,
              ),
              const SizedBox(height: 16),
              const Text('No result available'),
              const SizedBox(height: 24),
              ElevatedButton(
                onPressed: () => context.go(AppRoutes.home),
                child: const Text('Go Home'),
              ),
            ],
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero section with score
          SliverToBoxAdapter(
            child: _buildHeroSection(context, result),
          ),
          
          // Content
          SliverPadding(
            padding: const EdgeInsets.all(24),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Insights card
                _buildInsightsCard(context, result),
                const SizedBox(height: 24),
                
                // Dimension breakdown
                _buildDimensionSection(context, result),
                const SizedBox(height: 24),
                
                // Recommended journey
                if (result.recommendedJourneyId != null)
                  _buildRecommendedJourney(context, result),
                
                const SizedBox(height: 32),
                
                // Actions
                _buildActions(context),
                
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroSection(BuildContext context, AssessmentResult result) {
    final tierColor = _getTierColor(result.overallTier);
    final tierIcon = _getTierIcon(result.overallTier);
    final tierEmoji = _getTierEmoji(result.overallTier);

    return Container(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topCenter,
          end: Alignment.bottomCenter,
          colors: [
            tierColor,
            tierColor.withOpacity(0.85),
          ],
        ),
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 16, 24, 40),
          child: Column(
            children: [
              // Close button row
              Row(
                children: [
                  const Spacer(),
                  IconButton(
                    onPressed: () {
                      ref.read(assessmentNotifierProvider.notifier).reset();
                      context.go(AppRoutes.home);
                    },
                    icon: Icon(
                      Icons.close,
                      color: Colors.white.withOpacity(0.8),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              
              // Score circle
              AnimatedBuilder(
                animation: _scoreAnimation,
                builder: (context, child) {
                  return TweenAnimationBuilder<double>(
                    tween: Tween(begin: 0.0, end: 1.0),
                    duration: const Duration(milliseconds: 800),
                    curve: Curves.elasticOut,
                    builder: (context, scale, child) {
                      return Transform.scale(
                        scale: 0.5 + (scale * 0.5),
                        child: Container(
                          width: 160,
                          height: 160,
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            shape: BoxShape.circle,
                          ),
                          padding: const EdgeInsets.all(12),
                          child: Container(
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Text(
                                  tierEmoji,
                                  style: const TextStyle(fontSize: 32),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  '${(result.overallPercentage * _scoreAnimation.value).toInt()}%',
                                  style: TextStyle(
                                    fontSize: 36,
                                    fontWeight: FontWeight.w800,
                                    color: tierColor,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      );
                    },
                  );
                },
              ),
              const SizedBox(height: 24),
              
              // Tier name
              FadeTransition(
                opacity: _fadeController,
                child: Column(
                  children: [
                    Text(
                      result.overallTier.displayName,
                      style: const TextStyle(
                        fontSize: 32,
                        fontWeight: FontWeight.w800,
                        color: Colors.white,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      _getTierTagline(result.overallTier),
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.white.withOpacity(0.9),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildInsightsCard(BuildContext context, AssessmentResult result) {
    return FadeTransition(
      opacity: _fadeController,
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.info.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.lightbulb_outline,
                    color: AppColors.info,
                    size: 22,
                  ),
                ),
                const SizedBox(width: 12),
                const Text(
                  'Your Insight',
                  style: TextStyle(
                    fontSize: 18,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              _getTierDescription(result.overallTier),
              style: TextStyle(
                fontSize: 15,
                color: AppColors.textSecondary,
                height: 1.6,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildDimensionSection(BuildContext context, AssessmentResult result) {
    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Your Breakdown',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'See how you scored in each area',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          
          ...result.dimensionScores.map((score) => Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DimensionCard(score: score, animation: _scoreAnimation),
          )),
        ],
      ),
    );
  }

  Widget _buildRecommendedJourney(
    BuildContext context,
    AssessmentResult result,
  ) {
    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Recommended For You',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Based on your results',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
          const SizedBox(height: 16),
          
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              gradient: AppColors.primaryGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 6),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: const Center(
                    child: Text('🚀', style: TextStyle(fontSize: 28)),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Start Your Journey',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'We\'ve picked the perfect journey for you',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          'Day 1 Free',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(
                    Icons.arrow_forward,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return FadeTransition(
      opacity: _fadeController,
      child: Column(
        children: [
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                ref.read(assessmentNotifierProvider.notifier).reset();
                context.go(AppRoutes.home);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 18),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
              child: const Text(
                'Continue to Home',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: () {
                // TODO: Implement share
              },
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                side: BorderSide(color: AppColors.border),
              ),
              icon: const Icon(Icons.share_outlined, size: 20),
              label: const Text(
                'Share Results',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Color _getTierColor(SignalTier tier) {
    switch (tier) {
      case SignalTier.strong:
        return AppColors.success;
      case SignalTier.developing:
        return AppColors.info;
      case SignalTier.guarded:
        return AppColors.warning;
      case SignalTier.atRisk:
        return AppColors.error;
      case SignalTier.restoration:
        return AppColors.tierDeep;
    }
  }

  IconData _getTierIcon(SignalTier tier) {
    switch (tier) {
      case SignalTier.strong:
        return Icons.verified;
      case SignalTier.developing:
        return Icons.trending_up;
      case SignalTier.guarded:
        return Icons.shield;
      case SignalTier.atRisk:
        return Icons.warning_amber;
      case SignalTier.restoration:
        return Icons.healing;
    }
  }

  String _getTierEmoji(SignalTier tier) {
    switch (tier) {
      case SignalTier.strong:
        return '🌟';
      case SignalTier.developing:
        return '📈';
      case SignalTier.guarded:
        return '🛡️';
      case SignalTier.atRisk:
        return '⚠️';
      case SignalTier.restoration:
        return '🌱';
    }
  }

  String _getTierTagline(SignalTier tier) {
    switch (tier) {
      case SignalTier.strong:
        return 'You\'re in a great place!';
      case SignalTier.developing:
        return 'You\'re making progress!';
      case SignalTier.guarded:
        return 'Some areas need attention';
      case SignalTier.atRisk:
        return 'Let\'s work on this together';
      case SignalTier.restoration:
        return 'Healing takes time';
    }
  }

  String _getTierDescription(SignalTier tier) {
    switch (tier) {
      case SignalTier.strong:
        return 'You show excellent readiness! Your foundation is solid for building meaningful relationships. Keep nurturing these strengths.';
      case SignalTier.developing:
        return 'You\'re making good progress! Some areas could use attention, but you\'re on the right track. Our journeys can help you grow even stronger.';
      case SignalTier.guarded:
        return 'There are some areas that need attention. This is completely normal, and our guided journeys can help you work through them at your own pace.';
      case SignalTier.atRisk:
        return 'We see some challenges that may affect your relationships. The good news is that with the right support, these areas can improve significantly.';
      case SignalTier.restoration:
        return 'You\'re in a season of healing and rebuilding. Take it one step at a time. Our gentle, faith-centered approach can support you on this journey.';
    }
  }
}

// ============================================================================
// DIMENSION CARD
// ============================================================================

class _DimensionCard extends StatelessWidget {
  final DimensionScore score;
  final Animation<double> animation;

  const _DimensionCard({
    required this.score,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    final tierColor = _getTierColor(score.tier);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  score.dimensionName,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: tierColor.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: AnimatedBuilder(
                  animation: animation,
                  builder: (context, child) {
                    return Text(
                      '${(score.percentage * animation.value).toInt()}%',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: tierColor,
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          AnimatedBuilder(
            animation: animation,
            builder: (context, child) {
              return Container(
                height: 8,
                decoration: BoxDecoration(
                  color: AppColors.surfaceDark,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: (score.percentage / 100) * animation.value,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [tierColor.withOpacity(0.7), tierColor],
                      ),
                      borderRadius: BorderRadius.circular(4),
                    ),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }

  Color _getTierColor(SignalTier tier) {
    switch (tier) {
      case SignalTier.strong:
        return AppColors.success;
      case SignalTier.developing:
        return AppColors.info;
      case SignalTier.guarded:
        return AppColors.warning;
      case SignalTier.atRisk:
        return AppColors.error;
      case SignalTier.restoration:
        return AppColors.tierDeep;
    }
  }
}
