import 'package:country_picker/country_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/lists/onboarding_lists.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/application/dating_onboarding_draft.dart';

class DatingExtraInfoStubScreen extends ConsumerStatefulWidget {
  const DatingExtraInfoStubScreen({super.key});

  @override
  ConsumerState<DatingExtraInfoStubScreen> createState() =>
      _DatingExtraInfoStubScreenState();
}

class _DatingExtraInfoStubScreenState
    extends ConsumerState<DatingExtraInfoStubScreen> {
  final _cityController = TextEditingController();

  String? _countryOfResidence;
  String? _nationality;
  String? _educationLevel;
  String? _profession;
  String? _churchSelection;
  final _churchOtherController = TextEditingController();

  @override
  void initState() {
    super.initState();
    final draft = ref.read(datingOnboardingDraftProvider);

    _cityController.text = draft.city ?? '';
    _countryOfResidence = draft.countryOfResidence;
    _nationality = draft.nationality;
    _educationLevel = draft.educationLevel;
    _profession = draft.profession;
    _churchSelection = draft.churchName;
  }

  @override
  void dispose() {
    _cityController.dispose();
    _churchOtherController.dispose();
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
                'Failed to load lists: $e',
                style: AppTextStyles.bodyMedium,
              ),
            ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, OnboardingLists lists) {
    final showOtherChurch =
        (_churchSelection != null &&
            _churchSelection!.toLowerCase() == 'other');

    return Padding(
      padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const _ProgressHeader(
            stepLabel: 'Step 2 of 8',
            title: 'Extra information',
            subtitle: 'This helps us show you better matches.',
          ),
          const SizedBox(height: 18),
          Expanded(
            child: ListView(
              children: [
                _FieldLabel('City'),
                _TextInput(
                  controller: _cityController,
                  hintText: 'Enter your city',
                ),
                const SizedBox(height: 14),

                _FieldLabel('Country of Residence'),
                _CountryTile(
                  value: _countryOfResidence,
                  placeholder: 'Select country of residence',
                  onTap:
                      () => _pickCountry(
                        context,
                        onSelected:
                            (c) => setState(() => _countryOfResidence = c),
                      ),
                ),
                const SizedBox(height: 14),

                _FieldLabel('Nationality'),
                _CountryTile(
                  value: _nationality,
                  placeholder: 'Select nationality',
                  onTap:
                      () => _pickCountry(
                        context,
                        onSelected: (c) => setState(() => _nationality = c),
                      ),
                ),
                const SizedBox(height: 14),

                _FieldLabel('Education Level'),
                _PickerTile(
                  value: _educationLevel,
                  placeholder: 'Select education level',
                  onTap:
                      () => _pickFromList(
                        context,
                        title: 'Education Level',
                        options: lists.educationalLevels,
                        onSelected: (v) => setState(() => _educationLevel = v),
                      ),
                ),
                const SizedBox(height: 14),

                _FieldLabel('Profession'),
                _PickerTile(
                  value: _profession,
                  placeholder: 'Select profession',
                  onTap:
                      () => _pickFromList(
                        context,
                        title: 'Profession',
                        options: lists.professions,
                        onSelected: (v) => setState(() => _profession = v),
                      ),
                ),
                const SizedBox(height: 14),

                _FieldLabel('Church'),
                _PickerTile(
                  value: _churchSelection,
                  placeholder: 'Select church',
                  onTap:
                      () => _pickFromList(
                        context,
                        title: 'Church',
                        options: lists.churches,
                        onSelected: (v) {
                          setState(() {
                            _churchSelection = v;
                            if (v.toLowerCase() != 'other') {
                              _churchOtherController.clear();
                            }
                          });
                        },
                      ),
                ),

                if (showOtherChurch) ...[
                  const SizedBox(height: 12),
                  _TextInput(
                    controller: _churchOtherController,
                    hintText: 'Enter your church name',
                  ),
                ],

                const SizedBox(height: 26),
              ],
            ),
          ),

          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => _onContinue(context),
              child: const Text('Continue'),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            'Draft saved locally.',
            style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
          ),
        ],
      ),
    );
  }

  void _pickCountry(
    BuildContext context, {
    required ValueChanged<String> onSelected,
  }) {
    showCountryPicker(
      context: context,
      showPhoneCode: false,
      onSelect: (Country c) => onSelected(c.name),
    );
  }

  Future<void> _pickFromList(
    BuildContext context, {
    required String title,
    required List<String> options,
    required ValueChanged<String> onSelected,
  }) async {
    final v = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) => SafeArea(
            child: ListView(
              shrinkWrap: true,
              padding: const EdgeInsets.all(16),
              children: [
                Text(title, style: AppTextStyles.titleLarge),
                const SizedBox(height: 12),
                ...options.map(
                  (o) => ListTile(
                    title: Text(o),
                    trailing: const Icon(Icons.chevron_right),
                    onTap: () => Navigator.pop(context, o),
                  ),
                ),
              ],
            ),
          ),
    );

    if (v != null) onSelected(v);
  }

  void _onContinue(BuildContext context) {
    final city = _cityController.text.trim();
    final country = _countryOfResidence?.trim();
    final nationality = _nationality?.trim();
    final education = _educationLevel?.trim();
    final profession = _profession?.trim();

    String? churchValue = _churchSelection?.trim();
    if (churchValue != null && churchValue.toLowerCase() == 'other') {
      final typed = _churchOtherController.text.trim();
      if (typed.isEmpty) {
        _toast('Please enter your church name.');
        return;
      }
      churchValue = typed;
    }

    if (city.isEmpty) return _toast('Please enter your city.');
    if (country == null || country.isEmpty)
      return _toast('Select your country of residence.');
    if (nationality == null || nationality.isEmpty)
      return _toast('Select your nationality.');
    if (education == null || education.isEmpty)
      return _toast('Select your education level.');
    if (profession == null || profession.isEmpty)
      return _toast('Select your profession.');
    if (churchValue == null || churchValue.isEmpty)
      return _toast('Select your church.');

    ref
        .read(datingOnboardingDraftProvider.notifier)
        .setExtraInfo(
          city: city,
          countryOfResidence: country,
          nationality: nationality,
          educationLevel: education,
          profession: profession,
          churchName: churchValue,
        );

    Navigator.of(context).pushNamed('/dating/setup/hobbies');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }
}

class _ProgressHeader extends StatelessWidget {
  final String stepLabel;
  final String title;
  final String subtitle;

  const _ProgressHeader({
    required this.stepLabel,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(stepLabel, style: AppTextStyles.caption),
        const SizedBox(height: 8),
        Text(title, style: AppTextStyles.headlineLarge),
        const SizedBox(height: 10),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(text, style: AppTextStyles.labelLarge),
    );
  }
}

class _TextInput extends StatelessWidget {
  final TextEditingController controller;
  final String hintText;

  const _TextInput({required this.controller, required this.hintText});

  @override
  Widget build(BuildContext context) {
    return TextField(
      controller: controller,
      style: AppTextStyles.bodyMedium,
      decoration: InputDecoration(
        hintText: hintText,
        hintStyle: AppTextStyles.bodyMedium.copyWith(
          color: AppColors.textMuted,
        ),
        filled: true,
        fillColor: AppColors.surface,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 14,
        ),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide(color: AppColors.primary.withOpacity(0.65)),
        ),
      ),
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  const _PickerTile({
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final display = value?.trim();
    final isEmpty = display == null || display.isEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isEmpty ? placeholder : display,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.keyboard_arrow_down_rounded),
          ],
        ),
      ),
    );
  }
}

class _CountryTile extends StatelessWidget {
  final String? value;
  final String placeholder;
  final VoidCallback onTap;

  const _CountryTile({
    required this.value,
    required this.placeholder,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final display = value?.trim();
    final isEmpty = display == null || display.isEmpty;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Expanded(
              child: Text(
                isEmpty ? placeholder : display,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: isEmpty ? AppColors.textMuted : AppColors.textPrimary,
                ),
              ),
            ),
            const Icon(Icons.public),
          ],
        ),
      ),
    );
  }
}
