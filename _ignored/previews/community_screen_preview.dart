import 'package:flutter/material.dart';

import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_spacing.dart';

class CommunityScreenPreview extends StatelessWidget {
  const CommunityScreenPreview({super.key});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    final items = const [
      ("Faith & Dating", "How I found peace while waiting."),
      ("Healing", "My journey from heartbreak to hope."),
      ("Purpose", "Small habits that changed my life."),
      ("Prayer", "A 5-min routine that keeps me grounded."),
    ];

    return SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text("Community", style: t.headlineLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              "Stories from people like you (preview).",
              style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
            ),
            const SizedBox(height: AppSpacing.xl),

            ...items.map((e) => _StoryCard(title: e.$1, subtitle: e.$2)),
          ],
        ),
      ),
    );
  }
}

class _StoryCard extends StatelessWidget {
  final String title;
  final String subtitle;

  const _StoryCard({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Card(
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: t.titleMedium),
              const SizedBox(height: AppSpacing.xs),
              Text(
                subtitle,
                style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
              ),
              const SizedBox(height: AppSpacing.md),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () {},
                  child: const Text("Read"),
                ),
              )
            ],
          ),
        ),
      ),
    );
  }
}
