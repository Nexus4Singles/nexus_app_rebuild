import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';

/// Premium Login Screen with modern UI
class LoginScreen extends ConsumerStatefulWidget {
  const LoginScreen({super.key});

  @override
  ConsumerState<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends ConsumerState<LoginScreen>
    with SingleTickerProviderStateMixin {
  final _formKey = GlobalKey<FormState>();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _obscurePassword = true;
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _handleLogin() async {
    if (!_formKey.currentState!.validate()) return;
    HapticFeedback.lightImpact();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).signInWithEmail(
        email: _emailController.text.trim(),
        password: _passwordController.text,
      );
    } catch (e) {
      setState(() => _error = _getErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  Future<void> _handleGoogleSignIn() async {
    HapticFeedback.lightImpact();

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      await ref.read(authNotifierProvider.notifier).signInWithGoogle();
    } catch (e) {
      setState(() => _error = _getGoogleErrorMessage(e));
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  String _getGoogleErrorMessage(dynamic error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('cancelled') || msg.contains('cancel')) return 'Sign in cancelled';
    if (msg.contains('network')) return 'Network error. Check your connection';
    if (msg.contains('popup_closed')) return 'Sign in window closed';
    return 'Google sign in failed. Please try again';
  }

  String _getErrorMessage(dynamic error) {
    final msg = error.toString().toLowerCase();
    if (msg.contains('user-not-found')) return 'No account found with this email';
    if (msg.contains('wrong-password')) return 'Incorrect password';
    if (msg.contains('invalid-email')) return 'Invalid email address';
    if (msg.contains('too-many-requests')) return 'Too many attempts. Try again later';
    if (msg.contains('network')) return 'Network error. Check your connection';
    return 'Login failed. Please try again';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Stack(
        children: [
          // Background gradient
          Positioned(
            top: -100,
            right: -100,
            child: Container(
              width: 300,
              height: 300,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.primary.withOpacity(0.15),
                    AppColors.primary.withOpacity(0),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: Container(
              width: 200,
              height: 200,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  colors: [
                    AppColors.secondary.withOpacity(0.1),
                    AppColors.secondary.withOpacity(0),
                  ],
                ),
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
                        const SizedBox(height: 60),

                        // Logo
                        _buildLogo(),
                        const SizedBox(height: 48),

                        // Title
                        const Text(
                          'Welcome Back',
                          style: TextStyle(
                            fontSize: 32,
                            fontWeight: FontWeight.w800,
                            color: AppColors.textPrimary,
                            letterSpacing: -0.5,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Sign in to continue your journey',
                          style: TextStyle(
                            fontSize: 16,
                            color: AppColors.textSecondary,
                          ),
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 40),

                        // Error message
                        if (_error != null) ...[
                          _buildErrorBanner(),
                          const SizedBox(height: 20),
                        ],

                        // Email field
                        _buildTextField(
                          controller: _emailController,
                          label: 'Email',
                          hint: 'Enter your email',
                          icon: Icons.email_outlined,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter your email';
                            if (!v.contains('@')) return 'Please enter a valid email';
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),

                        // Password field
                        _buildTextField(
                          controller: _passwordController,
                          label: 'Password',
                          hint: 'Enter your password',
                          icon: Icons.lock_outline,
                          obscureText: _obscurePassword,
                          suffixIcon: IconButton(
                            onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_outlined : Icons.visibility_off_outlined,
                              color: AppColors.textMuted,
                              size: 20,
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return 'Please enter your password';
                            if (v.length < 6) return 'Password must be at least 6 characters';
                            return null;
                          },
                          onSubmitted: (_) => _handleLogin(),
                        ),
                        const SizedBox(height: 8),

                        // Forgot password
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: () => context.push('/forgot-password'),
                            style: TextButton.styleFrom(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            ),
                            child: Text(
                              'Forgot Password?',
                              style: TextStyle(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 24),

                        // Login button
                        _buildPrimaryButton(
                          label: 'Sign In',
                          onPressed: _handleLogin,
                          isLoading: _isLoading,
                        ),
                        const SizedBox(height: 28),

                        // Divider
                        Row(
                          children: [
                            Expanded(child: Divider(color: AppColors.border)),
                            Padding(
                              padding: const EdgeInsets.symmetric(horizontal: 16),
                              child: Text('OR', style: TextStyle(color: AppColors.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
                            ),
                            Expanded(child: Divider(color: AppColors.border)),
                          ],
                        ),
                        const SizedBox(height: 28),

                        // Google sign in
                        _buildSocialButton(
                          icon: 'G',
                          label: 'Continue with Google',
                          onPressed: _isLoading ? null : _handleGoogleSignIn,
                        ),
                        const SizedBox(height: 40),

                        // Sign up link
                        Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Text(
                              "Don't have an account? ",
                              style: TextStyle(color: AppColors.textSecondary, fontSize: 15),
                            ),
                            GestureDetector(
                              onTap: () => context.go(AppRoutes.signup),
                              child: Text(
                                'Sign Up',
                                style: TextStyle(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                  fontSize: 15,
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 40),
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

  Widget _buildLogo() {
    return Center(
      child: Container(
        width: 80,
        height: 80,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: const Center(
          child: Text(
            'N',
            style: TextStyle(
              fontSize: 42,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ),
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
          Container(
            padding: const EdgeInsets.all(6),
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Icon(Icons.error_outline, color: AppColors.error, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              _error!,
              style: TextStyle(color: AppColors.error, fontSize: 14, fontWeight: FontWeight.w500),
            ),
          ),
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
    Widget? suffixIcon,
    String? Function(String?)? validator,
    void Function(String)? onSubmitted,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 8),
        TextFormField(
          controller: controller,
          keyboardType: keyboardType,
          obscureText: obscureText,
          validator: validator,
          onFieldSubmitted: onSubmitted,
          style: const TextStyle(fontSize: 16),
          decoration: InputDecoration(
            hintText: hint,
            hintStyle: TextStyle(color: AppColors.textMuted),
            prefixIcon: Icon(icon, size: 20, color: AppColors.textMuted),
            suffixIcon: suffixIcon,
            filled: true,
            fillColor: AppColors.surfaceLight,
            contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
            border: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide.none,
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.primary, width: 2),
            ),
            errorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.error, width: 1),
            ),
            focusedErrorBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(14),
              borderSide: BorderSide(color: AppColors.error, width: 2),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildPrimaryButton({
    required String label,
    required VoidCallback onPressed,
    bool isLoading = false,
  }) {
    return GestureDetector(
      onTap: isLoading ? null : onPressed,
      child: Container(
        height: 56,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(14),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.3),
              blurRadius: 12,
              offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Center(
          child: isLoading
              ? const SizedBox(
                  width: 24,
                  height: 24,
                  child: CircularProgressIndicator(
                    strokeWidth: 2.5,
                    valueColor: AlwaysStoppedAnimation<Color>(Colors.white),
                  ),
                )
              : Text(
                  label,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 16,
                    fontWeight: FontWeight.w700,
                  ),
                ),
        ),
      ),
    );
  }

  Widget _buildSocialButton({
    required String icon,
    required String label,
    VoidCallback? onPressed,
  }) {
    final isEnabled = onPressed != null;
    
    return GestureDetector(
      onTap: isEnabled ? () {
        HapticFeedback.lightImpact();
        onPressed();
      } : null,
      child: AnimatedOpacity(
        duration: const Duration(milliseconds: 200),
        opacity: isEnabled ? 1.0 : 0.6,
        child: Container(
          height: 56,
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: AppColors.border),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.03),
                blurRadius: 8,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Google logo using official colors
              Container(
                width: 24,
                height: 24,
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(4),
                ),
                child: Center(
                  child: icon == 'G' 
                      ? _buildGoogleIcon()
                      : Text(
                          icon,
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w700,
                            color: Colors.red,
                          ),
                        ),
                ),
              ),
              const SizedBox(width: 12),
              Text(
                label,
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
    );
  }

  Widget _buildGoogleIcon() {
    return SizedBox(
      width: 24,
      height: 24,
      child: Stack(
        children: [
          // Simple "G" styled like Google logo
          Center(
            child: Text(
              'G',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                foreground: Paint()
                  ..shader = const LinearGradient(
                    colors: [
                      Color(0xFF4285F4), // Blue
                      Color(0xFF34A853), // Green
                      Color(0xFFFBBC05), // Yellow
                      Color(0xFFEA4335), // Red
                    ],
                    stops: [0.0, 0.33, 0.66, 1.0],
                  ).createShader(const Rect.fromLTWH(0, 0, 24, 24)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
