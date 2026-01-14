import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../challenges/providers/journeys_providers.dart';

class MyJourneyScreen extends ConsumerWidget {
  const MyJourneyScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final catalogAsync = ref.watch(journeyCatalogProvider);
    final bestStreakAsync = ref.watch(bestJourneysStreakProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('My Journey')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          _SummaryCard(bestStreakAsync: bestStreakAsync),
          const SizedBox(height: 16),
          const Text(
            'Your Programs',
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 8),
          catalogAsync.when(
            loading:
                () => const Padding(
                  padding: EdgeInsets.only(top: 24),
                  child: Center(child: CircularProgressIndicator()),
                ),
            error:
                (e, _) => _ErrorBlock(
                  message: 'Could not load your journeys.\n$e',
                  onRetry: () => ref.invalidate(journeyCatalogProvider),
                ),
            data: (catalog) {
              if (catalog.journeys.isEmpty) {
                return const _EmptyBlock(
                  title: 'No journeys yet',
                  message:
                      'Once you start Programs, you’ll see your progress here.',
                );
              }

              return Column(
                children: [
                  for (final j in catalog.journeys)
                    _JourneyProgressTile(journeyId: j.id),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _SummaryCard extends StatelessWidget {
  final AsyncValue<int> bestStreakAsync;
  const _SummaryCard({required this.bestStreakAsync});

  @override
  Widget build(BuildContext context) {
    final bestStreakText = bestStreakAsync.when(
      loading: () => '…',
      error: (_, __) => '—',
      data: (v) => '$v',
    );

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(14),
        child: Row(
          children: [
            const Icon(Icons.local_fire_department_outlined, size: 28),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    'Best streak',
                    style: TextStyle(fontWeight: FontWeight.w900),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    '$bestStreakText day(s)',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            TextButton(
              onPressed: () => Navigator.of(context).pushNamed('/challenges'),
              child: const Text('Browse'),
            ),
          ],
        ),
      ),
    );
  }
}

class _JourneyProgressTile extends ConsumerWidget {
  final String journeyId;
  const _JourneyProgressTile({required this.journeyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyByIdProvider(journeyId));
    final completedAsync = ref.watch(completedMissionIdsProvider(journeyId));
    final streakAsync = ref.watch(journeyStreakProvider(journeyId));

    final title = (journey == null) ? journeyId : (journey.title);
    final subtitle = 'Program';
    final completedCount = completedAsync.when(
      loading: () => null,
      error: (_, __) => null,
      data: (set) => set.length,
    );

    final streakCount = streakAsync.when(
      loading: () => null,
      error: (_, __) => null,
      data: (v) => v,
    );

    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: const Icon(Icons.flag_outlined),
        title: Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
        subtitle: Text(_buildSubtitle(subtitle, completedCount, streakCount)),
        trailing: const Icon(Icons.chevron_right),
        onTap: () => Navigator.of(context).pushNamed('/journey/$journeyId'),
      ),
    );
  }

  String _buildSubtitle(String base, int? completedCount, int? streakCount) {
    final parts = <String>[base];

    if (completedCount != null) {
      parts.add('$completedCount completed');
    }

    if (streakCount != null) {
      parts.add('streak: $streakCount');
    }

    return parts.join(' • ');
  }
}

class _EmptyBlock extends StatelessWidget {
  final String title;
  final String message;
  const _EmptyBlock({required this.title, required this.message});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.w900)),
          const SizedBox(height: 6),
          Text(message),
        ],
      ),
    );
  }
}

class _ErrorBlock extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;
  const _ErrorBlock({required this.message, required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Something went wrong',
            style: TextStyle(fontWeight: FontWeight.w900),
          ),
          const SizedBox(height: 6),
          Text(message),
          const SizedBox(height: 10),
          FilledButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}
