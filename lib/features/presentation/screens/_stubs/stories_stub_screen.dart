import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';

class StoriesStubScreen extends ConsumerWidget {
  const StoriesStubScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Stories')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('Stories (stub)'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                GuestGuard.requireSignedIn(
                  context,
                  ref,
                  title: 'Create an account to continue',
                  message:
                      'You\'re currently in guest mode. Create an account to access stories features like saving and voting.',
                  primaryText: 'Create an account',
                  onCreateAccount:
                      () => Navigator.of(context).pushNamed('/signup'),
                  onAllowed: () async {},
                );
              },
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}
