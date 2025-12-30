import 'dart:io';
import 'dart:ui';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:audioplayers/audioplayers.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/widgets/app_button.dart';
import '../../../../core/widgets/searchable_picker.dart';
import '../../../../core/widgets/country_picker_field.dart';
import '../../../../core/services/media_service.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/service_providers.dart';
import '../../../../core/providers/onboarding_provider.dart';

/// Dating Profile Setup - 7-step onboarding for singles
/// Based on Nexus 1.0 Figma designs
class DatingProfileSetupScreen extends ConsumerStatefulWidget {
  const DatingProfileSetupScreen({super.key});

  @override
  ConsumerState<DatingProfileSetupScreen> createState() => _DatingProfileSetupScreenState();
}

class _DatingProfileSetupScreenState extends ConsumerState<DatingProfileSetupScreen> {
  late PageController _pageController;
  int _currentStep = 0;
  final int _totalSteps = 7;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    _pageController = PageController();
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final formState = ref.watch(datingProfileFormProvider);
    
    return Scaffold(
      body: SafeArea(
        child: Column(
          children: [
            _buildHeader(context),
            Expanded(
              child: PageView(
                controller: _pageController,
                physics: const NeverScrollableScrollPhysics(),
                onPageChanged: (index) => setState(() => _currentStep = index),
                children: [
                  _AgeStep(onNext: _nextStep),
                  _ExtraInfoStep(onNext: _nextStep),
                  _HobbiesStep(onNext: _nextStep),
                  _DesiredQualitiesStep(onNext: _nextStep),
                  _PhotosStep(onNext: _nextStep),
                  _AudioRecordingsStep(onNext: _nextStep),
                  _ContactInfoStep(onComplete: _completeSetup),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
      child: Column(
        children: [
          // Back button and step indicator
          Row(
            children: [
              GestureDetector(
                onTap: _handleBack,
                child: Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.arrow_back, size: 20),
                ),
              ),
              const Spacer(),
              Text(
                'Step ${_currentStep + 1} of $_totalSteps',
                style: TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              const SizedBox(width: 40), // Balance the back button
            ],
          ),
          const SizedBox(height: 16),
          // Premium progress bar
          Row(
            children: List.generate(_totalSteps, (index) {
              final isComplete = index < _currentStep;
              final isCurrent = index == _currentStep;
              
              return Expanded(
                child: Container(
                  height: 4,
                  margin: EdgeInsets.only(right: index < _totalSteps - 1 ? 6 : 0),
                  decoration: BoxDecoration(
                    gradient: (isComplete || isCurrent) ? AppColors.primaryGradient : null,
                    color: (isComplete || isCurrent) ? null : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  String _getStepTitle() {
    switch (_currentStep) {
      case 0: return "What's Your Age?";
      case 1: return "Extra Information";
      case 2: return "Hobbies/Interests";
      case 3: return "Desired Qualities";
      case 4: return "Upload Your Photos";
      case 5: return "Audio Recordings";
      case 6: return "Contact Information";
      default: return "";
    }
  }

  void _handleBack() {
    if (_currentStep > 0) {
      setState(() => _currentStep--);
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    } else {
      _showExitDialog();
    }
  }

  void _showExitDialog() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Leave Profile Setup?'),
        content: const Text('Your progress will be saved.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Stay'),
          ),
          TextButton(
            onPressed: () {
              Navigator.pop(context);
              context.pop();
            },
            child: Text('Leave', style: TextStyle(color: AppColors.error)),
          ),
        ],
      ),
    );
  }

  void _nextStep() {
    if (_currentStep < _totalSteps - 1) {
      setState(() => _currentStep++);
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  Future<void> _completeSetup() async {
    setState(() => _isSaving = true);
    
    try {
      final success = await ref.read(datingProfileFormProvider.notifier).saveCompleteProfile();
      
      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(ref.read(datingProfileFormProvider).error ?? 'Failed to save profile'),
              backgroundColor: AppColors.error,
            ),
          );
        }
        return;
      }
      
      if (!mounted) return;
      _showSuccessDialog();
    } finally {
      if (mounted) {
        setState(() => _isSaving = false);
      }
    }
  }

  void _showSuccessDialog() {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.accent.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.celebration, size: 64, color: AppColors.accent),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Congratulations!',
              style: Theme.of(context).textTheme.titleLarge?.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'You have successfully created a profile on Nexus! Please complete the compatibility quiz to help us find your perfect match.',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.textSecondary,
                  ),
            ),
          ],
        ),
        actions: [
          AppButton.primary(
            label: 'Continue',
            onPressed: () {
              Navigator.pop(context);
              context.go('/profile');
            },
            isExpanded: true,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STEP 1: AGE
// ============================================================================

class _AgeStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const _AgeStep({required this.onNext});

  @override
  ConsumerState<_AgeStep> createState() => _AgeStepState();
}

class _AgeStepState extends ConsumerState<_AgeStep> {
  late FixedExtentScrollController _scrollController;
  final List<int> _ages = List.generate(50, (i) => i + 21);

  @override
  void initState() {
    super.initState();
    final currentAge = ref.read(datingProfileFormProvider).age;
    final initialIndex = currentAge != null ? _ages.indexOf(currentAge) : 9;
    _scrollController = FixedExtentScrollController(initialItem: initialIndex);
    
    if (currentAge == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ref.read(datingProfileFormProvider.notifier).setAge(_ages[9]);
      });
    }
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final age = ref.watch(datingProfileFormProvider.select((s) => s.age));
    
    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        children: [
          Text(
            'Nexus is for users between the ages of 21 to 70 years',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: ListWheelScrollView.useDelegate(
              controller: _scrollController,
              itemExtent: 60,
              perspective: 0.005,
              diameterRatio: 1.5,
              physics: const FixedExtentScrollPhysics(),
              onSelectedItemChanged: (index) {
                ref.read(datingProfileFormProvider.notifier).setAge(_ages[index]);
              },
              childDelegate: ListWheelChildBuilderDelegate(
                childCount: _ages.length,
                builder: (context, index) {
                  final itemAge = _ages[index];
                  final isSelected = age == itemAge;
                  return Center(
                    child: Text(
                      '$itemAge',
                      style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppColors.primary : AppColors.textMuted,
                          ),
                    ),
                  );
                },
              ),
            ),
          ),
          AppButton.primary(
            label: 'Next',
            onPressed: age != null ? widget.onNext : null,
            isExpanded: true,
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STEP 2: EXTRA INFORMATION
// ============================================================================

class _ExtraInfoStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const _ExtraInfoStep({required this.onNext});

  @override
  ConsumerState<_ExtraInfoStep> createState() => _ExtraInfoStepState();
}

class _ExtraInfoStepState extends ConsumerState<_ExtraInfoStep> {
  final _cityController = TextEditingController();
  final _churchController = TextEditingController();

  static const _nationalities = [
    'Nigerian', 'Ghanaian', 'Kenyan', 'South African', 'American',
    'British', 'Canadian', 'Other African', 'Other',
  ];

  static const _countries = [
    'Nigeria', 'Ghana', 'Kenya', 'South Africa', 'United States',
    'United Kingdom', 'Canada', 'Germany', 'Other',
  ];

  static const _educationLevels = [
    'High School', 'Diploma', 'Undergraduate Degree',
    'Postgraduate Degree', 'Doctorate Degree',
  ];

  static const _professions = [
    'Lawyer', 'Doctor', 'Engineer', 'Teacher', 'Nurse',
    'Accountant', 'Business Owner', 'IT Professional',
    'Student', 'Other',
  ];

  @override
  void initState() {
    super.initState();
    final state = ref.read(datingProfileFormProvider);
    _cityController.text = state.cityCountry ?? '';
    _churchController.text = state.church ?? '';
  }

  @override
  void dispose() {
    _cityController.dispose();
    _churchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(datingProfileFormProvider);
    final notifier = ref.read(datingProfileFormProvider.notifier);
    
    final isValid = state.isStep2Complete;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Tell us more about yourself',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.textMuted,
                ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView(
              children: [
                _buildDropdown(
                  label: 'Nationality',
                  value: state.nationality,
                  items: _nationalities,
                  onChanged: (v) => notifier.setNationality(v!),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _cityController,
                  decoration: InputDecoration(
                    labelText: 'City, Country of Residence',
                    hintText: 'e.g., Berlin, Germany',
                    prefixIcon: const Icon(Icons.location_on_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onChanged: (v) => notifier.setCityCountry(v),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildDropdown(
                  label: 'Country',
                  value: state.country,
                  items: _countries,
                  onChanged: (v) => notifier.setCountry(v!),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildDropdown(
                  label: 'Education Level',
                  value: state.educationLevel,
                  items: _educationLevels,
                  onChanged: (v) => notifier.setEducationLevel(v!),
                ),
                const SizedBox(height: AppSpacing.md),
                _buildDropdown(
                  label: 'Profession / Industry',
                  value: state.profession,
                  items: _professions,
                  onChanged: (v) => notifier.setProfession(v!),
                ),
                const SizedBox(height: AppSpacing.md),
                TextField(
                  controller: _churchController,
                  decoration: InputDecoration(
                    labelText: 'Church (Full name)',
                    hintText: 'e.g., Celebration Church',
                    prefixIcon: const Icon(Icons.church_outlined),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                    ),
                  ),
                  onChanged: (v) => notifier.setChurch(v.isEmpty ? null : v),
                ),
              ],
            ),
          ),
          AppButton.primary(
            label: 'Next',
            onPressed: isValid ? widget.onNext : null,
            isExpanded: true,
          ),
        ],
      ),
    );
  }

  Widget _buildDropdown({
    required String label,
    required String? value,
    required List<String> items,
    required ValueChanged<String?> onChanged,
  }) {
    return DropdownButtonFormField<String>(
      value: value,
      decoration: InputDecoration(
        labelText: label,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
        ),
      ),
      items: items.map((item) => DropdownMenuItem(value: item, child: Text(item))).toList(),
      onChanged: onChanged,
    );
  }
}

// ============================================================================
// STEP 3: HOBBIES (Premium Multi-Select Chips)
// ============================================================================

class _HobbiesStep extends ConsumerWidget {
  final VoidCallback onNext;
  const _HobbiesStep({required this.onNext});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final hobbies = ref.watch(datingProfileFormProvider.select((s) => s.hobbies));
    final notifier = ref.read(datingProfileFormProvider.notifier);
    final hobbiesListAsync = ref.watch(hobbiesListProvider);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & subtitle
                const Text(
                  'Hobbies/Interests',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                Text(
                  'Select up to 5 interests / hobbies to let users know what you are passionate about.',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),
                const SizedBox(height: 20),

                // Selection counter badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: hobbies.isNotEmpty ? AppColors.primarySoft : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: hobbies.isNotEmpty ? AppColors.primary.withOpacity(0.3) : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        hobbies.length >= 1 ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18,
                        color: hobbies.isNotEmpty ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${hobbies.length} of 5 selected',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: hobbies.isNotEmpty ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Premium Chips Grid
                hobbiesListAsync.when(
                  data: (allHobbies) => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: allHobbies.map((hobby) {
                      final isSelected = hobbies.contains(hobby);
                      final canSelect = isSelected || hobbies.length < 5;

                      return GestureDetector(
                        onTap: canSelect ? () {
                          HapticFeedback.lightImpact();
                          notifier.toggleHobby(hobby);
                        } : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Text(
                            hobby,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : (canSelect ? AppColors.textPrimary : AppColors.textMuted),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error loading hobbies: $e', style: TextStyle(color: AppColors.error)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom CTA
        Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: hobbies.isNotEmpty ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: hobbies.isNotEmpty ? AppColors.primary : AppColors.surfaceLight,
                foregroundColor: hobbies.isNotEmpty ? Colors.white : AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: hobbies.isNotEmpty ? 4 : 0,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STEP 4: DESIRED QUALITIES (Premium Multi-Select - Max 8)
// ============================================================================

class _DesiredQualitiesStep extends ConsumerWidget {
  final VoidCallback onNext;
  const _DesiredQualitiesStep({required this.onNext});

  static const int _maxQualities = 8;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final qualities = ref.watch(datingProfileFormProvider.select((s) => s.desiredQualities));
    final notifier = ref.read(datingProfileFormProvider.notifier);
    final qualitiesListAsync = ref.watch(desireQualitiesListProvider);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 8, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title & subtitle
                const Text(
                  'Desired Qualities',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                    height: 1.2,
                  ),
                ),
                const SizedBox(height: 10),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 15,
                      color: AppColors.textSecondary,
                      height: 1.4,
                    ),
                    children: [
                      const TextSpan(text: 'Select up to $_maxQualities qualities you value the most in the choice of a life partner, aside from '),
                      TextSpan(
                        text: 'Godliness',
                        style: TextStyle(
                          color: AppColors.primary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),

                // Selection counter badge
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                  decoration: BoxDecoration(
                    color: qualities.isNotEmpty ? AppColors.primarySoft : AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(
                      color: qualities.isNotEmpty ? AppColors.primary.withOpacity(0.3) : AppColors.border,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        qualities.length >= 1 ? Icons.check_circle : Icons.radio_button_unchecked,
                        size: 18,
                        color: qualities.isNotEmpty ? AppColors.primary : AppColors.textMuted,
                      ),
                      const SizedBox(width: 8),
                      Text(
                        '${qualities.length} of $_maxQualities selected',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: qualities.isNotEmpty ? AppColors.primary : AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Premium Chips Grid
                qualitiesListAsync.when(
                  data: (allQualities) => Wrap(
                    spacing: 10,
                    runSpacing: 10,
                    children: allQualities.map((quality) {
                      final isSelected = qualities.contains(quality);
                      final canSelect = isSelected || qualities.length < _maxQualities;

                      return GestureDetector(
                        onTap: canSelect ? () {
                          HapticFeedback.lightImpact();
                          notifier.toggleQuality(quality);
                        } : null,
                        child: AnimatedContainer(
                          duration: const Duration(milliseconds: 200),
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: isSelected ? AppColors.primary : AppColors.surface,
                            borderRadius: BorderRadius.circular(25),
                            border: Border.all(
                              color: isSelected ? AppColors.primary : AppColors.border,
                              width: isSelected ? 2 : 1,
                            ),
                            boxShadow: isSelected ? [
                              BoxShadow(
                                color: AppColors.primary.withOpacity(0.2),
                                blurRadius: 8,
                                offset: const Offset(0, 2),
                              ),
                            ] : null,
                          ),
                          child: Text(
                            quality,
                            style: TextStyle(
                              fontSize: 14,
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                              color: isSelected ? Colors.white : (canSelect ? AppColors.textPrimary : AppColors.textMuted),
                            ),
                          ),
                        ),
                      );
                    }).toList(),
                  ),
                  loading: () => const Center(
                    child: Padding(
                      padding: EdgeInsets.all(40),
                      child: CircularProgressIndicator(),
                    ),
                  ),
                  error: (e, _) => Center(
                    child: Text('Error loading qualities: $e', style: TextStyle(color: AppColors.error)),
                  ),
                ),
              ],
            ),
          ),
        ),

        // Bottom CTA
        Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
          decoration: BoxDecoration(
            color: AppColors.background,
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.05),
                blurRadius: 10,
                offset: const Offset(0, -4),
              ),
            ],
          ),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: qualities.isNotEmpty ? onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: qualities.isNotEmpty ? AppColors.primary : AppColors.surfaceLight,
                foregroundColor: qualities.isNotEmpty ? Colors.white : AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                elevation: qualities.isNotEmpty ? 4 : 0,
                shadowColor: AppColors.primary.withOpacity(0.3),
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// STEP 5: PHOTOS (Integrated with MediaService)
// ============================================================================

class _PhotosStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const _PhotosStep({required this.onNext});

  @override
  ConsumerState<_PhotosStep> createState() => _PhotosStepState();
}

class _PhotosStepState extends ConsumerState<_PhotosStep> {
  bool _isUploading = false;
  int _uploadingIndex = -1;
  double _uploadProgress = 0;

  @override
  Widget build(BuildContext context) {
    final photos = ref.watch(datingProfileFormProvider.select((s) => s.photos));

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Add at least 2 photos of yourself. First impressions matter!',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.textSecondary,
                ),
          ),
          const SizedBox(height: AppSpacing.xl),
          Expanded(
            child: GridView.count(
              crossAxisCount: 2,
              crossAxisSpacing: AppSpacing.md,
              mainAxisSpacing: AppSpacing.md,
              children: List.generate(4, (index) {
                final hasPhoto = index < photos.length;
                final isThisUploading = _isUploading && _uploadingIndex == index;
                
                return _PhotoSlot(
                  photoUrl: hasPhoto ? photos[index] : null,
                  showLabel: index == 0 && !hasPhoto,
                  isUploading: isThisUploading,
                  uploadProgress: isThisUploading ? _uploadProgress : 0,
                  onAdd: () => _pickPhoto(index),
                  onRemove: hasPhoto && !_isUploading ? () => _removePhoto(index) : null,
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Text(
            '${photos.length}/4 photos added (min 2 required)',
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: photos.length >= 2 ? AppColors.accent : AppColors.textMuted,
                ),
          ),
          const SizedBox(height: AppSpacing.md),
          AppButton.primary(
            label: 'Next',
            onPressed: photos.length >= 2 && !_isUploading ? widget.onNext : null,
            isExpanded: true,
          ),
        ],
      ),
    );
  }

  Future<void> _pickPhoto(int index) async {
    final mediaService = ref.read(mediaServiceProvider);
    
    try {
      final file = await mediaService.pickImage(context);
      if (file == null) return;

      setState(() {
        _isUploading = true;
        _uploadingIndex = index;
        _uploadProgress = 0;
      });

      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');

      final url = await mediaService.uploadProfilePhoto(
        userId,
        file,
        photoIndex: index,
        onProgress: (progress) {
          setState(() => _uploadProgress = progress);
        },
      );

      ref.read(datingProfileFormProvider.notifier).addPhoto(url);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload photo: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadingIndex = -1;
        });
      }
    }
  }

  void _removePhoto(int index) {
    ref.read(datingProfileFormProvider.notifier).removePhoto(index);
  }
}

class _PhotoSlot extends StatelessWidget {
  final String? photoUrl;
  final bool showLabel;
  final bool isUploading;
  final double uploadProgress;
  final VoidCallback onAdd;
  final VoidCallback? onRemove;

  const _PhotoSlot({
    this.photoUrl,
    this.showLabel = false,
    this.isUploading = false,
    this.uploadProgress = 0,
    required this.onAdd,
    this.onRemove,
  });

  @override
  Widget build(BuildContext context) {
    if (isUploading) {
      return Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(
              value: uploadProgress,
              color: AppColors.primary,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              '${(uploadProgress * 100).toInt()}%',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (photoUrl != null) {
      return Stack(
        fit: StackFit.expand,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
            child: Image.network(
              photoUrl!,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                color: AppColors.surfaceDark,
                child: Icon(Icons.broken_image, color: AppColors.textMuted),
              ),
            ),
          ),
          if (onRemove != null)
            Positioned(
              top: 8,
              right: 8,
              child: GestureDetector(
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 18),
                ),
              ),
            ),
        ],
      );
    }

    return GestureDetector(
      onTap: onAdd,
      child: Container(
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(Icons.add, color: AppColors.primary, size: 28),
            ),
            if (showLabel) ...[
              const SizedBox(height: AppSpacing.sm),
              Text('Main Photo', style: TextStyle(color: AppColors.primary, fontSize: 12)),
            ],
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// STEP 6: AUDIO RECORDINGS (Figma Design - Questions Hidden Until Recording)
// ============================================================================

class _AudioRecordingsStep extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  const _AudioRecordingsStep({required this.onNext});

  @override
  ConsumerState<_AudioRecordingsStep> createState() => _AudioRecordingsStepState();
}

class _AudioRecordingsStepState extends ConsumerState<_AudioRecordingsStep>
    with SingleTickerProviderStateMixin {
  int _currentScreen = -1; // -1 = instructions, 0-2 = recording, 3 = preview
  bool _isRecording = false;
  bool _isUploading = false;
  bool _hasRecording = false;
  Duration _recordingDuration = Duration.zero;
  String? _currentRecordingPath;
  
  // Playback state
  bool _isPlaying = false;
  int _playingIndex = -1;
  final AudioPlayer _audioPlayer = AudioPlayer();
  
  // Animation for recording
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  static const _maxDuration = 60; // 60 seconds

  // Questions are only revealed when user reaches that step
  static const _questions = [
    'How would you describe your current relationship with God & why is this relationship important to you?\n(Please answer both parts of this question)',
    'What are your thoughts on the role of a husband and a wife in marriage?',
    'What are your favourite qualities or traits about yourself?\n(If you have a good sense of humor, this is also an opportunity to make a great impression on listeners by being creative with your response)',
  ];

  static const _questionTitles = [
    'How would you describe your current relationship with God and why is this relationship important to you?',
    'What are your thoughts on the role of a husband and a wife in marriage?',
    'What are your favourite qualities or traits about yourself?',
  ];
  
  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.1).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
    
    // Listen for audio completion
    _audioPlayer.onPlayerComplete.listen((_) {
      if (mounted) {
        setState(() {
          _isPlaying = false;
          _playingIndex = -1;
        });
      }
    });
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (_currentScreen == -1) return _buildInstructions();
    if (_currentScreen < 3) return _buildRecordingScreen(_currentScreen);
    return _buildPreviewScreen();
  }

  // ==========================================================================
  // INSTRUCTIONS PAGE - No questions revealed
  // ==========================================================================
  Widget _buildInstructions() {
    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'Audio Recordings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 24),
                
                // Instructions header
                const Text(
                  'Instructions',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 16),
                
                // Instructions text
                Text(
                  'Please record genuine responses to the questions you see on the subsequent screens. These three (3) questions are centered around your ',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                RichText(
                  text: TextSpan(
                    style: TextStyle(
                      fontSize: 14,
                      color: AppColors.textSecondary,
                      height: 1.6,
                    ),
                    children: [
                      TextSpan(
                        text: 'christian faith, marriage beliefs & personality',
                        style: TextStyle(
                          fontWeight: FontWeight.w700,
                          color: AppColors.primary,
                        ),
                      ),
                      const TextSpan(text: '.'),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                Text(
                  'Each response has a limit of 60 seconds and you will not be able to change your responses after your profile is completed. Your responses don\'t need to be perfect, they just need to be audible & authentic.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                
                Text(
                  'Remember that people value authenticity and most people can tell when a response feels rehearsed or scripted, so we recommend reflecting deeply on each question & responding from your heart. To avoid wondering why you\'re not getting matches, despite saying impressive things in your responses.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 20),
                
                Text(
                  'It is also obvious that any user who records gibberish or submits empty recordings will not be taken seriously by other users, and such profiles will be deleted.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                    height: 1.6,
                  ),
                ),
                const SizedBox(height: 28),
                
                Text(
                  'Happy Recording!',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ],
            ),
          ),
        ),
        
        // Bottom CTA
        Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () => setState(() => _currentScreen = 0),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: const Text(
                'Begin Recording',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // RECORDING SCREEN - Each question revealed one at a time
  // ==========================================================================
  Widget _buildRecordingScreen(int index) {
    return Column(
      children: [
        // Next button in header area
        Padding(
          padding: const EdgeInsets.only(right: 16, top: 8),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.end,
            children: [
              if (_hasRecording && !_isRecording)
                TextButton(
                  onPressed: () => _saveAndNext(index),
                  child: Text(
                    'Next',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: 16,
                    ),
                  ),
                ),
            ],
          ),
        ),
        
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
            child: Column(
              children: [
                const SizedBox(height: 20),
                
                // Question number badge
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 28),
                
                // Question text
                Text(
                  _questions[index],
                  style: const TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w500,
                    height: 1.5,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 40),
                
                // Timer display
                Text(
                  _formatDuration(_recordingDuration),
                  style: TextStyle(
                    fontSize: 48,
                    fontWeight: FontWeight.w300,
                    color: AppColors.textSecondary,
                    fontFeatures: const [FontFeature.tabularFigures()],
                  ),
                ),
                const SizedBox(height: 24),
                
                // Waveform visualization
                _buildWaveform(),
                const SizedBox(height: 50),
                
                // Recording controls
                _buildRecordingControls(index),
              ],
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildWaveform() {
    return Container(
      height: 60,
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: List.generate(35, (i) {
          // Generate varying heights for waveform bars
          final baseHeight = _isRecording ? 8.0 + (i % 5) * 8.0 : 4.0;
          final animatedHeight = _isRecording 
              ? baseHeight + ((_recordingDuration.inMilliseconds ~/ 100) % 3) * 4.0
              : (_hasRecording ? 8.0 + (i % 4) * 10.0 : baseHeight);
          
          return Container(
            width: 3,
            height: animatedHeight.clamp(4.0, 50.0),
            margin: const EdgeInsets.symmetric(horizontal: 2),
            decoration: BoxDecoration(
              color: (_isRecording || _hasRecording) 
                  ? AppColors.primary.withOpacity(0.4 + (i % 3) * 0.2)
                  : AppColors.textMuted.withOpacity(0.3),
              borderRadius: BorderRadius.circular(2),
            ),
          );
        }),
      ),
    );
  }

  Widget _buildRecordingControls(int index) {
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        // Restart/Refresh button
        GestureDetector(
          onTap: (_isRecording || _hasRecording) ? _restartRecording : null,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.refresh,
              color: (_isRecording || _hasRecording) ? AppColors.textSecondary : AppColors.textMuted,
              size: 26,
            ),
          ),
        ),
        const SizedBox(width: 32),
        
        // Main record/pause button
        GestureDetector(
          onTap: _isRecording ? _stopRecording : _startRecording,
          child: AnimatedBuilder(
            animation: _pulseAnimation,
            builder: (context, child) {
              return Transform.scale(
                scale: _isRecording ? _pulseAnimation.value : 1.0,
                child: Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    color: AppColors.primary,
                    shape: BoxShape.circle,
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 4),
                      ),
                    ],
                  ),
                  child: Icon(
                    _isRecording ? Icons.pause : Icons.mic,
                    color: Colors.white,
                    size: 36,
                  ),
                ),
              );
            },
          ),
        ),
        const SizedBox(width: 32),
        
        // Stop button (square)
        GestureDetector(
          onTap: _isRecording ? _stopRecording : null,
          child: Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Center(
              child: Container(
                width: 22,
                height: 22,
                decoration: BoxDecoration(
                  color: _isRecording ? AppColors.textSecondary : AppColors.textMuted,
                  borderRadius: BorderRadius.circular(4),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  // ==========================================================================
  // PREVIEW SCREEN - Your Responses
  // ==========================================================================
  Widget _buildPreviewScreen() {
    final audioUrls = ref.watch(datingProfileFormProvider.select((s) => s.audioUrls));
    final allComplete = audioUrls.every((url) => url != null);

    return Column(
      children: [
        Expanded(
          child: SingleChildScrollView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Title
                const Text(
                  'Audio Recordings',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Your Responses',
                  style: TextStyle(
                    fontSize: 15,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 28),
                
                // Response cards
                ...List.generate(3, (i) => _buildResponseCard(
                  index: i,
                  questionTitle: _questionTitles[i],
                  audioUrl: audioUrls[i],
                  onPlay: audioUrls[i] != null ? () => _playPreviewAudio(i) : null,
                  onReRecord: () => setState(() {
                    _currentScreen = i;
                    _hasRecording = false;
                    _currentRecordingPath = null;
                    _recordingDuration = Duration.zero;
                  }),
                )),
              ],
            ),
          ),
        ),
        
        // Bottom CTA
        Container(
          padding: EdgeInsets.fromLTRB(24, 16, 24, MediaQuery.of(context).padding.bottom + 16),
          child: SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: allComplete ? widget.onNext : null,
              style: ElevatedButton.styleFrom(
                backgroundColor: allComplete ? AppColors.primary : AppColors.surfaceLight,
                foregroundColor: allComplete ? Colors.white : AppColors.textMuted,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(30)),
                elevation: 0,
              ),
              child: const Text(
                'Complete Profile',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildResponseCard({
    required int index,
    required String questionTitle,
    String? audioUrl,
    VoidCallback? onPlay,
    required VoidCallback onReRecord,
  }) {
    final hasRecording = audioUrl != null;
    final isThisPlaying = _playingIndex == index && _isPlaying;
    
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Question number and title
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '${index + 1}. ',
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
              Expanded(
                child: Text(
                  questionTitle,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w500,
                    color: AppColors.textPrimary,
                    height: 1.4,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          
          // Waveform with play button
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              children: [
                // Play button
                GestureDetector(
                  onTap: hasRecording ? onPlay : onReRecord,
                  child: Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      hasRecording 
                          ? (isThisPlaying ? Icons.pause : Icons.play_arrow)
                          : Icons.mic,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                
                // Waveform
                Expanded(
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: List.generate(25, (i) {
                      final height = hasRecording 
                          ? 6.0 + (i % 4) * 8.0
                          : 4.0;
                      return Container(
                        width: 3,
                        height: height,
                        decoration: BoxDecoration(
                          color: hasRecording 
                              ? AppColors.primary.withOpacity(0.5 + (i % 3) * 0.15)
                              : AppColors.textMuted.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      );
                    }),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ==========================================================================
  // HELPER METHODS
  // ==========================================================================

  String _formatDuration(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    return '$minutes:$seconds';
  }

  Future<void> _startRecording() async {
    final mediaService = ref.read(mediaServiceProvider);
    
    final started = await mediaService.startRecording(
      maxDuration: _maxDuration,
      onDurationUpdate: (duration) {
        if (mounted) {
          setState(() => _recordingDuration = duration);
          
          // Auto-stop at max duration
          if (duration.inSeconds >= _maxDuration) {
            _stopRecording();
          }
        }
      },
    );

    if (started) {
      HapticFeedback.mediumImpact();
      _pulseController.repeat(reverse: true);
      setState(() {
        _isRecording = true;
        _hasRecording = false;
      });
    } else {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to start recording. Please check microphone permission.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _stopRecording() async {
    final mediaService = ref.read(mediaServiceProvider);
    final path = await mediaService.stopRecording();
    
    HapticFeedback.lightImpact();
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isRecording = false;
      _currentRecordingPath = path;
      _hasRecording = path != null;
    });
  }

  Future<void> _restartRecording() async {
    final mediaService = ref.read(mediaServiceProvider);
    
    if (_isRecording) {
      await mediaService.cancelRecording();
    }
    
    HapticFeedback.lightImpact();
    _pulseController.stop();
    _pulseController.reset();
    setState(() {
      _isRecording = false;
      _hasRecording = false;
      _recordingDuration = Duration.zero;
      _currentRecordingPath = null;
    });
  }

  Future<void> _playPreviewAudio(int index) async {
    HapticFeedback.lightImpact();
    
    // Get the audio URL from provider
    final audioUrls = ref.read(datingProfileFormProvider.select((s) => s.audioUrls));
    final audioUrl = audioUrls[index];
    
    if (audioUrl == null) return;
    
    try {
      if (_playingIndex == index && _isPlaying) {
        // Pause if already playing this track
        await _audioPlayer.pause();
        setState(() {
          _isPlaying = false;
          _playingIndex = -1;
        });
      } else {
        // Stop any current playback and play new track
        await _audioPlayer.stop();
        await _audioPlayer.play(UrlSource(audioUrl));
        setState(() {
          _playingIndex = index;
          _isPlaying = true;
        });
      }
    } catch (e) {
      debugPrint('Error playing audio: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to play audio'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  Future<void> _saveAndNext(int index) async {
    if (_currentRecordingPath == null) return;

    setState(() => _isUploading = true);

    try {
      final mediaService = ref.read(mediaServiceProvider);
      final userId = ref.read(currentUserIdProvider);
      if (userId == null) throw Exception('Not authenticated');

      final url = await mediaService.uploadAudioRecording(
        userId,
        _currentRecordingPath!,
        questionIndex: index + 1,
      );

      ref.read(datingProfileFormProvider.notifier).setAudioUrl(index, url);

      HapticFeedback.mediumImpact();
      setState(() {
        _recordingDuration = Duration.zero;
        _currentRecordingPath = null;
        _hasRecording = false;
        _currentScreen = index < 2 ? index + 1 : 3;
      });
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to upload: $e'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isUploading = false);
    }
  }
}

// ============================================================================
// PREMIUM AUDIO PREVIEW CARD
// ============================================================================

class _PremiumAudioPreviewCard extends StatelessWidget {
  final int number;
  final String title;
  final String? audioUrl;
  final bool isPlaying;
  final VoidCallback? onPlay;
  final VoidCallback onReRecord;

  const _PremiumAudioPreviewCard({
    required this.number,
    required this.title,
    this.audioUrl,
    this.isPlaying = false,
    this.onPlay,
    required this.onReRecord,
  });

  @override
  Widget build(BuildContext context) {
    final hasRecording = audioUrl != null;
    
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: hasRecording ? AppColors.success.withOpacity(0.3) : AppColors.border,
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Header row
          Row(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: BoxDecoration(
                  color: hasRecording ? AppColors.success.withOpacity(0.1) : AppColors.surfaceLight,
                  shape: BoxShape.circle,
                ),
                child: Center(
                  child: hasRecording
                      ? Icon(Icons.check, color: AppColors.success, size: 18)
                      : Text(
                          '$number',
                          style: TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                            color: AppColors.textMuted,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
              ),
              if (hasRecording)
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.success.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.check_circle, size: 14, color: AppColors.success),
                      const SizedBox(width: 4),
                      Text(
                        'Saved',
                        style: TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                          color: AppColors.success,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          const SizedBox(height: 16),
          
          // Audio controls row
          Row(
            children: [
              // Play button
              GestureDetector(
                onTap: hasRecording ? onPlay : null,
                child: Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    gradient: hasRecording ? AppColors.primaryGradient : null,
                    color: hasRecording ? null : AppColors.surfaceLight,
                    shape: BoxShape.circle,
                    boxShadow: hasRecording ? [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ] : null,
                  ),
                  child: Icon(
                    isPlaying ? Icons.pause : Icons.play_arrow,
                    color: hasRecording ? Colors.white : AppColors.textMuted,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 14),
              
              // Waveform placeholder
              Expanded(
                child: Container(
                  height: 40,
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: hasRecording
                        ? List.generate(20, (i) => Container(
                            width: 3,
                            height: 8 + (i % 4) * 6.0,
                            margin: const EdgeInsets.symmetric(horizontal: 2),
                            decoration: BoxDecoration(
                              color: isPlaying 
                                  ? AppColors.primary.withOpacity(0.3 + (i % 3) * 0.2)
                                  : AppColors.textMuted.withOpacity(0.3),
                              borderRadius: BorderRadius.circular(2),
                            ),
                          ))
                        : [
                            Icon(Icons.mic_off, color: AppColors.textMuted, size: 20),
                            const SizedBox(width: 8),
                            Text(
                              'No recording yet',
                              style: TextStyle(
                                fontSize: 13,
                                color: AppColors.textMuted,
                              ),
                            ),
                          ],
                  ),
                ),
              ),
              const SizedBox(width: 14),
              
              // Re-record button
              OutlinedButton.icon(
                onPressed: onReRecord,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
                ),
                icon: Icon(Icons.refresh, size: 16),
                label: Text(
                  hasRecording ? 'Re-record' : 'Record',
                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// STEP 7: CONTACT INFORMATION
// ============================================================================

class _ContactInfoStep extends ConsumerStatefulWidget {
  final VoidCallback onComplete;
  const _ContactInfoStep({required this.onComplete});

  @override
  ConsumerState<_ContactInfoStep> createState() => _ContactInfoStepState();
}

class _ContactInfoStepState extends ConsumerState<_ContactInfoStep> {
  final _instagramController = TextEditingController();
  final _twitterController = TextEditingController();
  final _whatsappController = TextEditingController();
  final _facebookController = TextEditingController();
  final _telegramController = TextEditingController();
  final _snapchatController = TextEditingController();

  String _selectedCountryCode = '+234';

  static const _countryCodes = ['+234', '+233', '+254', '+27', '+1', '+44', '+49'];

  @override
  void initState() {
    super.initState();
    final state = ref.read(datingProfileFormProvider);
    _instagramController.text = state.instagramUsername ?? '';
    _twitterController.text = state.twitterUsername ?? '';
    _whatsappController.text = state.whatsappNumber ?? '';
    _facebookController.text = state.facebookUsername ?? '';
    _telegramController.text = state.telegramUsername ?? '';
    _snapchatController.text = state.snapchatUsername ?? '';
  }

  @override
  void dispose() {
    _instagramController.dispose();
    _twitterController.dispose();
    _whatsappController.dispose();
    _facebookController.dispose();
    _telegramController.dispose();
    _snapchatController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final state = ref.watch(datingProfileFormProvider);
    final notifier = ref.read(datingProfileFormProvider.notifier);
    final isValid = state.isStep7Complete;

    return Padding(
      padding: const EdgeInsets.all(AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share your contact details so potential matches can reach out.',
            style: Theme.of(context).textTheme.bodyMedium?.copyWith(color: AppColors.textSecondary),
          ),
          const SizedBox(height: AppSpacing.lg),
          Expanded(
            child: ListView(
              children: [
                _buildSocialInput(_instagramController, Icons.camera_alt_outlined, 'Instagram', (v) => notifier.setInstagram(v.isEmpty ? null : v)),
                const SizedBox(height: AppSpacing.md),
                _buildSocialInput(_twitterController, Icons.alternate_email, 'X (Twitter)', (v) => notifier.setTwitter(v.isEmpty ? null : v)),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(color: AppColors.border),
                        borderRadius: BorderRadius.circular(AppSpacing.radiusMd),
                      ),
                      padding: const EdgeInsets.symmetric(horizontal: 8),
                      child: DropdownButtonHideUnderline(
                        child: DropdownButton<String>(
                          value: _selectedCountryCode,
                          items: _countryCodes.map((c) => DropdownMenuItem(value: c, child: Text(c))).toList(),
                          onChanged: (v) => setState(() => _selectedCountryCode = v!),
                        ),
                      ),
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: TextField(
                        controller: _whatsappController,
                        keyboardType: TextInputType.phone,
                        decoration: InputDecoration(
                          prefixIcon: Icon(Icons.phone_android, color: Colors.green),
                          labelText: 'WhatsApp',
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
                        ),
                        onChanged: (v) => notifier.setWhatsapp(v.isEmpty ? null : '$_selectedCountryCode$v'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                _buildSocialInput(_facebookController, Icons.facebook, 'Facebook', (v) => notifier.setFacebook(v.isEmpty ? null : v), iconColor: Colors.blue),
                const SizedBox(height: AppSpacing.md),
                _buildSocialInput(_telegramController, Icons.send, 'Telegram', (v) => notifier.setTelegram(v.isEmpty ? null : v), iconColor: Colors.lightBlue),
                const SizedBox(height: AppSpacing.md),
                _buildSocialInput(_snapchatController, Icons.camera, 'Snapchat', (v) => notifier.setSnapchat(v.isEmpty ? null : v), iconColor: Colors.yellow.shade700),
              ],
            ),
          ),
          AppButton.primary(
            label: state.isSaving ? 'Saving...' : 'Complete Profile',
            onPressed: isValid && !state.isSaving ? widget.onComplete : null,
            isLoading: state.isSaving,
            isExpanded: true,
          ),
        ],
      ),
    );
  }

  Widget _buildSocialInput(TextEditingController controller, IconData icon, String label, ValueChanged<String> onChanged, {Color? iconColor}) {
    return TextField(
      controller: controller,
      decoration: InputDecoration(
        prefixIcon: Icon(icon, color: iconColor ?? AppColors.textSecondary),
        labelText: label,
        border: OutlineInputBorder(borderRadius: BorderRadius.circular(AppSpacing.radiusMd)),
      ),
      onChanged: onChanged,
    );
  }
}
