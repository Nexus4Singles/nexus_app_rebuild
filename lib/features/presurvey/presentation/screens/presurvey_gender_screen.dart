import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/session/guest_session_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../guest/guest_entry_gate.dart';
import '../../../../core/bootstrap/bootstrap_gate.dart';
import '../../../launch/presentation/app_launch_gate.dart';
import '../../../auth/presentation/screens/signup_screen.dart';
import 'presurvey_relationship_status_screen.dart';

String _relationshipStatusToKey(RelationshipStatus status) {
  switch (status) {
    case RelationshipStatus.singleNeverMarried:
      return 'single_never_married';
    case RelationshipStatus.married:
      return 'married';
    case RelationshipStatus.divorced:
      return 'divorced';
    case RelationshipStatus.widowed:
      return 'widowed';
  }
}

Future<void> _persistPresurveyForSignedInUser({
  required String uid,
  required String gender,
  required RelationshipStatus relationshipStatus,
}) async {
  final relKey = _relationshipStatusToKey(relationshipStatus);

  final payload = <String, dynamic>{
    'gender': gender.trim(),
    'nexus': {
      'relationshipStatus': relKey,
      'onboarding': {
        'presurveyCompleted': true,
        'presurveyCompletedAt': FieldValue.serverTimestamp(),
        'version': 2,
      },
    },
    // Temporary mirror for older codepaths (safe to remove later).
    'nexus2': {'relationshipStatus': relKey},
    'updatedAt': FieldValue.serverTimestamp(),
  };

  await FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .set(payload, SetOptions(merge: true));
}

class PresurveyGenderScreen extends ConsumerWidget {
  const PresurveyGenderScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guest = ref.watch(guestSessionProvider);

    final authAsync = ref.watch(authStateProvider);
    final signedInUid = authAsync.maybeWhen(
      data: (a) => a.user?.uid,
      orElse: () => null,
    );
    // Hard guard: relationship status MUST be selected before gender.
    // This protects all entry points (nav bar gates, deep links, back stack oddities).
    if (guest?.relationshipStatus == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!context.mounted) return;
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (_) => const PresurveyRelationshipStatusScreen(),
          ),
        );
      });
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        foregroundColor: AppColors.textPrimary,
        centerTitle: true,
        title: Text('Gender', style: AppTextStyles.headlineLarge),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(
                child: Text(
                  'What is your gender?',
                  style: AppTextStyles.headlineLarge.copyWith(fontSize: 26),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 10),
              Center(
                child: Text(
                  'This helps us personalize your experience.',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
              ),
              const SizedBox(height: 28),

              _OptionButton(
                label: 'Male',
                selected: guest?.gender == 'male',
                onTap: () async {
                  await ref
                      .read(guestSessionProvider.notifier)
                      .setGender('male');
                },
              ),
              const SizedBox(height: 12),
              _OptionButton(
                label: 'Female',
                selected: guest?.gender == 'female',
                onTap: () async {
                  await ref
                      .read(guestSessionProvider.notifier)
                      .setGender('female');
                },
              ),

              const Spacer(),
              const SizedBox(height: 22),

              if (signedInUid != null) ...[
                SizedBox(
                  height: 54,
                  child: ElevatedButton(
                    onPressed: () async {
                      final g = guest?.gender;
                      final rel = guest?.relationshipStatus;

                      if (g == null || g.toString().trim().isEmpty) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Please select your gender'),
                          ),
                        );
                        return;
                      }

                      if (rel == null) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text(
                              'Please select your relationship status',
                            ),
                          ),
                        );
                        return;
                      }

                      await _persistPresurveyForSignedInUser(
                        uid: signedInUid,
                        gender: g,
                        relationshipStatus: rel,
                      );

                      if (!context.mounted) return;

                      Navigator.pushAndRemoveUntil(
                        context,
                        MaterialPageRoute(
                          builder:
                              (_) =>
                                  const GuestEntryGate(child: BootstrapGate()),
                        ),
                        (_) => false,
                      );
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                    ),
                    child: Text(
                      'Continue',
                      style: AppTextStyles.labelLarge.copyWith(
                        color: Colors.white,
                      ),
                    ),
                  ),
                ),
              ] else ...[
                Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SizedBox(
                      height: 54,
                      child: ElevatedButton(
                        onPressed: () {
                          final g = guest?.gender;
                          if (g == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select your gender'),
                              ),
                            );
                            return;
                          }

                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const SignupScreen(),
                            ),
                          );
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                        child: Text(
                          'Create Account',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: Colors.white,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      height: 54,
                      child: OutlinedButton(
                        onPressed: () {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) => const AppLaunchGate(),
                            ),
                          );
                        },
                        style: OutlinedButton.styleFrom(
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                          ),
                          side: BorderSide(color: AppColors.border),
                        ),
                        child: Text('Log In', style: AppTextStyles.labelLarge),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Center(
                      child: TextButton(
                        onPressed: () {
                          final g = guest?.gender;
                          if (g == null) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Please select your gender'),
                              ),
                            );
                            return;
                          }

                          Navigator.pushAndRemoveUntil(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => const GuestEntryGate(
                                    child: BootstrapGate(),
                                  ),
                            ),
                            (_) => false,
                          );
                        },
                        child: Text(
                          'Continue as Guest',
                          style: AppTextStyles.labelLarge.copyWith(
                            color: AppColors.textMuted,
                            decoration: TextDecoration.underline,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

class _OptionButton extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _OptionButton({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: selected ? 1.6 : 1.1,
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.bodyLarge.copyWith(fontWeight: FontWeight.w600),
        ),
      ),
    );
  }
}
