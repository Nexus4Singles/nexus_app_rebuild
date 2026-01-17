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

  void _route() {
    if (!mounted) return;

    final authAsync = ref.read(authStateProvider);

    authAsync.when(
      data: (user) {
        // Logged out (or anonymous) -> auth entry screen (with guest option).
        if (user == null || user.isAnonymous) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => const GuestEntryGate(child: _AuthEntryScreen()),
            ),
          );
          return;
        }

        // Signed in -> check presurvey completion from Firestore doc.
        final docAsync = ref.read(currentUserDocProvider);

        docAsync.when(
          data: (doc) {
            final done = _isPresurveyCompleted(doc);

            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder: (_) =>
                    done
                        ? const GuestEntryGate(child: BootstrapGate())
                        : const PresurveySplashScreen(),
              ),
            );
          },
          loading: () {
            // If still loading, keep splash visible and try again shortly.
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
              final done = _isPresurveyCompleted(doc);
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) =>
                      done
                          ? const GuestEntryGate(child: BootstrapGate())
                          : const PresurveySplashScreen(),
                ),
              );
            },
            loading: () {
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        centerTitle: true,
        title: Text('Welcome', style: AppTextStyles.headlineLarge),
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 10),
              Text(
                'Choose how you want to continue',
                textAlign: TextAlign.center,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.textMuted,
                ),
              ),
              const SizedBox(height: 22),

              SizedBox(
                height: 54,
                child: ElevatedButton(
                  onPressed: () {
                    Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                  ),
                  child: Text(
                    'Log In',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
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
                      MaterialPageRoute(builder: (_) => const SignupScreen()),
                    );
                  },
                  style: OutlinedButton.styleFrom(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                    ),
                    side: BorderSide(color: AppColors.border),
                  ),
                  child: Text(
                    'Create Account',
                    style: AppTextStyles.labelLarge,
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
                          (_) => const GuestEntryGate(child: BootstrapGate()),
                    ),
                    (_) => false,
                  );
                },
                child: Text(
                  'Continue as Guest',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.textMuted,
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
