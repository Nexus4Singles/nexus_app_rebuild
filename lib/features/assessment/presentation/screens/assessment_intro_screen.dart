import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:core';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/assessment_provider.dart';
import '../../../../core/providers/auth_status_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/router/safe_nav.dart';
import '../../../../core/theme/theme.dart';

class AssessmentIntroScreen extends ConsumerWidget {
  const AssessmentIntroScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

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
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      body: SafeArea(
        child: configAsync.when(
          data: (config) {
            if (config == null) {
              return _ErrorState(
                message: 'Assessment not available right now.',
                onBack: () => navigateBackToHome(context),
              );
            }

            final meta = AssessmentMeta.fromType(typeToUse);

            return Padding(
              padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    _TopBar(onBack: () => navigateBackToHome(context)),
                    const SizedBox(height: 12),
                    Center(
                      child: Container(
                        width: 80,
                        height: 80,
                        decoration: BoxDecoration(
                          gradient: AppColors.primaryGradient,
                          borderRadius: BorderRadius.circular(24),
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
                            style: const TextStyle(fontSize: 40),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 14),
                    Center(
                      child: Text(
                        meta.title,
                        style: AppTextStyles.headlineLarge.copyWith(
                          fontSize: 20,
                          fontWeight: FontWeight.w800,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Center(
                      child: Text(
                        meta.subtitle,
                        style: AppTextStyles.bodyMedium.copyWith(
                          fontSize: 13,
                          color: AppColors.getTextSecondary(context),
                          height: 1.3,
                        ),
                        textAlign: TextAlign.center,
                      ),
                    ),
                    const SizedBox(height: 14),
                    _InfoRow(
                      items: [
                        _InfoChip(
                          icon: Icons.quiz_outlined,
                          title: '${config.questions.length} Questions',
                        ),
                        _InfoChip(
                          icon: Icons.timer_outlined,
                          title: '7–10 Minutes',
                        ),
                        _InfoChip(icon: Icons.lock_outline, title: 'Private'),
                      ],
                    ),
                    const SizedBox(height: 12),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.getSurface(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.getBorder(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'What you\'ll get',
                            style: AppTextStyles.titleSmall.copyWith(
                              fontSize: 13,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          const SizedBox(height: 10),
                          ...meta.discoveries.map(
                            (d) => Padding(
                              padding: const EdgeInsets.only(bottom: 6),
                              child: Row(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Icon(
                                    Icons.check_circle,
                                    color: AppColors.primary,
                                    size: 16,
                                  ),
                                  const SizedBox(width: 8),
                                  Expanded(
                                    child: Text(
                                      d,
                                      style: AppTextStyles.bodySmall.copyWith(
                                        fontSize: 12,
                                        height: 1.3,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Container(
                            width: double.infinity,
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: AppColors.getSurface(context),
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(
                                color: AppColors.getBorder(context),
                              ),
                            ),
                            child: Text(
                              meta.note,
                              style: AppTextStyles.bodySmall.copyWith(
                                fontSize: 12,
                                color: AppColors.getTextPrimary(context),
                                height: 1.3,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withOpacity(0.08),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: AppColors.primary.withOpacity(0.2),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.lightbulb_outlined,
                                color: AppColors.primary,
                                size: 18,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'How to Get the Most Out of This',
                                style: AppTextStyles.bodySmall.copyWith(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Your honesty is crucial. Answer based on how you truly feel and behave—not how you wish you were. The accuracy of your results depends on your authentic responses.\n\nTake your time and be genuine with yourself.',
                            style: AppTextStyles.bodySmall.copyWith(
                              fontSize: 12,
                              color: AppColors.getTextSecondary(context),
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 60),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
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
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 0,
                        ),
                        child: const Text(
                          'Start Assessment',
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
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
          title: 'Marriage Readiness Check',
          subtitle:
              'Find out how equipped and ready you are for the marriage you desire.',
          discoveries: [
            'Clarity on your readiness for marriage',

            'Signals and patterns holding you back',
            'Next steps to improve on these areas to hold you back',
          ],
          note:
              'This is private and designed to guide you on your journey to finding the right kind of love, not judge you.',
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
              'Test the pulse of your marriage and discover areas to strengthen it',
          discoveries: [
            'Strengths you can build on',
            'Blind spots affecting your marriage',
            'Ways to restore and rebuild weak areas.',
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
          icon: Icon(
            Icons.arrow_back,
            color: AppColors.getTextPrimary(context),
          ),
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
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.getBorder(context)),
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
            Icon(
              Icons.error_outline,
              size: 44,
              color: AppColors.getTextSecondary(context),
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
