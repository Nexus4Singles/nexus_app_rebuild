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
  bool _syncedFromDraft = false;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController();
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
    // Sync wheel once when draft age becomes available
    final draft = ref.watch(datingOnboardingDraftProvider);
    final draftAge = draft.age;
    if (!_syncedFromDraft && draftAge != null) {
      final clamped = draftAge.clamp(_minAge, _maxAge);
      _syncedFromDraft = true;
      _selectedAge = clamped;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        _controller.jumpToItem(clamped - _minAge);
        setState(() {});
      });
    }

    return WillPopScope(
      onWillPop: () async {
        await _onBackPressed();
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          elevation: 0,
          backgroundColor: AppColors.getBackground(context),
          surfaceTintColor: AppColors.getBackground(context),
          foregroundColor: AppColors.textPrimary,
          titleSpacing: 0,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back_rounded),
            onPressed: _onBackPressed,
          ),
          title: Text(
            'Age',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          centerTitle: true,
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Progress bar
                const DatingProfileProgressBar(currentStep: 1, totalSteps: 9),
                const SizedBox(height: 24),
                Text('How old are you?', style: AppTextStyles.titleLarge),
                const SizedBox(height: 10),
                Text(
                  'Nexus is for users between the ages of 21 to 70 years',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
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
                        color: AppColors.getSurface(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.getBorder(context)),
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
                              // Auto-save on selection change
                              ref
                                  .read(datingOnboardingDraftProvider.notifier)
                                  .setAge(_selectedAge);
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
                                                  color: AppColors.getTextPrimary(context),
                                                )
                                            : AppTextStyles.titleLarge.copyWith(
                                              color: AppColors.getTextSecondary(context),
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
