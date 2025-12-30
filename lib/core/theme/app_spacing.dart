import 'package:flutter/material.dart';

/// Nexus 2.0 Spacing System
class AppSpacing {
  // Animation tokens
  static const Duration durationFast = Duration(milliseconds: 180);
  static const Duration durationMedium = Duration(milliseconds: 280);
  static const Curve curveStandard = Curves.easeOutCubic;

  AppSpacing._();

  // Base spacing unit (4px grid)
  static const double unit = 4.0;

  // Named spacing values
  static const double xxs = 2.0; // unit * 0.5
  static const double xs = 4.0; // unit * 1
  static const double sm = 8.0; // unit * 2
  static const double md = 12.0; // unit * 3
  static const double base = 16.0; // unit * 4
  static const double lg = 20.0; // unit * 5
  static const double xl = 24.0; // unit * 6
  static const double xxl = 32.0; // unit * 8
  static const double xxxl = 40.0; // unit * 10
  static const double huge = 48.0; // unit * 12
  static const double massive = 64.0; // unit * 16

  // Screen padding
  static const double screenHorizontal = 20.0;
  static const double screenVertical = 24.0;
  static const EdgeInsets screenPadding = EdgeInsets.symmetric(
    horizontal: screenHorizontal,
    vertical: screenVertical,
  );

  // Card padding
  static const double cardPadding = 16.0;
  static const EdgeInsets cardInsets = EdgeInsets.all(cardPadding);

  // List item spacing
  static const double listItemSpacing = 12.0;
  static const double listSectionSpacing = 24.0;

  // Form spacing
  static const double formFieldSpacing = 16.0;
  static const double formSectionSpacing = 24.0;
  static const double inputVerticalPadding = 16.0;
  static const double inputHorizontalPadding = 16.0;

  // Button spacing
  static const double buttonVerticalPadding = 16.0;
  static const double buttonHorizontalPadding = 24.0;
  static const double buttonSpacing = 12.0;

  // Icon sizing
  static const double iconXs = 16.0;
  static const double iconSm = 20.0;
  static const double iconMd = 24.0;
  static const double iconLg = 28.0;
  static const double iconXl = 32.0;

  // Avatar sizes
  static const double avatarXs = 24.0;
  static const double avatarSm = 32.0;
  static const double avatarMd = 40.0;
  static const double avatarLg = 56.0;
  static const double avatarXl = 80.0;
  static const double avatarXxl = 120.0;

  // Bottom navigation
  static const double bottomNavHeight = 64.0;
  static const double bottomNavIconSize = 24.0;

  // App bar
  static const double appBarHeight = 56.0;
  static const double appBarElevation = 0.0;

  // Modal/Bottom sheet
  static const double bottomSheetRadius = 24.0;
  static const double modalRadius = 16.0;

  // Safe area bottom padding (for buttons above bottom nav)
  static const double safeAreaBottom = 34.0;

  // Border radius values (for convenience - also available in AppRadius)
  static const double radiusNone = 0.0;
  static const double radiusXs = 4.0;
  static const double radiusSm = 8.0;
  static const double radiusMd = 12.0;
  static const double radiusBase = 16.0;
  static const double radiusLg = 20.0;
  static const double radiusXl = 24.0;
  static const double radiusXxl = 32.0;
  static const double radiusFull = 999.0; // For pills/circles

  // Box shadows (convenience access to AppShadows)
  static const List<BoxShadow> shadowNone = [];
  static const List<BoxShadow> shadowSm = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
  ];
  static const List<BoxShadow> shadowMd = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
  ];
  static const List<BoxShadow> shadowLg = [
    BoxShadow(color: Color(0x10000000), blurRadius: 16, offset: Offset(0, 4)),
  ];
  static const List<BoxShadow> shadowXl = [
    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
  ];

  // Spacing widgets
  static const SizedBox verticalXxs = SizedBox(height: xxs);
  static const SizedBox verticalXs = SizedBox(height: xs);
  static const SizedBox verticalSm = SizedBox(height: sm);
  static const SizedBox verticalMd = SizedBox(height: md);
  static const SizedBox verticalBase = SizedBox(height: base);
  static const SizedBox verticalLg = SizedBox(height: lg);
  static const SizedBox verticalXl = SizedBox(height: xl);
  static const SizedBox verticalXxl = SizedBox(height: xxl);
  static const SizedBox verticalXxxl = SizedBox(height: xxxl);

  static const SizedBox horizontalXxs = SizedBox(width: xxs);
  static const SizedBox horizontalXs = SizedBox(width: xs);
  static const SizedBox horizontalSm = SizedBox(width: sm);
  static const SizedBox horizontalMd = SizedBox(width: md);
  static const SizedBox horizontalBase = SizedBox(width: base);
  static const SizedBox horizontalLg = SizedBox(width: lg);
  static const SizedBox horizontalXl = SizedBox(width: xl);
  static const SizedBox horizontalXxl = SizedBox(width: xxl);
}

/// Nexus 2.0 Border Radius System
class AppRadius {
  AppRadius._();

  // Named radius values
  static const double none = 0.0;
  static const double xs = 4.0;
  static const double sm = 8.0;
  static const double md = 12.0;
  static const double base = 16.0;
  static const double lg = 20.0;
  static const double xl = 24.0;
  static const double xxl = 32.0;
  static const double full = 999.0; // For pills/circles

  // BorderRadius objects
  static const BorderRadius borderRadiusNone = BorderRadius.zero;
  static const BorderRadius borderRadiusXs = BorderRadius.all(
    Radius.circular(xs),
  );
  static const BorderRadius borderRadiusSm = BorderRadius.all(
    Radius.circular(sm),
  );
  static const BorderRadius borderRadiusMd = BorderRadius.all(
    Radius.circular(md),
  );
  static const BorderRadius borderRadiusBase = BorderRadius.all(
    Radius.circular(base),
  );
  static const BorderRadius borderRadiusLg = BorderRadius.all(
    Radius.circular(lg),
  );
  static const BorderRadius borderRadiusXl = BorderRadius.all(
    Radius.circular(xl),
  );
  static const BorderRadius borderRadiusXxl = BorderRadius.all(
    Radius.circular(xxl),
  );
  static const BorderRadius borderRadiusFull = BorderRadius.all(
    Radius.circular(full),
  );

  // Common shapes
  static const BorderRadius card = borderRadiusBase;
  static const BorderRadius button = borderRadiusMd;
  static const BorderRadius input = borderRadiusMd;
  static const BorderRadius chip = borderRadiusFull;
  static const BorderRadius modal = borderRadiusXl;
  static const BorderRadius bottomSheet = BorderRadius.only(
    topLeft: Radius.circular(xl),
    topRight: Radius.circular(xl),
  );
  static const BorderRadius topRounded = BorderRadius.only(
    topLeft: Radius.circular(base),
    topRight: Radius.circular(base),
  );
  static const BorderRadius bottomRounded = BorderRadius.only(
    bottomLeft: Radius.circular(base),
    bottomRight: Radius.circular(base),
  );
}

/// Nexus 2.0 Shadow System
class AppShadows {
  AppShadows._();

  static const List<BoxShadow> none = [];

  static const List<BoxShadow> sm = [
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> md = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
    BoxShadow(color: Color(0x0A000000), blurRadius: 4, offset: Offset(0, 1)),
  ];

  static const List<BoxShadow> lg = [
    BoxShadow(color: Color(0x10000000), blurRadius: 16, offset: Offset(0, 4)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, 2)),
  ];

  static const List<BoxShadow> xl = [
    BoxShadow(color: Color(0x14000000), blurRadius: 24, offset: Offset(0, 8)),
    BoxShadow(color: Color(0x0D000000), blurRadius: 12, offset: Offset(0, 4)),
  ];

  static const List<BoxShadow> card = md;
  static const List<BoxShadow> button = sm;
  static const List<BoxShadow> modal = xl;
  static const List<BoxShadow> bottomNav = [
    BoxShadow(color: Color(0x0D000000), blurRadius: 8, offset: Offset(0, -2)),
  ];
}

/// Animation Durations
class AppDurations {
  AppDurations._();

  static const Duration instant = Duration.zero;
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 350);
  static const Duration slower = Duration(milliseconds: 500);
  static const Duration slowest = Duration(milliseconds: 750);
}

/// Animation Curves
class AppCurves {
  AppCurves._();

  static const Curve easeIn = Curves.easeIn;
  static const Curve easeOut = Curves.easeOut;
  static const Curve easeInOut = Curves.easeInOut;
  static const Curve bounceOut = Curves.bounceOut;
  static const Curve elastic = Curves.elasticOut;
  static const Curve smooth = Curves.fastOutSlowIn;
}
