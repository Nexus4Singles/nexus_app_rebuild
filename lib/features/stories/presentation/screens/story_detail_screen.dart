import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';

class StoryDetailScreen extends ConsumerWidget {
  final String storyId;

  const StoryDetailScreen({super.key, required this.storyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Story')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Story: $storyId',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text('Detail screen (Phase 2: fetch + render)'),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    () =>
                        Navigator.of(context).pushNamed('/story/$storyId/poll'),
                child: const Text('Open Poll'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () {
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
                child: const Text('Save Story'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
