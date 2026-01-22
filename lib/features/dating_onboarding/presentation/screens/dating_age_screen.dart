import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../application/dating_onboarding_draft.dart';
import '../widgets/dating_profile_progress_bar.dart';

class DatingAgeScreen extends ConsumerStatefulWidget {
  const DatingAgeScreen({super.key});

  @override
  ConsumerState<DatingAgeScreen> createState() => _DatingAgeScreenState();
}

class _DatingAgeScreenState extends ConsumerState<DatingAgeScreen> {
  static const int _minAge = 21;
  static const int _maxAge = 70;

  late FixedExtentScrollController _controller;
  int _selectedAge = 21;

  @override
  void initState() {
    super.initState();
    final draft = ref.read(datingOnboardingDraftProvider);
    _selectedAge = (draft.age ?? _minAge).clamp(_minAge, _maxAge);
    _controller = FixedExtentScrollController(
      initialItem: _selectedAge - _minAge,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _continue() {
    ref.read(datingOnboardingDraftProvider.notifier).setAge(_selectedAge);
    Navigator.pushNamed(context, '/dating/setup/extra-info');
  }

  Future<void> _onBackPressed() async {
    // On first step (age), ask if user wants to discard progress
    final shouldDiscard = await showDialog<bool>(
      context: context,
      builder:
          (ctx) => AlertDialog(
            title: const Text('Discard Profile Setup?'),
            content: const Text(
              'Going back will discard all progress. You\'ll need to start over.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: const Text('Continue'),
              ),
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Discard',
                  style: TextStyle(color: Colors.red),
                ),
              ),
            ],
          ),
    );

    if (shouldDiscard == true && mounted) {
      // Clear the draft and go back to main screen
      ref.read(datingOnboardingDraftProvider.notifier).reset();
      Navigator.of(context).pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        await _onBackPressed();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.background,
          foregroundColor: AppColors.textPrimary,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _onBackPressed,
          ),
          title: Text('Step 1 of 8', style: AppTextStyles.titleMedium),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress bar
                const DatingProfileProgressBar(currentStep: 1, totalSteps: 8),
                const SizedBox(height: 24),
                Text('How old are you?', style: AppTextStyles.headlineLarge),
                const SizedBox(height: 10),
                Text(
                  'Nexus is for users between the ages of 21 to 70 years',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),
                Expanded(
                  child: Center(
                    child: Container(
                      height: 280,
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 14,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surface,
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.border),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withOpacity(0.04),
                            blurRadius: 24,
                            offset: const Offset(0, 12),
                          ),
                        ],
                      ),
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: IgnorePointer(
                              child: Center(
                                child: Container(
                                  height: 54,
                                  decoration: BoxDecoration(
                                    color: AppColors.primary.withOpacity(0.08),
                                    borderRadius: BorderRadius.circular(16),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          ListWheelScrollView.useDelegate(
                            controller: _controller,
                            itemExtent: 52,
                            physics: const FixedExtentScrollPhysics(),
                            onSelectedItemChanged: (i) {
                              setState(() => _selectedAge = _minAge + i);
                            },
                            perspective: 0.003,
                            diameterRatio: 1.5,
                            childDelegate: ListWheelChildBuilderDelegate(
                              builder: (_, i) {
                                final age = _minAge + i;
                                final selected = age == _selectedAge;
                                return Center(
                                  child: AnimatedDefaultTextStyle(
                                    duration: const Duration(milliseconds: 180),
                                    style:
                                        selected
                                            ? AppTextStyles.headlineMedium
                                                .copyWith(
                                                  fontWeight: FontWeight.w800,
                                                  color: AppColors.textPrimary,
                                                )
                                            : AppTextStyles.titleLarge.copyWith(
                                              color: AppColors.textMuted,
                                            ),
                                    child: Text('$age'),
                                  ),
                                );
                              },
                              childCount: (_maxAge - _minAge) + 1,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _continue,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      elevation: 0,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(18),
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
              ],
            ),
          ),
        ),
      ),
    );
  }
}
