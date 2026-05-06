import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../application/counselling_providers.dart';
import '../../domain/counselling_models.dart';
import '../widgets/coach_card.dart';
import 'coach_profile_screen.dart';

class CoachListScreen extends ConsumerWidget {
  final SessionType sessionType;

  const CoachListScreen({super.key, required this.sessionType});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final coachesAsync = ref.watch(
      coachesBySessionTypeProvider(sessionType.firestoreKey),
    );

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              sessionType.shortLabel,
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Choose your counselor',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
                fontSize: 12,
              ),
            ),
          ],
        ),
      ),
      body: coachesAsync.when(
        loading: () => const _CoachListSkeleton(),
        error: (err, _) => _ErrorState(message: err.toString()),
        data: (coaches) {
          if (coaches.isEmpty) {
            return const _EmptyState();
          }
          return RefreshIndicator(
            color: AppColors.primary,
            onRefresh:
                () async => ref.invalidate(
                  coachesBySessionTypeProvider(sessionType.firestoreKey),
                ),
            child: CustomScrollView(
              slivers: [
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
                  sliver: SliverToBoxAdapter(
                    child: _SessionTypeHeader(sessionType: sessionType),
                  ),
                ),
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 100),
                  sliver: SliverGrid(
                    delegate: SliverChildBuilderDelegate(
                      (context, i) => CoachCard(
                        coach: coaches[i],
                        sessionTypeKey: sessionType.firestoreKey,
                        onTap:
                            () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder:
                                    (_) => CoachProfileScreen(
                                      coach: coaches[i],
                                      sessionType: sessionType,
                                    ),
                              ),
                            ),
                      ),
                      childCount: coaches.length,
                    ),
                    gridDelegate:
                        const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          crossAxisSpacing: 12,
                          mainAxisSpacing: 12,
                          childAspectRatio: 0.72,
                        ),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _SessionTypeHeader extends StatelessWidget {
  final SessionType sessionType;
  const _SessionTypeHeader({required this.sessionType});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppColors.primary.withOpacity(0.12),
            AppColors.primary.withOpacity(0.04),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.primary.withOpacity(0.15)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(sessionType.icon, color: AppColors.primary, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  sessionType.label,
                  style: AppTextStyles.titleSmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  sessionType.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontSize: 11,
                    height: 1.4,
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

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.people_outline_rounded,
              size: 64,
              color: AppColors.getTextSecondary(context).withOpacity(0.4),
            ),
            const SizedBox(height: 16),
            Text(
              'No counselors available yet',
              style: AppTextStyles.titleMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              'We\'re onboarding counselors for this session type. Check back soon.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final String message;
  const _ErrorState({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline_rounded, size: 48, color: AppColors.error),
            const SizedBox(height: 12),
            Text('Something went wrong', style: AppTextStyles.titleSmall),
            const SizedBox(height: 6),
            Text(
              message,
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

// ── Skeleton loader ──────────────────────────────────────────────────────────

class _CoachListSkeleton extends StatelessWidget {
  const _CoachListSkeleton();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: GridView.builder(
        itemCount: 4,
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 12,
          mainAxisSpacing: 12,
          childAspectRatio: 0.72,
        ),
        itemBuilder: (_, __) => _SkeletonCard(),
      ),
    );
  }
}

class _SkeletonCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Flexible(
            flex: 3,
            child: Container(
              decoration: BoxDecoration(
                color: AppColors.getTextSecondary(context).withOpacity(0.1),
                borderRadius: const BorderRadius.vertical(
                  top: Radius.circular(16),
                ),
              ),
            ),
          ),
          Flexible(
            flex: 2,
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    height: 12,
                    width: 100,
                    color: AppColors.getTextSecondary(context).withOpacity(0.1),
                  ),
                  const SizedBox(height: 6),
                  Container(
                    height: 10,
                    width: 70,
                    color: AppColors.getTextSecondary(
                      context,
                    ).withOpacity(0.08),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
