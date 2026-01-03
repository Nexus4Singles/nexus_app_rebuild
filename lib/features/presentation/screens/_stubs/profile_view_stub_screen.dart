import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';

class ProfileViewStubScreen extends ConsumerWidget {
  final String userId;

  const ProfileViewStubScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Profile')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Profile View (stub): $userId'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                GuestGuard.requireSignedIn(
                  context,
                  ref,
                  title: 'Create an account',
                  message:
                      'You\'re currently in guest mode. Create an account to access your profile and settings.',
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
