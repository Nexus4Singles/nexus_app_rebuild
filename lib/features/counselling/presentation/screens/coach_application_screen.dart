import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:country_picker/country_picker.dart';
import 'package:file_picker/file_picker.dart';
import 'dart:io';

import 'package:firebase_storage/firebase_storage.dart';
import '../../../../core/router/safe_nav.dart';
import 'dart:typed_data';

import '../../../../core/theme/theme.dart';
import '../../application/coach_application_service.dart';

/// Widget for uploading a PDF file (credentials, certifications, etc.)
Widget _buildPdfUploadWidget({
  required String label,
  required File? file,
  required VoidCallback onTap,
  required VoidCallback onRemove,
  required BuildContext context,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      if (file == null)
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onTap,
          child: Container(
            height: 60,
            decoration: BoxDecoration(
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 2,
              ),
              borderRadius: BorderRadius.circular(12),
              color: AppColors.primary.withOpacity(0.05),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(
                  Icons.upload_file,
                  color: AppColors.primary.withOpacity(0.6),
                  size: 24,
                ),
                const SizedBox(width: 12),
                Text(
                  'Tap to upload PDF',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        )
      else
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            border: Border.all(color: AppColors.primary),
            borderRadius: BorderRadius.circular(10),
            color: AppColors.primary.withOpacity(0.05),
          ),
          child: Row(
            children: [
              Icon(Icons.picture_as_pdf, color: Colors.red, size: 24),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  file.path.split('/').last,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onRemove,
                child: Container(
                  padding: const EdgeInsets.all(8),
                  child: Icon(
                    Icons.close,
                    color: Colors.red.shade400,
                    size: 20,
                  ),
                ),
              ),
            ],
          ),
        ),
    ],
  );
}

// State Management
final coachApplicationProvider =
    StateNotifierProvider<CoachApplicationNotifier, CoachApplication>((ref) {
      return CoachApplicationNotifier();
    });

class CoachApplicationNotifier extends StateNotifier<CoachApplication> {
  CoachApplicationNotifier() : super(CoachApplication());

  void updateApplication(CoachApplication newApplication) {
    state = newApplication;
  }

  void setFullName(String value) {
    if (value.isEmpty) {
      state = state.copyWith(fullName: null);
    } else {
      final filtered = value.replaceAll(RegExp(r'[^a-zA-Z ]'), '');
      final cap =
          filtered.isNotEmpty
              ? filtered[0].toUpperCase() + filtered.substring(1)
              : '';
      state = state.copyWith(fullName: cap);
    }
  }

  void setEmail(String value) =>
      state = state.copyWith(email: value.isEmpty ? null : value);

  void setPhoneNumber(String value) =>
      state = state.copyWith(phoneNumber: value.isEmpty ? null : value);

  void setGender(String? value) => state = state.copyWith(gender: value);

  void setNationality(String? value) {
    if (value == null || value.isEmpty) {
      state = state.copyWith(nationality: null);
    } else {
      final cap = value[0].toUpperCase() + value.substring(1);
      state = state.copyWith(nationality: cap);
    }
  }

  void setCity(String value) {
    if (value.isEmpty) {
      state = state.copyWith(residenceLocation: null);
    } else {
      final filtered = value.replaceAll(RegExp(r'[^a-zA-Z ]'), '');
      final cap =
          filtered.isNotEmpty
              ? filtered[0].toUpperCase() + filtered.substring(1)
              : '';
      state = state.copyWith(residenceLocation: cap);
    }
  }

  void setYearsOfExperience(int value) {
    final safeValue = value < 5 ? 5 : value;
    state = state.copyWith(yearsOfExperience: safeValue);
  }

  void setCountryOfResidence(String? value) {
    // Store country separately
    state = state.copyWith(country: value);
  }

  void setTitle(String? value) => state = state.copyWith(title: value);

  void setMaritalStatus(String? value) =>
      state = state.copyWith(maritalStatus: value);

  void setCredentials(String value) {
    if (value.isEmpty) {
      state = state.copyWith(credentials: null);
    } else {
      final cap = value[0].toUpperCase() + value.substring(1);
      state = state.copyWith(credentials: cap);
    }
  }

  void setSpecializations(List<String> value) =>
      state = state.copyWith(specializations: value);

  void setCareerAchievements(String value) {
    if (value.isEmpty) {
      state = state.copyWith(coachingPhilosophy: null);
    } else {
      final cap = value[0].toUpperCase() + value.substring(1);
      state = state.copyWith(coachingPhilosophy: cap);
    }
  }

  void setInstagramHandle(String value) =>
      state = state.copyWith(instagramHandle: value.isEmpty ? null : value);

  void setLinkedinProfile(String value) =>
      state = state.copyWith(linkedinProfile: value.isEmpty ? null : value);

  void setProfilePhoto(File? file) =>
      state = state.copyWith(profilePhoto: file);

  void setCredentialsPdf(File? file) =>
      state = state.copyWith(credentialsPdf: file);

  bool isFormValid() {
    return state.fullName != null &&
        state.fullName!.isNotEmpty &&
        _isValidEmail(state.email) &&
        _isValidPhoneNumber(state.phoneNumber) &&
        state.gender != null &&
        state.nationality != null &&
        state.residenceLocation != null &&
        state.title != null &&
        state.yearsOfExperience != null &&
        state.maritalStatus != null &&
        state.credentials != null &&
        state.credentials!.isNotEmpty &&
        state.profilePhoto != null;
  }

  bool _isValidEmail(String? email) {
    if (email == null || email.isEmpty) return false;
    final emailRegex = RegExp(r'^[^@]+@[^@]+\.[^@]+$');
    return emailRegex.hasMatch(email);
  }

  bool _isValidPhoneNumber(String? phone) {
    if (phone == null || phone.isEmpty) return false;
    final digitsOnly = phone.replaceAll(RegExp(r'[^\d]'), '');
    return digitsOnly.length >= 10;
  }
}

// Main Screen
class CoachApplicationScreen extends ConsumerStatefulWidget {
  const CoachApplicationScreen({super.key});

  @override
  ConsumerState<CoachApplicationScreen> createState() =>
      _CoachApplicationScreenState();
}

class _CoachApplicationScreenState
    extends ConsumerState<CoachApplicationScreen> {
  late PageController _pageController;
  int _currentPage = 0;

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

  void _nextPage() {
    if (_currentPage < 3) {
      _pageController.nextPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  void _previousPage() {
    if (_currentPage > 0) {
      _pageController.previousPage(
        duration: const Duration(milliseconds: 300),
        curve: Curves.easeInOut,
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () {
            navigateBackToHome(context);
          },
        ),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [
            Text(
              'Call for Applications',
              style: AppTextStyles.headlineSmall.copyWith(
                fontWeight: FontWeight.w700,
              ),
            ),
            Text(
              'Join our Counselling Team',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          // Progress Indicator
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 16),
            child: Row(
              children: List.generate(4, (index) {
                final isCompleted = index < _currentPage;
                final isCurrent = index == _currentPage;

                return Expanded(
                  child: Container(
                    height: 4,
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(2),
                      color:
                          isCompleted || isCurrent
                              ? AppColors.primary
                              : AppColors.getBorder(context),
                    ),
                  ),
                );
              }),
            ),
          ),

          // Form Pages
          Expanded(
            child: PageView(
              controller: _pageController,
              onPageChanged: (page) {
                setState(() => _currentPage = page);
              },
              children: [
                _PersonalInfoPage(onNext: _nextPage),
                _ProfessionalBackgroundPage(
                  onNext: _nextPage,
                  onPrev: _previousPage,
                ),
                _QualificationsPage(onNext: _nextPage, onPrev: _previousPage),
                _MediaPage(onPrev: _previousPage),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Page 1: Personal Information
class _PersonalInfoPage extends ConsumerStatefulWidget {
  final VoidCallback onNext;

  const _PersonalInfoPage({required this.onNext});

  @override
  ConsumerState<_PersonalInfoPage> createState() => _PersonalInfoPageState();
}

class _PersonalInfoPageState extends ConsumerState<_PersonalInfoPage> {
  late TextEditingController _fullNameController;
  late TextEditingController _emailController;
  late TextEditingController _phoneController;

  @override
  void initState() {
    super.initState();
    final application = ref.read(coachApplicationProvider);
    _fullNameController = TextEditingController(
      text: application.fullName ?? '',
    );
    _emailController = TextEditingController(text: application.email ?? '');
    _phoneController = TextEditingController(
      text: application.phoneNumber ?? '',
    );
  }

  @override
  void dispose() {
    _fullNameController.dispose();
    _emailController.dispose();
    _phoneController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final application = ref.watch(coachApplicationProvider);
    final notifier = ref.read(coachApplicationProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Personal Information',
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Let\'s start with your basic details',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 24),

          // Title Dropdown
          _buildDropdown(
            label: 'Title',
            value: application.title,
            items: ['Dr.', 'Mr.', 'Mrs.', 'Ms.', 'Prof.'],
            onChanged: (value) => notifier.setTitle(value),
            context: context,
          ),
          const SizedBox(height: 16),

          // Full Name
          _buildTextFieldWithController(
            label: 'Full Name',
            controller: _fullNameController,
            onChanged: (value) => notifier.setFullName(value),
            hint: 'Your full name',
            context: context,
          ),
          const SizedBox(height: 16),

          // Email
          _buildTextFieldWithController(
            label: 'Email Address',
            controller: _emailController,
            onChanged: (value) => notifier.setEmail(value),
            hint: 'your.email@example.com',
            keyboardType: TextInputType.emailAddress,
            context: context,
          ),
          const SizedBox(height: 16),

          // Phone Number with validation
          _buildPhoneNumberFieldWithController(
            label: 'Phone Number',
            controller: _phoneController,
            onChanged: (value) => notifier.setPhoneNumber(value),
            context: context,
          ),
          const SizedBox(height: 16),

          // Gender (without "Other")
          _buildDropdown(
            label: 'Gender',
            value: application.gender,
            items: ['Male', 'Female'],
            onChanged: (value) => notifier.setGender(value),
            context: context,
          ),
          const SizedBox(height: 24),

          // Next Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed: () {
                final isEmailValid = notifier._isValidEmail(application.email);
                final isPhoneValid = notifier._isValidPhoneNumber(
                  application.phoneNumber,
                );
                if (application.title != null &&
                    application.fullName != null &&
                    application.fullName!.isNotEmpty &&
                    isEmailValid &&
                    isPhoneValid &&
                    application.gender != null) {
                  widget.onNext();
                } else {
                  String errorMsg = 'Please fill all fields correctly.';
                  if (!isEmailValid && application.email != null) {
                    errorMsg = 'Please enter a valid email address.';
                  } else if (!isPhoneValid && application.phoneNumber != null) {
                    errorMsg =
                        'Please enter a valid phone number with at least 10 digits and country code.';
                  }
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text(
                'Next',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Page 2: Professional Background
class _ProfessionalBackgroundPage extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _ProfessionalBackgroundPage({
    required this.onNext,
    required this.onPrev,
  });

  @override
  ConsumerState<_ProfessionalBackgroundPage> createState() =>
      _ProfessionalBackgroundPageState();
}

class _ProfessionalBackgroundPageState
    extends ConsumerState<_ProfessionalBackgroundPage> {
  late TextEditingController _cityController;

  @override
  void initState() {
    super.initState();
    final application = ref.read(coachApplicationProvider);
    _cityController = TextEditingController(
      text: application.residenceLocation ?? '',
    );
  }

  @override
  void dispose() {
    _cityController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final application = ref.watch(coachApplicationProvider);
    final notifier = ref.read(coachApplicationProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Professional Background',
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Tell us about your professional experience',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 24),

          // Nationality - Country Picker
          _buildCountryPickerField(
            label: 'Nationality',
            value: application.nationality,
            onChanged: (country) => notifier.setNationality(country?.name),
            context: context,
          ),
          const SizedBox(height: 16),

          // City
          _buildTextFieldWithController(
            label: 'City',
            controller: _cityController,
            onChanged: (value) => notifier.setCity(value),
            hint: 'Your city',
            context: context,
          ),
          const SizedBox(height: 16),

          // Country of Residence - Country Picker
          _buildCountryPickerField(
            label: 'Country of Residence',
            value: application.country,
            onChanged:
                (country) => notifier.setCountryOfResidence(country?.name),
            context: context,
          ),
          const SizedBox(height: 16),

          // Years of Experience
          _buildNumberField(
            label: 'Years of Experience',
            value: application.yearsOfExperience ?? 0,
            onChanged: (value) => notifier.setYearsOfExperience(value),
            context: context,
          ),
          const SizedBox(height: 16),

          // Marital Status (removed "Separated")
          _buildDropdown(
            label: 'Marital Status',
            value: application.maritalStatus,
            items: ['Single', 'Married', 'Divorced', 'Widowed'],
            onChanged: (value) => notifier.setMaritalStatus(value),
            context: context,
          ),
          const SizedBox(height: 24),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onPrev,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (application.nationality != null &&
                        application.residenceLocation != null &&
                        application.yearsOfExperience != null &&
                        application.maritalStatus != null) {
                      widget.onNext();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please fill all fields'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Page 3: Qualifications & Philosophy
class _QualificationsPage extends ConsumerStatefulWidget {
  final VoidCallback onNext;
  final VoidCallback onPrev;

  const _QualificationsPage({required this.onNext, required this.onPrev});

  @override
  ConsumerState<_QualificationsPage> createState() =>
      _QualificationsPageState();
}

class _QualificationsPageState extends ConsumerState<_QualificationsPage> {
  late TextEditingController _credentialsController;
  late TextEditingController _achievementsController;
  late TextEditingController _instagramController;
  late TextEditingController _linkedinController;

  @override
  void initState() {
    super.initState();
    final application = ref.read(coachApplicationProvider);
    _credentialsController = TextEditingController(
      text: application.credentials ?? '',
    );
    _achievementsController = TextEditingController(
      text: application.coachingPhilosophy ?? '',
    );
    _instagramController = TextEditingController(
      text: application.instagramHandle ?? '',
    );
    _linkedinController = TextEditingController(
      text: application.linkedinProfile ?? '',
    );
  }

  @override
  void dispose() {
    _credentialsController.dispose();
    _achievementsController.dispose();
    _instagramController.dispose();
    _linkedinController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final application = ref.watch(coachApplicationProvider);
    final notifier = ref.read(coachApplicationProvider.notifier);

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Qualifications & Expertise',
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your credentials and coaching philosophy',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 24),

          // Credentials
          _buildTextFieldWithController(
            label: 'Credentials & Certifications',
            controller: _credentialsController,
            onChanged: (value) {
              if (value.isNotEmpty) {
                final capitalized = value[0].toUpperCase() + value.substring(1);
                notifier.setCredentials(capitalized);
              } else {
                notifier.setCredentials(value);
              }
            },
            hint: 'e.g., M.A. in Marriage & Family Therapy, LMFT License #...',
            maxLines: 3,
            context: context,
          ),
          const SizedBox(height: 16),

          // Career Achievements (optional)
          _buildTextFieldWithController(
            label: 'Career Achievements',
            controller: _achievementsController,
            onChanged: (value) {
              if (value.isNotEmpty) {
                final capitalized = value[0].toUpperCase() + value.substring(1);
                notifier.setCareerAchievements(capitalized);
              } else {
                notifier.setCareerAchievements(value);
              }
            },
            hint:
                'Write a compelling description of any achievements or milestones you have had in your coaching career, if any.',
            maxLines: 4,
            context: context,
            isOptional: true,
          ),
          const SizedBox(height: 16),

          // Social Media (Optional)
          const SizedBox(height: 12),
          _buildTextFieldWithController(
            label: 'Social Media Handles',
            controller: _instagramController,
            onChanged: (value) => notifier.setInstagramHandle(value),
            hint: '@yourhandle',
            context: context,
            isOptional: true,
          ),
          const SizedBox(height: 12),
          _buildTextFieldWithController(
            label: 'LinkedIn Profile URL',
            controller: _linkedinController,
            onChanged: (value) => notifier.setLinkedinProfile(value),
            hint: 'https://linkedin.com/in/yourprofile',
            keyboardType: TextInputType.url,
            context: context,
            isOptional: true,
          ),
          const SizedBox(height: 24),

          // Navigation Buttons
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: widget.onPrev,
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    side: BorderSide(color: AppColors.primary),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: Text(
                    'Back',
                    style: TextStyle(
                      fontSize: 16,
                      fontWeight: FontWeight.w600,
                      color: AppColors.primary,
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: ElevatedButton(
                  onPressed: () {
                    if (application.credentials != null &&
                        application.credentials!.isNotEmpty) {
                      widget.onNext();
                    } else {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text('Please fill credentials field'),
                          backgroundColor: AppColors.primary,
                        ),
                      );
                    }
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                  child: const Text(
                    'Next',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w600),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// Page 4: Media & Submit
class _MediaPage extends ConsumerStatefulWidget {
  final VoidCallback onPrev;

  const _MediaPage({required this.onPrev});

  @override
  ConsumerState<_MediaPage> createState() => _MediaPageState();
}

class _MediaPageState extends ConsumerState<_MediaPage> {
  bool _isSubmitting = false;

  @override
  Widget build(BuildContext context) {
    final application = ref.watch(coachApplicationProvider);
    final notifier = ref.read(coachApplicationProvider.notifier);
    final imagePicker = ImagePicker();

    return SingleChildScrollView(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Attachments & Submission',
            style: AppTextStyles.headlineSmall.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Upload your profile photo and credentials',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 24),

          // Profile Photo Upload
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.orange.shade50,
              border: Border.all(color: Colors.orange.shade300),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.warning_rounded,
                  color: Colors.orange.shade700,
                  size: 20,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Please upload a nice professional picture as this would be used to create your profile. AI-generated pictures are not acceptable and using them could invalidate your application.',
                    style: TextStyle(
                      color: Colors.orange.shade700,
                      fontSize: 12,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          _buildPhotoUploadWidget(
            label: 'Profile Photo *',
            file: application.profilePhoto,
            onTap: () async {
              final photo = await imagePicker.pickImage(
                source: ImageSource.gallery,
                imageQuality: 90,
              );
              if (photo != null) {
                notifier.setProfilePhoto(File(photo.path));
              }
            },
            onRemove: () => notifier.setProfilePhoto(null),
            context: context,
          ),
          const SizedBox(height: 24),

          // Credentials PDF Upload (Optional)
          _buildPdfUploadWidget(
            label: 'Credentials PDF (Optional)',
            file: application.credentialsPdf,
            onTap: () async {
              try {
                final result = await FilePicker.platform
                    .pickFiles(
                      type: FileType.custom,
                      allowedExtensions: ['pdf'],
                    )
                    .timeout(
                      const Duration(seconds: 30),
                      onTimeout: () {
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'File picker timed out. Please try again.',
                              ),
                              backgroundColor: Color(0xFFD32F2F),
                            ),
                          );
                        }
                        return null;
                      },
                    );
                if (result != null && result.files.isNotEmpty) {
                  notifier.setCredentialsPdf(File(result.files.first.path!));
                }
              } catch (e) {
                if (mounted) {
                  final errorMsg =
                      e.toString().contains('MissingPluginException')
                          ? 'File picker not available on this platform. Try uploading from device storage.'
                          : 'Error selecting PDF: $e';
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(errorMsg),
                      backgroundColor: AppColors.primary,
                    ),
                  );
                }
              }
            },
            onRemove: () => notifier.setCredentialsPdf(null),
            context: context,
          ),
          const SizedBox(height: 32),

          // Info Box
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Your application will be reviewed by our team. We\'ll provide a feedback you within 10 business days.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),

          // Submit Button
          SizedBox(
            width: double.infinity,
            child: ElevatedButton(
              onPressed:
                  _isSubmitting
                      ? null
                      : () async {
                        print('[DEBUG] Submit button pressed.');
                        if (application.profilePhoto == null) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: const Text(
                                'Please upload a profile photo',
                              ),
                              backgroundColor: AppColors.primary,
                            ),
                          );
                          print(
                            '[DEBUG] Submission blocked: profile photo missing.',
                          );
                          return;
                        }

                        setState(() => _isSubmitting = true);

                        try {
                          print('[DEBUG] Starting async submission...');
                          await ref.read(
                            coachApplicationSubmissionProvider(
                              application,
                            ).future,
                          );

                          if (mounted) {
                            print(
                              '[DEBUG] Submission success, showing snackbar.',
                            );
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: const Text(
                                  'Application submitted successfully!',
                                ),
                                backgroundColor: AppColors.success,
                              ),
                            );
                            Future.delayed(const Duration(seconds: 2), () {
                              if (!mounted) return;
                              // Dismiss keyboard before navigation
                              FocusScope.of(context).unfocus();
                              if (Navigator.of(context).canPop()) {
                                Navigator.pop(context);
                              } else {
                                Navigator.of(
                                  context,
                                ).popUntil((route) => route.isFirst);
                              }
                            });
                          }
                        } catch (e, stack) {
                          print('[ERROR] Submission failed: $e');
                          print(stack);
                          if (mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              SnackBar(
                                content: Text('Error: $e'),
                                backgroundColor: AppColors.primary,
                              ),
                            );
                          }
                        } finally {
                          if (mounted) {
                            setState(() => _isSubmitting = false);
                          }
                        }
                      },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                disabledBackgroundColor: AppColors.primary.withOpacity(0.5),
                padding: const EdgeInsets.symmetric(vertical: 16),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child:
                  _isSubmitting
                      ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            Colors.white,
                          ),
                        ),
                      )
                      : const Text(
                        'Submit Application',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

// Helper Widgets

Widget _buildTextFieldWithController({
  required String label,
  required TextEditingController controller,
  required Function(String) onChanged,
  required BuildContext context,
  String? hint,
  TextInputType keyboardType = TextInputType.text,
  int maxLines = 1,
  bool isOptional = false,
}) {
  // Determine inputFormatters and onChanged for specific fields
  List<TextInputFormatter>? inputFormatters;
  Function(String)? effectiveOnChanged = onChanged;
  if (label == 'Full Name' || label == 'City') {
    // Only allow alphabetic and space, and auto-capitalize first letter
    inputFormatters = [FilteringTextInputFormatter.allow(RegExp(r'[a-zA-Z ]'))];
    effectiveOnChanged = (value) {
      String filtered = value.replaceAll(RegExp(r'[^a-zA-Z ]'), '');
      String cap =
          filtered.isNotEmpty
              ? filtered[0].toUpperCase() + filtered.substring(1)
              : '';
      controller.value = controller.value.copyWith(
        text: cap,
        selection: TextSelection.collapsed(offset: cap.length),
      );
      onChanged(cap);
    };
  } else if (label == 'Credentials & Certifications' ||
      label == 'Career Achievements') {
    // Auto-capitalize first letter only
    effectiveOnChanged = (value) {
      String cap =
          value.isNotEmpty ? value[0].toUpperCase() + value.substring(1) : '';
      controller.value = controller.value.copyWith(
        text: cap,
        selection: TextSelection.collapsed(offset: cap.length),
      );
      onChanged(cap);
    };
  }
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        isOptional ? '$label (Optional)' : label,
        style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        onChanged: effectiveOnChanged,
        keyboardType: keyboardType,
        maxLines: maxLines,
        textDirection: TextDirection.ltr,
        textAlignVertical: TextAlignVertical.center,
        inputFormatters: inputFormatters,
        decoration: InputDecoration(
          hintText: hint,
          filled: true,
          fillColor: AppColors.getSurface(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.getBorder(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.getBorder(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: AppTextStyles.bodyMedium,
      ),
    ],
  );
}

Widget _buildPhoneNumberFieldWithController({
  required String label,
  required TextEditingController controller,
  required Function(String) onChanged,
  required BuildContext context,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      TextField(
        controller: controller,
        onChanged: onChanged,
        keyboardType: TextInputType.phone,
        inputFormatters: [FilteringTextInputFormatter.allow(RegExp(r'[0-9+]'))],
        maxLength: 20,
        decoration: InputDecoration(
          hintText: '+1 (555) 123-4567',
          helperText:
              'Include country code (e.g., +1 for USA, +234 for Nigeria)',
          counterText: '',
          filled: true,
          fillColor: AppColors.getSurface(context),
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.getBorder(context)),
          ),
          enabledBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.getBorder(context)),
          ),
          focusedBorder: OutlineInputBorder(
            borderRadius: BorderRadius.circular(10),
            borderSide: BorderSide(color: AppColors.primary, width: 2),
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 14,
          ),
        ),
        style: AppTextStyles.bodyMedium,
      ),
    ],
  );
}

Widget _buildDropdown({
  required String label,
  required String? value,
  required List<String> items,
  required Function(String?) onChanged,
  required BuildContext context,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Container(
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          border: Border.all(color: AppColors.getBorder(context)),
          borderRadius: BorderRadius.circular(10),
        ),
        child: DropdownButton<String>(
          value: value,
          items:
              items.map((item) {
                return DropdownMenuItem<String>(
                  value: item,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    child: Text(item, style: AppTextStyles.bodyMedium),
                  ),
                );
              }).toList(),
          onChanged: onChanged,
          isExpanded: true,
          underline: const SizedBox(),
          hint: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'Select $label',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ),
        ),
      ),
    ],
  );
}

Widget _buildCountryPickerField({
  required String label,
  required String? value,
  required Function(Country?) onChanged,
  required BuildContext context,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      GestureDetector(
        onTap: () {
          showCountryPicker(
            context: context,
            showPhoneCode: false,
            onSelect: onChanged,
          );
        },
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            border: Border.all(color: AppColors.getBorder(context)),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                value ?? 'Select country',
                style: AppTextStyles.bodyMedium.copyWith(
                  color:
                      value == null
                          ? AppColors.getTextSecondary(context)
                          : null,
                ),
              ),
              Icon(Icons.arrow_drop_down, color: AppColors.primary),
            ],
          ),
        ),
      ),
    ],
  );
}

Widget _buildNumberField({
  required String label,
  required int value,
  required Function(int) onChanged,
  required BuildContext context,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      Row(
        children: [
          IconButton(
            onPressed: value > 5 ? () => onChanged(value - 1) : null,
            icon: const Icon(Icons.remove_circle_outline),
            color: AppColors.primary,
          ),
          Expanded(
            child: TextField(
              controller: TextEditingController(text: value.toString()),
              onChanged: (val) {
                int intVal = int.tryParse(val) ?? 5;
                if (intVal < 5) intVal = 5;
                onChanged(intVal);
              },
              keyboardType: TextInputType.number,
              textAlign: TextAlign.center,
              decoration: InputDecoration(
                filled: true,
                fillColor: AppColors.getSurface(context),
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                  borderSide: BorderSide(color: AppColors.getBorder(context)),
                ),
              ),
              style: AppTextStyles.bodyMedium,
            ),
          ),
          IconButton(
            onPressed: () => onChanged(value + 1),
            icon: const Icon(Icons.add_circle_outline),
            color: AppColors.primary,
          ),
        ],
      ),
    ],
  );
}

Widget _buildPhotoUploadWidget({
  required String label,
  required File? file,
  required VoidCallback onTap,
  required VoidCallback onRemove,
  required BuildContext context,
}) {
  return Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Text(
        label,
        style: AppTextStyles.labelLarge.copyWith(fontWeight: FontWeight.w600),
      ),
      const SizedBox(height: 8),
      file == null
          ? GestureDetector(
            onTap: onTap,
            child: Container(
              height: 150,
              decoration: BoxDecoration(
                border: Border.all(
                  color: AppColors.primary.withOpacity(0.3),
                  width: 2,
                ),
                borderRadius: BorderRadius.circular(12),
                color: AppColors.primary.withOpacity(0.05),
              ),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(
                    Icons.image_outlined,
                    size: 48,
                    color: AppColors.primary.withOpacity(0.6),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: 120,
                    child: Text(
                      'Tap to upload photo',
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.primary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
          : Stack(
            children: [
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: Image.file(
                  file,
                  height: 150,
                  width: double.infinity,
                  fit: BoxFit.cover,
                ),
              ),
              Positioned(
                top: 8,
                right: 8,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: onRemove,
                  child: Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: Colors.black54,
                      shape: BoxShape.circle,
                    ),
                    child: Center(
                      child: Icon(Icons.close, color: Colors.white, size: 20),
                    ),
                  ),
                ),
              ),
            ],
          ),
    ],
  );
}
