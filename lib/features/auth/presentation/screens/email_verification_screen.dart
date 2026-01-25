import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/firestore_service_provider.dart';
import '../../../../core/bootstrap/bootstrap_gate.dart';
import '../../../../core/models/user_model.dart';
import '../../../guest/guest_entry_gate.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen> {
  Timer? _timer;
  bool _isCheckingVerification = false;
  bool _canResend = true;
  int _resendCountdown = 0;

  @override
  void initState() {
    super.initState();
    // Auto-check verification status every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkEmailVerified();
    });
    // Check immediately on screen load
    _checkEmailVerified();
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  Future<void> _checkEmailVerified() async {
    if (_isCheckingVerification) return;

    setState(() => _isCheckingVerification = true);

    try {
      // Get Firebase Auth directly for the most up-to-date user state
      final auth = FirebaseAuth.instance;
      final user = auth.currentUser;

      if (user == null) {
        // ignore: avoid_print
        print('[EmailVerification] No user found!');
        return;
      }

      // Force reload from Firebase to get latest verification status
      try {
        await auth.currentUser?.reload();
      } on FirebaseAuthException catch (e) {
        // ignore: avoid_print
        print('[EmailVerification] reload failed: ${e.code}');
        if (e.code == 'no-current-user') {
          return;
        }
        rethrow;
      }

      // Get fresh user reference after reload
      final freshUser = auth.currentUser;
      if (freshUser == null) {
        // ignore: avoid_print
        print(
          '[EmailVerification] User disappeared after reload (likely signed out).',
        );
        return;
      }

      final isVerified = freshUser.emailVerified;

      // ignore: avoid_print
      print(
        '[EmailVerification] Checking... isEmailVerified: $isVerified (uid: ${freshUser.uid})',
      );
      // ignore: avoid_print
      print(
        '[EmailVerification] User email: ${freshUser.email}, Metadata: ${freshUser.metadata}',
      );

      if (isVerified) {
        // ignore: avoid_print
        print('[EmailVerification] ✅ EMAIL VERIFIED! Auto-logging in...');

        if (!mounted) return;

        // Small delay to ensure auth state is propagated
        await Future.delayed(const Duration(milliseconds: 500));

        if (!mounted) return;

        // Email verified! Navigate to app
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(
            builder: (_) => const GuestEntryGate(child: BootstrapGate()),
          ),
          (_) => false,
        );
      }
    } catch (e) {
      // ignore: avoid_print
      print('[EmailVerification] ❌ Error checking verification: $e');
    } finally {
      if (mounted) {
        setState(() => _isCheckingVerification = false);
      }
    }
  }

  Future<void> _resendVerificationEmail() async {
    if (!_canResend) return;

    setState(() => _canResend = false);

    try {
      final authService = ref.read(authServiceProvider);
      await authService.sendEmailVerification();

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification email sent! Check your inbox.'),
          backgroundColor: Colors.green,
        ),
      );

      // Start 60 second countdown before allowing resend
      setState(() => _resendCountdown = 60);
      Timer.periodic(const Duration(seconds: 1), (timer) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _resendCountdown--;
          if (_resendCountdown == 0) {
            _canResend = true;
            timer.cancel();
          }
        });
      });
    } catch (e) {
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to resend email: $e'),
          backgroundColor: Colors.red,
        ),
      );

      setState(() => _canResend = true);
    }
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
        title: Text(
          'Verify Email',
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.primary.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.email_outlined,
                size: 50,
                color: AppColors.primary,
              ),
            ),
            const SizedBox(height: 32),
            Text(
              'Check your email',
              style: AppTextStyles.headlineLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'We sent a verification link to',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.textSecondary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 8),
            Text(
              widget.email,
              style: AppTextStyles.bodyLarge.copyWith(
                fontWeight: FontWeight.w600,
                color: AppColors.primary,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      Icon(
                        Icons.info_outline,
                        size: 20,
                        color: AppColors.primary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Click the link in the email to verify your account',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Icon(
                        Icons.folder_outlined,
                        size: 20,
                        color: AppColors.textSecondary,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Check your spam folder if you don\'t see it in your inbox',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      SizedBox(
                        width: 16,
                        height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor: AlwaysStoppedAnimation<Color>(
                            AppColors.primary,
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Checking verification status...',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
            Text(
              "Didn't receive the email?",
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textSecondary,
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: _canResend ? _resendVerificationEmail : null,
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  side: BorderSide(
                    color:
                        _canResend
                            ? AppColors.primary
                            : AppColors.textSecondary.withOpacity(0.3),
                  ),
                ),
                child: Text(
                  _canResend
                      ? 'Resend Verification Email'
                      : 'Resend in ${_resendCountdown}s',
                  style: AppTextStyles.labelLarge.copyWith(
                    color:
                        _canResend
                            ? AppColors.primary
                            : AppColors.textSecondary,
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextButton(
              onPressed: () {
                Navigator.of(context).pop();
              },
              child: Text(
                'Back to Login',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
