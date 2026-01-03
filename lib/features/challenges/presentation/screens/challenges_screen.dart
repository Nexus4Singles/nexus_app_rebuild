import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/auth/auth_providers.dart';
import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';

import '../../data/journeys_repository.dart';
import '../../domain/journey.dart';

final journeysListProvider = FutureProvider<List<Journey>>((ref) async {
  final authAsync = ref.watch(authStateProvider);
  final isSignedIn = authAsync.maybeWhen(
    data: (a) => a.isSignedIn,
    orElse: () => false,
  );

  // Guest: show limited list.
  final limit = isSignedIn ? 50 : 10;
  return ref.read(journeysRepositoryProvider).fetchJourneys(limit: limit);
});

class ChallengesScreen extends ConsumerWidget {
  const ChallengesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncJourneys = ref.watch(journeysListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Challenges')),
      body: asyncJourneys.when(
        data: (journeys) {
          if (journeys.isEmpty) {
            return const Center(child: Text('No journeys yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: journeys.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder:
                (context, i) => _JourneyCard(
                  journey: journeys[i],
                  onTap:
                      () => Navigator.of(
                        context,
                      ).pushNamed('/journey/${journeys[i].id}'),
                  onStart: () {
                    // Guest: allow preview session 1 only (Phase 2 will enforce deeper gating)
                    GuestGuard.requireSignedIn(
                      context,
                      ref,
                      title: 'Create an account to continue',
                      message:
                          'You\'re currently in guest mode. Create an account to access all sessions and track progress.',
                      primaryText: 'Create an account',
                      onCreateAccount:
                          () => Navigator.of(context).pushNamed('/signup'),
                      onAllowed: () async {
                        Navigator.of(
                          context,
                        ).pushNamed('/journey/${journeys[i].id}/session/1');
                      },
                    );
                  },
                ),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final Journey journey;
  final VoidCallback onTap;
  final VoidCallback onStart;

  const _JourneyCard({
    required this.journey,
    required this.onTap,
    required this.onStart,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: Theme.of(context).dividerColor),
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    journey.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    journey.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    '${journey.sessionCount} sessions',
                    style: Theme.of(context).textTheme.bodySmall,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 12),
            ElevatedButton(onPressed: onStart, child: const Text('Start')),
          ],
        ),
      ),
    );
  }
}
