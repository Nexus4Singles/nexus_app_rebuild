import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';

/// Premium animated splash screen for Nexus 2.0
/// Features:
/// - Animated logo reveal with scale and fade
/// - Pulsing glow effect
/// - Smooth transition to next screen
class SplashScreen extends ConsumerStatefulWidget {
  const SplashScreen({super.key});

  @override
  ConsumerState<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends ConsumerState<SplashScreen>
    with TickerProviderStateMixin {
  // Animation controllers
  late AnimationController _logoController;
  late AnimationController _glowController;
  late AnimationController _textController;
  late AnimationController _fadeOutController;
  
  // Logo animations
  late Animation<double> _logoScale;
  late Animation<double> _logoOpacity;
  late Animation<double> _logoRotation;
  
  // Glow animation
  late Animation<double> _glowOpacity;
  late Animation<double> _glowScale;
  
  // Text animations
  late Animation<double> _textOpacity;
  late Animation<Offset> _textSlide;
  late Animation<double> _taglineOpacity;
  
  // Fade out
  late Animation<double> _fadeOut;

  bool _isNavigating = false;

  @override
  void initState() {
    super.initState();
    
    // Set status bar style
    SystemChrome.setSystemUIOverlayStyle(
      const SystemUiOverlayStyle(
        statusBarColor: Colors.transparent,
        statusBarIconBrightness: Brightness.light,
      ),
    );
    
    _initAnimations();
    _startAnimations();
  }

  void _initAnimations() {
    // Logo controller - 1.2 seconds
    _logoController = AnimationController(
      duration: const Duration(milliseconds: 1200),
      vsync: this,
    );
    
    // Logo scale: starts small, bounces to full size
    _logoScale = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: 0.0, end: 1.15).chain(CurveTween(curve: Curves.easeOut)),
        weight: 60,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 1.15, end: 1.0).chain(CurveTween(curve: Curves.elasticOut)),
        weight: 40,
      ),
    ]).animate(_logoController);
    
    // Logo opacity: fade in
    _logoOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _logoController,
        curve: const Interval(0.0, 0.5, curve: Curves.easeOut),
      ),
    );
    
    // Subtle rotation for dynamism
    _logoRotation = TweenSequence<double>([
      TweenSequenceItem(
        tween: Tween(begin: -0.05, end: 0.02),
        weight: 50,
      ),
      TweenSequenceItem(
        tween: Tween(begin: 0.02, end: 0.0),
        weight: 50,
      ),
    ]).animate(CurvedAnimation(
      parent: _logoController,
      curve: Curves.easeInOut,
    ));
    
    // Glow controller - continuous pulse
    _glowController = AnimationController(
      duration: const Duration(milliseconds: 2000),
      vsync: this,
    );
    
    _glowOpacity = Tween<double>(begin: 0.3, end: 0.7).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    _glowScale = Tween<double>(begin: 1.0, end: 1.3).animate(
      CurvedAnimation(parent: _glowController, curve: Curves.easeInOut),
    );
    
    // Text controller - 800ms, starts after logo
    _textController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );
    
    _textOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _textController, curve: Curves.easeOut),
    );
    
    _textSlide = Tween<Offset>(
      begin: const Offset(0, 0.3),
      end: Offset.zero,
    ).animate(CurvedAnimation(
      parent: _textController,
      curve: Curves.easeOut,
    ));
    
    _taglineOpacity = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(
        parent: _textController,
        curve: const Interval(0.3, 1.0, curve: Curves.easeOut),
      ),
    );
    
    // Fade out controller
    _fadeOutController = AnimationController(
      duration: const Duration(milliseconds: 400),
      vsync: this,
    );
    
    _fadeOut = Tween<double>(begin: 1.0, end: 0.0).animate(
      CurvedAnimation(parent: _fadeOutController, curve: Curves.easeIn),
    );
  }

  void _startAnimations() async {
    // Start logo animation
    await Future.delayed(const Duration(milliseconds: 200));
    _logoController.forward();
    
    // Start glow pulse after logo appears
    await Future.delayed(const Duration(milliseconds: 600));
    _glowController.repeat(reverse: true);
    
    // Start text animation
    await Future.delayed(const Duration(milliseconds: 400));
    _textController.forward();
    
    // Check auth and navigate after animations
    await Future.delayed(const Duration(milliseconds: 1500));
    _checkAuthAndNavigate();
  }

  void _checkAuthAndNavigate() async {
    if (_isNavigating) return;
    _isNavigating = true;
    
    // Fade out before navigation
    await _fadeOutController.forward();
    
    if (!mounted) return;
    
    final authState = ref.read(authStateProvider);
    
    authState.when(
      data: (user) {
        if (user != null) {
          // User is logged in, check profile completion
          final userProfile = ref.read(currentUserProvider).valueOrNull;
          
          if (userProfile?.nexus2?.relationshipStatus == null) {
            // Needs to complete survey
            context.go('/survey');
          } else {
            // Go to home
            context.go('/home');
          }
        } else {
          // Not logged in
          context.go('/login');
        }
      },
      loading: () {
        // Still loading, wait a bit more
        Future.delayed(const Duration(milliseconds: 500), () {
          if (mounted) _checkAuthAndNavigate();
        });
      },
      error: (_, __) {
        context.go('/login');
      },
    );
  }

  @override
  void dispose() {
    _logoController.dispose();
    _glowController.dispose();
    _textController.dispose();
    _fadeOutController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: AnimatedBuilder(
        animation: _fadeOut,
        builder: (context, child) {
          return Opacity(
            opacity: _fadeOut.value,
            child: Container(
              width: double.infinity,
              height: double.infinity,
              decoration: const BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Color(0xFFBA223C), // Primary
                    Color(0xFF8E1A2E), // Primary Dark
                  ],
                ),
              ),
              child: Stack(
                children: [
                  // Background pattern (subtle)
                  _buildBackgroundPattern(),
                  
                  // Main content
                  Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Spacer(flex: 3),
                        
                        // Logo with glow
                        _buildAnimatedLogo(),
                        
                        const SizedBox(height: 32),
                        
                        // App name
                        _buildAppName(),
                        
                        const SizedBox(height: 12),
                        
                        // Tagline
                        _buildTagline(),
                        
                        const Spacer(flex: 4),
                        
                        // Loading indicator
                        _buildLoadingIndicator(),
                        
                        const SizedBox(height: 48),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBackgroundPattern() {
    return Positioned.fill(
      child: CustomPaint(
        painter: _PatternPainter(),
      ),
    );
  }

  Widget _buildAnimatedLogo() {
    return AnimatedBuilder(
      animation: Listenable.merge([_logoController, _glowController]),
      builder: (context, child) {
        return Transform.rotate(
          angle: _logoRotation.value,
          child: Transform.scale(
            scale: _logoScale.value,
            child: Opacity(
              opacity: _logoOpacity.value,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  // Glow effect
                  Transform.scale(
                    scale: _glowScale.value,
                    child: Container(
                      width: 180,
                      height: 180,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.white.withOpacity(_glowOpacity.value * 0.3),
                            blurRadius: 60,
                            spreadRadius: 20,
                          ),
                        ],
                      ),
                    ),
                  ),
                  
                  // Logo container
                  Container(
                    width: 140,
                    height: 140,
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(32),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withOpacity(0.2),
                          blurRadius: 30,
                          offset: const Offset(0, 10),
                        ),
                      ],
                    ),
                    padding: const EdgeInsets.all(20),
                    child: Image.asset(
                      'assets/images/logo.png',
                      errorBuilder: (_, __, ___) => _buildFallbackLogo(),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildFallbackLogo() {
    // Fallback if logo asset not found - recreate logo shape
    return CustomPaint(
      size: const Size(100, 100),
      painter: _LogoPainter(),
    );
  }

  Widget _buildAppName() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return SlideTransition(
          position: _textSlide,
          child: Opacity(
            opacity: _textOpacity.value,
            child: const Text(
              'NEXUS',
              style: TextStyle(
                fontSize: 42,
                fontWeight: FontWeight.w800,
                color: Colors.white,
                letterSpacing: 8,
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTagline() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return Opacity(
          opacity: _taglineOpacity.value,
          child: Text(
            'Raising Godly Families through\nKingdom Marriages',
            textAlign: TextAlign.center,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.w400,
              color: Colors.white.withOpacity(0.9),
              height: 1.5,
              letterSpacing: 0.5,
            ),
          ),
        );
      },
    );
  }

  Widget _buildLoadingIndicator() {
    return AnimatedBuilder(
      animation: _textController,
      builder: (context, child) {
        return Opacity(
          opacity: _taglineOpacity.value,
          child: SizedBox(
            width: 24,
            height: 24,
            child: CircularProgressIndicator(
              strokeWidth: 2.5,
              valueColor: AlwaysStoppedAnimation<Color>(
                Colors.white.withOpacity(0.8),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Background pattern painter - subtle geometric pattern
class _PatternPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = Colors.white.withOpacity(0.03)
      ..style = PaintingStyle.fill;
    
    // Draw subtle circles pattern
    const spacing = 80.0;
    const radius = 40.0;
    
    for (double x = -radius; x < size.width + radius; x += spacing) {
      for (double y = -radius; y < size.height + radius; y += spacing) {
        canvas.drawCircle(Offset(x, y), radius, paint);
      }
    }
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

/// Fallback logo painter - recreates the Nexus heart/infinity logo
class _LogoPainter extends CustomPainter {
  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = AppColors.primary
      ..style = PaintingStyle.stroke
      ..strokeWidth = 8
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    
    final path = Path();
    final w = size.width;
    final h = size.height;
    
    // Draw heart-like infinity symbol
    // Left heart curve
    path.moveTo(w * 0.5, h * 0.35);
    path.cubicTo(
      w * 0.15, h * 0.0,
      w * -0.05, h * 0.5,
      w * 0.5, h * 0.9,
    );
    
    // Right heart curve
    path.moveTo(w * 0.5, h * 0.35);
    path.cubicTo(
      w * 0.85, h * 0.0,
      w * 1.05, h * 0.5,
      w * 0.5, h * 0.9,
    );
    
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}
