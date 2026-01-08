import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:core';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/assessment_provider.dart';
import '../../../../core/providers/auth_status_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme.dart';

class AssessmentIntroScreen extends ConsumerWidget {
  const AssessmentIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    // Allow explicit assessment selection via route query param (?type=...)
    final routeName = ModalRoute.of(context)?.settings.name ?? '';
    final uri = Uri.tryParse(routeName);
    final typeParam = uri?.queryParameters['type'];

    AssessmentType? selectedType;
    if (typeParam != null && typeParam.isNotEmpty) {
      selectedType = AssessmentType.fromId(typeParam);
    }

    final recommendedType =
        ref.watch(recommendedAssessmentTypeProvider) ??
        AssessmentType.singlesReadiness;
    final typeToUse = selectedType ?? recommendedType;

    final configAsync = ref.watch(assessmentConfigProvider(typeToUse));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: configAsync.when(
          data: (config) {
            if (config == null) {
              return _ErrorState(
                message: 'Assessment not available right now.',
                onBack: () => Navigator.pop(context),
              );
            }

            final meta = AssessmentMeta.fromType(typeToUse);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _TopBar(onBack: () => Navigator.pop(context)),
                  const SizedBox(height: 18),

                  Center(
                    child: Container(
                      width: 96,
                      height: 96,
                      decoration: BoxDecoration(
                        gradient: AppColors.primaryGradient,
                        borderRadius: BorderRadius.circular(28),
                        boxShadow: [
                          BoxShadow(
                            color: AppColors.primary.withOpacity(0.20),
                            blurRadius: 22,
                            offset: const Offset(0, 10),
                          ),
                        ],
                      ),
                      child: Center(
                        child: Text(
                          meta.emoji,
                          style: const TextStyle(fontSize: 44),
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 22),

                  Center(
                    child: Text(
                      meta.title,
                      style: AppTextStyles.headlineLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 10),

                  Center(
                    child: Text(
                      meta.subtitle,
                      style: AppTextStyles.bodyLarge.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ),

                  const SizedBox(height: 22),

                  _InfoRow(
                    items: [
                      _InfoChip(
                        icon: Icons.quiz_outlined,
                        title: '${config.questions.length} Questions',
                      ),
                      _InfoChip(
                        icon: Icons.timer_outlined,
                        title: '5–7 Minutes',
                      ),
                      _InfoChip(icon: Icons.lock_outline, title: 'Private'),
                    ],
                  ),

                  const SizedBox(height: 18),

                  Expanded(
                    child: Container(
                      width: double.infinity,
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
                            'What you’ll get',
                            style: AppTextStyles.titleMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 14),
                          ...meta.discoveries.map(
                            (d) => Padding(
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
                                      d,
                                      style: AppTextStyles.bodyMedium.copyWith(
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const Spacer(),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(14),
                            decoration: BoxDecoration(
                              color: AppColors.primarySoft,
                              borderRadius: BorderRadius.circular(16),
                            ),
                            child: Text(
                              meta.note,
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: AppColors.textPrimary,
                                height: 1.35,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 18),

                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        if (!isLoggedIn) {
                          showDialog(
                            context: context,
                            builder:
                                (_) => AlertDialog(
                                  title: const Text('Sign in required'),
                                  content: const Text(
                                    'Create an account or sign in to take assessments.',
                                  ),
                                  actions: [
                                    TextButton(
                                      onPressed: () => Navigator.pop(context),
                                      child: const Text('Not now'),
                                    ),
                                    ElevatedButton(
                                      onPressed: () {
                                        Navigator.pop(context);
                                        Navigator.pushNamed(
                                          context,
                                          AppRoutes.login,
                                        );
                                      },
                                      child: const Text('Sign in'),
                                    ),
                                  ],
                                ),
                          );
                          return;
                        }

                        Navigator.pushNamed(context, AppRoutes.assessment);
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                        elevation: 0,
                      ),
                      child: const Text(
                        'Start Assessment',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            );
          },
          loading: () => const Center(child: CircularProgressIndicator()),
          error:
              (e, _) => _ErrorState(
                message: 'Error loading assessment: $e',
                onBack: () => Navigator.pop(context),
              ),
        ),
      ),
    );
  }
}

class AssessmentMeta {
  final String emoji;
  final String title;
  final String subtitle;
  final List<String> discoveries;
  final String note;

  const AssessmentMeta({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.discoveries,
    required this.note,
  });

  static AssessmentMeta fromType(AssessmentType type) {
    switch (type) {
      case AssessmentType.singlesReadiness:
        return const AssessmentMeta(
          emoji: '💛',
          title: 'Singles Readiness Check',
          subtitle:
              'Understand what you’re truly ready for in love and dating.',
          discoveries: [
            'Clarity on your emotional readiness',
            'Signals and patterns holding you back',
            'Next steps to build confidence',
          ],
          note:
              'This is private and designed to guide your next moves, not judge you.',
        );

      case AssessmentType.remarriageReadiness:
        return const AssessmentMeta(
          emoji: '🧡',
          title: 'Remarriage Readiness Check',
          subtitle: 'Heal, reset, and prepare for a healthier second chance.',
          discoveries: [
            'Healing progress & emotional stability',
            'Patterns that could repeat in the next marriage',
            'Practical steps for healthier relationships',
          ],
          note:
              'Your past does not define you. This helps you move forward with intention.',
        );

      case AssessmentType.marriageHealthCheck:
        return const AssessmentMeta(
          emoji: '💙',
          title: 'Marriage Health Check',
          subtitle:
              'Measure the health of your marriage and strengthen it together.',
          discoveries: [
            'Strengths you can build on',
            'Blind spots affecting closeness',
            'Ways to restore connection and trust',
          ],
          note: 'Best used as a reflection tool — alone or as a couple.',
        );
    }
  }
}

class _TopBar extends StatelessWidget {
  final VoidCallback onBack;
  const _TopBar({required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        IconButton(
          onPressed: onBack,
          icon: const Icon(Icons.arrow_back, color: AppColors.textPrimary),
        ),
        const Spacer(),
      ],
    );
  }
}

class _InfoRow extends StatelessWidget {
  final List<_InfoChip> items;
  const _InfoRow({required this.items});

  @override
  Widget build(BuildContext context) {
    return Row(
      children:
          items
              .map(
                (i) => Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 4),
                    child: i,
                  ),
                ),
              )
              .toList(),
    );
  }
}

class _InfoChip extends StatelessWidget {
  final IconData icon;
  final String title;
  const _InfoChip({required this.icon, required this.title});

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 46,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(icon, size: 18, color: AppColors.primary),
          const SizedBox(width: 8),
          Text(
            title,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onBack;
  const _ErrorState({required this.message, required this.onBack});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 44,
              color: AppColors.textSecondary,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 18),
            ElevatedButton(onPressed: onBack, child: const Text('Go back')),
          ],
        ),
      ),
    );
  }
}
