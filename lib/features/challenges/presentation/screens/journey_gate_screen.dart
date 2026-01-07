import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../providers/journeys_providers.dart';
import '../../domain/journey_v1_models.dart';
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
          title: const Text('Mission'),
          backgroundColor: AppColors.background,
          surfaceTintColor: AppColors.background,
          elevation: 0,
        ),
        body: const Center(child: Text('Journey not found')),
      );
    }

    final mission = journey.missions.firstWhere(
      (m) => m.id == missionId,
      orElse: () => journey.missions.first,
    );

    final isFree = mission.missionNumber == 1 && mission.isFree;
    final purchasedAsync = ref.watch(isJourneyPurchasedProvider(journeyId));

    return purchasedAsync.when(
      loading: () => const _GateLoading(),
      error: (_, __) => _LockedView(
        journeyId: journeyId,
        mission: mission,
        allowFree: isFree,
      ),
      data: (isPurchased) {
        if (isPurchased || isFree) {
          return JourneySessionScreen(journeyId: journeyId, missionId: missionId);
        }
        return _LockedView(
          journeyId: journeyId,
          mission: mission,
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
  final String journeyId;
  final MissionV1 mission;
  final bool allowFree;

  const _LockedView({
    required this.journeyId,
    required this.mission,
    required this.allowFree,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Locked'),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Unlock to continue',
              style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 8),
            Text(
              'This mission is part of a paid Journey. Unlock once to access all missions.',
              style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted, height: 1.35),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Row(
                children: [
                  const Icon(Icons.lock_outline, color: AppColors.textMuted),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      'Mission ${mission.missionNumber}: ${mission.title}',
                      style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w900),
                    ),
                  ),
                ],
              ),
            ),
            const Spacer(),
            Row(
              children: [
                if (allowFree) ...[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () {
                        Navigator.of(context).pop();
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.border),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Back'),
                    ),
                  ),
                  const SizedBox(width: 12),
                ],
                Expanded(
                  child: ElevatedButton(
                    onPressed: () async {
                      final ent = ref.read(journeyEntitlementsServiceProvider);
                      await ent.markPurchased(journeyId);

                      ref.invalidate(purchasedJourneyIdsProvider);
                      ref.invalidate(isJourneyPurchasedProvider(journeyId));

                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Unlocked. You can now access all missions.')),
                      );

                      if (context.mounted) {
                        Navigator.of(context).pushReplacement(
                          MaterialPageRoute(
                            builder: (_) => JourneySessionScreen(journeyId: journeyId, missionId: mission.id),
                          ),
                        );
                      }
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                    child: const Text('Unlock Journey'),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
