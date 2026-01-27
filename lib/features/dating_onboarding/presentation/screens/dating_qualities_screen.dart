import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/lists/onboarding_lists.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/application/dating_onboarding_draft.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';

class DatingQualitiesScreen extends ConsumerStatefulWidget {
  const DatingQualitiesScreen({super.key});

  @override
  ConsumerState<DatingQualitiesScreen> createState() =>
      _DatingQualitiesScreenState();
}

class _DatingQualitiesScreenState extends ConsumerState<DatingQualitiesScreen> {
  static const int _max = 8;

  final _search = TextEditingController();
  final Set<String> _selected = {};

  @override
  void initState() {
    super.initState();
    final draft = ref.read(datingOnboardingDraftProvider);
    _selected.addAll(draft.desiredQualities);
  }

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(onboardingListsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Desired Qualities',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: listsAsync.when(
        data: (lists) => _buildContent(context, lists),
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (e, _) => Center(
              child: Text(
                'Failed to load qualities: $e',
                style: AppTextStyles.bodyMedium,
              ),
            ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, OnboardingLists lists) {
    final q = _search.text.trim().toLowerCase();
    final items =
        lists.desiredQualities
            .where((h) => q.isEmpty || h.toLowerCase().contains(q))
            .toList();

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressHeader(
            subtitle: 'Select up to $_max qualities you seek in a partner.',
            counter: '${_selected.length} / $_max',
          ),
          const SizedBox(height: 12),

          _SearchField(controller: _search, onChanged: (_) => setState(() {})),
          const SizedBox(height: 14),

          Expanded(
            child: _SelectableGrid(
              items: items,
              selected: _selected,
              max: _max,
              onToggle: _toggle,
            ),
          ),

          SafeArea(
            top: false,
            child: Column(
              children: [
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        _selected.isEmpty ? null : () => _onContinue(context),
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
        ],
      ),
    );
  }

  void _toggle(String quality) {
    setState(() {
      if (_selected.contains(quality)) {
        _selected.remove(quality);
      } else if (_selected.length >= _max) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You can only select up to $_max qualities.')),
        );
        return;
      } else {
        _selected.add(quality);
      }

      // Auto-save on every toggle
      ref
          .read(datingOnboardingDraftProvider.notifier)
          .setDesiredQualities(_selected.toList());
    });
  }

  void _onContinue(BuildContext context) {
    // Draft is already saved via auto-save
    Navigator.of(context).pushNamed('/dating/setup/photos');
  }
}

class _ProgressHeader extends StatelessWidget {
  final String subtitle;
  final String counter;

  const _ProgressHeader({required this.subtitle, required this.counter});

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Text(
            subtitle,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textMuted,
            ),
          ),
        ),
        const SizedBox(width: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: AppColors.surface,
            borderRadius: BorderRadius.circular(999),
            border: Border.all(color: AppColors.border),
          ),
          child: Text(counter, style: AppTextStyles.labelLarge),
        ),
      ],
    );
  }
}

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _SearchField({required this.controller, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 12),
      child: Row(
        children: [
          Icon(Icons.search, color: AppColors.textMuted),
          const SizedBox(width: 10),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              decoration: InputDecoration(
                hintText: 'Search qualities',
                hintStyle: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
                border: InputBorder.none,
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            IconButton(
              onPressed: () {
                controller.clear();
                onChanged('');
              },
              icon: Icon(Icons.close, color: AppColors.textMuted),
            ),
        ],
      ),
    );
  }
}

class _SelectableGrid extends StatelessWidget {
  final List<String> items;
  final Set<String> selected;
  final int max;
  final ValueChanged<String> onToggle;

  const _SelectableGrid({
    required this.items,
    required this.selected,
    required this.max,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    if (items.isEmpty) {
      return Center(
        child: Text(
          'No matches found.',
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.only(bottom: 8),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: 3.4,
      ),
      itemCount: items.length,
      itemBuilder: (context, i) {
        final value = items[i];
        final isSelected = selected.contains(value);

        return InkWell(
          borderRadius: BorderRadius.circular(18),
          onTap: () => onToggle(value),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 180),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? AppColors.primary.withOpacity(0.10)
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppColors.primary : AppColors.border,
                width: isSelected ? 1.4 : 1,
              ),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodyMedium.copyWith(
                      fontWeight:
                          isSelected ? FontWeight.w700 : FontWeight.w500,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Icon(
                  isSelected ? Icons.check_circle : Icons.circle_outlined,
                  size: 20,
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
