import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../guest/guest_entry_gate.dart';
import '../../../../core/bootstrap/bootstrap_gate.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/session/guest_session_provider.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../presentation/screens/_stubs/login_stub_screen.dart';
import '../../../presentation/screens/_stubs/signup_stub_screen.dart';

class PresurveyGoalsScreen extends ConsumerStatefulWidget {
  final RelationshipStatus relationshipStatus;
  final String gender; // kept for future use, but goals are based on status

  const PresurveyGoalsScreen({
    super.key,
    required this.relationshipStatus,
    required this.gender,
  });

  @override
  ConsumerState<PresurveyGoalsScreen> createState() =>
      _PresurveyGoalsScreenState();
}

class _PresurveyGoalsScreenState extends ConsumerState<PresurveyGoalsScreen> {
  final Set<String> _selected = <String>{};

  List<String> _goalsFor(RelationshipStatus status) {
    switch (status) {
      case RelationshipStatus.singleNeverMarried:
        return const [
          'Find a Compatible Partner through our Dating hub',
          'Take a Free Test to check your Readiness for Marriage',
          'Heal from past Trauma or Family Hurt',
          'Prepare for Marriage',
        ];
      case RelationshipStatus.married:
        return const [
          'Check the Health of your Marriage',
          'Strengthen the Bond in Your Marriage',
          'Heal from Spousal Hurt',
          'Become a better Parent to your Kid(s)',
        ];
      case RelationshipStatus.divorced:
      case RelationshipStatus.widowed:
        return const [
          'Heal from a Traumatic Marriage or Family Hurt',
          'Prepare for Remarriage',
          'Find a Compatible Partner through our Dating Hub',
          'Become a better parent to your Kid(s)',
        ];
    }
  }

  String _subtitleFor(RelationshipStatus status) {
    return 'Select one or more goals (you can choose multiple).';
  }

  Future<void> _persistToGuestSession() async {
    // Optional: store as plain strings for now.
    // If your guest session model expects something else later, we can adapt.
    final notifier = ref.read(guestSessionProvider.notifier);

    // Only call if method exists (we avoid compile errors by not calling unknown APIs).
    // We'll wire this properly once you confirm the guest session model fields.
    // For now: do nothing.
    await Future.value(notifier);
  }

  void _goToSignup() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const SignupStubScreen()),
    );
  }

  void _goToLogin() {
    Navigator.push(
      context,
      MaterialPageRoute(builder: (_) => const LoginStubScreen()),
    );
  }

  void _continueAsGuest() {
    Navigator.pushAndRemoveUntil(
      context,
      MaterialPageRoute(
        builder: (_) => const GuestEntryGate(child: BootstrapGate()),
      ),
      (_) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    final goals = _goalsFor(widget.relationshipStatus);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text('Goals', style: AppTextStyles.headlineLarge),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 14, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                _subtitleFor(widget.relationshipStatus),
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 18),

              Expanded(
                child: ListView.separated(
                  itemCount: goals.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final label = goals[index];
                    final isSelected = _selected.contains(label);

                    return _GoalTile(
                      label: label,
                      selected: isSelected,
                      onTap: () {
                        setState(() {
                          if (isSelected) {
                            _selected.remove(label);
                          } else {
                            _selected.add(label);
                          }
                        });
                      },
                    );
                  },
                ),
              ),

              const SizedBox(height: 12),

              _PrimaryButton(
                label: 'Create Account',
                enabled: true,
                onTap: () async {
                  await _persistToGuestSession();
                  _goToSignup();
                },
              ),
              const SizedBox(height: 10),

              _OutlineButton(
                label: 'Log In',
                onTap: () async {
                  await _persistToGuestSession();
                  _goToLogin();
                },
              ),
              const SizedBox(height: 10),

              _TextLink(
                label: 'Continue as Guest',
                onTap: () async {
                  await _persistToGuestSession();
                  _continueAsGuest();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GoalTile extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;

  const _GoalTile({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color:
              selected
                  ? AppColors.primary.withOpacity(0.12)
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border, width: 1.2),
        ),
        child: Row(
          children: [
            Expanded(child: Text(label, style: AppTextStyles.bodyMedium)),
            const SizedBox(width: 10),
            AnimatedContainer(
              duration: const Duration(milliseconds: 180),
              width: 20,
              height: 20,
              decoration: BoxDecoration(
                color: selected ? AppColors.primary : Colors.transparent,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(color: AppColors.primary, width: 1.2),
              ),
              child:
                  selected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
            ),
          ],
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String label;
  final bool enabled;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.label,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

class _OutlineButton extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _OutlineButton({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 54,
      width: double.infinity,
      child: OutlinedButton(
        onPressed: onTap,
        style: OutlinedButton.styleFrom(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
          side: BorderSide(color: AppColors.border),
        ),
        child: Text(label, style: AppTextStyles.labelLarge),
      ),
    );
  }
}

class _TextLink extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _TextLink({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: TextButton(
        onPressed: onTap,
        child: Text(
          label,
          style: AppTextStyles.labelLarge.copyWith(
            color: AppColors.textMuted,
            decoration: TextDecoration.underline,
          ),
        ),
      ),
    );
  }
}
