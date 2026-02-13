import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../../core/providers/auth_provider.dart';
import '../../../core/user/current_user_doc_provider.dart';
import '../../../core/bootstrap/bootstrap_gate.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/app_text_styles.dart';
import '../../../core/notifications/notification_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../guest/guest_entry_gate.dart';
import '../../presurvey/presentation/screens/presurvey_relationship_status_screen.dart';
import '../../../core/session/guest_session_provider.dart';

import '../../auth/presentation/screens/login_screen.dart';
import '../../auth/presentation/screens/signup_screen.dart';
import 'screens/account_disabled_screen.dart';

class AppLaunchGate extends ConsumerWidget {
  const AppLaunchGate({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Initialize FCM for push notifications
    ref.watch(fcmInitializationProvider);

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
    // Show splash for 5 seconds to allow full animation viewing
    _timer = Timer(const Duration(seconds: 5), _route);
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

        // Logged out (or anonymous) -> Welcome screen with auth options
        if (user == null || user.isAnonymous) {
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(builder: (_) => const _AuthEntryScreen()),
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
              ref.read(guestSessionProvider.notifier).clear();
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder: (_) => const PresurveyRelationshipStatusScreen(),
                ),
              );
              return;
            }

            // Third check: is presurvey completed?
            final done = _isPresurveyCompleted(doc);

            if (!done) {
              ref.read(guestSessionProvider.notifier).clear();
            }
            Navigator.of(context).pushReplacement(
              MaterialPageRoute(
                builder:
                    (_) =>
                        done
                            ? const GuestEntryGate(child: BootstrapGate())
                            : const PresurveyRelationshipStatusScreen(),
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
                ref.read(guestSessionProvider.notifier).clear();
                Navigator.of(context).pushReplacement(
                  MaterialPageRoute(
                    builder: (_) => const PresurveyRelationshipStatusScreen(),
                  ),
                );
                return;
              }

              final done = _isPresurveyCompleted(doc);
              if (!done) {
                ref.read(guestSessionProvider.notifier).clear();
              }
              Navigator.of(context).pushReplacement(
                MaterialPageRoute(
                  builder:
                      (_) =>
                          done
                              ? const GuestEntryGate(child: BootstrapGate())
                              : const PresurveyRelationshipStatusScreen(),
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
            MaterialPageRoute(builder: (_) => const _AuthEntryScreen()),
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
          MaterialPageRoute(builder: (_) => const _AuthEntryScreen()),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return const _NexusSplashScreen();
  }
}

class _NexusSplashScreen extends StatefulWidget {
  const _NexusSplashScreen();

  @override
  State<_NexusSplashScreen> createState() => _NexusSplashScreenState();
}

class _NexusSplashScreenState extends State<_NexusSplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _controller;
  late final AnimationController _shimmerController;

  // Title: dramatic slide from LEFT
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;

  // Logo: dramatic scale + fade
  late final Animation<double> _logoScale;
  late final Animation<double> _logoFade;
  late final Animation<Offset> _logoSlide;

  // Tagline: dramatic slide from RIGHT
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _taglineFade;

  // Shimmer effect on logo
  late final Animation<double> _shimmer;

  @override
  void initState() {
    super.initState();

    // Pre-cache logo
    Future.microtask(() {
      if (mounted) {
        precacheImage(
          const AssetImage('assets/images/nexus_logo.png'),
          context,
        );
      }
    });

    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    );

    _shimmerController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    );

    // ─────────────────────────────────
    // TITLE: Slide dramatically from LEFT
    // ─────────────────────────────────
    _titleSlide = Tween<Offset>(
      begin: const Offset(-1.2, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.35, curve: Curves.easeOutCubic),
      ),
    );
    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.0, 0.30, curve: Curves.easeOut),
      ),
    );

    // ──────────────────────────────────────────
    // LOGO: Dramatic scale bounce + fade + slide
    // ──────────────────────────────────────────
    _logoScale = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.60, curve: Curves.easeOutBack),
      ),
    );
    _logoFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.45, curve: Curves.easeOut),
      ),
    );
    _logoSlide = Tween<Offset>(
      begin: const Offset(0, -0.3),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.25, 0.60, curve: Curves.easeOutCubic),
      ),
    );

    // ─────────────────────────────────
    // TAGLINE: Slide dramatically from RIGHT
    // ─────────────────────────────────
    _taglineSlide = Tween<Offset>(
      begin: const Offset(1.2, 0),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.80, curve: Curves.easeOutCubic),
      ),
    );
    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _controller,
        curve: const Interval(0.45, 0.75, curve: Curves.easeOut),
      ),
    );

    // Shimmer effect on logo
    _shimmer = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _shimmerController, curve: Curves.easeInOut),
    );

    _controller.forward();
    // Start shimmer after main entrance finishes
    Future.delayed(const Duration(milliseconds: 1500), () {
      if (mounted) _shimmerController.repeat(reverse: true);
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    _shimmerController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: Center(
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // ══════════════════════════════════
              // NEXUS TITLE: Slides in from LEFT
              // ══════════════════════════════════
              SlideTransition(
                position: _titleSlide,
                child: FadeTransition(
                  opacity: _titleFade,
                  child: Text(
                    'Nexus',
                    style: AppTextStyles.headlineLarge.copyWith(
                      color: Colors.white,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.5,
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 12),

              // ══════════════════════════════════
              // LOGO: Dramatic scale + fade + slide
              // ══════════════════════════════════
              SlideTransition(
                position: _logoSlide,
                child: ScaleTransition(
                  scale: _logoScale,
                  child: FadeTransition(
                    opacity: _logoFade,
                    child: AnimatedBuilder(
                      animation: _shimmerController,
                      builder: (context, child) {
                        return Container(
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            boxShadow: [
                              BoxShadow(
                                color: Colors.white.withOpacity(
                                  0.06 + 0.06 * _shimmer.value,
                                ),
                                blurRadius: 20 + 8 * _shimmer.value,
                                spreadRadius: 2 + 3 * _shimmer.value,
                              ),
                            ],
                          ),
                          child: child,
                        );
                      },
                      child: Image.asset(
                        'assets/images/nexus_logo.png',
                        height: 100,
                        fit: BoxFit.contain,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(height: 14),

              // ══════════════════════════════════
              // TAGLINE: Slides in from RIGHT
              // ══════════════════════════════════
              SlideTransition(
                position: _taglineSlide,
                child: FadeTransition(
                  opacity: _taglineFade,
                  child: Text(
                    'Raising Godly Families through\nKingdom Relationships & Marriages.',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: Colors.white.withOpacity(0.9),
                      fontSize: 14,
                      height: 1.4,
                      letterSpacing: 0.2,
                    ),
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

class _AuthEntryScreen extends StatelessWidget {
  const _AuthEntryScreen();

  @override
  Widget build(BuildContext context) {
    // Clear presurvey flag so users see it again if they're new
    Future.microtask(() async {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove('presurvey_local_done');
    });

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
                            color: AppColors.getTextSecondary(context),
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
                            onPressed: () async {
                              // First-time only: run presurvey before signup.
                              // Subsequent visits skip if local flag is set.
                              final prefs =
                                  await SharedPreferences.getInstance();
                              final done =
                                  prefs.getBool('presurvey_local_done') == true;

                              if (done) {
                                Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) => const SignupScreen(),
                                  ),
                                );
                                return;
                              }

                              Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder:
                                      (_) =>
                                          const PresurveyRelationshipStatusScreen(),
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
                              color: AppColors.getTextSecondary(context),
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
