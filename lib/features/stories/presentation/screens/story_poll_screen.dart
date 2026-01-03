import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';

class StoryPollScreen extends ConsumerWidget {
  final String storyId;

  const StoryPollScreen({super.key, required this.storyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Poll')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Poll for story: $storyId',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 12),
            const Text('Poll screen (Phase 3: fetch poll + vote)'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  GuestGuard.requireSignedIn(
                    context,
                    ref,
                    title: 'Create an account to vote',
                    message:
                        'You\'re currently in guest mode. Create an account to vote in polls.',
                    primaryText: 'Create an account',
                    onCreateAccount:
                        () => Navigator.of(context).pushNamed('/signup'),
                    onAllowed: () async {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Voted (TODO)')),
                      );
                    },
                  );
                },
                child: const Text('Vote (stub)'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
