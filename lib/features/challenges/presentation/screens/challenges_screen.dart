import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/icon_mapper.dart';
import '../../domain/journey_v1_models.dart';
import '../../providers/journeys_providers.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(journeyCatalogProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Journeys'),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _ErrorState(
          message: 'Unable to load journeys.',
          onRetry: () => ref.invalidate(journeyCatalogProvider),
        ),
        data: (catalog) {
          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              const _TopMomentumCard(),
              const SizedBox(height: 16),
              Text(
                'Pick an area to grow in',
                style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w900),
              ),
              const SizedBox(height: 6),
              Text(
                'Mission 1 is free. Unlock the rest when you’re ready.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 16),
              ...catalog.journeys.map((j) => Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _JourneyCard(journey: j),
                  )),
            ],
          );
        },
      ),
    );
  }
}

class _TopMomentumCard extends ConsumerWidget {
  const _TopMomentumCard();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bestStreakAsync = ref.watch(bestJourneysStreakProvider);

    return bestStreakAsync.when(
      loading: () => const _TopMomentumCardShell(streak: 0),
      error: (_, __) => const _TopMomentumCardShell(streak: 0),
      data: (streak) => _TopMomentumCardShell(streak: streak),
    );
  }
}

class _TopMomentumCardShell extends StatelessWidget {
  final int streak;
  const _TopMomentumCardShell({required this.streak});

  @override
  Widget build(BuildContext context) {
    final title = streak <= 0 ? 'Start your streak' : '$streak-day streak';
    final subtitle = streak <= 0
        ? 'Complete one mission today.'
        : 'You’re building consistency and strength.';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      child: Row(
        children: [
          _IconBubble(
            icon: Icons.local_fire_department_outlined,
            bg: AppColors.primary.withOpacity(0.12),
            fg: AppColors.primary,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 4),
                Text(
                  subtitle,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.textMuted,
                    height: 1.3,
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

class _JourneyCard extends ConsumerWidget {
  final JourneyV1 journey;
  const _JourneyCard({required this.journey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedAsync = ref.watch(completedMissionIdsProvider(journey.id));

    return completedAsync.when(
      loading: () => _JourneyCardShell(
        journey: journey,
        progress: 0.0,
        onTap: () => _openDetail(context, journey.id),
      ),
      error: (_, __) => _JourneyCardShell(
        journey: journey,
        progress: 0.0,
        onTap: () => _openDetail(context, journey.id),
      ),
      data: (completed) {
        final total = journey.missions.length;
        final done = completed.length.clamp(0, total);
        final progress = total == 0 ? 0.0 : (done / total);

        return _JourneyCardShell(
          journey: journey,
          progress: progress,
          onTap: () => _openDetail(context, journey.id),
        );
      },
    );
  }

  void _openDetail(BuildContext context, String journeyId) {
    Navigator.pushNamed(
      context,
      AppRoutes.journeyDetail.replaceFirst(':id', journeyId),
      arguments: {'journeyId': journeyId},
    );
  }
}

class _JourneyCardShell extends StatelessWidget {
  final JourneyV1 journey;
  final double progress;
  final VoidCallback onTap;

  const _JourneyCardShell({
    required this.journey,
    required this.progress,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFeatured = journey.priorityRank == 1;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color: isFeatured ? AppColors.primary.withOpacity(0.28) : AppColors.border,
            width: isFeatured ? 1.5 : 1,
          ),
          boxShadow: isFeatured
              ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.08),
                    blurRadius: 16,
                    offset: const Offset(0, 10),
                  ),
                ]
              : null,
        ),
        child: Row(
          children: [
            _IconBubble(
              icon: iconFromKey(journey.icon),
              bg: AppColors.primary.withOpacity(0.10),
              fg: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    journey.title,
                    style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    journey.summary,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.textMuted,
                      height: 1.3,
                    ),
                  ),
                  const SizedBox(height: 10),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(99),
                    child: LinearProgressIndicator(
                      value: progress,
                      minHeight: 6,
                      backgroundColor: AppColors.border.withOpacity(0.7),
                      valueColor: AlwaysStoppedAnimation(AppColors.primary),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;

  const _IconBubble({required this.icon, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 44,
      height: 44,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: fg),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _ErrorState({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: AppTextStyles.bodyLarge),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: onRetry,
              child: const Text('Retry'),
            ),
          ],
        ),
      ),
    );
  }
}
