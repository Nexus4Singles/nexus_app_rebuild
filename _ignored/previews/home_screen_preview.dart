import 'package:flutter/material.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class HomeScreenPreview extends StatelessWidget {
  const HomeScreenPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Welcome back 👋", style: t.headlineLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "This is the Home UI preview (no backend/providers yet).",
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),

            const SizedBox(height: AppSpacing.xl),

            _Card(
              title: "Today’s Streak",
              subtitle: "Keep going — you’re doing great.",
              trailing: "🔥 3",
            ),

            const SizedBox(height: AppSpacing.md),

            _Card(
              title: "Featured Journey",
              subtitle: "Singles Journey • Day 1",
              trailing: "Start",
            ),

            const SizedBox(height: AppSpacing.md),

            _Card(
              title: "Community",
              subtitle: "New stories from people like you",
              trailing: "View",
            ),

            const SizedBox(height: AppSpacing.xl),

            ElevatedButton(
              onPressed: () {},
              child: const Text("Continue"),
            ),
          ],
        ),
      ),
    );
  }
}

class _Card extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;

  const _Card({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              trailing,
              style: t.labelLarge?.copyWith(color: AppColors.primary),
            ),
          ],
        ),
      ),
    );
  }
}
