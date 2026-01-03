import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';

class JourneySessionScreen extends ConsumerWidget {
  final String journeyId;
  final int sessionNumber;

  const JourneySessionScreen({
    super.key,
    required this.journeyId,
    required this.sessionNumber,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Session')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Journey: $journeyId',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 8),
            Text(
              'Session $sessionNumber',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            const Text('Session screen (Phase 3: content + completion)'),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  if (sessionNumber <= 1) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(content: Text('Completed (TODO)')),
                    );
                    return;
                  }

                  // Guest restriction: session > 1 requires account.
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
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Completed (TODO)')),
                      );
                    },
                  );
                },
                child: Text(
                  sessionNumber <= 1
                      ? 'Complete session'
                      : 'Complete (requires account)',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
