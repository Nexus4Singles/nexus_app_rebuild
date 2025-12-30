import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class ChallengesScreenPreview extends StatelessWidget {
  const ChallengesScreenPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Challenges", style: t.headlineLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Preview-only Challenges UI (no backend yet).",
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),

            _ChallengeCard(
              title: "21-Day Prayer Challenge",
              subtitle: "Build consistency daily.",
              tag: "STARTER",
              icon: Icons.local_fire_department_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            _ChallengeCard(
              title: "Dating Boundaries",
              subtitle: "Strengthen clarity & discipline.",
              tag: "GROWTH",
              icon: Icons.favorite_border,
            ),
            const SizedBox(height: AppSpacing.md),
            _ChallengeCard(
              title: "Marriage Reset",
              subtitle: "Rebuild connection and trust.",
              tag: "DEEP",
              icon: Icons.handshake_outlined,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String tag;
  final IconData icon;

  const _ChallengeCard({
    required this.title,
    required this.subtitle,
    required this.tag,
    required this.icon,
  });

  Color _tagColor() {
    switch (tag) {
      case "STARTER":
        return AppColors.tierFree;
      case "GROWTH":
        return AppColors.tierGrowth;
      case "DEEP":
        return AppColors.tierDeep;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(child: Text(title, style: t.titleMedium)),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                      decoration: BoxDecoration(
                        color: _tagColor().withOpacity(0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        tag,
                        style: t.labelSmall?.copyWith(color: _tagColor()),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                ),
              ],
            ),
          ),
          const Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
