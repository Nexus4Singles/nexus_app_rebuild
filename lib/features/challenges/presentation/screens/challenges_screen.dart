import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/guest_guard.dart';

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
        error:
            (_, __) => _ErrorState(
              message: 'Unable to load journeys.',
              onRetry: () => ref.invalidate(journeyCatalogProvider),
            ),
        data: (catalog) {
          final featured = _pickFeaturedJourneys(catalog.journeys, limit: 5);
          final featuredIds = featured.map((e) => e.id).toSet();
          final rest =
              catalog.journeys
                  .where((j) => !featuredIds.contains(j.id))
                  .toList();

          return CustomScrollView(
            slivers: [
              const SliverToBoxAdapter(
                child: Padding(
                  padding: EdgeInsets.fromLTRB(20, 14, 20, 8),
                  child: _PremiumHeader(),
                ),
              ),

              if (featured.isNotEmpty)
                SliverToBoxAdapter(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(20, 12, 0, 10),
                    child: _FeaturedHeroCarousel(featured: featured),
                  ),
                ),

              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
                  child: Row(
                    children: [
                      Text(
                        'All journeys',
                        style: AppTextStyles.titleMedium.copyWith(
                          fontWeight: FontWeight.w900,
                          letterSpacing: -0.2,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        '${rest.length}',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ],
                  ),
                ),
              ),

              SliverPadding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 28),
                sliver: SliverList.separated(
                  itemCount: rest.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 12),
                  itemBuilder:
                      (context, index) =>
                          _ClassyJourneyListCard(journey: rest[index]),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

class _PremiumHeader extends StatelessWidget {
  const _PremiumHeader();

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Grow with guided journeys',
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w900,
            letterSpacing: -0.35,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          'Short, practical activities that build consistency and strengthen love.',
          style: AppTextStyles.bodyMedium.copyWith(
            color: AppColors.textMuted,
            height: 1.35,
          ),
        ),
        const SizedBox(height: 12),
        Wrap(
          spacing: 10,
          runSpacing: 10,
          children: const [
            _TagChip(label: 'Faith'),
            _TagChip(label: 'Communication'),
            _TagChip(label: 'Healing'),
            _TagChip(label: 'Discernment'),
            _TagChip(label: 'Intimacy'),
            _TagChip(label: 'Boundaries'),
            _TagChip(label: 'Purpose'),
            _TagChip(label: 'Conflict'),
          ],
        ),
      ],
    );
  }
}

class _TagChip extends StatelessWidget {
  final String label;
  const _TagChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.08),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: AppColors.primary.withOpacity(0.22)),
      ),
      child: Text(
        label,
        style: AppTextStyles.bodySmall.copyWith(
          fontWeight: FontWeight.w900,
          color: AppColors.primary,
        ),
      ),
    );
  }
}

class _FeaturedHeroCarousel extends StatelessWidget {
  final List<JourneyV1> featured;
  const _FeaturedHeroCarousel({required this.featured});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(right: 20),
          child: Row(
            children: [
              Text(
                'Featured',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const Spacer(),
              Text(
                'Swipe',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 12),
        SizedBox(
          height: 150,
          child: ListView.separated(
            padding: const EdgeInsets.only(right: 20),
            scrollDirection: Axis.horizontal,
            itemCount: featured.length,
            separatorBuilder: (_, __) => const SizedBox(width: 14),
            itemBuilder:
                (context, index) => _FeaturedHeroCard(journey: featured[index]),
          ),
        ),
      ],
    );
  }
}

class _FeaturedHeroCard extends ConsumerWidget {
  final JourneyV1 journey;
  const _FeaturedHeroCard({required this.journey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tint = AppColors.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(22),
      onTap: () => _openDetail(context, ref, journey.id),
      child: Container(
        width: 280,
        height: 150,
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(22),
          color: tint.withOpacity(0.78),
          boxShadow: [
            BoxShadow(
              color: tint.withOpacity(0.20),
              blurRadius: 22,
              offset: const Offset(0, 14),
            ),
          ],
        ),
        child: Stack(
          children: [
            Column(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [_HeroIcon(iconKey: journey.icon), const Spacer()],
                ),

                Expanded(
                  child: Text(
                    journey.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.w900,
                      color: Colors.white,
                      height: 1.12,
                      letterSpacing: -0.2,
                    ),
                  ),
                ),

                const Align(
                  alignment: Alignment.centerRight,
                  child: _GlassPill(text: 'Start'),
                ),
              ],
            ),

            Positioned(
              top: 0,
              right: 0,
              child: _ThemePill(tag: journey.themeTag),
            ),
          ],
        ),
      ),
    );
  }
}

class _HeroIcon extends StatelessWidget {
  final String iconKey;
  const _HeroIcon({required this.iconKey});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.primary.withOpacity(0.22)),
      ),
      child: Icon(iconFromKey(iconKey), color: AppColors.primary, size: 22),
    );
  }
}

class _GlassPill extends StatelessWidget {
  final String text;
  const _GlassPill({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.16),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: Colors.white.withOpacity(0.24)),
      ),
      child: Text(
        text,
        style: AppTextStyles.bodySmall.copyWith(
          fontWeight: FontWeight.w900,
          color: Colors.white,
        ),
      ),
    );
  }
}

class _ClassyJourneyListCard extends ConsumerWidget {
  final JourneyV1 journey;
  const _ClassyJourneyListCard({required this.journey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tint = AppColors.primary;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: () => _openDetail(context, ref, journey.id),
      child: Container(
        padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.primary.withOpacity(0.22)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.035),
              blurRadius: 18,
              offset: const Offset(0, 12),
            ),
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: tint.withOpacity(0.12),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: tint.withOpacity(0.22)),
              ),
              child: Icon(
                iconFromKey(_iconKeyForJourney(journey)),
                color: tint,
                size: 20,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                journey.title,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: AppTextStyles.bodyMedium.copyWith(
                  fontWeight: FontWeight.w900,
                  height: 1.15,
                  letterSpacing: -0.15,
                ),
              ),
            ),
            const SizedBox(width: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
              decoration: BoxDecoration(
                color: tint.withOpacity(0.10),
                borderRadius: BorderRadius.circular(999),
                border: Border.all(color: tint.withOpacity(0.22)),
              ),
              child: Text(
                'Start',
                style: AppTextStyles.bodySmall.copyWith(
                  fontWeight: FontWeight.w900,
                  color: tint.withOpacity(0.95),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ThemePill extends StatelessWidget {
  final String? tag;
  const _ThemePill({required this.tag});

  @override
  Widget build(BuildContext context) {
    final t = (tag ?? '').trim();
    if (t.isEmpty) return const SizedBox.shrink();

    return ConstrainedBox(
      constraints: const BoxConstraints(maxWidth: 120),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.20),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white.withOpacity(0.24)),
        ),
        child: Text(
          _prettyTag(t),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w900,
            color: Colors.white,
            letterSpacing: -0.2,
          ),
        ),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(message, style: AppTextStyles.bodyLarge),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: onRetry, child: const Text('Retry')),
          ],
        ),
      ),
    );
  }
}

void _openDetail(BuildContext context, WidgetRef ref, String journeyId) {
  GuestGuard.requireSignedIn(
    context,
    ref,
    title: 'Sign in required',
    message: 'Create an account to start a Journey and track your progress.',
    primaryText: 'Continue',
    onCreateAccount: () {
      Navigator.of(context).pushNamed(AppRoutes.login);
    },
    onAllowed: () async {
      Navigator.of(context).pushNamed('/journey/$journeyId');
    },
  );
}

String _iconKeyForJourney(JourneyV1 journey) {
  final k = journey.accentIcon;
  if (k != null && k.trim().isNotEmpty) return k;
  return journey.icon;
}

List<JourneyV1> _pickFeaturedJourneys(
  List<JourneyV1> journeys, {
  int limit = 5,
}) {
  final sorted = [...journeys];
  sorted.sort((a, b) => a.priorityRank.compareTo(b.priorityRank));
  return sorted.take(limit).toList();
}

String _prettyTag(String t) {
  final s = t.trim();
  if (s.isEmpty) return '';
  return s[0].toUpperCase() + s.substring(1);
}
