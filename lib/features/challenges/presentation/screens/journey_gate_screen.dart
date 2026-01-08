import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../domain/journey_v1_models.dart';
import '../../providers/journeys_providers.dart';
import 'journey_session_screen.dart';

class JourneyGateScreen extends ConsumerWidget {
  final String journeyId;
  final String missionId;

  const JourneyGateScreen({
    super.key,
    required this.journeyId,
    required this.missionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyByIdProvider(journeyId));

    if (journey == null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Activity'),
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          elevation: 0,
        ),
        body: const Center(child: Text('Journey not found')),
      );
    }

    final activity = journey.missions.firstWhere(
      (m) => m.id == missionId,
      orElse: () => journey.missions.first,
    );

    final isFree = activity.missionNumber == 1 && activity.isFree;
    final purchasedAsync = ref.watch(isJourneyPurchasedProvider(journeyId));

    return purchasedAsync.when(
      loading: () => const _GateLoading(),
      error:
          (_, __) => _LockedView(
            journey: journey,
            activity: activity,
            allowFree: isFree,
          ),
      data: (isPurchased) {
        if (isPurchased || isFree) {
          return JourneySessionScreen(
            journeyId: journeyId,
            missionId: missionId,
          );
        }
        return _LockedView(
          journey: journey,
          activity: activity,
          allowFree: true,
        );
      },
    );
  }
}

class _GateLoading extends StatelessWidget {
  const _GateLoading();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: const Center(child: CircularProgressIndicator()),
    );
  }
}

class _LockedView extends ConsumerWidget {
  final JourneyV1 journey;
  final MissionV1 activity;
  final bool allowFree;

  const _LockedView({
    required this.journey,
    required this.activity,
    required this.allowFree,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Locked',
          style: AppTextStyles.titleMedium.copyWith(fontWeight: FontWeight.w900),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _GateHero(journey: journey, activity: activity),
            const SizedBox(height: 12),
            Text(
              'Unlock to continue',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            Text(
              'This activity is part of a paid Journey. Unlock once to access all activities.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.textMuted,
                height: 1.35,
              ),
            ),
            const SizedBox(height: 12),
            _BenefitsRow(),
            const Spacer(),
            _UnlockFooter(
              allowFree: allowFree,
              onBack: () => Navigator.of(context).pop(),
              onUnlock: () async {
                final ent = ref.read(journeyEntitlementsServiceProvider);
                await ent.markPurchased(journey.id);

                ref.invalidate(purchasedJourneyIdsProvider);
                ref.invalidate(isJourneyPurchasedProvider(journey.id));

                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Unlocked. You can now access all activities.',
                    ),
                  ),
                );

                if (context.mounted) {
                  Navigator.of(context).pushReplacement(
                    MaterialPageRoute(
                      builder:
                          (_) => JourneySessionScreen(
                            journeyId: journey.id,
                            missionId: activity.id,
                          ),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }
}

class _GateHero extends StatelessWidget {
  final JourneyV1 journey;
  final MissionV1 activity;

  const _GateHero({
    required this.journey,
    required this.activity,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.90),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.25)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.12),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: Colors.white.withOpacity(0.16),
              borderRadius: BorderRadius.circular(14),
            ),
            child: const Icon(
              Icons.lock_outline,
              color: Colors.white,
              size: 22,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        journey.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withOpacity(0.18),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        'LOCKED',
                        style: AppTextStyles.labelSmall.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Activity ${activity.missionNumber}: ${activity.title}',
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: AppTextStyles.titleSmall.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.w900,
                    height: 1.15,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Unlock this Journey to complete all activities and track progress.',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: Colors.white.withOpacity(0.88),
                    height: 1.35,
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

class _BenefitsRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: const [
        _BenefitChip(text: 'Full journey access'),
        _BenefitChip(text: 'Track progress'),
        _BenefitChip(text: 'Guided growth'),
      ],
    );
  }
}

class _BenefitChip extends StatelessWidget {
  final String text;
  const _BenefitChip({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.14)),
      ),
      child: Text(
        text,
        style: AppTextStyles.labelSmall.copyWith(
          color: AppColors.primary,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

class _UnlockFooter extends StatelessWidget {
  final bool allowFree;
  final VoidCallback onBack;
  final VoidCallback onUnlock;

  const _UnlockFooter({
    required this.allowFree,
    required this.onBack,
    required this.onUnlock,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        if (allowFree) ...[
          Expanded(
            child: OutlinedButton(
              onPressed: onBack,
              style: OutlinedButton.styleFrom(
                foregroundColor: AppColors.textPrimary,
                side: BorderSide(color: AppColors.border),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                padding: const EdgeInsets.symmetric(vertical: 14),
              ),
              child: const Text('Back'),
            ),
          ),
          const SizedBox(width: 12),
        ],
        Expanded(
          child: ElevatedButton(
            onPressed: onUnlock,
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              padding: const EdgeInsets.symmetric(vertical: 14),
            ),
            child: const Text('Unlock Journey'),
          ),
        ),
      ],
    );
  }
}
