import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';

/// Premium Signup Screen with modern UI
class SignupScreen extends ConsumerStatefulWidget {
  const SignupScreen({super.key});

  @override
  ConsumerState<SignupScreen> createState() => _SignupScreenState();
}

class _SignupScreenState extends ConsumerState<SignupScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  
  bool _isLoading = false;
  bool _isGoogleLoading = false;
  bool _obscurePassword = true;
  bool _obscureConfirm = true;
  bool _acceptedTerms = false;
  String? _error;

  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOutCubic));
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    _usernameController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _handleSignup() async {
    if (!_formKey.currentState!.validate()) return;
    if (!_acceptedTerms) {
      setState(() => _error = 'Please accept the Terms & Conditions');
      return;
    }
    HapticFeedback.lightImpact();

    setState(() { _isLoading = true; _error = null; });

    try {
      await ref.read(authNotifierProvider.notifier).signUpWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
        username: _usernameController.text.trim(),
      );
    } catch (e) {
      setState(() => _error = _getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignup() async {
    if (!_acceptedTerms) {
      setState(() => _error = 'Please accept the Terms & Conditions first');
      return;
    }
    HapticFeedback.lightImpact();

    setState(() { _isGoogleLoading = true; _error = null; });

    try {
      final needsUsername = await ref.read(authNotifierProvider.notifier).signInWithGoogle();
      if (needsUsername && mounted) await _showUsernameDialog();
    } catch (e) {
      setState(() => _error = _getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isGoogleLoading = false);
    }
  }

  Future<void> _showUsernameDialog() async {
    final controller = TextEditingController();
    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      isDismissible: false,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: EdgeInsets.only(bottom: MediaQuery.of(ctx).viewInsets.bottom),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
              const SizedBox(height: 24),
              const Text('Choose Your Username', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 8),
              Text('Welcome! Pick a unique username to continue.', style: TextStyle(color: AppColors.textSecondary)),
              const SizedBox(height: 24),
              _buildTextField(controller: controller, label: 'Username', hint: 'e.g., Grace_21', icon: Icons.alternate_email, autofocus: true),
              const SizedBox(height: 24),
              _buildPrimaryButton(
                label: 'Continue',
                onPressed: () async {
                  final username = controller.text.trim();
                  if (username.isEmpty || username.length < 2) {
                    ScaffoldMessenger.of(ctx).showSnackBar(SnackBar(content: const Text('Username must be at least 2 characters'), backgroundColor: AppColors.error, behavior: SnackBarBehavior.floating));
                    return;
                  }
                  await ref.read(authNotifierProvider.notifier).updateUsername(username);
                  if (ctx.mounted) Navigator.pop(ctx);
                },
              ),
              SizedBox(height: MediaQuery.of(ctx).padding.bottom + 8),
            ],
          ),
        ),
      ),
    );
    controller.dispose();
  }

  String _getErrorMessage(dynamic error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('email-already-in-use')) return 'An account with this email already exists';
    if (msg.contains('invalid-email')) return 'Invalid email address';
    if (msg.contains('weak-password')) return 'Password is too weak';
    if (msg.contains('network')) return 'Network error. Check your connection';
    if (msg.contains('username-taken')) return 'This username is already taken';
    return 'Sign up failed. Please try again';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background decorations
          Positioned(
            top: -80,
            left: -80,
            child: Container(
              width: 250,
              height: 250,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.primary.withOpacity(0.12), AppColors.primary.withOpacity(0)]),
              ),
            ),
          ),
          Positioned(
            bottom: -100,
            right: -60,
            child: Container(
              width: 280,
              height: 280,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [AppColors.secondary.withOpacity(0.08), AppColors.secondary.withOpacity(0)]),
              ),
            ),
          ),

          // Content
          SafeArea(
            child: FadeTransition(
              opacity: _fadeIn,
              child: SlideTransition(
                position: _slideUp,
                child: SingleChildScrollView(
                  physics: const BouncingScrollPhysics(),
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const SizedBox(height: 16),

                        // Back button
                        Align(
                          alignment: Alignment.centerLeft,
                          child: GestureDetector(
                            onTap: () => context.go(AppRoutes.login),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                color: AppColors.surfaceLight,
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Icon(Icons.arrow_back, color: AppColors.textPrimary, size: 22),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Title
                        const Text(
                          'Create Account',
                          style: TextStyle(fontSize: 32, fontWeight: FontWeight.w800, color: AppColors.textPrimary, letterSpacing: -0.5),
                        ),
                        const SizedBox(height: 8),
                        Text('Start your faith-centered journey', style: TextStyle(fontSize: 16, color: AppColors.textSecondary)),
                        const SizedBox(height: 32),

                        // Error
                        if (_error != null) ...[_buildErrorBanner(), const SizedBox(height: 20)],

                        // Username
                        _buildTextField(controller: _usernameController, label: 'Username', hint: 'Choose a username', icon: Icons.person_outline, validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter a username';
                          if (v.length < 2) return 'At least 2 characters';
                          if (v.length > 20) return 'Maximum 20 characters';
                          return null;
                        }),
                        const SizedBox(height: 16),

                        // Email
                        _buildTextField(controller: _emailController, label: 'Email', hint: 'Enter your email', icon: Icons.email_outlined, keyboardType: TextInputType.emailAddress, validator: (v) {
                          if (v == null || v.isEmpty) return 'Please enter your email';
                          if (!v.contains('@') || !v.contains('.')) return 'Please enter a valid email';
                          return null;
                        }),
                        const SizedBox(height: 16),

                        // Password
                        _buildTextField(controller: _passwordController, label: 'Password', hint: 'Create a password', icon: Icons.lock_outline, obscureText: _obscurePassword, suffixIcon: IconButton(onPressed: () => setState(() => _obscurePassword = !_obscurePassword), icon: Icon(_obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textMuted, size: 20)), validator: (v) {
                          if (v == null || v.isEmpty) return 'Please create a password';
                          if (v.length < 6) return 'At least 6 characters';
                          return null;
                        }),
                        const SizedBox(height: 16),

                        // Confirm Password
                        _buildTextField(controller: _confirmPasswordController, label: 'Confirm Password', hint: 'Re-enter password', icon: Icons.lock_outline, obscureText: _obscureConfirm, suffixIcon: IconButton(onPressed: () => setState(() => _obscureConfirm = !_obscureConfirm), icon: Icon(_obscureConfirm ? Icons.visibility_outlined : Icons.visibility_off_outlined, color: AppColors.textMuted, size: 20)), validator: (v) {
                          if (v == null || v.isEmpty) return 'Please confirm password';
                          if (v != _passwordController.text) return 'Passwords do not match';
                          return null;
                        }),
                        const SizedBox(height: 20),

                        // Terms checkbox
                        _buildTermsCheckbox(),
                        const SizedBox(height: 24),

                        // Signup button
                        _buildPrimaryButton(label: 'Create Account', onPressed: _handleSignup, isLoading: _isLoading),
                        const SizedBox(height: 24),

                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: AppColors.border)),
                            Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: Text('OR', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500))),
                            Expanded(child: Divider(color: AppColors.border)),
                          ],
                        ),
                        const SizedBox(height: 24),

                        // Google
                        _buildSocialButton(icon: 'G', label: 'Continue with Google', onPressed: _handleGoogleSignup, isLoading: _isGoogleLoading),
                        const SizedBox(height: 32),

                        // Login link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text('Already have an account? ', style: TextStyle(color: AppColors.textSecondary, fontSize: 15)),
                            GestureDetector(
                              onTap: () => context.go(AppRoutes.login),
                              child: Text('Sign In', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w700, fontSize: 15)),
                            ),
                          ],
                        ),
                        const SizedBox(height: 32),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.error.withOpacity(0.2)),
      ),
      child: Row(
        children: [
          Container(padding: const EdgeInsets.all(6), decoration: BoxDecoration(color: AppColors.error.withOpacity(0.1), borderRadius: BorderRadius.circular(8)), child: Icon(Icons.error_outline, color: AppColors.error, size: 18)),
          const SizedBox(width: 12),
          Expanded(child: Text(_error!, style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w500))),
        ],
      ),
    );
  }

  Widget _buildTextField({
    required TextEditingController controller,
    required String label,
    required String hint,
    required IconData icon,
    TextInputType? keyboardType,
    bool obscureText = false,
    bool autofocus = false,
    Widget? suffixIcon,
    String? Function(String?)? validator,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          autofocus: autofocus,
          validator: validator,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted),
            prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surfaceLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide.none),
            focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.primary, width: 2)),
            errorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.error)),
            focusedErrorBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(14), borderSide: BorderSide(color: AppColors.error, width: 2)),
          ),
        ),
      ],
    );
  }

  Widget _buildTermsCheckbox() {
    return GestureDetector(
      onTap: () => setState(() { _acceptedTerms = !_acceptedTerms; if (_acceptedTerms) _error = null; }),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 24,
            height: 24,
            margin: const EdgeInsets.only(top: 2),
            decoration: BoxDecoration(
              color: _acceptedTerms ? AppColors.primary : Colors.transparent,
              borderRadius: BorderRadius.circular(6),
              border: Border.all(color: _acceptedTerms ? AppColors.primary : AppColors.border, width: 2),
            ),
            child: _acceptedTerms ? const Icon(Icons.check, size: 16, color: Colors.white) : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
                children: [
                  const TextSpan(text: 'I agree to the '),
                  TextSpan(text: 'Terms of Service', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                  const TextSpan(text: ' and '),
                  TextSpan(text: 'Privacy Policy', style: TextStyle(color: AppColors.primary, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPrimaryButton({required String label, required VoidCallback onPressed, bool isLoading = false}) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [BoxShadow(color: AppColors.primary.withOpacity(0.3), blurRadius: 12, offset: const Offset(0, 6))],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2.5, valueColor: AlwaysStoppedAnimation<Color>(Colors.white)))
              : Text(label, style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w700)),
        ),
      ),
    );
  }

  Widget _buildSocialButton({required String icon, required String label, required VoidCallback onPressed, bool isLoading = false}) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: AppColors.border),
          boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.03), blurRadius: 8, offset: const Offset(0, 2))],
        ),
        child: isLoading
            ? const Center(child: SizedBox(width: 24, height: 24, child: CircularProgressIndicator(strokeWidth: 2)))
            : Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(icon, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: Colors.red)),
                  const SizedBox(width: 12),
                  Text(label, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)),
                ],
              ),
      ),
    );
  }
}
