import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_providers.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/guest_guard.dart';
import '../../../../core/ui/icon_mapper.dart';
import '../../domain/journey_v1_models.dart';
import '../../providers/journeys_providers.dart';

class JourneyDetailScreen extends ConsumerStatefulWidget {
  final String id;
  const JourneyDetailScreen({super.key, required this.id});

  @override
  ConsumerState<JourneyDetailScreen> createState() =>
      _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends ConsumerState<JourneyDetailScreen> {
  bool _gateChecked = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _ensureSignedIn());
  }

  Future<void> _ensureSignedIn() async {
    if (_gateChecked) return;
    _gateChecked = true;

    await GuestGuard.requireSignedIn(
      context,
      ref,
      title: 'Sign in required',
      message: 'Create an account to start a Journey and track your progress.',
      primaryText: 'Continue',
      onCreateAccount: () {
        Navigator.of(context).pushNamed(AppRoutes.login);
      },
    );

    // If still not signed in after the modal, bounce back.
    final authAsync = ref.read(authStateProvider);
    final isSignedIn = authAsync.maybeWhen(
      data: (a) => a.isSignedIn,
      orElse: () => false,
    );
    if (!isSignedIn && mounted) {
      Navigator.of(context).maybePop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final isSignedIn = authAsync.maybeWhen(
      data: (a) => a.isSignedIn,
      orElse: () => false,
    );

    if (!isSignedIn) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final id = widget.id;
    final journey = ref.watch(journeyByIdProvider(id));
    if (journey == null) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: const Text('Journey'),
          backgroundColor: AppColors.getBackground(context),
          surfaceTintColor: AppColors.getBackground(context),
          elevation: 0,
        ),
        body: const Center(child: Text('Journey not found')),
      );
    }

    final purchaseAsync = ref.watch(isJourneyPurchasedProvider(journey.id));

    return purchaseAsync.when(
      loading:
          () => _Shell(journey: journey, isPurchased: false, isLoading: true),
      error:
          (_, __) =>
              _Shell(journey: journey, isPurchased: false, isLoading: false),
      data:
          (isPurchased) => _Shell(
            journey: journey,
            isPurchased: isPurchased,
            isLoading: false,
          ),
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

    final activities =
        journey.missions.toList()
          ..sort((a, b) => a.missionNumber.compareTo(b.missionNumber));

    final freeMissionId =
        activities.isEmpty
            ? ''
            : activities
                .firstWhere(
                  (m) => m.missionNumber == 1,
                  orElse: () => activities.first,
                )
                .id;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Journey',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ),
      body: completedAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (_, __) => _Body(
              journey: journey,
              activities: activities,
              completedMissionIds: const {},
              isPurchased: isPurchased,
              isLoading: isLoading,
              freeMissionId: freeMissionId,
            ),
        data:
            (completed) => _Body(
              journey: journey,
              activities: activities,
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
  final List<MissionV1> activities;
  final Set<String> completedMissionIds;
  final bool isPurchased;
  final bool isLoading;
  final String freeMissionId;

  const _Body({
    required this.journey,
    required this.activities,
    required this.completedMissionIds,
    required this.isPurchased,
    required this.isLoading,
    required this.freeMissionId,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final total = activities.length;
    final done = completedMissionIds.length.clamp(0, total);
    final progress = total == 0 ? 0.0 : done / total;

    return ListView(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 22),
      children: [
        _HeroHeader(
          journey: journey,
          progress: progress,
          done: done,
          total: total,
          isPurchased: isPurchased,
        ),
        const SizedBox(height: 12),
        Text(
          'Activities',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ...activities.asMap().entries.map((entry) {
          final idx = entry.key;
          final m = entry.value;

          final isFree = m.missionNumber == 1 && m.isFree;
          final isLocked = !(isPurchased || isFree);
          final isDone = completedMissionIds.contains(m.id);
          final isLast = idx == activities.length - 1;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: _ActivityCard(
              activity: m,
              isLocked: isLocked,
              isDone: isDone,
              showRail: !isLast,
              onTap: () {
                if (isLocked) {
                  _showUnlockSheet(
                    context,
                    ref,
                    journey: journey,
                    freeMissionId: freeMissionId,
                  );
                  return;
                }

                Navigator.pushNamed(
                  context,
                  '/journey/${journey.id}/activity/${m.id}',
                  arguments: {'journeyId': journey.id, 'missionId': m.id},
                );
              },
            ),
          );
        }),
        const SizedBox(height: 10),
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
      backgroundColor: AppColors.getBackground(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
      ),
      builder: (_) {
        final missionCount = journey.missions.length;

        return Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 44,
                height: 5,
                decoration: BoxDecoration(
                  color: AppColors.getBorder(context),
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              const SizedBox(height: 14),
              Row(
                children: [
                  _IconBubble(
                    icon: iconFromKey(journey.icon),
                    bg: AppColors.primary.withOpacity(0.12),
                    fg: AppColors.primary,
                    size: 42,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Unlock this Journey',
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$missionCount activities • One-time purchase',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Text(
                'You can complete Activity 1 free. Unlock to access the full Journey and finish strong.',
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
                          '/journey/${journey.id}/activity/$freeMissionId',
                          arguments: {
                            'journeyId': journey.id,
                            'missionId': freeMissionId,
                          },
                        );
                      },
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.textPrimary,
                        side: BorderSide(color: AppColors.getBorder(context)),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: const Text('Do free activity'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () async {
                        final ent = ref.read(
                          journeyEntitlementsServiceProvider,
                        );
                        await ent.markPurchased(journey.id);

                        ref.invalidate(purchasedJourneyIdsProvider);
                        ref.invalidate(isJourneyPurchasedProvider(journey.id));

                        if (context.mounted) Navigator.pop(context);

                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Unlocked. You can now access all activities.',
                            ),
                          ),
                        );
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
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
  final bool isPurchased;

  const _HeroHeader({
    required this.journey,
    required this.progress,
    required this.done,
    required this.total,
    required this.isPurchased,
  });

  @override
  Widget build(BuildContext context) {
    final showProgress = done > 0 && total > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.88),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: AppColors.primary.withOpacity(0.22)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.10),
            blurRadius: 18,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              _IconBubble(
                icon: iconFromKey(journey.icon),
                bg: Colors.white.withOpacity(0.18),
                fg: Colors.white,
                size: 42,
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journey.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.titleMedium.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        height: 1.12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '$total activities • ${isPurchased ? 'Full access' : 'First Activity is Free'}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.white.withOpacity(0.80),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            journey.summary,
            maxLines: 4,
            overflow: TextOverflow.ellipsis,
            style: AppTextStyles.bodySmall.copyWith(
              color: Colors.white.withOpacity(0.92),
              height: 1.35,
            ),
          ),
          if (showProgress) ...[
            const SizedBox(height: 12),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: Colors.white.withOpacity(0.22),
                valueColor: const AlwaysStoppedAnimation<Color>(Colors.white),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              '$done of $total complete',
              style: AppTextStyles.bodySmall.copyWith(
                color: Colors.white.withOpacity(0.85),
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final MissionV1 activity;
  final bool isLocked;
  final bool isDone;
  final bool showRail;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.activity,
    required this.isLocked,
    required this.isDone,
    required this.showRail,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFree = activity.missionNumber == 1 && activity.isFree;

    final leftIcon =
        isDone
            ? Icons.check_circle_outline
            : isLocked
            ? Icons.lock_outline
            : iconFromKey(activity.icon);

    // Only show DONE/FREE badges. LOCKED is already communicated by the icon.
    final badgeText = isDone ? 'DONE' : (isFree ? 'FREE' : null);

    final badgeBg = AppColors.primary.withOpacity(0.10);

    final cardBg =
        isLocked ? AppColors.surface.withOpacity(0.58) : AppColors.surface;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(
            color:
                isLocked
                    ? AppColors.border
                    : AppColors.primary.withOpacity(0.18),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(isLocked ? 0.012 : 0.040),
              blurRadius: 12,
              offset: const Offset(0, 9),
            ),
          ],
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            _ProgressRailDot(
              number: activity.missionNumber,
              isDone: isDone,
              isLocked: isLocked,
              showRail: showRail,
            ),
            const SizedBox(width: 10),
            _IconBubble(
              icon: leftIcon,
              bg:
                  isLocked
                      ? AppColors.primary.withOpacity(0.06)
                      : AppColors.primary.withOpacity(0.10),
              fg: isLocked ? AppColors.textMuted : AppColors.primary,
              size: 38,
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Expanded(
                        child: Text(
                          activity.title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: AppTextStyles.bodyMedium.copyWith(
                            fontWeight: FontWeight.w900,
                            height: 1.12,
                          ),
                        ),
                      ),
                      if (badgeText != null) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 9,
                            vertical: 5,
                          ),
                          decoration: BoxDecoration(
                            color: badgeBg,
                            borderRadius: BorderRadius.circular(999),
                          ),
                          child: Text(
                            badgeText,
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 6),
                  Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(
                        child: Text(
                          activity.subtitle,
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                            height: 1.32,
                          ),
                        ),
                      ),

                      if (isLocked) ...[
                        const SizedBox(width: 10),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 10,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primary.withOpacity(0.08),
                            borderRadius: BorderRadius.circular(999),
                            border: Border.all(
                              color: AppColors.primary.withOpacity(0.14),
                            ),
                          ),
                          child: Text(
                            'Unlock',
                            style: AppTextStyles.labelSmall.copyWith(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w900,
                              height: 1.0,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(width: 6),
            Icon(
              Icons.chevron_right,
              color: AppColors.getTextSecondary(context),
            ),
          ],
        ),
      ),
    );
  }
}

class _ProgressRailDot extends StatelessWidget {
  final int number;
  final bool isDone;
  final bool isLocked;
  final bool showRail;

  const _ProgressRailDot({
    required this.number,
    required this.isDone,
    required this.isLocked,
    required this.showRail,
  });

  @override
  Widget build(BuildContext context) {
    final bg =
        isDone
            ? AppColors.primary
            : isLocked
            ? AppColors.border
            : AppColors.primary.withOpacity(0.15);

    final fg = isDone ? Colors.white : AppColors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 26,
          height: 26,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(
              color:
                  isDone
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.18),
            ),
          ),
          child:
              isDone
                  ? const Icon(Icons.check, size: 14, color: Colors.white)
                  : Text(
                    '$number',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
        ),
        // no rail line (intentionally)
        if (showRail) const SizedBox(height: 0),
      ],
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.06),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.primary.withOpacity(0.22)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Unlock this Journey',
            style: AppTextStyles.titleSmall.copyWith(
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            '$missionCount activities • One-time purchase',
            style: AppTextStyles.bodySmall.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
          ElevatedButton(
            onPressed:
                isLoading
                    ? null
                    : () async {
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
                    },
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
        ],
      ),
    );
  }
}

class _IconBubble extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color fg;
  final double size;

  const _IconBubble({
    required this.icon,
    required this.bg,
    required this.fg,
    this.size = 44,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Icon(icon, color: fg, size: size * 0.52),
    );
  }
}
