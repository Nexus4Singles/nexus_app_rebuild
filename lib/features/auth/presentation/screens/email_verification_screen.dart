import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'dart:async';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/firestore_service_provider.dart';
import '../../../../core/bootstrap/bootstrap_gate.dart';
import '../../../../core/models/user_model.dart';
import '../../../guest/guest_entry_gate.dart';
import 'login_screen.dart';
import 'signup_screen.dart';

class EmailVerificationScreen extends ConsumerStatefulWidget {
  final String email;

  const EmailVerificationScreen({super.key, required this.email});

  @override
  ConsumerState<EmailVerificationScreen> createState() =>
      _EmailVerificationScreenState();
}

class _EmailVerificationScreenState
    extends ConsumerState<EmailVerificationScreen>
    with SingleTickerProviderStateMixin {
  Timer? _timer;
  Timer? _resendCountdownTimer;
  bool _isCheckingVerification = false;
  bool _canResend = true;
  int _resendCountdown = 0;

  // Error tracking to detect persistent failures
  int _consecutiveFailures = 0;
  String? _lastCheckError;

  // Blink animation for spam folder warning
  late final AnimationController _blinkController;
  late final Animation<double> _blinkAnimation;

  @override
  void initState() {
    super.initState();

    // Pulsing opacity animation for spam warning
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    )..repeat(reverse: true);
    _blinkAnimation = Tween<double>(begin: 0.4, end: 1.0).animate(
      CurvedAnimation(parent: _blinkController, curve: Curves.easeInOut),
    );

    // Auto-check verification status every 3 seconds
    _timer = Timer.periodic(const Duration(seconds: 3), (_) {
      _checkEmailVerified();
    });
    // Check immediately on screen load
    _checkEmailVerified();
  }

  @override
  void dispose() {
    _blinkController.dispose();
    _timer?.cancel();
    _resendCountdownTimer?.cancel();
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
        // User signed out while on this screen - critical error
        // ignore: avoid_print
        print(
          '[EmailVerification] ❌ CRITICAL: No user found! User likely signed out.',
        );
        _timer?.cancel();
        _resendCountdownTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _lastCheckError = 'Session lost. Please sign in again.';
          _consecutiveFailures++;
        });
        return;
      }

      // Force reload from Firebase to get latest verification status
      try {
        await auth.currentUser?.reload();
      } on FirebaseAuthException catch (e) {
        // ignore: avoid_print
        print('[EmailVerification] ⚠️ Reload error (${e.code}): ${e.message}');

        if (e.code == 'no-current-user' || e.code == 'user-not-found') {
          // User was deleted/signed out - this is terminal, stop polling
          _timer?.cancel();
          _resendCountdownTimer?.cancel();
          if (!mounted) return;
          setState(() {
            _lastCheckError = 'Account no longer exists.';
            _consecutiveFailures++;
          });
          return;
        }

        // For other firebase errors (network, permission, etc), log but don't crash
        // We'll retry on next interval
        if (!mounted) return;
        setState(() {
          _lastCheckError = 'Cannot connect to server (${e.code})';
          _consecutiveFailures++;
        });
        return; // DON'T rethrow - let timer retry
      } catch (e) {
        // Non-Firebase error (network, timeout, etc)
        // ignore: avoid_print
        print('[EmailVerification] ⚠️ Reload failed: $e');
        if (!mounted) return;
        setState(() {
          _lastCheckError = 'Network error, retrying...';
          _consecutiveFailures++;
        });
        return;
      }

      // Get fresh user reference after reload
      final freshUser = auth.currentUser;
      if (freshUser == null) {
        // User disappeared after reload (unlikely but handle it)
        // ignore: avoid_print
        print(
          '[EmailVerification] ❌ User disappeared after reload (likely signed out).',
        );
        _timer?.cancel();
        _resendCountdownTimer?.cancel();
        if (!mounted) return;
        setState(() {
          _lastCheckError = 'Session lost unexpectedly.';
          _consecutiveFailures++;
        });
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
        // SUCCESS! Clear any errors and stop checking
        // ignore: avoid_print
        print('[EmailVerification] ✅ EMAIL VERIFIED! Navigating to app...');
        _timer?.cancel();
        _resendCountdownTimer?.cancel();

        if (!mounted) return;

        // Navigate to the app - push and remove all routes so user can't go back
        Navigator.pushAndRemoveUntil(
          context,
          MaterialPageRoute(builder: (_) => const BootstrapGate()),
          (_) => false,
        );
        return;
      } else {
        // Email still not verified, but check succeeded
        // Reset error tracking since we got a good response
        if (!mounted) return;
        setState(() {
          _consecutiveFailures = 0;
          _lastCheckError = null;
        });
      }
    } catch (e) {
      // Catch-all for unexpected errors (shouldn't reach here)
      // ignore: avoid_print
      print('[EmailVerification] ❌ Unexpected error checking verification: $e');
      if (!mounted) return;
      setState(() {
        _lastCheckError = 'Unexpected error: $e';
        _consecutiveFailures++;
      });
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
          backgroundColor: AppColors.success,
        ),
      );

      // Cancel any existing countdown timer
      _resendCountdownTimer?.cancel();

      // Start 60 second countdown before allowing resend
      setState(() => _resendCountdown = 60);
      _resendCountdownTimer = Timer.periodic(const Duration(seconds: 1), (
        timer,
      ) {
        if (!mounted) {
          timer.cancel();
          return;
        }
        setState(() {
          _resendCountdown--;
          if (_resendCountdown <= 0) {
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
          backgroundColor: AppColors.primary,
        ),
      );

      setState(() => _canResend = true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return WillPopScope(
      onWillPop: () async {
        // Handle back button - delete account and sign out like the manual button does
        try {
          final user = FirebaseAuth.instance.currentUser;

          if (user != null) {
            final uid = user.uid;
            // Delete the Firestore document FIRST (before deleting auth user),
            // otherwise we lose access to the uid.
            try {
              await FirebaseFirestore.instance
                  .collection('users')
                  .doc(uid)
                  .delete();
              // ignore: avoid_print
              print(
                '[EmailVerification] Deleted Firestore doc (back button) for uid: $uid',
              );
            } catch (fsError) {
              // ignore: avoid_print
              print(
                '[EmailVerification] Firestore doc deletion failed on back: $fsError',
              );
              // Non-fatal: still proceed with auth deletion
            }

            try {
              await user.delete();
              // ignore: avoid_print
              print(
                '[EmailVerification] Deleted incomplete account (back button) for uid: $uid',
              );
            } on FirebaseAuthException catch (deleteError) {
              // ignore: avoid_print
              print(
                '[EmailVerification] Account deletion failed on back (${deleteError.code}): ${deleteError.message}',
              );
              // Still proceed with sign out
            } catch (deleteError) {
              // ignore: avoid_print
              print(
                '[EmailVerification] Unexpected deletion error on back: $deleteError',
              );
              // Still proceed with sign out
            }
          }

          await FirebaseAuth.instance.signOut();
          // ignore: avoid_print
          print('[EmailVerification] User signed out (back button)');
        } catch (e) {
          // ignore: avoid_print
          print('[EmailVerification] Error during back button rollback: $e');
        }

        _timer?.cancel();
        _resendCountdownTimer?.cancel();

        return true; // Allow pop
      },
      child: Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          surfaceTintColor: AppColors.getBackground(context),
          elevation: 0,
          titleSpacing: 0,
          title: Text(
            'Verify Email',
            style: AppTextStyles.headlineMedium.copyWith(
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
                style: AppTextStyles.headlineMedium.copyWith(
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                'We sent a verification link to',
                style: AppTextStyles.bodyLarge.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                widget.email.isNotEmpty
                    ? widget.email
                    : '(no email found - please restart)',
                style: AppTextStyles.bodyLarge.copyWith(
                  fontWeight: FontWeight.w600,
                  color:
                      widget.email.isEmpty
                          ? AppColors.error
                          : AppColors.primary,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(context)),
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
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    FadeTransition(
                      opacity: _blinkAnimation,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.1),
                          borderRadius: BorderRadius.circular(10),
                          border: Border.all(
                            color: AppColors.primary.withOpacity(0.4),
                          ),
                        ),
                        child: Row(
                          children: [
                            Icon(
                              Icons.warning_amber_rounded,
                              size: 22,
                              color: AppColors.primary,
                            ),
                            const SizedBox(width: 10),
                            Expanded(
                              child: Text(
                                'If you dont find it in your inbox, check your SPAM / JUNK folder',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.primary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        _lastCheckError == null
                            ? SizedBox(
                              width: 16,
                              height: 16,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                  AppColors.primary,
                                ),
                              ),
                            )
                            : Icon(
                              Icons.error_outline,
                              size: 16,
                              color: AppColors.error,
                            ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            _lastCheckError ??
                                'Checking verification status...',
                            style: AppTextStyles.bodySmall.copyWith(
                              color:
                                  _lastCheckError != null
                                      ? AppColors.error
                                      : AppColors.getTextSecondary(context),
                            ),
                          ),
                        ),
                      ],
                    ),
                    // Show retry suggestion after persistent failures
                    if (_consecutiveFailures > 3)
                      Padding(
                        padding: const EdgeInsets.only(top: 8),
                        child: Text(
                          'Still having trouble? Try refreshing the app or checking your internet connection.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                            fontStyle: FontStyle.italic,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              Text(
                "Didn't receive the email?",
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
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
                onPressed: () async {
                  try {
                    final user = FirebaseAuth.instance.currentUser;

                    if (user != null) {
                      final uid = user.uid;
                      // Delete Firestore document FIRST (before auth deletion)
                      // to prevent orphaned documents when user retries signup.
                      try {
                        await FirebaseFirestore.instance
                            .collection('users')
                            .doc(uid)
                            .delete();
                        // ignore: avoid_print
                        print(
                          '[EmailVerification] Deleted Firestore doc for uid: $uid',
                        );
                      } catch (fsError) {
                        // ignore: avoid_print
                        print(
                          '[EmailVerification] Firestore doc deletion failed: $fsError',
                        );
                        // Non-fatal: still proceed with auth deletion
                      }

                      // Delete the current Firebase Auth account to roll back the failed signup
                      // This allows the user to sign up again with the same email corrected
                      try {
                        await user.delete();
                        // ignore: avoid_print
                        print(
                          '[EmailVerification] Deleted incomplete account for uid: $uid',
                        );
                      } on FirebaseAuthException catch (deleteError) {
                        // Account deletion can fail if user hasn't signed in recently
                        // In this case, just sign out. The account still exists but they
                        // can try creating a new one with a different email.
                        // ignore: avoid_print
                        print(
                          '[EmailVerification] Account deletion failed (${deleteError.code}): ${deleteError.message}',
                        );
                        if (mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text(
                                'Could not delete account. Please try again or use a different email.',
                              ),
                              backgroundColor: AppColors.error,
                              duration: const Duration(seconds: 3),
                            ),
                          );
                        }
                        // Still proceed with sign out
                      } catch (deleteError) {
                        // ignore: avoid_print
                        print(
                          '[EmailVerification] Unexpected deletion error: $deleteError',
                        );
                        // Still proceed with sign out
                      }
                    }

                    // Sign out any remaining auth session
                    await FirebaseAuth.instance.signOut();
                    // ignore: avoid_print
                    print('[EmailVerification] User signed out');
                  } catch (e) {
                    // ignore: avoid_print
                    print('[EmailVerification] Error during rollback: $e');
                    if (mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: const Text(
                            'Error signing out. Please restart the app.',
                          ),
                          backgroundColor: AppColors.error,
                        ),
                      );
                    }
                  }

                  if (!mounted) return;

                  // Cancel verification timer before navigating away
                  _timer?.cancel();
                  _resendCountdownTimer?.cancel();

                  // Navigate back to signup screen so user can fix the email address
                  Navigator.pushAndRemoveUntil(
                    context,
                    MaterialPageRoute(builder: (_) => const SignupScreen()),
                    (_) => false,
                  );
                },
                child: Text(
                  'Back to Create Account',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.getTextSecondary(context),
                    decoration: TextDecoration.underline,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
