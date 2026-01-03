import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/auth/auth_providers.dart';
import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';

import '../../data/stories_repository.dart';
import '../../domain/story.dart';

final storiesListProvider = FutureProvider<List<Story>>((ref) async {
  final authAsync = ref.watch(authStateProvider);
  final isSignedIn = authAsync.maybeWhen(
    data: (a) => a.isSignedIn,
    orElse: () => false,
  );

  final limit = isSignedIn ? 20 : 4;
  return ref.read(storiesRepositoryProvider).fetchStories(limit: limit);
});

class StoriesScreen extends ConsumerWidget {
  const StoriesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final asyncStories = ref.watch(storiesListProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Stories')),
      body: asyncStories.when(
        data: (stories) {
          if (stories.isEmpty) {
            return const Center(child: Text('No stories yet'));
          }
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: stories.length,
            separatorBuilder: (_, __) => const SizedBox(height: 12),
            itemBuilder:
                (context, i) => _StoryCard(
                  story: stories[i],
                  onTap:
                      () => Navigator.of(
                        context,
                      ).pushNamed('/story/${stories[i].id}'),
                  onSave: () {
                    GuestGuard.requireSignedIn(
                      context,
                      ref,
                      title: 'Create an account to save stories',
                      message:
                          'You\'re currently in guest mode. Create an account to save stories and track progress.',
                      primaryText: 'Create an account',
                      onCreateAccount:
                          () => Navigator.of(context).pushNamed('/signup'),
                      onAllowed: () async {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(content: Text('Saved (TODO)')),
                        );
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

class _StoryCard extends StatelessWidget {
  final Story story;
  final VoidCallback onTap;
  final VoidCallback onSave;

  const _StoryCard({
    required this.story,
    required this.onTap,
    required this.onSave,
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
                    story.title,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    story.summary,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
            IconButton(
              icon: const Icon(Icons.bookmark_border),
              onPressed: onSave,
            ),
          ],
        ),
      ),
    );
  }
}
