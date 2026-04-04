import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexus_app_v2/core/router/safe_nav.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/features/dating_onboarding/application/dating_onboarding_draft.dart';
import 'package:nexus_app_v2/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_v2/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_v2/core/providers/service_providers.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Canonicalize strings for consistent Firestore queries
String _normBasic(String? v) =>
    (v ?? '').trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');

String _normAlnum(String? v) {
  final s = _normBasic(v);
  return s
      .replaceAll(RegExp(r'[^a-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

String _canonMarital(String? v) {
  final s = _normAlnum(v);
  if (s.isEmpty) return '';
  if (s.contains('never') && s.contains('married')) return 'single';
  if (s.contains('single')) return 'single';
  if (s.contains('married')) return 'married';
  if (s.contains('divorced')) return 'divorced';
  if (s.contains('widowed')) return 'widowed';
  return s;
}

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
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => navigateBackToHome(context),
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
            const DatingProfileProgressBar(currentStep: 9, totalSteps: 9),
            const SizedBox(height: 14),
            Expanded(
              child: ListView.builder(
                itemCount:
                    _fields.length +
                    2 +
                    1, // +2 for Phone/WhatsApp, +1 for subtitle header
                itemBuilder: (context, i) {
                  // First item: subtitle text (scrolls with the list)
                  if (i == 0) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 14),
                      child: Text(
                        "Kindly provide the details of at least one social media platform you feel comfortable sharing, where users can easily contact you in case you're away from the app and unable to see messages.",
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    );
                  }
                  // Shift remaining indices by 1
                  final ai = i - 1;
                  // WhatsApp field (after Facebook, index 3 in original)
                  if (ai == 3) {
                    return _PhoneInputTile(
                      label: 'WhatsApp',
                      countryCodeController: _whatsappCountryCodeController,
                      phoneNumberController: _whatsappNumberController,
                      onChanged: (_) => setState(() {}),
                    );
                  }
                  // Adjust index for regular fields
                  final fieldIndex = ai < 3 ? ai : ai - 1;
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
                  backgroundColor: Theme.of(context).colorScheme.primary,
                  foregroundColor: Theme.of(context).colorScheme.onPrimary,
                  elevation: 0,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Complete Profile',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: Theme.of(context).colorScheme.onPrimary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'At least one contact method is required.',
              style: AppTextStyles.caption.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
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
        SnackBar(
          content: const Text('Please provide at least one contact method.'),
          backgroundColor: AppColors.primary,
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
        // Ensure the draft has been fully loaded from SharedPreferences
        // (guards against race condition if provider was recently recreated)
        await ref.read(datingOnboardingDraftProvider.notifier).ensureLoaded();
        var d = ref.read(datingOnboardingDraftProvider);

        // Safety check: if critical fields are null, the in-memory draft may
        // have been lost (e.g. hot restart). Try one more reload.
        if (d.age == null && d.countryOfResidence == null) {
          print(
            '[DATING_SAVE] ⚠️ Draft appears empty — attempting manual reload',
          );
          try {
            final prefs = await SharedPreferences.getInstance();
            final raw = prefs.getString('dating_onboarding_draft');
            if (raw != null) {
              final json = jsonDecode(raw) as Map<String, dynamic>;
              final reloaded = DatingOnboardingDraft.fromJson(json);
              if (reloaded.age != null || reloaded.countryOfResidence != null) {
                d = reloaded;
                print(
                  '[DATING_SAVE] ✅ Manual reload recovered data: age=${d.age}, country=${d.countryOfResidence}',
                );
              }
            }
          } catch (e) {
            print('[DATING_SAVE] Manual reload failed: $e');
          }
        }

        // DEBUG: Log draft contents to identify why data may be missing
        debugPrint('[DATING_SAVE] Draft contents at save time:');
        print(
          '[DATING_SAVE]   age=${d.age}, city=${d.city}, country=${d.countryOfResidence}',
        );
        print(
          '[DATING_SAVE]   nationality=${d.nationality}, education=${d.educationLevel}',
        );
        print(
          '[DATING_SAVE]   profession=${d.profession}, church=${d.churchName}',
        );
        print(
          '[DATING_SAVE]   hobbies=${d.hobbies}, qualities=${d.desiredQualities}',
        );
        print(
          '[DATING_SAVE]   audio1Url=${d.audio1Url != null}, audio2Url=${d.audio2Url != null}, audio3Url=${d.audio3Url != null}',
        );
        print('[DATING_SAVE]   contactInfo=${d.contactInfo}');

        // Use photo URLs from draft (uploaded during photos screen)
        final photoUrls = d.photoUrls;
        print('[DATING_SAVE]   photoUrls=${photoUrls.length} urls: $photoUrls');

        // ── Safety guard: abort if media URLs are missing ──
        // This prevents writing an empty reviewPack to Firestore, which
        // would cause the admin review screen to show "No photos/audio".
        if (photoUrls.isEmpty) {
          debugPrint('[DATING_SAVE] ❌ ABORT: photoUrls is empty at submission');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Photo upload data is missing. Please go back to the Photos step and re-upload.',
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        // Collect audio URLs for review pack
        final audioUrls = <String>[];
        if (d.audio1Url?.isNotEmpty ?? false) audioUrls.add(d.audio1Url!);
        if (d.audio2Url?.isNotEmpty ?? false) audioUrls.add(d.audio2Url!);
        if (d.audio3Url?.isNotEmpty ?? false) audioUrls.add(d.audio3Url!);

        if (audioUrls.isEmpty) {
          debugPrint('[DATING_SAVE] ❌ ABORT: audioUrls is empty at submission');
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text(
                  'Audio upload data is missing. Please go back to the Audio step and re-record.',
                ),
                duration: Duration(seconds: 5),
              ),
            );
          }
          return;
        }

        // Collect audio durations (seconds) in matching order.
        // Clamp each to 90s max as a safety net (prevents stale draft data
        // or timer edge-cases from writing impossible values to Firestore).
        const _maxRecordingSeconds = 90;
        final audioDurations = <int>[];
        if (d.audio1Url?.isNotEmpty ?? false)
          audioDurations.add(
            (d.audio1Duration ?? 0).clamp(0, _maxRecordingSeconds),
          );
        if (d.audio2Url?.isNotEmpty ?? false)
          audioDurations.add(
            (d.audio2Duration ?? 0).clamp(0, _maxRecordingSeconds),
          );
        if (d.audio3Url?.isNotEmpty ?? false)
          audioDurations.add(
            (d.audio3Duration ?? 0).clamp(0, _maxRecordingSeconds),
          );

        // Get gender and relationship status from user doc
        final userDoc = await fs.collection('users').doc(uid).get();
        final userData = userDoc.data();
        final nexus2 = userData?['nexus2'] as Map<String, dynamic>?;
        // Gender: try dating.profile.gender → root gender (presurvey writes root)
        final datingMap =
            (userData?['dating'] is Map)
                ? (userData!['dating'] as Map).cast<String, dynamic>()
                : null;
        final datingProfileMap =
            (datingMap?['profile'] is Map)
                ? (datingMap!['profile'] as Map).cast<String, dynamic>()
                : null;
        final gender =
            datingProfileMap?['gender'] as String? ??
            userData?['gender'] as String?;
        final relationshipStatus = nexus2?['relationshipStatus'] as String?;

        // Canonicalize marital status for consistent Firestore queries
        final canonMaritalStatus = _canonMarital(relationshipStatus);

        // ── Build dot-notation update payload ──
        // IMPORTANT: We use .update() with dot-notation keys instead of
        // .set(merge:true) with a full 'dating' object. A nested object
        // inside set(merge:true) REPLACES the entire map, wiping sibling
        // fields like dating.optIn, dating.availability, etc.
        // Dot-notation preserves all existing sibling fields.

        // ── Map contactInfo display-keys → individual Firestore fields ──
        // UserModel reads from root-level instagramUsername etc.
        // Without this mapping, social media entered during onboarding
        // would be stored in dating.contactInfo but never readable.
        final ciInstagram = d.contactInfo['Instagram']?.trim() ?? '';
        final ciTwitter = d.contactInfo['X']?.trim() ?? '';
        final ciFacebook = d.contactInfo['Facebook']?.trim() ?? '';
        final ciEmail = d.contactInfo['Email']?.trim() ?? '';
        final ciPhone = d.contactInfo['Phone']?.trim() ?? '';
        final ciWhatsApp = d.contactInfo['WhatsApp']?.trim() ?? '';
        // If user provided a phone but no WhatsApp, use phone as the contact number
        final ciPrimaryPhone = ciWhatsApp.isNotEmpty ? ciWhatsApp : ciPhone;

        final updatePayload = <String, dynamic>{
          // ── Root-level fields (needed by DatingProfile.fromFirestore) ──
          // DatingProfile.fromFirestore reads ALL these from root level,
          // NOT from dating.profile.*, so they MUST be written at root.
          'photos': photoUrls,
          'audioPrompts': audioUrls,
          'audioDurations': audioDurations,
          'createdAt': FieldValue.serverTimestamp(),
          'schemaVersion': 2,
          'age': d.age,
          // Only write gender if non-null — avoid overwriting presurvey gender with null
          if (gender != null) 'gender': gender,
          'name': userData?['name'],
          'city': d.city,
          'country': d.countryOfResidence?.trim() ?? '',
          'nationality': d.nationality,
          'educationLevel': d.educationLevel,
          'profession': d.profession,
          'churchName': d.churchName ?? d.otherChurchName,
          'hobbies': d.hobbies,
          'desiredQualities': d.desiredQualities,
          'profileUrl': photoUrls.isNotEmpty ? photoUrls.first : null,
          'maritalStatus': canonMaritalStatus,
          'isActive': true,

          // ── Root-level social media (UserModel reads these) ──
          if (ciInstagram.isNotEmpty) 'instagramUsername': ciInstagram,
          if (ciTwitter.isNotEmpty) 'twitterUsername': ciTwitter,
          if (ciFacebook.isNotEmpty) 'facebookUsername': ciFacebook,
          if (ciPrimaryPhone.isNotEmpty) 'phoneNumber': ciPrimaryPhone,
          if (ciEmail.isNotEmpty) 'email': ciEmail,

          // ── dating.* flat fields (dot-notation preserves siblings) ──
          'dating.contactInfo': d.contactInfo,
          'dating.profileCompleted': true,
          'dating.isActive': true,
          'dating.createdAt': FieldValue.serverTimestamp(),
          'dating.verificationStatus': 'pending',
          'dating.verificationQueuedAt': FieldValue.serverTimestamp(),
          // Clear any previous rejection data when creating/updating profile
          'dating.rejectionReason': FieldValue.delete(),
          'dating.rejectedAt': FieldValue.delete(),
          'dating.schemaVersion': 2,
          'dating.maritalStatus': canonMaritalStatus,
          // Country of residence — used by dating_search_service Firestore
          // WHERE queries (must match capitalized filter dropdown values).
          'dating.countryOfResidence': d.countryOfResidence?.trim() ?? '',
          'dating.haveKids': null,
          'dating.longDistance': null,
          'dating.genotype': null,
          // Audio prompts at dating level (readable by UserModel.fromMap)
          'dating.audioPrompts': audioUrls,

          // ── dating.reviewPack (admin queue — written as full sub-map) ──
          'dating.reviewPack': {
            'photoUrls': photoUrls,
            'audioUrls': audioUrls,
            'submittedAt': FieldValue.serverTimestamp(),
          },

          // ── dating.profile fields (dot-notation preserves siblings) ──
          // IMPORTANT: Must NOT use 'dating.profile': {fullMap} because that
          // replaces the entire sub-document, wiping fields added by other
          // write paths (e.g. profile_screen edit adds name, photos, etc.).
          'dating.profile.age': d.age,
          'dating.profile.city': d.city,
          'dating.profile.country': d.countryOfResidence?.trim() ?? '',
          'dating.profile.nationality': d.nationality,
          'dating.profile.educationLevel': d.educationLevel,
          'dating.profile.profession': d.profession,
          'dating.profile.churchName': d.churchName ?? d.otherChurchName,
          'dating.profile.hobbies': d.hobbies,
          'dating.profile.desiredQualities': d.desiredQualities,
          'dating.profile.photos': photoUrls,
          'dating.profile.profileUrl':
              photoUrls.isNotEmpty ? photoUrls.first : null,
          if (gender != null) 'dating.profile.gender': gender,
          if (userData?['name'] != null)
            'dating.profile.name': userData!['name'],
          // Social media — UserModel priority reads dating.profile.phoneNumber;
          // others read from root but stored here for completeness.
          if (ciInstagram.isNotEmpty)
            'dating.profile.instagramUsername': ciInstagram,
          if (ciTwitter.isNotEmpty) 'dating.profile.twitterUsername': ciTwitter,
          if (ciFacebook.isNotEmpty)
            'dating.profile.facebookUsername': ciFacebook,
          if (ciPrimaryPhone.isNotEmpty)
            'dating.profile.phoneNumber': ciPrimaryPhone,
        };

        // Use .update() — document must exist (it does, from signup/presurvey).
        // IMPORTANT: We cannot use .set(merge:true) as a fallback because
        // Firestore's set() treats dot-notation keys (e.g. 'dating.contactInfo')
        // as LITERAL field names, not nested paths. Only .update() interprets
        // dots as nested paths. If the doc somehow doesn't exist, create it
        // first, then update.
        if (!userDoc.exists) {
          await fs.collection('users').doc(uid).set(<String, dynamic>{});
        }
        await fs.collection('users').doc(uid).update(updatePayload);
        debugPrint('[DATING_SAVE] ✅ Firestore write successful (dot-notation)');
        print(
          '[DATING_SAVE]   Root-level photos (${photoUrls.length}): $photoUrls',
        );
        print(
          '[DATING_SAVE]   reviewPack.photoUrls (${photoUrls.length}): $photoUrls',
        );

        // Track nationality and country through service (centralized handling)
        debugPrint(
          '[DATING_SAVE] Tracking nationality and country via service...',
        );
        try {
          final profileService = ref.read(datingProfileServiceProvider);
          if (d.nationality?.isNotEmpty ?? false) {
            await profileService.trackNationality(d.nationality!);
            debugPrint('[DATING_SAVE] ✅ Tracked nationality: ${d.nationality}');
          }
          if (d.countryOfResidence?.isNotEmpty ?? false) {
            await profileService.trackCountryOfResidence(d.countryOfResidence!);
            debugPrint(
              '[DATING_SAVE] ✅ Tracked country: ${d.countryOfResidence}',
            );
          }
        } catch (trackError) {
          print(
            '[DATING_SAVE] ❌ CRITICAL - Error tracking nationality/country: $trackError',
          );
          rethrow; // Re-throw so caller can handle appropriately
        }
      } else {
        print(
          '[DATING_SAVE] ⚠️ Skipped Firestore write: ready=$ready, fs=${fs != null}, uid=$uid',
        );
      }
    } catch (e, st) {
      debugPrint('[DATING_SAVE] ❌ Error saving profile: $e');
      debugPrint('[DATING_SAVE] Stack: $st');
    }

    if (!mounted) return;
    Navigator.of(context).pushNamed('/dating/setup/complete');
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
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.getBorder(context)),
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
                color: AppColors.getTextSecondary(context),
              ),
              filled: true,
              fillColor: AppColors.getBackground(context),
              border: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.getBorder(context)),
                borderRadius: BorderRadius.circular(14),
              ),
              enabledBorder: OutlineInputBorder(
                borderSide: BorderSide(color: AppColors.getBorder(context)),
                borderRadius: BorderRadius.circular(14),
              ),
              focusedBorder: OutlineInputBorder(
                borderSide: BorderSide(
                  color: Theme.of(context).colorScheme.primary,
                ),
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
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.getBorder(context)),
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
                  Icon(
                    materialIcon,
                    size: 24,
                    color: Theme.of(context).colorScheme.primary,
                  ),
                const SizedBox(width: 10),
                Text(label, style: AppTextStyles.labelLarge),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '(include your country code in the first box)',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontSize: 10,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
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
                        color: AppColors.getTextSecondary(context),
                      ),
                      filled: true,
                      fillColor: AppColors.getBackground(context),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.getBorder(context),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.getBorder(context),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: Theme.of(context).colorScheme.primary,
                        ),
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
                        color: AppColors.getTextSecondary(context),
                      ),
                      filled: true,
                      fillColor: AppColors.getBackground(context),
                      border: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.getBorder(context),
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderSide: BorderSide(
                          color: AppColors.getBorder(context),
                        ),
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
