import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:country_picker/country_picker.dart';

import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/lists/nexus_lists_provider.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/application/dating_onboarding_draft.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/data/church_list_provider.dart';
import 'package:nexus_app_min_test/core/widgets/nexus_country_picker.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';

class DatingExtraInfoScreen extends ConsumerStatefulWidget {
  const DatingExtraInfoScreen({super.key});

  @override
  ConsumerState<DatingExtraInfoScreen> createState() =>
      _DatingExtraInfoScreenState();
}

class _DatingExtraInfoScreenState extends ConsumerState<DatingExtraInfoScreen> {
  final _cityCtrl = TextEditingController();
  final _otherChurchCtrl = TextEditingController();

  String? _countryOfResidence;
  String? _nationality;
  String? _education;
  String? _profession;
  String? _church;
  bool _showOtherChurch = false;

  @override
  void initState() {
    super.initState();
    // Load existing draft values
    final draft = ref.read(datingOnboardingDraftProvider);
    _cityCtrl.text = draft.city ?? '';
    _otherChurchCtrl.text = draft.otherChurchName ?? '';
    _countryOfResidence = draft.countryOfResidence;
    _nationality = draft.nationality;
    _education = draft.educationLevel;
    _profession = draft.profession;
    _church = draft.churchName;
    _showOtherChurch = _church == 'Other';

    // Add listeners for auto-save on text changes
    _cityCtrl.addListener(_saveDraft);
    _otherChurchCtrl.addListener(_saveDraft);
  }

  @override
  void dispose() {
    _cityCtrl.removeListener(_saveDraft);
    _otherChurchCtrl.removeListener(_saveDraft);
    _cityCtrl.dispose();
    _otherChurchCtrl.dispose();
    super.dispose();
  }

  void _pickCountry({
    required String title,
    required void Function(String) onPicked,
  }) {
    NexusCountryPicker.show(context: context, title: title, onPicked: onPicked);
  }

  Future<void> _pickFromList({
    required String title,
    required List<String> items,
    required void Function(String v) onPicked,
    bool searchable = true,
  }) async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.background,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder:
          (_) =>
              _PickerSheet(title: title, items: items, searchable: searchable),
    );

    if (picked != null) onPicked(picked);
  }

  void _saveDraft() {
    final draftNotifier = ref.read(datingOnboardingDraftProvider.notifier);

    final city = _cityCtrl.text.trim();
    final churchValue =
        _church == 'Other' ? _otherChurchCtrl.text.trim() : _church;

    draftNotifier.setExtraInfo(
      city: city.isEmpty ? null : city,
      countryOfResidence: _countryOfResidence,
      nationality: _nationality,
      educationLevel: _education,
      profession: _profession,
      churchName: churchValue?.isEmpty == true ? null : churchValue,
    );
  }

  bool get _valid {
    if (_cityCtrl.text.trim().isEmpty) return false;
    if (_countryOfResidence == null) return false;
    if (_nationality == null) return false;
    if (_education == null) return false;
    if (_profession == null) return false;
    if (_church == null) return false;
    if (_church == 'Other' && _otherChurchCtrl.text.trim().isEmpty)
      return false;
    return true;
  }

  @override
  Widget build(BuildContext context) {
    final listsAsync = ref.watch(onboardingListsProvider);
    final churchesAsync = ref.watch(churchListProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Extra Information',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: SafeArea(
        child: listsAsync.when(
          data:
              (lists) => churchesAsync.when(
                data:
                    (churches) => _Body(
                      cityCtrl: _cityCtrl,
                      otherChurchCtrl: _otherChurchCtrl,
                      countryOfResidence: _countryOfResidence,
                      nationality: _nationality,
                      education: _education,
                      profession: _profession,
                      church: _church,
                      showOtherChurch: _showOtherChurch,
                      churches: churches,
                      educationLevels: lists.educationalLevels,
                      professions: lists.professions,
                      onPickCountry:
                          () => _pickCountry(
                            title: 'Country of Residence',
                            onPicked: (v) {
                              setState(() => _countryOfResidence = v);
                              _saveDraft();
                            },
                          ),
                      onPickNationality:
                          () => _pickCountry(
                            title: 'Nationality',
                            onPicked: (v) {
                              setState(() => _nationality = v);
                              _saveDraft();
                            },
                          ),
                      onPickEducation:
                          () => _pickFromList(
                            title: 'Education Level',
                            items: lists.educationalLevels,
                            onPicked: (v) {
                              setState(() => _education = v);
                              _saveDraft();
                            },
                          ),
                      onPickProfession:
                          () => _pickFromList(
                            title: 'Profession',
                            items: lists.professions,
                            onPicked: (v) {
                              setState(() => _profession = v);
                              _saveDraft();
                            },
                          ),
                      onPickChurch:
                          () => _pickFromList(
                            title: 'Church Name',
                            items: churches,
                            onPicked: (v) {
                              setState(() {
                                _church = v;
                                _showOtherChurch = v == 'Other';
                                if (!_showOtherChurch) _otherChurchCtrl.clear();
                              });
                              _saveDraft();
                            },
                          ),
                      onOtherChurchChanged: () => setState(() {}),
                      onContinue: () {
                        // Draft is already saved via auto-save
                        Navigator.of(
                          context,
                        ).pushNamed('/dating/setup/hobbies');
                      },
                      isValid: _valid,
                    ),
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (_, __) => const _ErrorState(),
              ),
          loading: () => const Center(child: CircularProgressIndicator()),
          error: (_, __) => const _ErrorState(),
        ),
      ),
    );
  }
}

class _Body extends StatelessWidget {
  final TextEditingController cityCtrl;
  final TextEditingController otherChurchCtrl;

  final String? countryOfResidence;
  final String? nationality;
  final String? education;
  final String? profession;
  final String? church;
  final bool showOtherChurch;

  final List<String> churches;
  final List<String> educationLevels;
  final List<String> professions;

  final VoidCallback onPickCountry;
  final VoidCallback onPickNationality;
  final VoidCallback onPickEducation;
  final VoidCallback onPickProfession;
  final VoidCallback onPickChurch;
  final VoidCallback onOtherChurchChanged;

  final VoidCallback onContinue;
  final bool isValid;

  const _Body({
    required this.cityCtrl,
    required this.otherChurchCtrl,
    required this.countryOfResidence,
    required this.nationality,
    required this.education,
    required this.profession,
    required this.church,
    required this.showOtherChurch,
    required this.churches,
    required this.educationLevels,
    required this.professions,
    required this.onPickCountry,
    required this.onPickNationality,
    required this.onPickEducation,
    required this.onPickProfession,
    required this.onPickChurch,
    required this.onOtherChurchChanged,
    required this.onContinue,
    required this.isValid,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 18),
      child: Column(
        children: [
          const DatingProfileProgressBar(currentStep: 2, totalSteps: 9),
          const SizedBox(height: 20),
          _InfoCard(
            text:
                'To select your church below, search with the full name. If your church is not listed, kindly select "Other" and type the full name of your Church in the text box displayed.',
          ),
          const SizedBox(height: 24),

          Expanded(
            child: ListView(
              children: [
                _LabeledField(
                  label: 'City',
                  child: TextField(
                    controller: cityCtrl,
                    textCapitalization: TextCapitalization.words,
                    style: AppTextStyles.bodyMedium,
                    decoration: _inputDeco(hint: 'Enter your city'),
                  ),
                ),
                const SizedBox(height: 14),

                _LabeledField(
                  label: 'Country of Residence',
                  child: _PickerTile(
                    value: countryOfResidence,
                    hint: 'Select country of residence',
                    onTap: onPickCountry,
                  ),
                ),
                const SizedBox(height: 14),

                _LabeledField(
                  label: 'Nationality',
                  child: _PickerTile(
                    value: nationality,
                    hint: 'Select nationality',
                    onTap: onPickNationality,
                  ),
                ),
                const SizedBox(height: 14),

                _LabeledField(
                  label: 'Education Level',
                  child: _PickerTile(
                    value: education,
                    hint: 'Select education level',
                    onTap: onPickEducation,
                  ),
                ),
                const SizedBox(height: 14),

                _LabeledField(
                  label: 'Profession',
                  child: _PickerTile(
                    value: profession,
                    hint: 'Select profession',
                    onTap: onPickProfession,
                  ),
                ),
                const SizedBox(height: 14),

                _LabeledField(
                  label: 'Church Name',
                  child: _PickerTile(
                    value: church,
                    hint: 'Select your church',
                    onTap: onPickChurch,
                  ),
                ),

                if (showOtherChurch) ...[
                  const SizedBox(height: 12),
                  _LabeledField(
                    label: 'Enter your church name',
                    child: TextField(
                      controller: otherChurchCtrl,
                      style: AppTextStyles.bodyMedium,
                      decoration: _inputDeco(hint: 'Type full church name'),
                      onChanged: (_) => onOtherChurchChanged(),
                    ),
                  ),
                ],

                const SizedBox(height: 24),
              ],
            ),
          ),

          SafeArea(
            top: false,
            child: _PrimaryButton(
              text: 'Continue',
              enabled: isValid,
              onTap: onContinue,
            ),
          ),
        ],
      ),
    );
  }

  static InputDecoration _inputDeco({required String hint}) => InputDecoration(
    hintText: hint,
    hintStyle: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
    filled: true,
    fillColor: AppColors.surface,
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: const BorderSide(color: Color(0xFFE5E7EB)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(16),
      borderSide: BorderSide(color: AppColors.primary, width: 1.4),
    ),
    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
  );
}

class _InfoCard extends StatelessWidget {
  final String text;

  const _InfoCard({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(Icons.info_outline, color: AppColors.primary, size: 24),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: AppTextStyles.bodyMedium.copyWith(height: 1.5),
            ),
          ),
        ],
      ),
    );
  }
}

class _LabeledField extends StatelessWidget {
  final String label;
  final Widget child;

  const _LabeledField({required this.label, required this.child});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: AppTextStyles.labelLarge),
        const SizedBox(height: 8),
        child,
      ],
    );
  }
}

class _PickerTile extends StatelessWidget {
  final String? value;
  final String hint;
  final VoidCallback onTap;

  const _PickerTile({
    required this.value,
    required this.hint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surface,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
          ),
          child: Row(
            children: [
              Expanded(
                child: Text(
                  value ?? hint,
                  style:
                      value == null
                          ? AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textMuted,
                          )
                          : AppTextStyles.bodyMedium,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(
                Icons.keyboard_arrow_down_rounded,
                color: AppColors.textMuted,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _PrimaryButton extends StatelessWidget {
  final String text;
  final bool enabled;
  final VoidCallback onTap;

  const _PrimaryButton({
    required this.text,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Opacity(
      opacity: enabled ? 1.0 : 0.45,
      child: SizedBox(
        width: double.infinity,
        height: 54,
        child: ElevatedButton(
          onPressed: enabled ? onTap : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            elevation: 0,
          ),
          child: Text(
            text,
            style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
          ),
        ),
      ),
    );
  }
}

class _PickerSheet extends StatefulWidget {
  final String title;
  final List<String> items;
  final bool searchable;

  const _PickerSheet({
    required this.title,
    required this.items,
    required this.searchable,
  });

  @override
  State<_PickerSheet> createState() => _PickerSheetState();
}

class _PickerSheetState extends State<_PickerSheet> {
  String q = '';

  @override
  Widget build(BuildContext context) {
    final filtered =
        widget.items
            .where(
              (e) => q.isEmpty || e.toLowerCase().contains(q.toLowerCase()),
            )
            .toList();

    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 16,
          bottom: MediaQuery.of(context).viewInsets.bottom + 16,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(widget.title, style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            if (widget.searchable)
              TextField(
                decoration: InputDecoration(
                  hintText: 'Search',
                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                  ),
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: AppColors.surface,
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(16),
                    borderSide: BorderSide(color: AppColors.border),
                  ),
                ),
                onChanged: (v) => setState(() => q = v),
              ),
            const SizedBox(height: 12),
            Flexible(
              child: ListView.separated(
                shrinkWrap: true,
                itemCount: filtered.length,
                separatorBuilder:
                    (_, __) =>
                        Divider(color: AppColors.border.withOpacity(0.7)),
                itemBuilder: (_, i) {
                  final v = filtered[i];
                  return ListTile(
                    title: Text(v, style: AppTextStyles.bodyMedium),
                    onTap: () => Navigator.pop(context, v),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'Unable to load lists',
        style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
      ),
    );
  }
}
