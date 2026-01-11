import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/router/app_routes.dart';
import 'package:nexus_app_min_test/core/safe_providers/user_provider_safe.dart';
import 'package:nexus_app_min_test/features/stories/presentation/screens/story_detail_screen.dart';
import 'package:nexus_app_min_test/core/session/effective_relationship_status_provider.dart';
import 'package:nexus_app_min_test/core/constants/app_constants.dart';

class HomeScreen extends ConsumerWidget {
  const HomeScreen({super.key});

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final user = ref.watch(safeUserProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Home', style: AppTextStyles.headlineLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const SizedBox(height: 8),
          _HomeAssessmentCTA(),
          const SizedBox(height: 16),
          // ✅ Story of the Week (tap to open StoryDetailScreen)
          GestureDetector(
            onTap: () {
              Navigator.push(
                context,
                MaterialPageRoute(
                  builder:
                      (_) =>
                          const StoryDetailScreen(storyId: 'story_of_the_week'),
                ),
              );
            },
            child: Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  Container(
                    width: 54,
                    height: 54,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(18),
                    ),
                    child: Icon(Icons.menu_book, color: AppColors.primary),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Story of the Week',
                          style: AppTextStyles.labelLarge,
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Tap to open story detail',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right, color: AppColors.textMuted),
                ],
              ),
            ),
          ),
          const SizedBox(height: 12),

          _SectionCard(
            title: 'Today',
            subtitle: user.status,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${_getGreeting()}, ${user.firstName} 👋',
                  style: AppTextStyles.headlineSmall,
                ),
                const SizedBox(height: 8),
                Text(
                  'Riverpod is now enabled in Safe Mode. Backend stays OFF.',
                  style: AppTextStyles.bodyMedium,
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Your Journeys',
            subtitle: 'Preview',
            child: Column(
              children: const [
                _ListRow(
                  title: 'Starter Journey',
                  subtitle: '5 steps • Beginner',
                ),
                SizedBox(height: 10),
                _ListRow(
                  title: 'Mindful Reset',
                  subtitle: '7 steps • Intermediate',
                ),
              ],
            ),
          ),
          const SizedBox(height: 12),
          _SectionCard(
            title: 'Journeys',
            subtitle: 'Preview',
            child: Column(
              children: const [
                _ListRow(title: '7-Day Focus', subtitle: '3 days left'),
                SizedBox(height: 10),
                _ListRow(
                  title: 'Hydration Sprint',
                  subtitle: 'Starts tomorrow',
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final Widget child;

  const _SectionCard({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: AppTextStyles.titleLarge),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTextStyles.caption),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _ListRow extends StatelessWidget {
  final String title;
  final String subtitle;

  const _ListRow({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border.withOpacity(0.5)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}

class _HomeAssessmentCTA extends ConsumerWidget {
  const _HomeAssessmentCTA();

  ({String title, String subtitle, String type}) _copyFor(
    RelationshipStatus? s,
  ) {
    switch (s) {
      case RelationshipStatus.married:
        return (
          title: "Marriage Health Check",
          subtitle:
              "Spot strengths, uncover blind spots, and strengthen your bond.",
          type: "marriage_health_check",
        );
      case RelationshipStatus.divorced:
      case RelationshipStatus.widowed:
        return (
          title: "Remarriage Readiness",
          subtitle:
              "Heal, rebuild trust, and prepare for a healthier next chapter.",
          type: "remarriage_readiness",
        );
      case RelationshipStatus.singleNeverMarried:
      default:
        return (
          title: "Marriage Readiness",
          subtitle: "Know what to build now for a strong future marriage.",
          type: "singles_readiness",
        );
    }
  }

  Widget build(BuildContext context, WidgetRef ref) {
    final status = ref.watch(effectiveRelationshipStatusProvider);
    final copy = _copyFor(status);

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primarySoft,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            copy.title,
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            copy.subtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 12),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                Navigator.pushNamed(
                  context,
                  "${AppRoutes.assessmentIntro}?type=${copy.type}",
                );
              },
              child: const Text("Start Assessment"),
            ),
          ),
        ],
      ),
    );
  }
}
