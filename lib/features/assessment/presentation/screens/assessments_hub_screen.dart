import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/assessment_provider.dart';
import '../../../../core/providers/auth_status_provider.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme.dart';

class AssessmentsHubScreen extends ConsumerWidget {
  const AssessmentsHubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isLoggedIn = ref.watch(isLoggedInProvider);

    final cards = const [
      _AssessmentCardData(
        type: AssessmentType.singlesReadiness,
        emoji: "💛",
        title: "Singles Readiness",
        subtitle: "For never-married singles preparing for intentional dating.",
      ),
      _AssessmentCardData(
        type: AssessmentType.remarriageReadiness,
        emoji: "🕊️",
        title: "Remarriage Readiness",
        subtitle: "For divorced or widowed singles preparing for love again.",
      ),
      _AssessmentCardData(
        type: AssessmentType.marriageHealthCheck,
        emoji: "💍",
        title: "Marriage Health Check",
        subtitle: "For married couples strengthening trust, intimacy & growth.",
      ),
    ];

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        elevation: 0,
        backgroundColor: AppColors.background,
        title: Text("Assessments", style: AppTextStyles.headlineLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          Text(
            "Choose an assessment that matches your current relationship journey.",
            style: AppTextStyles.bodyLarge.copyWith(
              color: AppColors.textSecondary,
              height: 1.35,
            ),
          ),
          const SizedBox(height: 18),

          ...cards.map((c) {
            return _AssessmentCard(
              data: c,
              isLoggedIn: isLoggedIn,
              onTap: () {
                if (!isLoggedIn) {
                  showDialog(
                    context: context,
                    builder: (_) => AlertDialog(
                      title: const Text("Sign in required"),
                      content: const Text(
                        "Create an account or sign in to take assessments.",
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(context),
                          child: const Text("Not now"),
                        ),
                        ElevatedButton(
                          onPressed: () {
                            Navigator.pop(context);
                            Navigator.pushNamed(context, AppRoutes.login);
                          },
                          child: const Text("Sign in"),
                        ),
                      ],
                    ),
                  );
                  return;
                }

                Navigator.pushNamed(
                  context,
                  "${AppRoutes.assessmentIntro}?type=${c.type.id}",
                );
              },
            );
          }),
        ],
      ),
    );
  }
}

class _AssessmentCardData {
  final AssessmentType type;
  final String emoji;
  final String title;
  final String subtitle;

  const _AssessmentCardData({
    required this.type,
    required this.emoji,
    required this.title,
    required this.subtitle,
  });
}

class _AssessmentCard extends ConsumerWidget {
  final _AssessmentCardData data;
  final bool isLoggedIn;
  final VoidCallback onTap;

  const _AssessmentCard({
    required this.data,
    required this.isLoggedIn,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final configAsync = ref.watch(assessmentConfigProvider(data.type));

    return Padding(
      padding: const EdgeInsets.only(bottom: 14),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Center(
                  child: Text(data.emoji, style: const TextStyle(fontSize: 26)),
                ),
              ),
              const SizedBox(width: 14),

              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      data.title,
                      style: AppTextStyles.titleLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      data.subtitle,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textSecondary,
                        height: 1.3,
                      ),
                    ),
                    const SizedBox(height: 10),

                    configAsync.when(
                      data: (config) {
                        final q = config?.questions.length ?? 0;
                        return Row(
                          children: [
                            _MetaChip(icon: Icons.quiz_outlined, text: "$q Questions"),
                            const SizedBox(width: 8),
                            _MetaChip(icon: Icons.timer_outlined, text: "5–7 mins"),
                            const Spacer(),
                            if (!isLoggedIn)
                              _LockedChip(),
                          ],
                        );
                      },
                      loading: () => Row(
                        children: const [
                          _MetaChip(icon: Icons.quiz_outlined, text: "Loading..."),
                        ],
                      ),
                      error: (_, __) => Row(
                        children: const [
                          _MetaChip(icon: Icons.error_outline, text: "Unavailable"),
                        ],
                      ),
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
}

class _MetaChip extends StatelessWidget {
  final IconData icon;
  final String text;

  const _MetaChip({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.primary),
          const SizedBox(width: 6),
          Text(
            text,
            style: AppTextStyles.bodySmall.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _LockedChip extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(Icons.lock_outline, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 6),
        Text(
          "Sign in",
          style: AppTextStyles.bodySmall.copyWith(
            color: AppColors.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ],
    );
  }
}
