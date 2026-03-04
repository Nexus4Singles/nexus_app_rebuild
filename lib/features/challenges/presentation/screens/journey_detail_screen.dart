import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/auth/auth_providers.dart';
import '../../../../core/router/safe_nav.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/router/app_routes.dart';
import '../../../../core/widgets/guest_guard.dart';
import '../../../../core/ui/icon_mapper.dart';
import '../../../../core/utils/image_utils.dart';
import '../../../../core/providers/user_provider.dart';
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
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Fetching Journeys...'),
            ],
          ),
        ),
      );
    }

    final id = widget.id;
    final catalogAsync = ref.watch(journeyCatalogProvider);

    if (catalogAsync.isLoading) {
      // ignore: avoid_print
      print('[JourneyDetailScreen] Loading catalog for journey id=$id');
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: const Text('Journey'),
          backgroundColor: AppColors.getBackground(context),
          surfaceTintColor: AppColors.getBackground(context),
          elevation: 0,
        ),
        body: const Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              CircularProgressIndicator(),
              SizedBox(height: 16),
              Text('Fetching Journeys...'),
            ],
          ),
        ),
      );
    }

    if (catalogAsync.hasError) {
      // ignore: avoid_print
      print(
        '[JourneyDetailScreen] ❌ Catalog error for journey id=$id: ${catalogAsync.error}',
      );
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          title: const Text('Journey'),
          backgroundColor: AppColors.getBackground(context),
          surfaceTintColor: AppColors.getBackground(context),
          elevation: 0,
        ),
        body: const Center(
          child: Text('Unable to load journeys. Please try again.'),
        ),
      );
    }

    final catalog = catalogAsync.value;
    final journey = catalog?.findByReference(id);
    if (journey == null) {
      final availableIds =
          (catalog?.journeys ?? const <JourneyV1>[]).map((j) => j.id).toList();
      // ignore: avoid_print
      print(
        '[JourneyDetailScreen] ❌ Journey not found. requested=$id, catalogCategory=${catalog?.category}, catalogCount=${availableIds.length}, sampleIds=${availableIds.take(8).toList()}',
      );
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

    // ignore: avoid_print
    print(
      '[JourneyDetailScreen] ✅ Journey resolved. requested=$id, resolved=${journey.id}, title=${journey.title}, matchMode=${journey.id == id ? 'id' : 'reference-fallback'}',
    );

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
      backgroundColor: Theme.of(context).colorScheme.background,
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.background,
        surfaceTintColor: Theme.of(context).colorScheme.background,
        elevation: 0,
        title: Text(
          'Journeys',
          style: Theme.of(context).textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: Theme.of(context).colorScheme.onBackground,
          ),
        ),
        centerTitle: true,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            color: Theme.of(context).colorScheme.onBackground,
          ),
          onPressed: () => navigateBackToHome(context),
        ),
      ),
      body: completedAsync.when(
        loading:
            () => const Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  CircularProgressIndicator(),
                  SizedBox(height: 16),
                  Text('Fetching Journeys...'),
                ],
              ),
            ),
        error:
            (e, __) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  const Text('Unable to load journey'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 120,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(completedMissionIdsProvider(journey.id));
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              ),
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
    final totalMinutes = activities.fold<int>(
      0,
      (sum, m) => sum + m.timeBoxMinutes,
    );
    final isCompleted = done >= total && total > 0;

    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      children: [
        // Featured Journey Card (compact)
        _HeroHeader(
          journey: journey,
          progress: progress,
          done: done,
          total: total,
          isPurchased: isPurchased,
          isCompleted: isCompleted,
          totalMinutes: totalMinutes,
        ),
        const SizedBox(height: 14),
        // Weekly stats card (journey-specific, with progress)
        _WeeklyStatsCard(
          journey: journey,
          completedMissionIds: completedMissionIds,
        ),
        const SizedBox(height: 4),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Icon(
              Icons.list_rounded,
              size: 18,
              color: Theme.of(context).colorScheme.primary,
            ),
            const SizedBox(width: 8),
            Text(
              'ACTIVITIES',
              style: Theme.of(context).textTheme.titleSmall?.copyWith(
                fontWeight: FontWeight.w800,
                fontSize: 12,
                letterSpacing: 0.5,
                color: Theme.of(context).colorScheme.onSurface,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Container(
          height: 2,
          width: 30,
          decoration: BoxDecoration(
            color: Theme.of(context).colorScheme.primary,
            borderRadius: BorderRadius.circular(1),
          ),
        ),
        const SizedBox(height: 12),
        // Continue banner for in-progress activity
        FutureBuilder<String?>(
          future: ref
              .read(journeyProgressServiceProvider)
              .getInProgressMissionId(journey.id),
          builder: (context, snapshot) {
            final inProgressMissionId = snapshot.data;
            if (inProgressMissionId != null &&
                !completedMissionIds.contains(inProgressMissionId)) {
              try {
                final inProgressActivity = activities.firstWhere(
                  (a) => a.id == inProgressMissionId,
                  orElse: () => throw Exception('Not found'),
                );
                return _ContinueBanner(
                  activity: inProgressActivity,
                  onTap: () {
                    Navigator.pushNamed(
                      context,
                      '/journey/${journey.id}/activity/${inProgressActivity.id}',
                      arguments: {
                        'journeyId': journey.id,
                        'missionId': inProgressActivity.id,
                      },
                    );
                  },
                );
              } catch (_) {
                // Activity not found, don't show banner
              }
            }
            return const SizedBox.shrink();
          },
        ),
        ...activities.asMap().entries.map((entry) {
          final idx = entry.key;
          final m = entry.value;

          final isFree = m.missionNumber == 1 && m.isFree;
          final isLocked = !(isPurchased || isFree);
          final isDone = completedMissionIds.contains(m.id);
          final isLast = idx == activities.length - 1;

          return Padding(
            padding: const EdgeInsets.only(bottom: 4),
            child: _ActivityCard(
              activity: m,
              isLocked: isLocked,
              isDone: isDone,
              showRail: !isLast,
              isPurchased: isPurchased,
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
        const SizedBox(height: 12),
        // Show completion celebration when journey is complete
        if (isCompleted)
          _JourneyCompletionCard(
            journey: journey,
            onRestart: () async {
              // Show confirmation dialog
              showDialog(
                context: context,
                builder:
                    (ctx) => AlertDialog(
                      title: const Text('Restart Journey?'),
                      content: const Text(
                        'Would you like to restart this journey? Your previous entries will be saved.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx),
                          child: const Text('Cancel'),
                        ),
                        ElevatedButton(
                          onPressed: () async {
                            Navigator.pop(ctx);
                            final currentUserAsync = ref.watch(
                              currentUserProvider,
                            );
                            final uid = currentUserAsync.maybeWhen(
                              data: (user) => user?.id ?? '',
                              orElse: () => '',
                            );

                            if (uid.isNotEmpty) {
                              final progressSvc = ref.read(
                                journeyProgressServiceProvider,
                              );
                              await progressSvc.restartJourney(journey.id, uid);

                              // Invalidate the provider to refresh the UI
                              ref.invalidate(
                                completedMissionIdsProvider(journey.id),
                              );
                              ref.invalidate(
                                isJourneyCompletedProvider(journey.id),
                              );

                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: const Text(
                                      'Journey restarted! You\'re ready to begin again.',
                                    ),
                                    duration: const Duration(seconds: 3),
                                    behavior: SnackBarBehavior.floating,
                                    backgroundColor: AppColors.success,
                                  ),
                                );
                              }
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor:
                                Theme.of(context).colorScheme.primary,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                          ),
                          child: const Text(
                            'Restart',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
              );
            },
          ),
        const SizedBox(height: 6),
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
                  color: Theme.of(context).dividerColor.withOpacity(0.18),
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
                          style: AppTextStyles.titleSmall.copyWith(
                            fontWeight: FontWeight.w900,
                            color: AppColors.getTextPrimary(context),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$missionCount activities • One-time purchase',
                          style: AppTextStyles.caption.copyWith(
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
                style: AppTextStyles.bodySmall.copyWith(
                  height: 1.35,
                  color: AppColors.getTextPrimary(context).withOpacity(0.85),
                ),
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
                        foregroundColor: AppColors.getTextPrimary(context),
                        side: BorderSide(
                          color: AppColors.primary.withOpacity(0.28),
                          width: 1.4,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                        padding: const EdgeInsets.symmetric(vertical: 14),
                      ),
                      child: Text(
                        'Do free activity',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.pop(context);
                        // Navigate to journey purchase screen
                        Navigator.pushNamed(
                          context,
                          '/journey-purchase',
                          arguments: journey,
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
                      child: Text(
                        'Unlock',
                        style: AppTextStyles.bodySmall.copyWith(
                          fontWeight: FontWeight.w700,
                          color: Colors.white,
                        ),
                      ),
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

class _HeroHeader extends ConsumerWidget {
  final JourneyV1 journey;
  final double progress;
  final int done;
  final int total;
  final bool isPurchased;
  final bool isCompleted;
  final int totalMinutes;

  const _HeroHeader({
    required this.journey,
    required this.progress,
    required this.done,
    required this.total,
    required this.isPurchased,
    required this.isCompleted,
    required this.totalMinutes,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final showProgress = done > 0 && total > 0;
    final userAsync = ref.watch(currentUserProvider);
    String? userGender = userAsync.maybeWhen(
      data: (user) => user?.gender,
      orElse: () => null,
    );
    String heroImage = journey.heroImage ?? '';
    int journeyIndex = 1;
    final reg = RegExp(r'Journey (\d+)', caseSensitive: false);
    final match = reg.firstMatch(journey.title);
    if (match != null && match.groupCount > 0) {
      journeyIndex = int.tryParse(match.group(1) ?? '1') ?? 1;
    }
    if (heroImage.isEmpty) {
      if (journey.id == 'singles_biblical_femininity' ||
          (journeyIndex == 9 && userGender == 'female')) {
        heroImage = 'assets/images/journeys/Singles_journey9_female.jpg';
      } else if (journey.id == 'singles_biblical_masculinity' ||
          (journeyIndex == 9 && userGender == 'male')) {
        heroImage = 'assets/images/journeys/Singles_journey9_male.jpeg';
      } else {
        const exts = ['.jpg', '.jpeg', '.png', '.webp', '.avif'];
        for (final ext in exts) {
          final candidate =
              'assets/images/journeys/Singles_journey$journeyIndex$ext';
          heroImage = candidate;
          break;
        }
      }
    }
    final hasImage = heroImage.isNotEmpty;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final base = AppColors.getSurface(context);
    final textColor =
        hasImage
            ? AppColors.getTextOnDark(context)
            : AppColors.getTextPrimary(context);
    final secondaryColor =
        hasImage
            ? (isDark
                ? Colors.white.withOpacity(0.90)
                : AppColors.getTextSecondary(context))
            : AppColors.getTextSecondary(context);
    final pillBg =
        hasImage
            ? (isDark
                ? AppColors.primary.withOpacity(0.15)
                : AppColors.primary.withOpacity(0.10))
            : AppColors.primary.withOpacity(0.10);
    final pillBorder =
        hasImage
            ? (isDark
                ? AppColors.primary.withOpacity(0.30)
                : AppColors.primary.withOpacity(0.16))
            : AppColors.primary.withOpacity(0.16);
    final progressTrack =
        hasImage
            ? (isDark
                ? Colors.white.withOpacity(0.22)
                : Theme.of(context).colorScheme.primary.withOpacity(0.12))
            : Theme.of(context).colorScheme.primary.withOpacity(0.12);
    final progressFill = Theme.of(context).colorScheme.primary;

    return ClipRRect(
      borderRadius: BorderRadius.circular(18),
      child: Container(
        decoration: BoxDecoration(
          color: base,
          border: Border.all(color: AppColors.getBorder(context)),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.06), blurRadius: 14),
          ],
        ),
        child: Padding(
          padding: const EdgeInsets.all(18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (hasImage)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.asset(
                    heroImage,
                    fit: BoxFit.cover,
                    width: double.infinity,
                    height: 220, // Increased height for more visible image
                    errorBuilder:
                        (context, error, stackTrace) => Container(
                          height: 220,
                          color: Colors.grey[300],
                          child: Center(
                            child: Icon(
                              Icons.broken_image,
                              color: Colors.grey[600],
                            ),
                          ),
                        ),
                  ),
                ),
              const SizedBox(height: 12),
              Text(
                journey.title,
                style: AppTextStyles.headlineSmall.copyWith(
                  color: textColor,
                  fontWeight: FontWeight.bold,
                  fontSize: 14, // Slightly reduced for compactness
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              if (journey.subtitle.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4.0, bottom: 2.0),
                  child: Text(
                    journey.subtitle,
                    style: AppTextStyles.bodySmall.copyWith(
                      color: secondaryColor,
                      fontWeight: FontWeight.w500,
                      fontSize: 13,
                    ),
                  ),
                ),
              const SizedBox(height: 4),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: _HeroPill(
                        text: '$total activities',
                        icon: Icons.splitscreen,
                        bg: pillBg,
                        fg: AppColors.primary,
                        borderColor: pillBorder,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Center(
                      child: _HeroPill(
                        text: '${(totalMinutes / 60).ceil()} Hours',
                        icon: Icons.timer_outlined,
                        bg: pillBg,
                        fg: AppColors.primary,
                        borderColor: pillBorder,
                      ),
                    ),
                  ),
                  Expanded(
                    child: Align(
                      alignment: Alignment.centerRight,
                      child:
                          (journey.themeTag ?? '').isNotEmpty
                              ? _HeroPill(
                                text: _prettyTag(journey.themeTag!),
                                icon: Icons.bookmark_outline,
                                bg: pillBg,
                                fg: AppColors.primary,
                                borderColor: pillBorder,
                              )
                              : const SizedBox.shrink(),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 7),
              // Removed summary from hero card
              if (showProgress) ...[
                const SizedBox(height: 10),
                ClipRRect(
                  borderRadius: BorderRadius.circular(99),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 5,
                    backgroundColor: progressTrack,
                    valueColor: AlwaysStoppedAnimation<Color>(progressFill),
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  isCompleted
                      ? 'Journey Complete!'
                      : '$done of $total complete',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: secondaryColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (isCompleted) ...[
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    icon: const Icon(Icons.refresh_rounded, size: 16),
                    label: const Text('Restart Journey'),
                    style: OutlinedButton.styleFrom(
                      foregroundColor: AppColors.getTextPrimary(context),
                      side: BorderSide(color: AppColors.getBorder(context)),
                      padding: const EdgeInsets.symmetric(vertical: 8),
                      textStyle: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                    onPressed:
                        () =>
                            _showRestartConfirmation(context, ref, journey.id),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  void _showRestartConfirmation(
    BuildContext context,
    WidgetRef ref,
    String journeyId,
  ) {
    showCupertinoDialog(
      context: context,
      builder: (BuildContext ctx) {
        return CupertinoAlertDialog(
          title: const Text('Restart Journey?'),
          content: const Text(
            'Your current progress will be lost. This cannot be undone.',
          ),
          actions: [
            CupertinoDialogAction(
              child: const Text('Cancel'),
              onPressed: () => Navigator.of(ctx).pop(),
            ),
            CupertinoDialogAction(
              isDestructiveAction: true,
              child: const Text('Restart'),
              onPressed: () async {
                final user = ref.read(currentUserProvider).value;
                if (user != null) {
                  await ref
                      .read(journeyProgressServiceProvider)
                      .restartJourney(journeyId, user.id);

                  // Invalidate providers to force a refresh
                  ref.invalidate(completedMissionIdsProvider(journeyId));
                  ref.invalidate(isJourneyCompletedProvider(journeyId));
                }
                Navigator.of(ctx).pop();
              },
            ),
          ],
        );
      },
    );
  }
}

class _ActivityCard extends StatelessWidget {
  final MissionV1 activity;
  final bool isLocked;
  final bool isDone;
  final bool showRail;
  final bool isPurchased;
  final VoidCallback onTap;

  const _ActivityCard({
    required this.activity,
    required this.isLocked,
    required this.isDone,
    required this.showRail,
    required this.isPurchased,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isFree = activity.missionNumber == 1 && activity.isFree;
    final theme = Theme.of(context);
    final cardBg =
        isLocked
            ? theme.colorScheme.surface.withOpacity(
              theme.brightness == Brightness.dark ? 0.60 : 0.90,
            )
            : theme.colorScheme.surface;
    // final minutes = activity.timeBoxMinutes; // Removed: no longer used after timer row removal.

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
        decoration: BoxDecoration(
          color: cardBg,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.10),
            width: 1.0,
          ),
          boxShadow: [
            BoxShadow(
              color: theme.colorScheme.shadow.withOpacity(
                isLocked ? 0.008 : 0.025,
              ),
              blurRadius: 8,
              offset: const Offset(0, 5),
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
            const SizedBox(width: 7),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          activity.title,
                          style: theme.textTheme.bodySmall?.copyWith(
                            fontWeight: FontWeight.w600,
                            color: theme.colorScheme.onSurface,
                            fontSize: 13,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      const SizedBox(width: 4),
                      if (isDone)
                        _AnimatedCompletionCheckmark(theme: theme)
                      else if (isFree &&
                          activity.missionNumber == 1 &&
                          !isPurchased)
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.09),
                            borderRadius: BorderRadius.circular(7),
                          ),
                          child: Text(
                            'Free',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: theme.colorScheme.primary,
                              fontWeight: FontWeight.bold,
                              fontSize: 11,
                            ),
                          ),
                        )
                      else if (isLocked)
                        Container(
                          width: 28,
                          height: 28,
                          decoration: BoxDecoration(
                            color: theme.colorScheme.primary.withOpacity(0.10),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(
                              color: theme.colorScheme.primary.withOpacity(
                                0.20,
                              ),
                              width: 0.8,
                            ),
                          ),
                          child: Icon(
                            Icons.lock_rounded,
                            size: 14,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 5),
                  // Removed duplicate upper right Locked/Done tag row. Only lower right tag remains.
                ],
              ),
            ),
          ],
        ),
      ),
      // End of widget
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
    final theme = Theme.of(context);
    final bg =
        isDone
            ? theme.colorScheme.primary
            : isLocked
            ? theme.colorScheme.onSurface.withOpacity(0.13)
            : theme.colorScheme.primary.withOpacity(0.15);

    final fg = isDone ? theme.colorScheme.onPrimary : theme.colorScheme.primary;

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
                      ? theme.colorScheme.primary
                      : theme.colorScheme.primary.withOpacity(0.18),
            ),
          ),
          child:
              isDone
                  ? Icon(
                    Icons.check,
                    size: 14,
                    color: theme.colorScheme.onPrimary,
                  )
                  : Text(
                    '$number',
                    style: AppTextStyles.labelSmall.copyWith(
                      color: fg,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
        ),
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
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  isLoading
                      ? null
                      : () {
                        // Navigate to journey purchase screen
                        Navigator.pushNamed(
                          context,
                          '/journey-purchase',
                          arguments: journey,
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
              child: Text(
                'Unlock Journey',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
            ),
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

class _HeroPill extends StatelessWidget {
  final String text;
  final Color bg;
  final Color fg;
  final Color borderColor;
  final IconData? icon;
  const _HeroPill({
    required this.text,
    required this.bg,
    required this.fg,
    required this.borderColor,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: borderColor),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 13, color: fg),
            const SizedBox(width: 2),
          ],
          Flexible(
            child: Text(
              text,
              style: AppTextStyles.labelSmall.copyWith(
                color: fg,
                fontWeight: FontWeight.w900,
              ),
              overflow: TextOverflow.ellipsis,
              maxLines: 1,
            ),
          ),
        ],
      ),
    );
  }
}

String _prettyTag(String t) {
  final s = t.trim();
  if (s.isEmpty) return '';
  return s[0].toUpperCase() + s.substring(1);
}

class _ContinueBanner extends StatelessWidget {
  final MissionV1 activity;
  final VoidCallback onTap;

  const _ContinueBanner({required this.activity, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            theme.colorScheme.primary.withOpacity(0.15),
            theme.colorScheme.primary.withOpacity(0.08),
          ],
        ),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: theme.colorScheme.primary.withOpacity(0.25),
          width: 1.5,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Icon(
                    Icons.play_arrow_rounded,
                    color: theme.colorScheme.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Continue where you left off',
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w600,
                          fontSize: 12,
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        activity.title,
                        style: theme.textTheme.bodySmall?.copyWith(
                          fontWeight: FontWeight.w700,
                          fontSize: 14,
                          color: theme.colorScheme.primary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  Icons.chevron_right_rounded,
                  color: theme.colorScheme.primary.withOpacity(0.5),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _WeeklyStatsCard extends StatelessWidget {
  final JourneyV1 journey;
  final Set<String> completedMissionIds;

  const _WeeklyStatsCard({
    required this.journey,
    required this.completedMissionIds,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final total = journey.missions.length;
    final completed = completedMissionIds.length;

    // Only show if there's progress
    if (completed == 0) return const SizedBox.shrink();

    final percent = total > 0 ? ((completed / total) * 100).toInt() : 0;

    return Padding(
      padding: const EdgeInsets.only(bottom: 16),
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              theme.colorScheme.primary.withOpacity(0.08),
              theme.colorScheme.primary.withOpacity(0.04),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: theme.colorScheme.primary.withOpacity(0.15),
            width: 1,
          ),
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Title + ratio
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Progress',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w600,
                      fontSize: 12,
                      color: theme.colorScheme.onSurface.withOpacity(0.6),
                    ),
                  ),
                  Text(
                    '$completed/$total',
                    style: theme.textTheme.bodySmall?.copyWith(
                      fontWeight: FontWeight.w700,
                      fontSize: 13,
                      color: theme.colorScheme.primary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              // Progress bar
              ClipRRect(
                borderRadius: BorderRadius.circular(4),
                child: LinearProgressIndicator(
                  value: completed / total,
                  minHeight: 6,
                  backgroundColor: theme.colorScheme.primary.withOpacity(0.1),
                  valueColor: AlwaysStoppedAnimation(
                    theme.colorScheme.primary.withOpacity(0.7),
                  ),
                ),
              ),
              const SizedBox(height: 10),
              // Motivation message (journey-specific)
              Text(
                _buildPersonalizedMessage(journey.title, percent),
                style: theme.textTheme.labelSmall?.copyWith(
                  fontWeight: FontWeight.w500,
                  fontSize: 11,
                  color: theme.colorScheme.onSurface.withOpacity(0.7),
                  height: 1.4,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _buildPersonalizedMessage(String journeyTitle, int percent) {
    // Journey-specific messages tied to completion %
    if (percent < 25) {
      return '$journeyTitle • You\'ve started something transformative';
    } else if (percent < 50) {
      return '$journeyTitle • You\'re discovering who you really are';
    } else if (percent < 75) {
      return '$journeyTitle • You\'re more than halfway there';
    } else if (percent < 100) {
      return '$journeyTitle • You\'re so close to the finish line';
    } else {
      return '$journeyTitle • You completed this journey!';
    }
  }
}

/// Theme-aware animated checkmark widget for completed activities
class _AnimatedCompletionCheckmark extends StatefulWidget {
  final ThemeData theme;

  const _AnimatedCompletionCheckmark({required this.theme});

  @override
  State<_AnimatedCompletionCheckmark> createState() =>
      _AnimatedCompletionCheckmarkState();
}

class _AnimatedCompletionCheckmarkState
    extends State<_AnimatedCompletionCheckmark>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<double> _opacityAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _opacityAnimation = Tween<double>(
      begin: 0.0,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: FadeTransition(
        opacity: _opacityAnimation,
        child: Container(
          width: 28,
          height: 28,
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                widget.theme.colorScheme.primary.withOpacity(0.15),
                widget.theme.colorScheme.primary.withOpacity(0.08),
              ],
            ),
            borderRadius: BorderRadius.circular(8),
            border: Border.all(
              color: widget.theme.colorScheme.primary.withOpacity(0.30),
              width: 1.0,
            ),
          ),
          child: Icon(
            Icons.check_circle_rounded,
            size: 16,
            color: widget.theme.colorScheme.primary,
          ),
        ),
      ),
    );
  }
}

/// Celebration card shown when journey is completely finished
class _JourneyCompletionCard extends StatefulWidget {
  final JourneyV1 journey;
  final VoidCallback onRestart;

  const _JourneyCompletionCard({
    required this.journey,
    required this.onRestart,
  });

  @override
  State<_JourneyCompletionCard> createState() => _JourneyCompletionCardState();
}

class _JourneyCompletionCardState extends State<_JourneyCompletionCard>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;
  late Animation<Offset> _slideAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _scaleAnimation = Tween<double>(
      begin: 0.8,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.elasticOut));

    _slideAnimation = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic));

    _controller.forward();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final isDark = theme.brightness == Brightness.dark;

    return SlideTransition(
      position: _slideAnimation,
      child: ScaleTransition(
        scale: _scaleAnimation,
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                theme.colorScheme.primary.withOpacity(isDark ? 0.25 : 0.12),
                theme.colorScheme.primary.withOpacity(isDark ? 0.15 : 0.05),
              ],
            ),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: theme.colorScheme.primary.withOpacity(0.3),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: theme.colorScheme.primary.withOpacity(0.15),
                blurRadius: 24,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Celebration icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        theme.colorScheme.primary.withOpacity(0.25),
                        theme.colorScheme.primary.withOpacity(0.10),
                      ],
                    ),
                    border: Border.all(
                      color: theme.colorScheme.primary.withOpacity(0.5),
                      width: 2,
                    ),
                  ),
                  child: Icon(
                    Icons.celebration_rounded,
                    size: 44,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Journey Complete! 🎉',
                  style: theme.textTheme.headlineSmall?.copyWith(
                    fontWeight: FontWeight.w900,
                    fontSize: 20,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Message
                Text(
                  'You\'ve completed all activities in this journey. Celebrate your growth and transformation!',
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurface.withOpacity(0.7),
                    height: 1.6,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Action buttons
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ElevatedButton(
                      onPressed: widget.onRestart,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: theme.colorScheme.primary,
                        foregroundColor: theme.colorScheme.onPrimary,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.refresh_rounded,
                            size: 20,
                            color: theme.colorScheme.onPrimary,
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Restart Journey',
                            style: TextStyle(
                              fontWeight: FontWeight.w600,
                              fontSize: 16,
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      'Begin again and deepen your understanding',
                      style: theme.textTheme.labelSmall?.copyWith(
                        color: theme.colorScheme.onSurface.withOpacity(0.5),
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
