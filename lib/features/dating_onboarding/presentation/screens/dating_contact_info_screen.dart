import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/application/dating_onboarding_draft.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatingContactInfoScreen extends ConsumerStatefulWidget {
  const DatingContactInfoScreen({super.key});

  @override
  ConsumerState<DatingContactInfoScreen> createState() =>
      _DatingContactInfoScreenState();
}

class _DatingContactInfoScreenState
    extends ConsumerState<DatingContactInfoScreen> {
  final _controllers = <String, TextEditingController>{};
  late TextEditingController _phoneCountryCodeController;
  late TextEditingController _phoneNumberController;
  late TextEditingController _whatsappCountryCodeController;
  late TextEditingController _whatsappNumberController;

  static const _fields = <_ContactField>[
    _ContactField(
      keyName: 'Instagram',
      hint: '@yourhandle',
      iconPath: 'assets/images/social_icons/instagram.png',
    ),
    _ContactField(
      keyName: 'X',
      hint: '@yourhandle',
      iconPath: 'assets/images/social_icons/x.png',
    ),
    _ContactField(
      keyName: 'Facebook',
      hint: 'username',
      iconPath: 'assets/images/social_icons/facebook.png',
    ),
    _ContactField(
      keyName: 'Email',
      hint: 'you@example.com',
      icon: Icons.mail_rounded,
    ),
  ];

  @override
  void initState() {
    super.initState();
    final draft = ref.read(datingOnboardingDraftProvider);

    for (final f in _fields) {
      _controllers[f.keyName] = TextEditingController(
        text: draft.contactInfo[f.keyName] ?? '',
      );
    }

    // Parse existing phone and whatsapp if they exist
    final phoneValue = draft.contactInfo['Phone'] ?? '';
    final whatsappValue = draft.contactInfo['WhatsApp'] ?? '';

    String phoneCode = '';
    String phoneNumber = '';
    String whatsappCode = '';
    String whatsappNumber = '';

    if (phoneValue.isNotEmpty && phoneValue.startsWith('+')) {
      final parts = phoneValue.substring(1).split(RegExp(r'(?<=^\d{1,3})'));
      if (parts.length == 2) {
        phoneCode = '+${parts[0]}';
        phoneNumber = parts[1];
      }
    }

    if (whatsappValue.isNotEmpty && whatsappValue.startsWith('+')) {
      final parts = whatsappValue.substring(1).split(RegExp(r'(?<=^\d{1,3})'));
      if (parts.length == 2) {
        whatsappCode = '+${parts[0]}';
        whatsappNumber = parts[1];
      }
    }

    _phoneCountryCodeController = TextEditingController(text: phoneCode);
    _phoneNumberController = TextEditingController(text: phoneNumber);
    _whatsappCountryCodeController = TextEditingController(text: whatsappCode);
    _whatsappNumberController = TextEditingController(text: whatsappNumber);

    // Attach listeners for auto-save
    _phoneCountryCodeController.addListener(_saveDraft);
    _phoneNumberController.addListener(_saveDraft);
    _whatsappCountryCodeController.addListener(_saveDraft);
    _whatsappNumberController.addListener(_saveDraft);
    for (final c in _controllers.values) {
      c.addListener(_saveDraft);
    }
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    _phoneCountryCodeController.dispose();
    _phoneNumberController.dispose();
    _whatsappCountryCodeController.dispose();
    _whatsappNumberController.dispose();
    super.dispose();
  }

  bool get _hasAtLeastOneFilled {
    final textFieldsFilled = _controllers.values.any(
      (c) => c.text.trim().isNotEmpty,
    );
    final phoneFilled =
        _phoneNumberController.text.trim().isNotEmpty ||
        _whatsappNumberController.text.trim().isNotEmpty;
    return textFieldsFilled || phoneFilled;
  }

  void _saveDraft() {
    final info = <String, String>{};

    for (final f in _fields) {
      final v = _controllers[f.keyName]!.text.trim();
      if (v.isNotEmpty) info[f.keyName] = v;
    }

    // Concatenate phone number with country code
    final phoneCode = _phoneCountryCodeController.text.trim();
    final phoneNumber = _phoneNumberController.text.trim();
    if (phoneNumber.isNotEmpty) {
      info['Phone'] =
          phoneCode.isEmpty ? phoneNumber : '$phoneCode$phoneNumber';
    }

    // Concatenate WhatsApp with country code
    final whatsappCode = _whatsappCountryCodeController.text.trim();
    final whatsappNumber = _whatsappNumberController.text.trim();
    if (whatsappNumber.isNotEmpty) {
      info['WhatsApp'] =
          whatsappCode.isEmpty
              ? whatsappNumber
              : '$whatsappCode$whatsappNumber';
    }

    ref.read(datingOnboardingDraftProvider.notifier).setContactInfo(info);
  }

  @override
  Widget build(BuildContext context) {
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
          'Contact Information',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ProgressHeader(
              subtitle:
                  "Kindly provide the details of at least one social media platform you feel comfortable sharing, where users can easily contact you in case you're away from the app and unable to see messages.",
            ),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                itemCount: _fields.length + 2, // +2 for Phone and WhatsApp
                itemBuilder: (context, i) {
                  // Phone field (after Facebook)
                  if (i == 3) {
                    return _PhoneInputTile(
                      label: 'WhatsApp',
                      countryCodeController: _whatsappCountryCodeController,
                      phoneNumberController: _whatsappNumberController,
                      onChanged: (_) => setState(() {}),
                    );
                  }
                  // Adjust index for regular fields
                  final fieldIndex = i < 3 ? i : i - 1;
                  if (fieldIndex >= _fields.length) {
                    return _PhoneInputTile(
                      label: 'Phone',
                      countryCodeController: _phoneCountryCodeController,
                      phoneNumberController: _phoneNumberController,
                      onChanged: (_) => setState(() {}),
                    );
                  }

                  final f = _fields[fieldIndex];
                  final c = _controllers[f.keyName]!;
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _InputTile(
                      label: f.keyName,
                      hint: f.hint,
                      controller: c,
                      iconPath: f.iconPath,
                      icon: f.icon,
                      onChanged: (_) => setState(() {}),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed:
                    _hasAtLeastOneFilled
                        ? () async => await _completeProfile()
                        : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Complete Profile',
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'At least one contact method is required.',
              style: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _completeProfile() async {
    final info = <String, String>{};

    for (final f in _fields) {
      final v = _controllers[f.keyName]!.text.trim();
      if (v.isNotEmpty) info[f.keyName] = v;
    }

    // Concatenate phone number with country code
    final phoneCode = _phoneCountryCodeController.text.trim();
    final phoneNumber = _phoneNumberController.text.trim();
    if (phoneNumber.isNotEmpty) {
      info['Phone'] =
          phoneCode.isEmpty ? phoneNumber : '$phoneCode$phoneNumber';
    }

    // Concatenate WhatsApp with country code
    final whatsappCode = _whatsappCountryCodeController.text.trim();
    final whatsappNumber = _whatsappNumberController.text.trim();
    if (whatsappNumber.isNotEmpty) {
      info['WhatsApp'] =
          whatsappCode.isEmpty
              ? whatsappNumber
              : '$whatsappCode$whatsappNumber';
    }

    if (info.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least one contact method.'),
        ),
      );
      return;
    }

    // Persist contact info in local draft
    ref.read(datingOnboardingDraftProvider.notifier).setContactInfo(info);

    // Build dating profile payload from draft and save to Firestore
    try {
      final ready = ref.read(firebaseReadyProvider);
      final fs = ref.read(firestoreInstanceProvider);
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (ready && fs != null && uid != null) {
        final d = ref.read(datingOnboardingDraftProvider);
        final payload = <String, dynamic>{
          // Flat fields specific to dating flow
          'countryOfResidence': d.countryOfResidence,
          'contactInfo': d.contactInfo,
          'profileCompleted': true,
          'verificationStatus': 'pending',
          // Profile sub-map (matches UserModel expectations)
          'profile': {
            'age': d.age,
            'city': d.city,
            'country': d.countryOfResidence,
            'nationality': d.nationality,
            'educationLevel': d.educationLevel,
            'profession': d.profession,
            'churchName': d.churchName ?? d.otherChurchName,
            'hobbies': d.hobbies,
            'desiredQualities': d.desiredQualities,
          },
        };

        await fs.collection('users').doc(uid).set({
          'dating': payload,
        }, SetOptions(merge: true));
        debugPrint('[ContactInfo] Saved dating profile to Firestore for $uid');
      } else {
        debugPrint(
          '[ContactInfo] Skipped Firestore save (not ready or no uid).',
        );
      }
    } catch (e) {
      debugPrint('[ContactInfo] Firestore save failed: $e');
    }

    if (!mounted) return;
    Navigator.of(context).pushNamed('/dating/setup/complete');
  }
}

class _ProgressHeader extends StatelessWidget {
  final String subtitle;

  const _ProgressHeader({required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const DatingProfileProgressBar(currentStep: 9, totalSteps: 9),
        const SizedBox(height: 12),
        Text(
          subtitle,
          style: AppTextStyles.bodyMedium.copyWith(color: AppColors.textMuted),
        ),
      ],
    );
  }
}

class _InputTile extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String? iconPath;
  final IconData? icon;

  const _InputTile({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
    this.iconPath,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (iconPath != null) ...[
                Image.asset(
                  iconPath!,
                  width: 24,
                  height: 24,
                  fit: BoxFit.contain,
                ),
                const SizedBox(width: 10),
              ] else if (icon != null) ...[
                Icon(icon, size: 24),
                const SizedBox(width: 10),
              ],
              Text(label, style: AppTextStyles.labelLarge),
            ],
          ),
          const SizedBox(height: 10),
          TextField(
            controller: controller,
            onChanged: onChanged,
            decoration: InputDecoration(
              hintText: hint,
              hintStyle: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
              filled: true,
              fillColor: AppColors.background,
              border: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.border),
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.primary),
                borderRadius: BorderRadius.circular(14),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _PhoneInputTile extends StatelessWidget {
  final String label;
  final TextEditingController countryCodeController;
  final TextEditingController phoneNumberController;
  final ValueChanged<String> onChanged;

  const _PhoneInputTile({
    required this.label,
    required this.countryCodeController,
    required this.phoneNumberController,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final isWhatsApp = label == 'WhatsApp';
    final iconPath =
        isWhatsApp ? 'assets/images/social_icons/whatsapp.png' : null;
    final materialIcon = !isWhatsApp ? Icons.phone_rounded : null;

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                if (iconPath != null)
                  Image.asset(
                    iconPath,
                    width: 24,
                    height: 24,
                    fit: BoxFit.contain,
                  )
                else if (materialIcon != null)
                  Icon(materialIcon, size: 24, color: AppColors.primary),
                const SizedBox(width: 10),
                Text(label, style: AppTextStyles.labelLarge),
              ],
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                // Country Code Field
                SizedBox(
                  width: 100,
                  child: TextField(
                    controller: countryCodeController,
                    onChanged: onChanged,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: '+1',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                // Phone Number Field
                Expanded(
                  child: TextField(
                    controller: phoneNumberController,
                    onChanged: onChanged,
                    keyboardType: TextInputType.phone,
                    decoration: InputDecoration(
                      hintText: 'phone number',
                      hintStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.textMuted,
                      ),
                      filled: true,
                      fillColor: AppColors.background,
                      border: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.border),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(color: AppColors.primary),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 12,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ContactField {
  final String keyName;
  final String hint;
  final String? iconPath;
  final IconData? icon;
  const _ContactField({
    required this.keyName,
    required this.hint,
    this.iconPath,
    this.icon,
  });
}
