import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../auth/auth_providers.dart';
import '../bootstrap/firebase_ready_provider.dart';
import '../user/dating_opt_in_provider.dart';
import '../user/is_admin_provider.dart';
import '../user/current_user_doc_provider.dart';
import '../session/effective_relationship_status_provider.dart';
import '../widgets/guest_guard.dart';
import 'dating_profile_status_provider.dart';
import 'dating_profile_exists_provider.dart';
import 'dating_verification_status_provider.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';

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

    // Admin bypass: Admins can access search and chat without profile verification
    final isAdminAsync = ref.read(isAdminProvider);
    final isAdmin = isAdminAsync.maybeWhen(
      data: (admin) => admin,
      orElse: () => false,
    );

    if (isAdmin) {
      print(
        '[DatingProfileGate] ✓ Admin user → bypassing dating profile requirements',
      );
      await onAllowed();
      return;
    }

    // If Firebase isn't ready yet, don't mis-classify signed-in users as guests.
    final ready = ref.read(firebaseReadyProvider);
    if (!ready) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text('Setting things up… try again shortly.'),
          backgroundColor: AppColors.primary,
        ),
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

    // Check if profile was rejected
    final verificationStatus = await ref.read(datingVerificationStatusProvider.future);
    if (!context.mounted) return;

    if (verificationStatus == 'rejected') {
      // Get the rejection reason from the user doc
      final userDocData = await ref.read(currentUserDocProvider.future);
      if (!context.mounted) return;
      final dating = (userDocData?['dating'] as Map?)?.cast<String, dynamic>();
      final rejectionReason =
          dating?['rejectionReason']?.toString() ??
          'Your profile did not meet our requirements.';

      await showDialog<void>(
        context: context,
        builder:
            (_) => AlertDialog(
              title: const Text('Profile Rejected'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Your dating profile was not approved after admin review.',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Reason:',
                      style: TextStyle(fontWeight: FontWeight.w500),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      rejectionReason,
                      style: const TextStyle(fontStyle: FontStyle.italic),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'You can create a new dating profile to try again. Make sure to follow our community guidelines.',
                      style: TextStyle(fontSize: 12, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Go Back'),
                ),
                ElevatedButton(
                  onPressed: () {
                    Navigator.pop(context);
                    Navigator.of(context).pushNamed('/dating/setup/age');
                  },
                  child: const Text('Create New Profile'),
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

    // Check if profile exists at all (to give different message if they haven't created one)
    final profileExistsAsync = ref.read(datingProfileExistsProvider);
    final profileExists = profileExistsAsync.maybeWhen(
      data: (exists) => exists,
      orElse: () => false,
    );

    String title, message, buttonText;
    if (status == DatingProfileStatus.none && !profileExists) {
      // User hasn't created a dating profile yet
      title = 'Create Your Dating Profile';
      message =
          'To use this feature, you need to create a dating profile first. Start building your profile now!';
      buttonText = 'Create Profile';
    } else {
      // User has started a profile but it's incomplete
      title = 'Complete Your Profile';
      message =
          'You\'ve started your dating profile, but need to finish it before using this feature.';
      buttonText = 'Complete Profile';
    }

    await showDialog<void>(
      context: context,
      builder:
          (_) => AlertDialog(
            title: Text(title),
            content: Text(message),
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
                child: Text(buttonText),
              ),
            ],
          ),
    );
  }
}
