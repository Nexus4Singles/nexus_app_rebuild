import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/utils/auth_validators.dart';
import '../../../../core/bootstrap/bootstrap_gate.dart';
import '../../../guest/guest_entry_gate.dart';
import '../../../launch/presentation/app_launch_gate.dart';
import '../../../profile/presentation/screens/terms_screen.dart';
import '../../../profile/presentation/screens/privacy_policy_screen.dart';
import 'email_verification_screen.dart';
import 'login_screen.dart';

class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen> {
  final _formKey = GlobalKey<FormState>();
  final _username = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();

  bool _busy = false;
  bool _obscurePassword = true;
  bool _agreedToTerms = false;
  String? _error;

  @override
  void dispose() {
    _username.dispose();
    _email.dispose();
    _password.dispose();
    super.dispose();
  }

  String? _validateEmail(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Email is required';
    }

    final trimmedEmail = value.trim();

    // Basic structural checks
    if (!trimmedEmail.contains('@')) {
      return 'Email must contain @ symbol';
    }

    if (!trimmedEmail.contains('.')) {
      return 'Email must contain a domain';
    }

    // More comprehensive email validation regex
    // Pattern: local-part@domain.extension
    final emailRegex = RegExp(
      r'^[a-zA-Z0-9._%+-]+@[a-zA-Z0-9.-]+\.[a-zA-Z]{2,}$',
    );

    if (!emailRegex.hasMatch(trimmedEmail)) {
      // Provide specific error messages based on common mistakes
      if (trimmedEmail.startsWith('@')) {
        return 'Email cannot start with @';
      }
      if (trimmedEmail.endsWith('@')) {
        return 'Email cannot end with @';
      }
      if (trimmedEmail.split('@').length > 2) {
        return 'Email can only contain one @ symbol';
      }
      if (trimmedEmail.endsWith('.')) {
        return 'Email cannot end with a dot';
      }
      if (trimmedEmail.contains('..')) {
        return 'Email cannot contain consecutive dots';
      }
      if (trimmedEmail.contains(' ')) {
        return 'Email cannot contain spaces';
      }
      return 'Please enter a valid email address';
    }

    // Extract and validate TLD length
    final parts = trimmedEmail.split('@');
    if (parts.length != 2) {
      return 'Invalid email format';
    }

    final domainPart = parts[1];
    final domainParts = domainPart.split('.');

    if (domainParts.length < 2) {
      return 'Email must have a valid domain';
    }

    final tld = domainParts.last.toLowerCase();

    // Validate TLD length
    if (tld.length < 2) {
      return 'TLD must be at least 2 characters';
    }

    // TLD should typically be 2-6 characters
    // Most valid TLDs: com(3), uk(2), co(2), io(2), org(3), net(3), edu(3)
    // New gTLDs up to 6: tech(4), guru(4), shop(4), museum(6), travel(6)
    // Catches mistakes like: comn(4), neet(4), con(3), coom(4)
    if (tld.length > 6) {
      return 'That TLD seems too long. Please double-check your email';
    }

    // Additional check: Common typos
    // Catches mistakes where user adds extra characters
    if (tld == 'comn' ||
        tld == 'con' ||
        tld == 'coom' ||
        tld == 'comu' ||
        tld == 'comm') {
      return 'Did you mean .com? Please check your email';
    }
    if (tld == 'neet' || tld == 'nett') {
      return 'Did you mean .net? Please check your email';
    }
    if (tld == 'ogr' || tld == 'orgg') {
      return 'Did you mean .org? Please check your email';
    }

    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    if (value.length < 8) {
      return 'Must be at least 8 characters';
    }
    if (!RegExp(r'^[A-Z]').hasMatch(value)) {
      return 'Must start with a capital letter';
    }
    if (!RegExp(r'[!@#$%^&*(),.?":{}|<>]').hasMatch(value)) {
      return 'Must contain a special character';
    }
    return null;
  }

  Future<void> _signup() async {
    if (_formKey.currentState?.validate() != true) {
      return;
    }

    FocusScope.of(context).unfocus();

    setState(() {
      _busy = true;
      _error = null;
    });

    try {
      final email = _email.text.trim();

      // ignore: avoid_print
      print('[SignupScreen] Starting signup for: $email');

      try {
        await ref
            .read(authNotifierProvider.notifier)
            .signUpWithEmail(
              email: email,
              password: _password.text,
              username: _username.text.trim(),
            );
        // ignore: avoid_print
        print('[SignupScreen] Signup completed successfully');
      } catch (signupError, stackTrace) {
        // ignore: avoid_print
        print('[SignupScreen] Signup call failed: $signupError');
        // ignore: avoid_print
        print('[SignupScreen] Stack trace: $stackTrace');
        rethrow;
      }

      if (!mounted) return;

      // ignore: avoid_print
      print('[SignupScreen] Routing to email verification screen');

      // Route to email verification screen (auto-detects when user verifies)
      Navigator.pushAndRemoveUntil(
        context,
        MaterialPageRoute(
          builder: (_) => EmailVerificationScreen(email: email),
        ),
        (_) => false,
      );
    } catch (e) {
      // ignore: avoid_print
      print('[SignupScreen] Signup error: $e');
      if (!mounted) return;
      setState(() => _error = e.toString());
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // If there's an error, clear it first
        if (_error != null) {
          setState(() => _error = null);
          return false;
        }
        // Always go back to the welcome screen, regardless of stack state
        Navigator.of(
          context,
        ).pushNamedAndRemoveUntil('/auth-entry', (_) => false);
        return false;
      },
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          surfaceTintColor: AppColors.getBackground(context),
          elevation: 0,
          titleSpacing: 0,
          automaticallyImplyLeading: false,
          leading:
              _busy
                  ? null
                  : IconButton(
                    icon: const Icon(Icons.arrow_back_ios_new_rounded),
                    onPressed:
                        () => Navigator.of(
                          context,
                        ).pushNamedAndRemoveUntil('/auth-entry', (_) => false),
                  ),
          title: Text(
            'Create Account',
            style: AppTextStyles.headlineMedium.copyWith(
              fontWeight: FontWeight.w700,
            ),
          ),
        ),
        body: SafeArea(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24),
            child: Form(
              key: _formKey,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Join Nexus',
                    style: AppTextStyles.titleLarge.copyWith(
                      fontWeight: FontWeight.w500,
                      height: 1.1,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Text(
                    'Create your account to get started',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                  const SizedBox(height: 32),
                  TextFormField(
                    controller: _username,
                    enabled: !_busy,
                    textCapitalization: TextCapitalization.none,
                    inputFormatters: [
                      FilteringTextInputFormatter.allow(RegExp(r'[A-Za-z]')),
                      LengthLimitingTextInputFormatter(12),
                    ],
                    maxLength: 12,
                    validator: AuthValidators.username,
                    style: AppTextStyles.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Username',
                      hintText: 'Choose a username (letters only)',
                      helperText: 'Letters only, 3-12 characters',
                      labelStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      filled: true,
                      fillColor: AppColors.getSurface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.getBorder(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.getBorder(context).withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.error,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _email,
                    enabled: !_busy,
                    keyboardType: TextInputType.emailAddress,
                    validator: _validateEmail,
                    style: AppTextStyles.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Email',
                      hintText: 'your.email@example.com',
                      labelStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      filled: true,
                      fillColor: AppColors.getSurface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.getBorder(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.getBorder(context).withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.error,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(18),
                    ),
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    enabled: !_busy,
                    obscureText: _obscurePassword,
                    validator: _validatePassword,
                    style: AppTextStyles.bodyLarge,
                    decoration: InputDecoration(
                      labelText: 'Password',
                      hintText:
                          '8+ characters, start with caps, 1 special char',
                      labelStyle: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      hintStyle: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.getTextSecondary(
                          context,
                        ).withOpacity(0.7),
                      ),
                      filled: true,
                      fillColor: AppColors.getSurface(context),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.getBorder(context),
                        ),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.getBorder(context).withOpacity(0.5),
                        ),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.primary,
                          width: 2,
                        ),
                      ),
                      errorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(color: AppColors.error),
                      ),
                      focusedErrorBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(16),
                        borderSide: BorderSide(
                          color: AppColors.error,
                          width: 2,
                        ),
                      ),
                      contentPadding: const EdgeInsets.all(18),
                      suffixIcon: IconButton(
                        onPressed:
                            _busy
                                ? null
                                : () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                        icon: Icon(
                          _obscurePassword
                              ? Icons.visibility_outlined
                              : Icons.visibility_off_outlined,
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  // Terms & Privacy Policy checkbox
                  GestureDetector(
                    onTap:
                        _busy
                            ? null
                            : () => setState(
                              () => _agreedToTerms = !_agreedToTerms,
                            ),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        SizedBox(
                          width: 24,
                          height: 24,
                          child: Checkbox(
                            value: _agreedToTerms,
                            onChanged:
                                _busy
                                    ? null
                                    : (v) => setState(
                                      () => _agreedToTerms = v ?? false,
                                    ),
                            activeColor: AppColors.primary,
                            checkColor: Colors.white,
                            side: BorderSide(
                              color: AppColors.getTextSecondary(context),
                              width: 1.5,
                            ),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(4),
                            ),
                            materialTapTargetSize:
                                MaterialTapTargetSize.shrinkWrap,
                            visualDensity: VisualDensity.compact,
                          ),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text.rich(
                            TextSpan(
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.getTextSecondary(context),
                                height: 1.4,
                              ),
                              children: [
                                const TextSpan(text: 'I agree to the '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap:
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder: (_) => const TermsScreen(),
                                          ),
                                        ),
                                    child: Text(
                                      'Terms of Use',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: AppColors.primary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                                const TextSpan(text: ' and '),
                                WidgetSpan(
                                  alignment: PlaceholderAlignment.baseline,
                                  baseline: TextBaseline.alphabetic,
                                  child: GestureDetector(
                                    onTap:
                                        () => Navigator.push(
                                          context,
                                          MaterialPageRoute(
                                            builder:
                                                (_) =>
                                                    const PrivacyPolicyScreen(),
                                          ),
                                        ),
                                    child: Text(
                                      'Privacy Policy',
                                      style: AppTextStyles.bodySmall.copyWith(
                                        color: AppColors.primary,
                                        fontWeight: FontWeight.w600,
                                        decoration: TextDecoration.underline,
                                        decorationColor: AppColors.primary,
                                        height: 1.4,
                                      ),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                  if (_error != null) ...[
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.error.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.error.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          Icon(
                            Icons.error_outline,
                            color: AppColors.error,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              _error ?? 'Unknown error',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.error,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                  ],
                  SizedBox(
                    width: double.infinity,
                    height: 56,
                    child: ElevatedButton(
                      onPressed: (_busy || !_agreedToTerms) ? null : _signup,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.getTextOnPrimary(context),
                        elevation: 0,
                        disabledBackgroundColor: AppColors.getTextMuted(
                          context,
                        ).withOpacity(0.3),
                        disabledForegroundColor: AppColors.getTextMuted(
                          context,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(16),
                        ),
                      ),
                      child:
                          _busy
                              ? SizedBox(
                                width: 24,
                                height: 24,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    AppColors.getTextOnPrimary(context),
                                  ),
                                ),
                              )
                              : Text(
                                'Create Account',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: AppColors.getTextOnPrimary(context),
                                ),
                              ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
