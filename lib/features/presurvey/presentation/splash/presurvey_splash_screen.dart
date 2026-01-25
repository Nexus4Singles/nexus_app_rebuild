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
  late final AnimationController _c;

  late final Animation<double> _fade;
  late final Animation<double> _scale;

  late final Animation<Offset> _titleSlide;
  late final Animation<Offset> _logoSlide;
  late final Animation<Offset> _taglineSlide;

  Timer? _timer;

  @override
  void initState() {
    super.initState();

    // Always reset guest session at the start of presurvey
    Future.microtask(() => ref.read(guestSessionProvider.notifier).clear());

    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 4500),
    );

    _fade = CurvedAnimation(parent: _c, curve: Curves.easeOut);

    _scale = Tween<double>(
      begin: 0.78,
      end: 1.0,
    ).animate(CurvedAnimation(parent: _c, curve: Curves.easeOutBack));

    _titleSlide = Tween<Offset>(
      begin: const Offset(0, -0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.0, 0.75, curve: Curves.easeOut),
      ),
    );

    _logoSlide = Tween<Offset>(
      begin: const Offset(0, 0.35),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.10, 0.90, curve: Curves.easeOutBack),
      ),
    );

    _taglineSlide = Tween<Offset>(
      begin: const Offset(0, 0.55),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _c,
        curve: const Interval(0.25, 1.0, curve: Curves.easeOut),
      ),
    );

    _c.forward();

    // Auto-route after 5 seconds
    _timer = Timer(const Duration(seconds: 10), _goNext);
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
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.primary,
      body: SafeArea(
        child: FadeTransition(
          opacity: _fade,
          child: ScaleTransition(
            scale: _scale,
            child: Center(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 28),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    SlideTransition(
                      position: _titleSlide,
                      child: Text(
                        'Nexus',
                        style: AppTextStyles.headlineLarge.copyWith(
                          color: Colors.white,
                          fontSize: 30,
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),
                    ),
                    const SizedBox(height: 18),

                    SlideTransition(
                      position: _logoSlide,
                      child: Image.asset(
                        'assets/images/nexus_logo.png',
                        height: 132,
                        fit: BoxFit.contain,
                      ),
                    ),
                    const SizedBox(height: 18),

                    SlideTransition(
                      position: _taglineSlide,
                      child: Text(
                        'Raising Godly Families through Kingdom Relationships & Marriages.',
                        textAlign: TextAlign.center,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.95),
                          height: 1.35,
                        ),
                      ),
                    ),
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
