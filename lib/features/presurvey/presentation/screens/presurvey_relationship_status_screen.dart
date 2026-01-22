import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/auth/auth_providers.dart';
import '../../../../core/bootstrap/bootstrap_gate.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/session/guest_session_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/user/current_user_doc_provider.dart';
import '../../../guest/guest_entry_gate.dart';
import 'presurvey_gender_screen.dart';

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

/// Normalize v1 gender values ("Male"/"Female") to v2 format ("male"/"female")
String? _normalizeGender(String? gender) {
  if (gender == null) return null;
  final normalized = gender.trim().toLowerCase();
  if (normalized == 'male' || normalized == 'female') return normalized;
  return null;
}

Future<void> _persistPresurveyForV1User({
  required String uid,
  required String normalizedGender,
  required RelationshipStatus relationshipStatus,
}) async {
  final relKey = _relationshipStatusToKey(relationshipStatus);

  final payload = <String, dynamic>{
    // Normalize v1 gender if needed (will be merge-safe, won't overwrite if already lowercase)
    'gender': normalizedGender,
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

class PresurveyRelationshipStatusScreen extends ConsumerWidget {
  const PresurveyRelationshipStatusScreen({super.key});

  Future<void> _selectStatus(
    BuildContext context,
    WidgetRef ref,
    RelationshipStatus status,
  ) async {
    await ref.read(guestSessionProvider.notifier).setRelationshipStatus(status);

    if (!context.mounted) return;

    // Check if user is signed in (v1 user)
    final authAsync = ref.read(authStateProvider);
    final signedInUid = authAsync.maybeWhen(
      data: (a) => a.user?.uid,
      orElse: () => null,
    );

    // If signed in, check if they already have gender (v1 users do)
    if (signedInUid != null) {
      final docAsync = ref.read(currentUserDocProvider);
      final doc = docAsync.maybeWhen(data: (d) => d, orElse: () => null);

      final existingGender = doc?['gender']?.toString();
      final normalizedGender = _normalizeGender(existingGender);

      if (normalizedGender != null) {
        // V1 user with existing gender - save presurvey and go to home
        try {
          await _persistPresurveyForV1User(
            uid: signedInUid,
            normalizedGender: normalizedGender,
            relationshipStatus: status,
          );

          if (!context.mounted) return;

          Navigator.pushAndRemoveUntil(
            context,
            MaterialPageRoute(
              builder: (_) => const GuestEntryGate(child: BootstrapGate()),
            ),
            (_) => false,
          );
          return;
        } catch (e) {
          if (!context.mounted) return;
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}')));
          return;
        }
      }
    }

    // New user (v2) or v1 user without gender - go to gender selection
    if (context.mounted) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => const PresurveyGenderScreen()),
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final guest = ref.watch(guestSessionProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text('Relationship Status', style: AppTextStyles.headlineLarge),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'What is your relationship status?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 22),

              _OptionButton(
                label: 'Never Married',
                selected:
                    guest?.relationshipStatus ==
                    RelationshipStatus.singleNeverMarried,
                onTap:
                    () => _selectStatus(
                      context,
                      ref,
                      RelationshipStatus.singleNeverMarried,
                    ),
              ),
              const SizedBox(height: 12),

              _OptionButton(
                label: 'Married',
                selected:
                    guest?.relationshipStatus == RelationshipStatus.married,
                onTap:
                    () =>
                        _selectStatus(context, ref, RelationshipStatus.married),
              ),
              const SizedBox(height: 12),

              _OptionButton(
                label: 'Divorced',
                selected:
                    guest?.relationshipStatus == RelationshipStatus.divorced,
                onTap:
                    () => _selectStatus(
                      context,
                      ref,
                      RelationshipStatus.divorced,
                    ),
              ),
              const SizedBox(height: 12),

              _OptionButton(
                label: 'Widowed',
                selected:
                    guest?.relationshipStatus == RelationshipStatus.widowed,
                onTap:
                    () =>
                        _selectStatus(context, ref, RelationshipStatus.widowed),
              ),
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
        height: 56,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: selected ? AppColors.primary : AppColors.border,
            width: 1.2,
          ),
        ),
        child: Text(label, style: AppTextStyles.labelLarge),
      ),
    );
  }
}
