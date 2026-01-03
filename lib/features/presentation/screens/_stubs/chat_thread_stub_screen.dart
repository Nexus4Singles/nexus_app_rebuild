import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';

class ChatThreadStubScreen extends ConsumerWidget {
  final String chatId;

  const ChatThreadStubScreen({super.key, required this.chatId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text('Chat Thread (stub): $chatId'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () {
                GuestGuard.requireSignedIn(
                  context,
                  ref,
                  title: 'Create an account to chat',
                  message:
                      'You\'re currently in guest mode. Create an account to send messages and chat.',
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
