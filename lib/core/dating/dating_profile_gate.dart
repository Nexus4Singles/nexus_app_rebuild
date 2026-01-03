import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
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

    // For singles, enforce sign-in first.
    final statusAsync = ref.read(datingProfileStatusProvider);
    final status = statusAsync.maybeWhen(
      data: (s) => s,
      orElse: () => DatingProfileStatus.none,
    );

    if (status == DatingProfileStatus.none) {
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
                  Navigator.of(context).pushNamed('/dating-profile/complete');
                },
                child: const Text('Complete profile'),
              ),
            ],
          ),
    );
  }
}
