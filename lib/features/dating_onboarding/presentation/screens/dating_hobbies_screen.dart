import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_v2/core/lists/onboarding_lists.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/features/dating_onboarding/application/dating_onboarding_draft.dart';
import 'package:nexus_app_v2/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';
import 'package:nexus_app_v2/core/router/safe_nav.dart';

class DatingHobbiesScreen extends ConsumerStatefulWidget {
  const DatingHobbiesScreen({super.key});

  @override
  ConsumerState<DatingHobbiesScreen> createState() => _DatingHobbiesScreenState();
}

class _DatingHobbiesScreenState extends ConsumerState<DatingHobbiesScreen> {
  static const int _max = 5;
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    final draft = ref.read(datingOnboardingDraftProvider);
    _selected.addAll(draft.hobbies);
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(onboardingListsProvider);
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(icon: const Icon(Icons.arrow_back_ios_new_rounded), onPressed: () => navigateBackToHome(context)),
        title: Text('Hobbies & Interests', style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700)),
      ),
      body: listsAsync.when(
        data: (lists) => _buildContent(context, lists),
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed to load hobbies: $e', style: AppTextStyles.bodyMedium)),
      ),
    );
  }

  Widget _buildContent(BuildContext context, OnboardingLists lists) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 10, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressHeader(subtitle: 'Select up to $_max Hobbies or Interests.', counter: '${_selected.length} / $_max'),
          const SizedBox(height: 12),
          Expanded(child: _SelectableGrid(items: lists.hobbies, selected: _selected, max: _max, onToggle: _toggle)),
          SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed: _selected.isEmpty ? null : () => Navigator.of(context).pushNamed('/dating/setup/qualities'),
                    style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, foregroundColor: Colors.white, elevation: 0, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18))),
                    child: const Text('Continue'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _toggle(String hobby) {
    setState(() {
      if (_selected.contains(hobby)) { _selected.remove(hobby); } 
      else if (_selected.length >= _max) { HapticFeedback.mediumImpact(); return; } 
      else { _selected.add(hobby); }
      ref.read(datingOnboardingDraftProvider.notifier).setHobbies(_selected.toList());
    });
  }
}

class _ProgressHeader extends StatelessWidget {
  final String subtitle; final String counter;
  const _ProgressHeader({required this.subtitle, required this.counter});
  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DatingProfileProgressBar(currentStep: 3, totalSteps: 9),
        const SizedBox(height: 12),
        Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Expanded(child: Text(subtitle, style: AppTextStyles.bodySmall.copyWith(color: AppColors.getTextMuted(context)))),
            const SizedBox(width: 10),
            Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(color: AppColors.getSurface(context), borderRadius: BorderRadius.circular(999), border: Border.all(color: AppColors.getBorder(context))), child: Text(counter, style: AppTextStyles.labelSmall)),
          ],
        ),
      ],
    );
  }
}

class _SelectableGrid extends StatelessWidget {
  final List<String> items; final Set<String> selected; final int max; final ValueChanged<String> onToggle;
  const _SelectableGrid({required this.items, required this.selected, required this.max, required this.onToggle});
  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 2, crossAxisSpacing: 10, mainAxisSpacing: 10, childAspectRatio: 3.4),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final val = items[i]; final sel = selected.contains(val);
        return InkWell(
          borderRadius: BorderRadius.circular(14), onTap: () => onToggle(val),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180), padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(color: sel ? AppColors.primary.withOpacity(0.10) : AppColors.getSurface(context), borderRadius: BorderRadius.circular(14), border: Border.all(color: sel ? AppColors.primary : AppColors.getBorder(context), width: sel ? 1.4 : 1)),
            child: Row(children: [Expanded(child: Text(val, maxLines: 1, overflow: TextOverflow.ellipsis, style: AppTextStyles.bodySmall.copyWith(fontWeight: sel ? FontWeight.w700 : FontWeight.w500))), const SizedBox(width: 8), Icon(sel ? Icons.check_circle : Icons.circle_outlined, size: 18, color: sel ? AppColors.primary : AppColors.getTextMuted(context))]),
          ),
        );
      },
    );
  }
}
