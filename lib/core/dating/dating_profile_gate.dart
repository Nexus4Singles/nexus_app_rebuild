import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../auth/auth_providers.dart';
import '../bootstrap/firebase_ready_provider.dart';
import '../user/dating_opt_in_provider.dart';
import '../session/effective_relationship_status_provider.dart';
import '../widgets/guest_guard.dart';
import 'dating_profile_status_provider.dart';

class DatingProfileGate {
  static Future<void> requireCompleteProfile(
    BuildContext context,
    WidgetRef ref, {
    required Future<void> Function() onAllowed,
  }) async {
    final rel = ref.read(effectiveRelationshipStatusProvider);

    // Married users have no dating profile gating.
    if (rel == RelationshipStatus.married) {
      await onAllowed();
      return;
    }

    // First enforce sign-in explicitly (do NOT infer guest from profile status).
    final authAsync = ref.read(authStateProvider);
    final isSignedIn = authAsync.maybeWhen(
      data: (a) => a.isSignedIn,
      orElse: () => false,
    );

    if (!isSignedIn) {
      await GuestGuard.requireSignedIn(
        context,
        ref,
        title: 'Create an account to continue',
        message:
            'You\'re currently in guest mode. Create an account to access this feature.',
        primaryText: 'Create an account',
        onCreateAccount: () => Navigator.of(context).pushNamed('/signup'),
      );
      return;
    }

    // If Firebase isn't ready yet, don't mis-classify signed-in users as guests.
    final ready = ref.read(firebaseReadyProvider);
    if (!ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Setting things up… try again shortly.')),
      );
      return;
    }

    // Dating opt-in gate (default is true; only block when explicitly false).
    final optedIn = await ref.read(datingOptInProvider.future);
    if (!optedIn) {
      await showDialog<void>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Dating is turned off'),
              content: const Text(
                'To use Search and Chats, turn on the dating experience in your profile settings.',
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Not now'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushNamed('/profile');
                  },
                  child: const Text('Go to Profile'),
                ),
              ],
            ),
      );
      return;
    }

    // Dating profile completion gate
    final statusAsync = ref.read(datingProfileStatusProvider);
    final status = statusAsync.maybeWhen(
      data: (s) => s,
      orElse: () => DatingProfileStatus.incomplete,
    );

    if (status == DatingProfileStatus.complete) {
      await onAllowed();
      return;
    }

    await showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: const Text('Complete your profile'),
            content: const Text(
              'You need to complete your dating profile before using this feature.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('Not now'),
              ),
              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.of(context).pushNamed('/dating/setup/age');
                },
                child: const Text('Complete profile'),
              ),
            ],
          ),
    );
  }
}
