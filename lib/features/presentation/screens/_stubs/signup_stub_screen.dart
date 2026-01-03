import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/theme/app_colors.dart';
import 'package:nexus_app_min_test/core/theme/app_text_styles.dart';
import 'package:nexus_app_min_test/core/utils/auth_validators.dart';
import 'package:nexus_app_min_test/core/utils/text_formatters.dart';
import 'package:nexus_app_min_test/core/providers/auth_provider.dart';

class SignupStubScreen extends ConsumerStatefulWidget {
  const SignupStubScreen({super.key});

  @override
  ConsumerState<SignupStubScreen> createState() => _SignupStubScreenState();
}

class _SignupStubScreenState extends ConsumerState<SignupStubScreen> {
  final _formKey = GlobalKey<FormState>();

  final _usernameCtrl = TextEditingController();
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  bool _isBusy = false;
  bool _obscure = true;

  @override
  void dispose() {
    _usernameCtrl.dispose();
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    FocusScope.of(context).unfocus();

    final ok = _formKey.currentState?.validate() ?? false;
    if (!ok) return;

    final username = TextFormatters.toTitleCase(_usernameCtrl.text);
    final email = _emailCtrl.text.trim();
    final password = _passwordCtrl.text;

    setState(() => _isBusy = true);
    try {
      // NOTE: AuthProvider currently handles Firebase auth + profile storage.
      await ref
          .read(authNotifierProvider.notifier)
          .signUpWithEmail(
            email: email,
            password: password,
            username: username,
          );

      // Update username after successful account creation

      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Account created successfully ✅')),
      );
      Navigator.pop(context);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not create account: $e')));
    } finally {
      if (mounted) setState(() => _isBusy = false);
    }
  }

  void _onUsernameChanged(String raw) {
    final formatted = TextFormatters.toTitleCase(raw);

    if (formatted == raw) return;

    final sel = _usernameCtrl.selection;
    _usernameCtrl.value = TextEditingValue(
      text: formatted,
      selection: TextSelection.collapsed(
        offset:
            formatted.length < sel.baseOffset
                ? formatted.length
                : sel.baseOffset,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final canSubmit = !_isBusy;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text('Create Account', style: AppTextStyles.headlineLarge),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 10, 16, 16),
          children: [
            _IntroCard(),
            const SizedBox(height: 18),

            Form(
              key: _formKey,
              child: Column(
                children: [
                  _FieldLabel('Username'),
                  TextFormField(
                    controller: _usernameCtrl,
                    enabled: !_isBusy,
                    textCapitalization: TextCapitalization.words,
                    keyboardType: TextInputType.name,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r"[A-Za-z ]")),
                    ],
                    onChanged: _onUsernameChanged,
                    validator: AuthValidators.username,
                    style: AppTextStyles.bodyMedium,
                    decoration: _inputDeco(
                      hint: 'e.g. Ayomide Bajomo',
                      icon: Icons.person_outline,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _FieldLabel('Email'),
                  TextFormField(
                    controller: _emailCtrl,
                    enabled: !_isBusy,
                    keyboardType: TextInputType.emailAddress,
                    autofillHints: const [AutofillHints.email],
                    validator: (v) {
                      final value = (v ?? '').trim();
                      if (value.isEmpty) return 'Email is required';
                      if (!value.contains('@')) return 'Enter a valid email';
                      return null;
                    },
                    style: AppTextStyles.bodyMedium,
                    decoration: _inputDeco(
                      hint: 'name@email.com',
                      icon: Icons.mail_outline,
                    ),
                  ),
                  const SizedBox(height: 14),

                  _FieldLabel('Password'),
                  TextFormField(
                    controller: _passwordCtrl,
                    enabled: !_isBusy,
                    obscureText: _obscure,
                    autofillHints: const [AutofillHints.newPassword],
                    validator: AuthValidators.password,
                    style: AppTextStyles.bodyMedium,
                    decoration: _inputDeco(
                      hint: 'Min 8 chars, 1 number, 1 special character',
                      icon: Icons.lock_outline,
                      trailing: IconButton(
                        onPressed: () => setState(() => _obscure = !_obscure),
                        icon: Icon(
                          _obscure ? Icons.visibility_off : Icons.visibility,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),

                  _PrimaryButton(
                    text: _isBusy ? 'Creating…' : 'Create Account',
                    enabled: canSubmit,
                    onTap: _submit,
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),

            Text(
              'Already have an account? Go back and log in.',
              style: AppTextStyles.caption,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  InputDecoration _inputDeco({
    required String hint,
    required IconData icon,
    Widget? trailing,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: AppTextStyles.caption.copyWith(color: AppColors.textMuted),
      filled: true,
      fillColor: AppColors.surface,
      prefixIcon: Icon(icon, color: AppColors.textMuted),
      suffixIcon: trailing,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(16),
        borderSide: BorderSide(color: AppColors.primary, width: 1.5),
      ),
    );
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Welcome to Nexus', style: AppTextStyles.titleLarge),
          const SizedBox(height: 8),
          Text(
            'Create an account to personalize your experience and unlock full access.',
            style: AppTextStyles.bodyMedium,
          ),
        ],
      ),
    );
  }
}

class _FieldLabel extends StatelessWidget {
  final String text;
  const _FieldLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 6),
        child: Text(text, style: AppTextStyles.labelLarge),
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
    return SizedBox(
      width: double.infinity,
      child: ElevatedButton(
        onPressed: enabled ? onTap : null,
        style: ElevatedButton.styleFrom(
          backgroundColor: AppColors.primary,
          disabledBackgroundColor: AppColors.border,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          text,
          style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
        ),
      ),
    );
  }
}

/// Keeps username input in Title Case as the user types.
