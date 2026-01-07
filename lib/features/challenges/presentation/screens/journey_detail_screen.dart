import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/icon_mapper.dart';
import '../../domain/journey_v1_models.dart';
import '../../providers/journeys_providers.dart';

class JourneyDetailScreen extends ConsumerWidget {
  final String id;
  const JourneyDetailScreen({super.key, required this.id});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyByIdProvider(id));
    if (journey == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Journey'),
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          elevation: 0,
        ),
        body: const Center(child: Text('Journey not found')),
      );
    }

    final purchaseAsync = ref.watch(isJourneyPurchasedProvider(journey.id));

    return purchaseAsync.when(
      loading: () => _Shell(journey: journey, isPurchased: false, isLoading: true),
      error: (_, __) => _Shell(journey: journey, isPurchased: false, isLoading: false),
      data: (isPurchased) => _Shell(journey: journey, isPurchased: isPurchased, isLoading: false),
    );
  }
}

class _Shell extends ConsumerWidget {
  final JourneyV1 journey;
  final bool isPurchased;
  final bool isLoading;

  const _Shell({
    required this.journey,
    required this.isPurchased,
    required this.isLoading,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final completedAsync = ref.watch(completedMissionIdsProvider(journey.id));

    final missions = journey.missions.toList()
      ..sort((a, b) => a.missionNumber.compareTo(b.missionNumber));

    final freeMissionId = missions.firstWhere((m) => m.missionNumber == 1, orElse: () => missions.first).id;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(journey.title),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
      ),
      body: completedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (_, __) => _Body(
          journey: journey,
          missions: missions,
          completedMissionIds: const {},
          isPurchased: isPurchased,
          isLoading: isLoading,
          freeMissionId: freeMissionId,
        ),
        data: (completed) => _Body(
          journey: journey,
          missions: missions,
          completedMissionIds: completed,
          isPurchased: isPurchased,
          isLoading: isLoading,
          freeMissionId: freeMissionId,
        ),
      ),
    );
  }
}

class _Body extends ConsumerWidget {
  final JourneyV1 journey;
  final List<MissionV1> missions;
  final Set<String> completedMissionIds;
  final bool isPurchased;
  final bool isLoading;
  final String freeMissionId;

  const _Body({
    required this.journey,
    required this.missions,
    required this.completedMissionIds,
    required this.isPurchased,
    required this.isLoading,
    required this.freeMissionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = missions.length;
    final done = completedMissionIds.length.clamp(0, total);
    final progress = total == 0 ? 0.0 : done / total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
      children: [
        _HeroHeader(journey: journey, progress: progress, done: done, total: total),
        const SizedBox(height: 16),
        Text('Missions', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w900)),
        const SizedBox(height: 10),

        ...missions.map((m) {
          final isFree = m.missionNumber == 1 && m.isFree;
          final isLocked = !(isPurchased || isFree);
          final isDone = completedMissionIds.contains(m.id);

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: _MissionRow(
              mission: m,
              isLocked: isLocked,
              isDone: isDone,
              onTap: () {
                if (isLocked) {
                  _showUnlockSheet(context, ref, journey: journey, freeMissionId: freeMissionId);
                  return;
                }

                Navigator.pushNamed(
                  context,
                  '/journey/${journey.id}/mission/${m.id}',
                  arguments: {'journeyId': journey.id, 'missionId': m.id},
                );
              },
            ),
          );
        }),

        const SizedBox(height: 16),

        if (!isPurchased) _UnlockCta(journey: journey, isLoading: isLoading),
      ],
    );
  }

  void _showUnlockSheet(
    BuildContext context,
    WidgetRef ref, {
    required JourneyV1 journey,
    required String freeMissionId,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        final missionCount = journey.missions.length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.border,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Row(
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
                        Text('Unlock this Journey', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w900)),
                        const SizedBox(height: 4),
                        Text('$missionCount missions • One-time purchase', style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted)),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              Text(
                'You can complete Mission 1 free. Unlock to access the full Journey and finish strong.',
                style: AppTextStyles.bodyMedium.copyWith(height: 1.35),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        Navigator.pushNamed(
                          context,
                          '/journey/${journey.id}/mission/$freeMissionId',
                          arguments: {'journeyId': journey.id, 'missionId': freeMissionId},
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Do free mission'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final ent = ref.read(journeyEntitlementsServiceProvider);
                        await ent.markPurchased(journey.id);

                        ref.invalidate(purchasedJourneyIdsProvider);
                        ref.invalidate(isJourneyPurchasedProvider(journey.id));

                        if (context.mounted) Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Unlocked. You can now access all missions.')),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Unlock'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

class _HeroHeader extends StatelessWidget {
  final JourneyV1 journey;
  final double progress;
  final int done;
  final int total;

  const _HeroHeader({
    required this.journey,
    required this.progress,
    required this.done,
    required this.total,
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
                Text(journey.summary, style: AppTextStyles.bodyMedium.copyWith(height: 1.35)),
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
                const SizedBox(height: 8),
                Text(
                  '$done of $total missions complete',
                  style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _MissionRow extends StatelessWidget {
  final MissionV1 mission;
  final bool isLocked;
  final bool isDone;
  final VoidCallback onTap;

  const _MissionRow({
    required this.mission,
    required this.isLocked,
    required this.isDone,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final leftIcon = isDone
        ? Icons.check_circle_outline
        : isLocked
            ? Icons.lock_outline
            : iconFromKey(mission.icon);

    final badge = isDone
        ? 'DONE'
        : (mission.missionNumber == 1 && mission.isFree)
            ? 'FREE'
            : null;

    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            _IconBubble(
              icon: leftIcon,
              bg: AppColors.primary.withOpacity(0.08),
              fg: AppColors.primary,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Mission ${mission.missionNumber}: ${mission.title}',
                          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w900),
                        ),
                      ),
                      if (badge != null)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badge,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    isLocked ? 'Unlock to access this mission' : mission.subtitle,
                    style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted, height: 1.3),
                  ),
                ],
              ),
            ),
            const SizedBox(width: 8),
            Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _UnlockCta extends ConsumerWidget {
  final JourneyV1 journey;
  final bool isLoading;
  const _UnlockCta({required this.journey, required this.isLoading});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final missionCount = journey.missions.length;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.18)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Unlock this Journey', style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(
            '$missionCount missions • One-time purchase',
            style: AppTextStyles.bodySmall.copyWith(color: AppColors.textMuted),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed: isLoading
                ? null
                : () async {
                    final ent = ref.read(journeyEntitlementsServiceProvider);
                    await ent.markPurchased(journey.id);

                    ref.invalidate(purchasedJourneyIdsProvider);
                    ref.invalidate(isJourneyPurchasedProvider(journey.id));

                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Unlocked. You can now access all missions.')),
                    );
                  },
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Unlock Journey'),
          ),
        ],
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
