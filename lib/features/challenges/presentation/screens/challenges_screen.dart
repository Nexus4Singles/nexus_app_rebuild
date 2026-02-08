import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/widgets/guest_guard.dart';

import '../../../../core/router/app_routes.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/ui/icon_mapper.dart';
import '../../../../core/providers/user_provider.dart';
import '../../domain/journey_v1_models.dart';
import '../../providers/journeys_providers.dart';

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(journeyCatalogProvider);
    final userAsync = ref.watch(currentUserProvider);
    String? userGender = userAsync.maybeWhen(
      data: (user) => user?.gender,
      orElse: () => null,
    );

    return Scaffold(
      backgroundColor: Theme.of(context).scaffoldBackgroundColor,
      appBar: AppBar(
        backgroundColor: Theme.of(context).scaffoldBackgroundColor,
        elevation: 0,
        title: Text(
          'Journeys',
          style: Theme.of(
            context,
          ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
        ),
        centerTitle: true,
      ),
      body: catalogAsync.when(
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.error_outline,
                    size: 48,
                    color: Theme.of(context).colorScheme.error,
                  ),
                  const SizedBox(height: 16),
                  const Text('Unable to load journeys'),
                  const SizedBox(height: 24),
                  SizedBox(
                    width: 120,
                    child: ElevatedButton.icon(
                      onPressed: () {
                        ref.invalidate(journeyCatalogProvider);
                      },
                      icon: const Icon(Icons.refresh, size: 18),
                      label: const Text('Retry'),
                    ),
                  ),
                ],
              ),
            ),
        data: (catalog) {
          var journeys = catalog.journeys;
          // Filter gender-specific journeys
          journeys =
              journeys.where((j) {
                if (j.id == 'singles_biblical_femininity' &&
                    userGender == 'male')
                  return false;
                if (j.id == 'singles_biblical_masculinity' &&
                    userGender == 'female')
                  return false;
                return true;
              }).toList();
          final featured =
              journeys
                  .where((j) => [1, 3, 9, 19, 20].contains(j.priorityRank))
                  .toList();
          return ListView(
            padding: const EdgeInsets.all(20),
            children: [
              // Intro Card
              Padding(
                padding: const EdgeInsets.only(
                  top: 8.0,
                  bottom: 14.0,
                ), // Card closer to header
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 10,
                  ),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    borderRadius: BorderRadius.circular(14),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.black.withOpacity(0.05),
                        blurRadius: 10,
                        offset: const Offset(0, 2),
                      ),
                    ],
                    border: Border.all(
                      color: Theme.of(context).colorScheme.primary.withOpacity(
                        0.22,
                      ), // More visible border
                      width: 1.4,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.center,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.emoji_events_rounded,
                            size: 22,
                            color: AppColors.warning,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Welcome to Journeys',
                            style: Theme.of(
                              context,
                            ).textTheme.titleMedium?.copyWith(
                              fontWeight: FontWeight.w700,
                              fontSize: 16,
                              color: Theme.of(context).colorScheme.onSurface,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Journeys are guided experiences designed to help you grow in key areas of life, relationships & marriage. Each journey is crafted to bring real transformation, one step at a time. Start a journey today and unlock your best self!',
                        textAlign: TextAlign.center,
                        style: Theme.of(context).textTheme.bodySmall?.copyWith(
                          color: Theme.of(
                            context,
                          ).colorScheme.onSurface.withOpacity(0.80),
                          fontSize: 13,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(
                height: 10,
              ), // Featured Journeys closer to welcome card
              // Featured Journeys Carousel
              if (featured.isNotEmpty) ...[
                Row(
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    Icon(
                      Icons.flag,
                      size: 18,
                      color: Theme.of(context).colorScheme.primary,
                    ),
                    const SizedBox(width: 8),
                    Text(
                      'FEATURED JOURNEYS',
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
                SizedBox(
                  height: 100,
                  child: ListView.separated(
                    scrollDirection: Axis.horizontal,
                    itemCount: featured.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 16),
                    itemBuilder: (context, i) {
                      final journey = featured[i];
                      return _FeaturedJourneyCard(journey: journey);
                    },
                  ),
                ),
                const SizedBox(height: 18),
              ],
              // All Journeys List
              Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Icon(
                    Icons.list,
                    size: 18,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  const SizedBox(width: 8),
                  Text(
                    'ALL JOURNEYS',
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
              ...journeys.map((j) => _JourneyListCard(journey: j)).toList(),
            ],
          );
        },
      ),
    );
  }
}

class _FeaturedJourneyCard extends StatelessWidget {
  final JourneyV1 journey;
  const _FeaturedJourneyCard({required this.journey});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primary = Theme.of(context).colorScheme.primary;
    final onPrimary = Theme.of(context).colorScheme.onPrimary;
    final overlayColor =
        isDark ? primary.withOpacity(0.90) : primary.withOpacity(0.93);
    final textColor =
        isDark ? onPrimary.withOpacity(0.97) : onPrimary.withOpacity(0.97);
    final iconColor = textColor;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => Navigator.of(context).pushNamed('/journey/${journey.id}'),
      child: Container(
        width: 220,
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: overlayColor,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.07),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                Icon(Icons.flag, color: iconColor, size: 16),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    journey.title,
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      fontWeight: FontWeight.w700,
                      color: textColor,
                      fontSize: 12,
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12), // Reduced spacing to prevent overflow
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 3,
                  ),
                  decoration: BoxDecoration(
                    color: textColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(
                      color: iconColor.withOpacity(0.18),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.splitscreen, size: 14, color: iconColor),
                      const SizedBox(width: 5),
                      Text(
                        '${journey.missions.length} activities',
                        style: Theme.of(context).textTheme.labelSmall?.copyWith(
                          color: iconColor,
                          fontWeight: FontWeight.w700,
                          fontSize: 12,
                          letterSpacing: 0.12,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                SizedBox(
                  width: 54,
                  height: 26,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: textColor,
                      foregroundColor: primary,
                      padding: EdgeInsets.zero,
                      shape: StadiumBorder(),
                      elevation: 0,
                      textStyle: const TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).pushNamed('/journey/${journey.id}'),
                    child: const Text('Start'),
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

class _JourneyListCard extends StatelessWidget {
  final JourneyV1 journey;
  const _JourneyListCard({required this.journey});

  @override
  Widget build(BuildContext context) {
    final accent = Theme.of(context).colorScheme.primary;
    final isDark = Theme.of(context).brightness == Brightness.dark;
    // Dynamic tag background: higher opacity in dark mode for better contrast
    final tagBg = isDark ? accent.withOpacity(0.18) : accent.withOpacity(0.13);
    final tagBorder =
        isDark ? accent.withOpacity(0.30) : accent.withOpacity(0.20);

    return InkWell(
      borderRadius: BorderRadius.circular(12),
      onTap: () => Navigator.of(context).pushNamed('/journey/${journey.id}'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: Theme.of(context).colorScheme.surface,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: accent.withOpacity(0.13), width: 1.2),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.06),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        clipBehavior: Clip.hardEdge,
        child: Row(
          children: [
            Icon(Icons.flag, color: accent, size: 15),
            const SizedBox(width: 8),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    journey.title,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                      fontSize: 14, // Reduced from default (usually 16)
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    journey.subtitle,
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: Theme.of(
                        context,
                      ).colorScheme.onSurface.withOpacity(0.82),
                    ),
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 5),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: tagBg,
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: tagBorder, width: 0.75),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.splitscreen, size: 13, color: accent),
                            const SizedBox(width: 4),
                            Text(
                              '${journey.missions.length} activities',
                              style: Theme.of(
                                context,
                              ).textTheme.labelSmall?.copyWith(
                                color: accent,
                                fontWeight: FontWeight.w700,
                                fontSize: 11,
                                letterSpacing: 0.10,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Spacer(),
                      SizedBox(
                        width: 56,
                        height: 26,
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: accent,
                            foregroundColor:
                                Theme.of(context).colorScheme.onPrimary,
                            padding: EdgeInsets.zero,
                            shape: StadiumBorder(),
                            elevation: 0,
                            textStyle: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                          onPressed:
                              () => Navigator.of(
                                context,
                              ).pushNamed('/journey/${journey.id}'),
                          child: const Text('Start'),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
