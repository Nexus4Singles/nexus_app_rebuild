import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/lists/onboarding_lists.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/application/dating_onboarding_draft.dart';

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
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Dating Profile', style: AppTextStyles.titleLarge),
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
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _ProgressHeader(
            stepLabel: 'Step 4 of 8',
            title: 'Desired Qualities',
            subtitle:
                'Select up to $_max qualities you seek in a partner. This helps us find better matches.',
            counter: '${_selected.length} / $_max',
          ),
          const SizedBox(height: 14),

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

          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: _selected.isEmpty ? null : () => _onContinue(context),
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'You can update this later.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  void _toggle(String quality) {
    setState(() {
      if (_selected.contains(quality)) {
        _selected.remove(quality);
        return;
      }

      if (_selected.length >= _max) {
        HapticFeedback.mediumImpact();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('You can only select up to $_max qualities.')),
        );
        return;
      }

      _selected.add(quality);
    });
  }

  void _onContinue(BuildContext context) {
    ref
        .read(datingOnboardingDraftProvider.notifier)
        .setDesiredQualities(_selected.toList());
    Navigator.of(context).pushNamed('/dating/setup/photos');
  }
}

class _ProgressHeader extends StatelessWidget {
  final String stepLabel;
  final String title;
  final String subtitle;
  final String counter;

  const _ProgressHeader({
    required this.stepLabel,
    required this.title,
    required this.subtitle,
    required this.counter,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(stepLabel, style: AppTextStyles.caption),
              const SizedBox(height: 8),
              Text(title, style: AppTextStyles.headlineLarge),
              const SizedBox(height: 10),
              Text(
                subtitle,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
            ],
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
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
        childAspectRatio: 2.6,
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
            padding: const EdgeInsets.symmetric(horizontal: 14),
            decoration: BoxDecoration(
              color:
                  isSelected
                      ? AppColors.primary.withOpacity(0.10)
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(18),
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
