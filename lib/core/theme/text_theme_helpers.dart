import 'package:flutter/material.dart';
import 'app_colors.dart';
import 'app_text_styles.dart';

/// Helper class for text styles that dynamically adjust based on theme
/// Use these instead of hardcoding Colors.white or Colors.black
class TextThemeHelpers {
  TextThemeHelpers._();

  // ============================================================================
  // TEXT ON GRADIENT BACKGROUNDS (always white - brand red, primary colors)
  // ============================================================================

  /// Text on red/primary gradient backgrounds (always white)
  static TextStyle titleOnGradient(BuildContext context) {
    return AppTextStyles.titleMedium.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );
  }

  /// Body text on red/primary gradient backgrounds (always white)
  static TextStyle bodyOnGradient(BuildContext context) {
    return AppTextStyles.bodyMedium.copyWith(
      color: Colors.white.withOpacity(0.9),
      height: 1.4,
    );
  }

  /// Headline on red/primary gradient backgrounds (always white)
  static TextStyle headlineOnGradient(BuildContext context) {
    return AppTextStyles.headlineLarge.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
    );
  }

  // ============================================================================
  // TEXT ON REGULAR SURFACES (switches with theme)
  // ============================================================================

  /// Primary text on regular surface (white in dark mode, dark in light mode)
  static TextStyle titleOnSurface(BuildContext context) {
    return AppTextStyles.titleMedium.copyWith(
      color: AppColors.getTextPrimary(context),
      fontWeight: FontWeight.w700,
    );
  }

  /// Body text on regular surface (switches with theme)
  static TextStyle bodyOnSurface(BuildContext context) {
    return AppTextStyles.bodyMedium.copyWith(
      color: AppColors.getTextPrimary(context),
    );
  }

  /// Secondary text on regular surface (switches with theme)
  static TextStyle secondaryTextOnSurface(BuildContext context) {
    return AppTextStyles.bodySmall.copyWith(
      color: AppColors.getTextSecondary(context),
    );
  }

  // ============================================================================
  // BADGE/CHIP TEXT
  // ============================================================================

  /// Text for badges/chips with background (always white)
  static TextStyle badgeText(BuildContext context) {
    return AppTextStyles.labelSmall.copyWith(
      color: Colors.white,
      fontWeight: FontWeight.w700,
      letterSpacing: 0.5,
    );
  }

  // ============================================================================
  // ICON COLORS
  // ============================================================================

  /// Icon color on gradient backgrounds (always white)
  static Color iconOnGradient(BuildContext context) {
    return Colors.white;
  }

  /// Icon color on regular surfaces (switches with theme)
  static Color iconOnSurface(BuildContext context) {
    return AppColors.getTextPrimary(context);
  }

  // ============================================================================
  // HELPER OPACITY COLORS
  // ============================================================================

  /// Get white color with opacity appropriate for theme
  /// In light mode: use dark text with low opacity
  /// In dark mode: use white with given opacity
  static Color whiteOrDarkWithOpacity(
    BuildContext context, {
    required double opacityDark,
    required double opacityLight,
  }) {
    if (Theme.of(context).brightness == Brightness.light) {
      return Colors.black.withOpacity(opacityLight);
    } else {
      return Colors.white.withOpacity(opacityDark);
    }
  }

  /// Border overlay color on gradient (always white with opacity)
  static Color borderOnGradient(BuildContext context, double opacity) {
    return Colors.white.withOpacity(opacity);
  }

  /// Background overlay on gradient (always white with opacity)
  static Color overlayOnGradient(BuildContext context, double opacity) {
    return Colors.white.withOpacity(opacity);
  }
}
