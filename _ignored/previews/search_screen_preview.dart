import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class SearchScreenPreview extends StatelessWidget {
  const SearchScreenPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Search", style: t.headlineLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Preview-only Search UI (no backend yet).",
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),

            TextField(
              decoration: InputDecoration(
                hintText: "Search stories, challenges, people...",
                prefixIcon: const Icon(Icons.search),
                filled: true,
                fillColor: AppColors.surface,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
                enabledBorder: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(16),
                  borderSide: const BorderSide(color: AppColors.border),
                ),
              ),
            ),

            const SizedBox(height: AppSpacing.xl),

            Text("Trending", style: t.titleLarge),
            const SizedBox(height: AppSpacing.md),

            _ChipRow(chips: const [
              "Love & Dating",
              "Marriage",
              "Prayer",
              "Healing",
              "Boundaries",
            ]),

            const SizedBox(height: AppSpacing.xl),

            Text("Suggested", style: t.titleLarge),
            const SizedBox(height: AppSpacing.md),

            _ResultCard(
              title: "21-Day Prayer Challenge",
              subtitle: "Build a consistent prayer habit.",
              icon: Icons.emoji_events_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            _ResultCard(
              title: "Story of the Week",
              subtitle: "Read and vote on today’s feature story.",
              icon: Icons.auto_stories_outlined,
            ),
            const SizedBox(height: AppSpacing.md),
            _ResultCard(
              title: "Compatibility Quiz",
              subtitle: "Preview the dating compatibility flow.",
              icon: Icons.favorite_border,
            ),
          ],
        ),
      ),
    );
  }
}

class _ChipRow extends StatelessWidget {
  final List<String> chips;
  const _ChipRow({required this.chips});

  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: chips
          .map(
            (c) => Chip(
              label: Text(c),
              backgroundColor: AppColors.primaryMuted,
              labelStyle: Theme.of(context)
                  .textTheme
                  .labelLarge
                  ?.copyWith(color: AppColors.primaryDark),
              side: const BorderSide(color: AppColors.border),
            ),
          )
          .toList(),
    );
  }
}

class _ResultCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;
  const _ResultCard({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

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
                Text(title, style: t.titleMedium),
                const SizedBox(height: 4),
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
