import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/session/guest_session_provider.dart';
import '../screens/presurvey_relationship_status_screen.dart';

class PresurveySplashScreen extends ConsumerStatefulWidget {
  const PresurveySplashScreen({super.key});

  @override
  ConsumerState<PresurveySplashScreen> createState() =>
      _PresurveySplashScreenState();
}

class _PresurveySplashScreenState extends ConsumerState<PresurveySplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _mainController;

  // Phase 1: Logo entrance & rotation
  late final Animation<double> _logoRotation;
  late final Animation<double> _logoGlow;

  // Phase 2: Title slide & fade
  late final Animation<Offset> _titleSlide;
  late final Animation<double> _titleFade;
  late final Animation<double> _titleScale;

  // Phase 3: Tagline slide & fade
  late final Animation<Offset> _taglineSlide;
  late final Animation<double> _taglineFade;

  // Overall container effects
  late final Animation<double> _containerFade;
  late final Animation<double> _containerScale;

  // Pulsing effects
  late final Animation<double> _logoPulse;

  Timer? _navigationTimer;

  @override
  void initState() {
    super.initState();

    // Pre-cache logo image to load immediately
    Future.microtask(() {
      precacheImage(const AssetImage('assets/images/nexus_logo.png'), context);
    });

    // Always reset guest session at the start of presurvey
    Future.microtask(() => ref.read(guestSessionProvider.notifier).clear());

    // Branding animation controller
    _mainController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 3500),
    );

    // PHASE 1 (0% - 15%): Logo enters with rotation
    _logoRotation = Tween<double>(begin: -0.3, end: 0.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOutBack),
      ),
    );

    _logoGlow = Tween<double>(begin: 0.3, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.15, curve: Curves.easeOut),
      ),
    );

    // PHASE 2 (15% - 35%): Title slides in from top
    _titleSlide = Tween<Offset>(
      begin: const Offset(0, -0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.15, 0.35, curve: Curves.easeOutCubic),
      ),
    );

    _titleFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.15, 0.35, curve: Curves.easeOut),
      ),
    );

    _titleScale = Tween<double>(begin: 0.7, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.15, 0.35, curve: Curves.easeOutBack),
      ),
    );

    // PHASE 3 (35% - 55%): Tagline slides in from bottom
    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.5),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.55, curve: Curves.easeOutCubic),
      ),
    );

    _taglineFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.35, 0.55, curve: Curves.easeOut),
      ),
    );

    // Overall container animations
    _containerFade = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.2, curve: Curves.easeOut),
      ),
    );

    _containerScale = Tween<double>(begin: 0.85, end: 1.0).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.0, 0.25, curve: Curves.easeOutBack),
      ),
    );

    // PHASE 4 (55% - 100%): Pulsing glow effect (breathing animation)
    _logoPulse = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(
        parent: _mainController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeInOutSine),
      ),
    );

    _mainController.forward();

    // Auto-route after animation completes
    _navigationTimer = Timer(const Duration(seconds: 4), _goNext);
  }

  void _goNext() {
    if (!mounted) return;
    Navigator.pushReplacement(
      context,
      MaterialPageRoute(
        builder: (_) => const PresurveyRelationshipStatusScreen(),
      ),
    );
  }

  @override
  void dispose() {
    _navigationTimer?.cancel();
    _mainController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: FadeTransition(
          opacity: _containerFade,
          child: ScaleTransition(
            scale: _containerScale,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    // ===== TITLE SECTION =====
                    SlideTransition(
                      position: _titleSlide,
                      child: FadeTransition(
                        opacity: _titleFade,
                        child: ScaleTransition(
                          scale: _titleScale,
                          child: Text(
                            'Nexus',
                            style: AppTextStyles.displaySmall.copyWith(
                              color: Colors.white,
                              fontWeight: FontWeight.w700,
                              letterSpacing: -0.4,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ===== LOGO SECTION WITH DRAMATIC EFFECTS =====
                    ScaleTransition(
                      scale: _logoPulse,
                      child: RotationTransition(
                        turns: _logoRotation,
                        child: FadeTransition(
                          opacity: _logoGlow,
                          child: AnimatedBuilder(
                            animation: _mainController,
                            builder: (context, child) {
                              // Create pulsing shadow/glow effect
                              final glowIntensity = _logoPulse.value;
                              return Container(
                                decoration: BoxDecoration(
                                  boxShadow: [
                                    BoxShadow(
                                      color: Colors.white.withOpacity(
                                        0.3 * (_logoPulse.value - 1.0) * 10,
                                      ),
                                      blurRadius: 20 * glowIntensity,
                                      spreadRadius: 5 * glowIntensity,
                                    ),
                                  ],
                                ),
                                child: child,
                              );
                            },
                            child: Image.asset(
                              'assets/images/nexus_logo.png',
                              height: 50,
                              width: 70,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    // ===== TAGLINE SECTION =====
                    SlideTransition(
                      position: _taglineSlide,
                      child: FadeTransition(
                        opacity: _taglineFade,
                        child: Text(
                          'Raising Godly Families through Kingdom Relationships & Marriages.',
                          textAlign: TextAlign.center,
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: Colors.white.withOpacity(0.95),
                            height: 1.35,
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
