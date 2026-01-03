import 'package:flutter/material.dart';

// ============================================================================
// DESIGN TOKENS
// ============================================================================
//
// This file centralizes all design tokens for easy Figma adaptation.
// When Figma designs are ready:
// 1. Update token values in this file
// 2. UI components will automatically reflect changes
//
// Organization:
// - Color tokens → app_colors.dart (for brand colors)
// - Spacing tokens → app_spacing.dart (for layout)
// - Component tokens → this file (for specific UI elements)
// ============================================================================

/// Button design tokens
class ButtonTokens {
  ButtonTokens._();

  // Sizes
  static const double heightSmall = 36.0;
  static const double heightMedium = 48.0;
  static const double heightLarge = 56.0;

  // Padding
  static const EdgeInsets paddingSmall = EdgeInsets.symmetric(
    horizontal: 12,
    vertical: 6,
  );
  static const EdgeInsets paddingMedium = EdgeInsets.symmetric(
    horizontal: 20,
    vertical: 10,
  );
  static const EdgeInsets paddingLarge = EdgeInsets.symmetric(
    horizontal: 24,
    vertical: 14,
  );

  // Border radius
  static const double borderRadius = 12.0;

  // Icon sizes
  static const double iconSizeSmall = 16.0;
  static const double iconSizeMedium = 20.0;
  static const double iconSizeLarge = 24.0;

  // Elevation
  static const double elevation = 0.0;
  static const double pressedElevation = 0.0;
}

/// Card design tokens
class CardTokens {
  CardTokens._();

  // Padding
  static const EdgeInsets padding = EdgeInsets.all(16);
  static const EdgeInsets paddingCompact = EdgeInsets.all(12);
  static const EdgeInsets paddingLarge = EdgeInsets.all(20);

  // Border radius
  static const double borderRadius = 12.0;
  static const double borderRadiusLarge = 16.0;

  // Border
  static const double borderWidth = 1.0;

  // Elevation
  static const double elevation = 2.0;
  static const double elevationHover = 4.0;

  // Image
  static const double imageHeight = 160.0;
  static const double imageHeightCompact = 120.0;
}

/// Input field design tokens
class InputTokens {
  InputTokens._();

  // Sizing
  static const double height = 56.0;
  static const double heightCompact = 48.0;

  // Padding
  static const EdgeInsets contentPadding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 16,
  );

  // Border
  static const double borderRadius = 12.0;
  static const double borderWidth = 1.0;
  static const double focusedBorderWidth = 2.0;

  // Label
  static const double labelSpacing = 8.0;

  // Icon
  static const double iconSize = 20.0;
}

/// Chip design tokens
class ChipTokens {
  ChipTokens._();

  // Sizing
  static const double height = 36.0;
  static const double heightLarge = 44.0;

  // Padding
  static const EdgeInsets padding = EdgeInsets.symmetric(
    horizontal: 16,
    vertical: 8,
  );

  // Border
  static const double borderRadius = 100.0; // Fully rounded
  static const double borderWidth = 1.0;
  static const double selectedBorderWidth = 2.0;

  // Icon
  static const double iconSize = 18.0;
  static const double checkIconSize = 16.0;

  // Spacing
  static const double iconSpacing = 6.0;
}

/// Option card design tokens (for survey)
class OptionCardTokens {
  OptionCardTokens._();

  // Padding
  static const EdgeInsets padding = EdgeInsets.all(16);

  // Border
  static const double borderRadius = 12.0;
  static const double borderWidth = 1.0;
  static const double selectedBorderWidth = 2.0;

  // Icon container
  static const double iconContainerSize = 40.0;
  static const double iconSize = 24.0;

  // Check indicator
  static const double checkIndicatorSize = 24.0;

  // Spacing
  static const double iconSpacing = 12.0;
  static const double titleSubtitleSpacing = 4.0;
  static const double cardSpacing = 8.0;
}

/// Progress indicator design tokens
class ProgressTokens {
  ProgressTokens._();

  // Linear progress
  static const double linearHeight = 8.0;
  static const double linearHeightThin = 4.0;

  // Circular progress
  static const double circularSize = 80.0;
  static const double circularSizeSmall = 40.0;
  static const double circularStrokeWidth = 8.0;

  // Step progress
  static const double stepSize = 32.0;
  static const double stepLineHeight = 3.0;

  // Question dots
  static const double dotSize = 8.0;
  static const double dotSpacing = 6.0;
  static const double activeDotWidth = 16.0; // Elongated when active
}

/// App bar design tokens
class AppBarTokens {
  AppBarTokens._();

  // Height
  static const double height = 56.0;
  static const double heightLarge = 64.0;

  // Elevation
  static const double elevation = 0.0;
  static const double scrolledElevation = 2.0;

  // Icon
  static const double iconSize = 24.0;
  static const double backButtonSize = 40.0;

  // Title
  static const double titleSpacing = 16.0;
}

/// Bottom sheet design tokens
class BottomSheetTokens {
  BottomSheetTokens._();

  // Border radius (top only)
  static const double borderRadius = 24.0;

  // Handle
  static const double handleWidth = 40.0;
  static const double handleHeight = 4.0;
  static const double handleTopPadding = 12.0;

  // Content padding
  static const EdgeInsets contentPadding = EdgeInsets.all(24);

  // Min/max height ratios
  static const double minHeightRatio = 0.25;
  static const double maxHeightRatio = 0.9;
}

/// Dialog design tokens
class DialogTokens {
  DialogTokens._();

  // Border radius
  static const double borderRadius = 20.0;

  // Padding
  static const EdgeInsets padding = EdgeInsets.all(24);

  // Width constraints
  static const double minWidth = 280.0;
  static const double maxWidth = 400.0;

  // Button spacing
  static const double buttonSpacing = 12.0;
}

/// Avatar design tokens
class AvatarTokens {
  AvatarTokens._();

  // Sizes
  static const double sizeSmall = 32.0;
  static const double sizeMedium = 48.0;
  static const double sizeLarge = 64.0;
  static const double sizeXLarge = 96.0;
  static const double sizeProfile = 120.0;

  // Border
  static const double borderWidth = 2.0;
  static const double onlineBadgeSize = 12.0;
}

/// Story card design tokens
class StoryCardTokens {
  StoryCardTokens._();

  // Card
  static const double borderRadius = 16.0;
  static const EdgeInsets padding = EdgeInsets.all(16);

  // Image
  static const double heroImageHeight = 200.0;
  static const double thumbnailSize = 80.0;

  // Badge (week number, reading time)
  static const double badgeHeight = 24.0;
  static const double badgeBorderRadius = 12.0;

  // Content
  static const double titleMaxLines = 2;
  static const double subtitleMaxLines = 2;
}

/// Poll design tokens
class PollTokens {
  PollTokens._();

  // Option bar
  static const double optionHeight = 48.0;
  static const double optionBorderRadius = 12.0;
  static const double optionBorderWidth = 1.0;

  // Progress bar inside option
  static const double progressHeight = 48.0;

  // Percentage label
  static const double percentageFontSize = 14.0;
}

/// Session card design tokens
class SessionCardTokens {
  SessionCardTokens._();

  // Card
  static const double borderRadius = 12.0;
  static const EdgeInsets padding = EdgeInsets.all(16);

  // Status indicator
  static const double statusDotSize = 8.0;

  // Lock icon
  static const double lockIconSize = 20.0;

  // Tier badge
  static const double tierBadgeHeight = 24.0;
}

// ============================================================================
// ANIMATION TOKENS
// ============================================================================

/// Animation duration tokens
class AnimationTokens {
  AnimationTokens._();

  // Durations
  static const Duration instant = Duration(milliseconds: 0);
  static const Duration fast = Duration(milliseconds: 150);
  static const Duration normal = Duration(milliseconds: 250);
  static const Duration slow = Duration(milliseconds: 400);
  static const Duration slower = Duration(milliseconds: 600);

  // Curves
  static const Curve standard = Curves.easeInOut;
  static const Curve enter = Curves.easeOut;
  static const Curve exit = Curves.easeIn;
  static const Curve bounce = Curves.elasticOut;
  static const Curve overshoot = Curves.easeOutBack;

  // Page transitions
  static const Duration pageTransition = Duration(milliseconds: 300);
  static const Curve pageTransitionCurve = Curves.easeInOutCubic;
}

// ============================================================================
// ICON SIZE TOKENS
// ============================================================================

/// Icon size tokens
class IconSizeTokens {
  IconSizeTokens._();

  static const double xs = 12.0;
  static const double sm = 16.0;
  static const double md = 20.0;
  static const double base = 24.0;
  static const double lg = 28.0;
  static const double xl = 32.0;
  static const double xxl = 40.0;
  static const double xxxl = 48.0;
  static const double huge = 64.0;
}

// ============================================================================
// BREAKPOINTS
// ============================================================================

/// Responsive breakpoint tokens
class BreakpointTokens {
  BreakpointTokens._();

  // Screen widths
  static const double mobile = 0;
  static const double tablet = 600;
  static const double desktop = 1024;
  static const double wide = 1440;

  // Max content widths
  static const double maxContentWidthMobile = double.infinity;
  static const double maxContentWidthTablet = 720;
  static const double maxContentWidthDesktop = 960;

  /// Check if width is mobile
  static bool isMobile(double width) => width < tablet;

  /// Check if width is tablet
  static bool isTablet(double width) => width >= tablet && width < desktop;

  /// Check if width is desktop
  static bool isDesktop(double width) => width >= desktop;
}
