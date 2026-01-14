import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/compatibility_quiz/data/compatibility_quiz_service.dart';
import 'package:nexus_app_min_test/core/auth/auth_providers.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/application/dating_onboarding_draft.dart';

class DatingContactInfoStubScreen extends ConsumerStatefulWidget {
  const DatingContactInfoStubScreen({super.key});

  @override
  ConsumerState<DatingContactInfoStubScreen> createState() =>
      _DatingContactInfoStubScreenState();
}

class _DatingContactInfoStubScreenState
    extends ConsumerState<DatingContactInfoStubScreen> {
  final _controllers = <String, TextEditingController>{};

  static const _fields = <_ContactField>[
    _ContactField(keyName: 'Instagram', hint: '@yourhandle'),
    _ContactField(keyName: 'X', hint: '@yourhandle'),
    _ContactField(keyName: 'Facebook', hint: 'facebook.com/yourname'),
    _ContactField(keyName: 'WhatsApp', hint: '+234...'),
    _ContactField(keyName: 'Phone', hint: '+234...'),
    _ContactField(keyName: 'Email', hint: 'you@example.com'),
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
  }

  @override
  void dispose() {
    for (final c in _controllers.values) {
      c.dispose();
    }
    super.dispose();
  }

  bool get _hasAtLeastOneFilled =>
      _controllers.values.any((c) => c.text.trim().isNotEmpty);

  @override
  Widget build(BuildContext context) {
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
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const _ProgressHeader(
              stepLabel: 'Step 7 of 8',
              title: 'Contact Information',
              subtitle:
                  "Kindly provide the details of the social media platforms you feel comfortable sharing, where users can easily contact you in case you're away from the app and unable to see messages.",
            ),
            const SizedBox(height: 18),
            Expanded(
              child: ListView.separated(
                itemCount: _fields.length,
                separatorBuilder: (_, __) => const SizedBox(height: 12),
                itemBuilder: (context, i) {
                  final f = _fields[i];
                  final c = _controllers[f.keyName]!;
                  return _InputTile(
                    label: f.keyName,
                    hint: f.hint,
                    controller: c,
                    onChanged: (_) => setState(() {}),
                  );
                },
              ),
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed:
                    _hasAtLeastOneFilled
                        ? () async => await _onContinue()
                        : null,
                child: const Text('Continue'),
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

  Future<void> _onContinue() async {
    final info = <String, String>{};

    for (final f in _fields) {
      final v = _controllers[f.keyName]!.text.trim();
      if (v.isNotEmpty) info[f.keyName] = v;
    }

    if (info.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please provide at least one contact method.'),
        ),
      );
      return;
    }

    // Persist in local onboarding draft (Phase 1 + smooth migration later).
    ref.read(datingOnboardingDraftProvider.notifier).setContactInfo(info);

    // If the user already completed compatibility quiz in Firestore,
    // do NOT send them through the quiz gate again.
    final authAsync = ref.read(authStateProvider);
    final uid = authAsync.maybeWhen(
      data: (a) => a.user?.uid,
      orElse: () => null,
    );

    if (uid != null && uid.isNotEmpty) {
      final svc = ref.read(compatibilityQuizServiceProvider);
      bool ok = false;
      try {
        ok = await svc.isQuizComplete(uid);
      } catch (_) {
        ok = false;
      }

      if (!mounted) return;

      if (ok) {
        Navigator.of(context).pushNamedAndRemoveUntil('/profile', (r) => false);
        return;
      }
    }

    if (!mounted) return;
    Navigator.of(context).pushNamed('/dating/setup/complete');
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

class _InputTile extends StatelessWidget {
  final String label;
  final String hint;
  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  const _InputTile({
    required this.label,
    required this.hint,
    required this.controller,
    required this.onChanged,
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
          Text(label, style: AppTextStyles.labelLarge),
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

class _ContactField {
  final String keyName;
  final String hint;
  const _ContactField({required this.keyName, required this.hint});
}
