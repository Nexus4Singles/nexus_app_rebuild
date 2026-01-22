import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/user/current_user_doc_provider.dart';
import '../../../core/bootstrap/bootstrap_gate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';

import '../../guest/guest_entry_gate.dart';
import '../../presurvey/presentation/splash/presurvey_splash_screen.dart';

import '../../auth/presentation/screens/login_screen.dart';
import '../../auth/presentation/screens/signup_screen.dart';
import 'screens/account_disabled_screen.dart';

class AppLaunchGate extends ConsumerWidget {
  const AppLaunchGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Always show splash first. Splash decides where to go next.
    return const _AppSplashRouter();
  }
}

class _AppSplashRouter extends ConsumerStatefulWidget {
  const _AppSplashRouter();

  @override
  ConsumerState<_AppSplashRouter> createState() => _AppSplashRouterState();
}

class _AppSplashRouterState extends ConsumerState<_AppSplashRouter> {
  Timer? _timer;
  int _retryCount = 0;
  static const _maxRetries = 6; // Max ~2 seconds of retries (6 x 350ms)

  @override
  void initState() {
    super.initState();
    // Short splash delay for branding; then route.
    _timer = Timer(const Duration(seconds: 2), _route);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  bool _isPresurveyCompleted(Map<String, dynamic>? doc) {
    if (doc == null) return false;
    final nexus = (doc['nexus'] as Map?)?.cast<String, dynamic>();
    final onboarding = (nexus?['onboarding'] as Map?)?.cast<String, dynamic>();
    return onboarding?['presurveyCompleted'] == true;
  }

  bool _isRelationshipStatusSelected(Map<String, dynamic>? doc) {
    if (doc == null) return false;
    final nexus = (doc['nexus'] as Map?)?.cast<String, dynamic>();
    final session = (nexus?['session'] as Map?)?.cast<String, dynamic>();
    final nexus2 = (doc['nexus2'] as Map?)?.cast<String, dynamic>();
    final statusCandidates = [
      session?['relationshipStatus'], // primary write path
      nexus2?['relationshipStatus'], // possible v2 path
      (nexus2?['profile'] as Map?)?['relationshipStatus'],
      (nexus?['profile'] as Map?)?['relationshipStatus'],
      doc['relationshipStatus'],
    ];
    return statusCandidates.any(
      (s) => s != null && s.toString().trim().isNotEmpty,
    );
  }

  bool _isAccountDisabled(Map<String, dynamic>? doc) {
    if (doc == null) return false;
    final account = (doc['account'] as Map?)?.cast<String, dynamic>();
    return (account?['disabled'] == true) || (account?['isDisabled'] == true);
  }

  void _route() {
    if (!mounted) return;

    final authAsync = ref.read(authStateProvider);

    authAsync.when(
      data: (user) {
        _retryCount = 0; // Reset retry count on data

        // Logged out (or anonymous) -> auth entry screen (with guest option).
        if (user == null || user.isAnonymous) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const GuestEntryGate(child: _AuthEntryScreen()),
            ),
          );
          return;
        }

        // Signed in -> check if account is disabled.
        final docAsync = ref.read(currentUserDocProvider);

        docAsync.when(
          data: (doc) {
            // First check: is account disabled?
            if (_isAccountDisabled(doc)) {
              final account =
                  (doc?['account'] as Map?)?.cast<String, dynamic>();
              final disabledReason = account?['disabledReason']?.toString();

              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder:
                      (_) =>
                          AccountDisabledScreen(disabledReason: disabledReason),
                ),
              );
              return;
            }

            // Second check: is relationship status selected (required for v1 users)?
            final hasRelationshipStatus = _isRelationshipStatusSelected(doc);
            if (!hasRelationshipStatus) {
              // V1 users must select relationship status in presurvey
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const PresurveySplashScreen(),
                ),
              );
              return;
            }

            // Third check: is presurvey completed?
            final done = _isPresurveyCompleted(doc);

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder:
                    (_) =>
                        done
                            ? const GuestEntryGate(child: BootstrapGate())
                            : const PresurveySplashScreen(),
              ),
            );
          },
          loading: () {
            // If still loading, keep splash visible and try again shortly.
            // But don't retry infinitely; after max retries, continue to app
            if (_retryCount >= _maxRetries) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const GuestEntryGate(child: BootstrapGate()),
                ),
              );
              return;
            }

            _retryCount++;
            _timer?.cancel();
            _timer = Timer(const Duration(milliseconds: 350), _route);
          },
          error: (_, __) {
            // Don't block signed-in users on transient Firestore issues.
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) => const GuestEntryGate(child: BootstrapGate()),
              ),
            );
          },
        );
      },
      loading: () {
        // Auth stream may still be resolving, but FirebaseAuth can already have a user.
        // Avoid getting stuck on splash by falling back to the synchronous currentUser.
        final fallbackUser = FirebaseAuth.instance.currentUser;
        if (fallbackUser != null && !fallbackUser.isAnonymous) {
          // Treat as signed in and continue routing.
          final docAsync = ref.read(currentUserDocProvider);

          docAsync.when(
            data: (doc) {
              _retryCount = 0; // Reset on data

              // Check if account is disabled first
              if (_isAccountDisabled(doc)) {
                final account =
                    (doc?['account'] as Map?)?.cast<String, dynamic>();
                final disabledReason = account?['disabledReason']?.toString();

                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder:
                        (_) => AccountDisabledScreen(
                          disabledReason: disabledReason,
                        ),
                  ),
                );
                return;
              }

              // V1 users must select relationship status
              final hasRelationshipStatus = _isRelationshipStatusSelected(doc);
              if (!hasRelationshipStatus) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const PresurveySplashScreen(),
                  ),
                );
                return;
              }

              final done = _isPresurveyCompleted(doc);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder:
                      (_) =>
                          done
                              ? const GuestEntryGate(child: BootstrapGate())
                              : const PresurveySplashScreen(),
                ),
              );
            },
            loading: () {
              // Retry with max limit
              if (_retryCount >= _maxRetries) {
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder:
                        (_) => const GuestEntryGate(child: BootstrapGate()),
                  ),
                );
                return;
              }

              _retryCount++;
              _timer?.cancel();
              _timer = Timer(const Duration(milliseconds: 350), _route);
            },
            error: (_, __) {
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const GuestEntryGate(child: BootstrapGate()),
                ),
              );
            },
          );
          return;
        }

        // Still no auth info; keep splash visible and try again.
        if (_retryCount >= _maxRetries) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const GuestEntryGate(child: _AuthEntryScreen()),
            ),
          );
          return;
        }

        _retryCount++;
        _timer?.cancel();
        _timer = Timer(const Duration(milliseconds: 350), _route);
      },
      error: (_, __) {
        // If auth stream errors, fall back to auth entry.
        Navigator.of(context).pushReplacement(
          MaterialPageRoute(
            builder: (_) => const GuestEntryGate(child: _AuthEntryScreen()),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _NexusSplashScreen();
  }
}

class _NexusSplashScreen extends StatelessWidget {
  const _NexusSplashScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 28),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Nexus',
                  style: AppTextStyles.headlineLarge.copyWith(
                    color: Colors.white,
                    fontSize: 40,
                    fontWeight: FontWeight.w800,
                    letterSpacing: -0.4,
                  ),
                ),
                const SizedBox(height: 18),
                Image.asset(
                  'assets/images/nexus_logo.png',
                  height: 132,
                  fit: BoxFit.contain,
                ),
                const SizedBox(height: 18),
                Text(
                  'Raising Godly Families through Kingdom Relationships & Marriages.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: Colors.white.withOpacity(0.95),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 22),
                const CircularProgressIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _AuthEntryScreen extends StatelessWidget {
  const _AuthEntryScreen();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        fit: StackFit.expand,
        children: [
          // Background Image
          Image.asset('assets/images/welcome_bg.jpg', fit: BoxFit.cover),

          // Gradient overlay for better text readability
          Container(
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
                colors: [
                  Colors.black.withOpacity(0.3),
                  Colors.black.withOpacity(0.5),
                  Colors.black.withOpacity(0.8),
                ],
                stops: const [0.0, 0.5, 1.0],
              ),
            ),
          ),

          // Content
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Logo/Title at top
                  Text(
                    'Welcome',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.bold,
                    ),
                  ),

                  const Spacer(),

                  // CTAs at bottom with backdrop
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.95),
                      borderRadius: BorderRadius.circular(24),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 20,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Choose how you want to continue',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textSecondary,
                          ),
                        ),
                        const SizedBox(height: 20),

                        SizedBox(
                          height: 54,
                          child: ElevatedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const LoginScreen(),
                                ),
                              );
                            },
                            style: ElevatedButton.styleFrom(
                              backgroundColor: AppColors.primary,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              elevation: 0,
                            ),
                            child: Text(
                              'Log In',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        SizedBox(
                          height: 54,
                          child: OutlinedButton(
                            onPressed: () {
                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) => const SignupScreen(),
                                ),
                              );
                            },
                            style: OutlinedButton.styleFrom(
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                              side: BorderSide(
                                color: AppColors.primary,
                                width: 2,
                              ),
                              backgroundColor: Colors.white,
                            ),
                            child: Text(
                              'Create Account',
                              style: AppTextStyles.labelLarge.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),

                        TextButton(
                          onPressed: () {
                            Navigator.pushAndRemoveUntil(
                              context,
                              MaterialPageRoute(
                                builder:
                                    (_) => const GuestEntryGate(
                                      child: BootstrapGate(),
                                    ),
                              ),
                              (_) => false,
                            );
                          },
                          child: Text(
                            'Continue as Guest',
                            style: AppTextStyles.labelLarge.copyWith(
                              color: AppColors.textSecondary,
                              decoration: TextDecoration.underline,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
