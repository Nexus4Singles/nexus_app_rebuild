import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/config_loader_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/session/effective_relationship_status_provider.dart';
import '../../../../core/router/app_routes.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(effectiveRelationshipStatusProvider) ??
        RelationshipStatus.singleNeverMarried;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Challenges'),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
      ),
      body: FutureBuilder(
        future: ConfigLoaderService().getJourneyCatalogForStatus(status),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return _ErrorState(
              message: 'Unable to load challenges.',
              onRetry: () => (context as Element).markNeedsBuild(),
            );
          }

          final catalog = snapshot.data!;
          final products = catalog.products;

          final featured = const [];
          final all = products;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Text(
                'Pick an area to grow in',
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Each challenge is session-based. Session 1 is free — unlock the rest when you’re ready.',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                  height: 1.35,
                ),
              ),

              const SizedBox(height: 18),

              if (featured.isNotEmpty) ...[
                _SectionHeader(title: 'Featured'),
                const SizedBox(height: 12),
                SizedBox(
                  height: 170,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: featured.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 12),
                    itemBuilder: (context, index) {
                      final p = featured[index];
                      return _ChallengeCard(
                        title: p.title,
                        subtitle: p.subtitle,
                        badge: p.tier.toUpperCase(),
                        onTap:
                            () => Navigator.pushNamed(
                              context,
                              Uri(
                                path: AppRoutes.journeyDetail.replaceFirst(
                                  ':id',
                                  p.productId,
                                ),
                              ).toString(),
                            ),
                      );
                    },
                  ),
                ),
                const SizedBox(height: 18),
              ],

              _SectionHeader(title: 'All Challenges'),
              const SizedBox(height: 12),

              ...all.map(
                (p) => Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ChallengeListTile(
                    title: p.title,
                    subtitle: p.subtitle,
                    pill: p.tier.toUpperCase(),
                    sessionsCount: p.sessions.length,
                    onTap:
                        () => Navigator.pushNamed(
                          context,
                          Uri(
                            path: AppRoutes.journeyDetail.replaceFirst(
                              ':id',
                              p.productId,
                            ),
                          ).toString(),
                        ),
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  final String title;
  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w900,
          ),
        ),
      ],
    );
  }
}

class _ChallengeCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String badge;
  final VoidCallback onTap;

  const _ChallengeCard({
    required this.title,
    required this.subtitle,
    required this.badge,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(20),
      child: Container(
        width: 260,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: AppColors.border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 18,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _Pill(
              label: badge,
              icon: Icons.bolt_outlined,
              backgroundColor: AppColors.primary.withOpacity(0.10),
              textColor: AppColors.primary,
            ),
            const Spacer(),
            Text(
              title,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 6),
            if (subtitle.trim().isNotEmpty)
              Text(
                subtitle,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                  height: 1.3,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _ChallengeListTile extends StatelessWidget {
  final String title;
  final String subtitle;
  final String pill;
  final int sessionsCount;
  final VoidCallback onTap;

  const _ChallengeListTile({
    required this.title,
    required this.subtitle,
    required this.pill,
    required this.sessionsCount,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.10),
                borderRadius: BorderRadius.circular(14),
              ),
              child: const Icon(Icons.fitness_center, color: AppColors.primary),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  const SizedBox(height: 4),
                  if (subtitle.trim().isNotEmpty)
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      _Pill(
                        label: pill,
                        icon: Icons.bolt_outlined,
                        backgroundColor: AppColors.border.withOpacity(0.45),
                        textColor: AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      _Pill(
                        label: '$sessionsCount sessions',
                        icon: Icons.play_circle_outline,
                        backgroundColor: AppColors.border.withOpacity(0.45),
                        textColor: AppColors.textMuted,
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const Icon(Icons.chevron_right, color: AppColors.textMuted),
          ],
        ),
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color backgroundColor;
  final Color textColor;

  const _Pill({
    required this.label,
    required this.icon,
    required this.backgroundColor,
    required this.textColor,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 7),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: textColor),
          const SizedBox(width: 6),
          Text(
            label,
            style: AppTextStyles.labelSmall.copyWith(
              color: textColor,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
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
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 56,
              color: AppColors.textMuted,
            ),
            const SizedBox(height: 12),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}
