import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../application/dating_onboarding_draft.dart';
import '../widgets/dating_profile_progress_bar.dart';
import '../../../dating_search/presentation/widgets/dating_pool_guidelines_modal.dart';
import '../../../dating_search/application/dating_pool_guidelines_provider.dart';

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
  bool _guidelinesModalShown = false;

  @override
  void initState() {
    super.initState();
    _controller = FixedExtentScrollController();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resetAndShowGuidelines();
    });
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
      ref.read(datingOnboardingDraftProvider.notifier).reset();
      Navigator.of(context).pop();
    }
  }

  void _showGuidelinesManual() {
    showDialog(
      context: context,
      builder:
          (ctx) => DatingPoolGuidelinesModal(
            onDismiss: () => Navigator.of(ctx).pop(),
          ),
    );
  }

  Future<void> _resetAndShowGuidelines() async {
    final userId = ref.watch(currentUserIdProvider);
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('dating_pool_guidelines_shown');
    if (userId != null)
      await prefs.remove('dating_pool_guidelines_shown_$userId');
    if (mounted) _showGuidelinesIfNeeded();
  }

  Future<void> _showGuidelinesIfNeeded() async {
    if (_guidelinesModalShown) return;
    final userId = ref.watch(currentUserIdProvider);
    if (userId == null) return;
    final prefs = await SharedPreferences.getInstance();
    final userSpecificKey = 'dating_pool_guidelines_shown_$userId';
    if (prefs.getBool(userSpecificKey) == false && mounted) {
      _guidelinesModalShown = true;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder:
            (ctx) => DatingPoolGuidelinesModal(
              onDismiss: () {
                Navigator.of(ctx).pop();
                if (mounted)
                  ref.read(markGuidelinesSeenProvider.notifier).markAsRead();
              },
            ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(datingOnboardingDraftProvider);
    if (!_syncedFromDraft && draft.age != null) {
      final clamped = draft.age!.clamp(_minAge, _maxAge);
      _syncedFromDraft = true;
      _selectedAge = clamped;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) {
          _controller.jumpToItem(clamped - _minAge);
          setState(() {});
        }
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
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline_rounded),
              onPressed: _showGuidelinesManual,
            ),
          ],
        ),
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const DatingProfileProgressBar(currentStep: 1, totalSteps: 9),
                const SizedBox(height: 12),
                Text('How old are you?', style: AppTextStyles.headlineSmall),
                const SizedBox(height: 6),
                Text(
                  'Nexus is for users between the ages of 21 to 70 years',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 16),
                Expanded(
                  child: Center(
                    child: Container(
                      height: 220, // Reduced height for better fit
                      decoration: BoxDecoration(
                        color: AppColors.getSurface(context),
                        borderRadius: BorderRadius.circular(24),
                        border: Border.all(color: AppColors.getBorder(context)),
                      ),
                      child: ListWheelScrollView.useDelegate(
                        controller: _controller,
                        itemExtent: 52,
                        physics: const FixedExtentScrollPhysics(),
                        onSelectedItemChanged: (i) {
                          setState(() => _selectedAge = _minAge + i);
                          ref
                              .read(datingOnboardingDraftProvider.notifier)
                              .setAge(_selectedAge);
                        },
                        childDelegate: ListWheelChildBuilderDelegate(
                          builder: (_, i) {
                            final age = _minAge + i;
                            final sel = age == _selectedAge;
                            return Center(
                              child: Text(
                                '$age',
                                style:
                                    sel
                                        ? AppTextStyles.headlineMedium.copyWith(
                                          fontWeight: FontWeight.w800,
                                          color: AppColors.primary,
                                        )
                                        : AppTextStyles.titleLarge.copyWith(
                                          color: AppColors.getTextSecondary(
                                            context,
                                          ),
                                        ),
                              ),
                            );
                          },
                          childCount: (_maxAge - _minAge) + 1,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _continue,
                    child: const Text('Continue'),
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
