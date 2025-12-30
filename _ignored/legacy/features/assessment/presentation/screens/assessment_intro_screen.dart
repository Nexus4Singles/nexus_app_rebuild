import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/assessment_provider.dart';
import '../../../../core/models/assessment_model.dart';

/// Assessment Intro Screen
/// Shows assessment details before user starts
class AssessmentIntroScreen extends ConsumerWidget {
  final AssessmentType assessmentType;

  const AssessmentIntroScreen({
    super.key,
    required this.assessmentType,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(assessmentConfigProvider(assessmentType));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: configAsync.when(
        data: (config) {
          if (config == null) {
            return _buildError(context, 'Assessment not found');
          }
          return _buildContent(context, config);
        },
        loading: () => _buildLoading(),
        error: (e, _) => _buildError(context, e.toString()),
      ),
    );
  }

  Widget _buildLoading() {
    return const Center(
      child: CircularProgressIndicator(),
    );
  }

  Widget _buildError(BuildContext context, String message) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.error_outline, size: 64, color: AppColors.error),
          const SizedBox(height: 16),
          Text(message),
          const SizedBox(height: 24),
          ElevatedButton(
            onPressed: () => context.pop(),
            child: const Text('Go Back'),
          ),
        ],
      ),
    );
  }

  Widget _buildContent(BuildContext context, AssessmentConfig config) {
    final info = _getAssessmentInfo(assessmentType);

    return SafeArea(
      child: Column(
        children: [
          // Header
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                IconButton(
                  onPressed: () => context.pop(),
                  icon: const Icon(Icons.arrow_back),
                ),
                const Spacer(),
              ],
            ),
          ),

          // Content
          Expanded(
            child: SingleChildScrollView(
              physics: const BouncingScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon
                  Center(
                    child: Container(
                      width: 100,
                      height: 100,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.3),
                            blurRadius: 24,
                            offset: const Offset(0, 8),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          info.emoji,
                          style: const TextStyle(fontSize: 48),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Title
                  Center(
                    child: Text(
                      config.assessmentName,
                      style: const TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 12),

                  // Subtitle
                  Center(
                    child: Text(
                      info.subtitle,
                      style: TextStyle(
                        fontSize: 16,
                        color: AppColors.textSecondary,
                        height: 1.5,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),
                  const SizedBox(height: 32),

                  // Info cards
                  _InfoCard(
                    icon: Icons.help_outline,
                    title: '${config.questions.length} Questions',
                    subtitle: 'Answer honestly for accurate results',
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.timer_outlined,
                    title: '5-7 Minutes',
                    subtitle: 'Take your time, no rush',
                  ),
                  const SizedBox(height: 12),
                  _InfoCard(
                    icon: Icons.lock_outline,
                    title: 'Private & Secure',
                    subtitle: 'Your answers are confidential',
                  ),
                  const SizedBox(height: 32),

                  // What you'll discover
                  Container(
                    padding: const EdgeInsets.all(20),
                    decoration: BoxDecoration(
                      color: AppColors.primarySoft,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(
                              Icons.insights,
                              color: AppColors.primary,
                              size: 22,
                            ),
                            const SizedBox(width: 10),
                            const Text(
                              'What you\'ll discover',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 16),
                        ...info.discoveries.map((item) => Padding(
                              padding: const EdgeInsets.only(bottom: 10),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: AppColors.primary,
                                    size: 18,
                                  ),
                                  const SizedBox(width: 10),
                                  Expanded(
                                    child: Text(
                                      item,
                                      style: TextStyle(
                                        fontSize: 14,
                                        color: AppColors.textPrimary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            )),
                      ],
                    ),
                  ),
                  const SizedBox(height: 100),
                ],
              ),
            ),
          ),

          // Bottom CTA
          Container(
            padding: EdgeInsets.fromLTRB(
              24,
              16,
              24,
              MediaQuery.of(context).padding.bottom + 16,
            ),
            decoration: BoxDecoration(
              color: AppColors.background,
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.05),
                  blurRadius: 20,
                  offset: const Offset(0, -4),
                ),
              ],
            ),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // Navigate to actual assessment
                  context.go('/assessment/${assessmentType.name}/questions');
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16),
                  ),
                  elevation: 4,
                  shadowColor: AppColors.primary.withOpacity(0.3),
                ),
                child: const Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Text(
                      'Begin Assessment',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    SizedBox(width: 8),
                    Icon(Icons.arrow_forward, size: 20),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  _AssessmentInfo _getAssessmentInfo(AssessmentType type) {
    switch (type) {
      case AssessmentType.singlesReadiness:
        return _AssessmentInfo(
          emoji: '💍',
          subtitle:
              'Discover how ready you are for a committed relationship and marriage.',
          discoveries: [
            'Your emotional readiness score',
            'Areas of strength in relationships',
            'Growth opportunities to work on',
            'Personalized journey recommendations',
          ],
        );
      case AssessmentType.remarriageReadiness:
        return _AssessmentInfo(
          emoji: '🌱',
          subtitle:
              'Understand your readiness to love again after divorce or loss.',
          discoveries: [
            'Your healing and recovery progress',
            'Lessons learned from past relationships',
            'Emotional availability score',
            'Personalized healing journey',
          ],
        );
      case AssessmentType.marriageHealthCheck:
        return _AssessmentInfo(
          emoji: '❤️',
          subtitle:
              'Get insights into your marriage\'s health and areas to strengthen.',
          discoveries: [
            'Your marriage health score',
            'Communication patterns analysis',
            'Areas thriving in your marriage',
            'Opportunities for deeper connection',
          ],
        );
    }
  }
}

class _AssessmentInfo {
  final String emoji;
  final String subtitle;
  final List<String> discoveries;

  _AssessmentInfo({
    required this.emoji,
    required this.subtitle,
    required this.discoveries,
  });
}

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _InfoCard({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppColors.textSecondary, size: 22),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    fontSize: 13,
                    color: AppColors.textSecondary,
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
