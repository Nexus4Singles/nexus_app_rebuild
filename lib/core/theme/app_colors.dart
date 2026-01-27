import 'package:flutter/material.dart';

/// Nexus 2.0 Premium Color System
///
/// A refined, world-class color palette built around the Nexus brand red (#BA223C).
/// Designed for a premium faith-based wellness experience.
class AppColors {
  AppColors._();

  // ============================================================================
  // BRAND COLORS
  // ============================================================================

  /// Primary Nexus Red - The heart of the brand
  static const Color primary = Color(0xFFBA223C);

  /// Primary variants for different states
  static const Color primaryLight = Color(0xFFD64A60);
  static const Color primaryDark = Color(0xFF8E1A2E);
  static const Color primarySoft = Color(0xFFFDF2F4);
  static const Color primaryMuted = Color(0xFFF8E1E5);

  /// Secondary - Warm rose accent
  static const Color secondary = Color(0xFFE85A6B);
  static const Color secondaryLight = Color(0xFFFF8A94);
  static const Color secondaryDark = Color(0xFFB23A48);

  /// Accent colors for gamification and engagement
  static const Color accent = Color(0xFFFFB800);
  static const Color gold = Color(0xFFFFB800);
  static const Color goldLight = Color(0xFFFFD54F);
  static const Color goldDark = Color(0xFFC79100);

  // ============================================================================
  // TIER COLORS (for challenges/journeys)
  // ============================================================================

  /// Free/Starter tier - Fresh green
  static const Color tierFree = Color(0xFF22C55E);
  static const Color tierFreeLight = Color(0xFFDCFCE7);
  static const Color tierFreeDark = Color(0xFF16A34A);

  /// Growth tier - Energetic orange
  static const Color tierGrowth = Color(0xFFF97316);
  static const Color tierGrowthLight = Color(0xFFFFF7ED);
  static const Color tierGrowthDark = Color(0xFFEA580C);

  /// Deep tier - Rich indigo
  static const Color tierDeep = Color(0xFF8B5CF6);
  static const Color tierDeepLight = Color(0xFFF3E8FF);
  static const Color tierDeepDark = Color(0xFF7C3AED);

  /// Premium tier - Luxurious gold
  static const Color tierPremium = Color(0xFFFFB800);
  static const Color tierPremiumLight = Color(0xFFFFFBEB);
  static const Color tierPremiumDark = Color(0xFFD97706);

  // ============================================================================
  // SEMANTIC COLORS
  // ============================================================================

  /// Success states
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFFDCFCE7);
  static const Color successDark = Color(0xFF16A34A);

  /// Warning states
  static const Color warning = Color(0xFFF97316);
  static const Color warningLight = Color(0xFFFFF7ED);
  static const Color warningDark = Color(0xFFEA580C);

  /// Error states
  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFFFEE2E2);
  static const Color errorDark = Color(0xFFDC2626);

  /// Info states
  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFFDBEAFE);
  static const Color infoDark = Color(0xFF2563EB);

  // ============================================================================
  // NEUTRAL COLORS (DARK MODE AS DEFAULT)
  // ============================================================================

  /// Text colors - Dark mode first
  static const Color textPrimary = Color(0xFFF9FAFB);
  static const Color textSecondary = Color(0xFF9CA3AF);
  static const Color textMuted = Color(0xFF6B7280);
  static const Color textDisabled = Color(0xFF4B5563);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textTertiary = Color(0xFF9CA3AF);

  /// Background colors - Dark mode first
  static const Color background = Color(0xFF111827);
  static const Color backgroundSecondary = Color(0xFF1F2937);
  static const Color backgroundTertiary = Color(0xFF374151);
  static const Color backgroundWarm = Color(0xFF1F2937);

  /// Surface colors - Dark mode first
  static const Color surface = Color(0xFF1F2937);
  static const Color surfaceLight = Color(0xFF374151);
  static const Color surfaceDark = Color(0xFF111827);
  static const Color surfaceElevated = Color(0xFF374151);
  static const Color surfaceVariant = Color(0xFF374151);
  static const Color cardBackground = Color(0xFF1F2937);

  /// Border colors - Dark mode first
  static const Color border = Color(0xFF374151);
  static const Color borderLight = Color(0xFF4B5563);
  static const Color borderDark = Color(0xFF1F2937);
  static const Color divider = Color(0xFF374151);
  static const Color inputBorder = Color(0xFF4B5563);
  static const Color inputFocusBorder = primary;

  // ============================================================================
  // GRADIENT DEFINITIONS
  // ============================================================================

  /// Primary brand gradient
  static const LinearGradient primaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFBA223C), Color(0xFFD64A60)],
  );

  /// Primary vertical gradient (for cards, buttons)
  static const LinearGradient primaryVerticalGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFD64A60), Color(0xFFBA223C)],
  );

  /// Secondary gradient
  static const LinearGradient secondaryGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFE85A6B), Color(0xFFB23A48)],
  );

  /// Accent gradient
  static const LinearGradient accentGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD54F), Color(0xFFFFB800)],
  );

  /// Premium gold gradient
  static const LinearGradient goldGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD54F), Color(0xFFFFB800)],
  );

  /// Warm background gradient (subtle)
  static const LinearGradient warmGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFFFFBFA)],
  );

  /// Surface gradient
  static const LinearGradient surfaceGradient = LinearGradient(
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
    colors: [Color(0xFFFFFFFF), Color(0xFFFAFAFA)],
  );

  /// Soft pink gradient (for featured cards)
  static const LinearGradient softPinkGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFDF2F4), Color(0xFFF8E1E5)],
  );

  /// Streak fire gradient
  static const LinearGradient streakGradient = LinearGradient(
    begin: Alignment.bottomCenter,
    end: Alignment.topCenter,
    colors: [Color(0xFFFF6B00), Color(0xFFFFB800)],
  );

  /// Challenge card gradients by tier
  static const LinearGradient starterGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF22C55E), Color(0xFF16A34A)],
  );

  static const LinearGradient growthGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFF97316), Color(0xFFEA580C)],
  );

  static const LinearGradient deepGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF8B5CF6), Color(0xFF7C3AED)],
  );

  static const LinearGradient premiumGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFFFFD54F), Color(0xFFFFB800)],
  );

  // ============================================================================
  // LEGACY COMPATIBILITY
  // ============================================================================

  /// Signal colors (for compatibility indicators)
  static const Color signalStrong = Color(0xFF22C55E);
  static const Color signalMedium = Color(0xFFF97316);
  static const Color signalWeak = Color(0xFFEF4444);
  static const Color signalDeveloping = Color(0xFF3B82F6);
  static const Color signalGuarded = Color(0xFFF97316);
  static const Color signalAtRisk = Color(0xFFEF4444);
  static const Color signalRestoration = Color(0xFF8B5CF6);

  /// Audience-specific colors
  static const Color singlesAccent = primary;
  static const Color marriedAccent = secondary;
  static const Color remarriageAccent = Color(0xFF8B5CF6);
  static const Color audienceSingles = primary;
  static const Color audienceMarried = secondary;
  static const Color audienceRemarriage = Color(0xFF8B5CF6);

  /// Progress colors - Dark mode first
  static const Color progressBackground = Color(0xFF374151);
  static const Color progressFill = primary;
  static const Color streakActive = Color(0xFFFFB800);
  static const Color streakInactive = Color(0xFF374151);

  /// Chip colors - Dark mode first
  static const Color chipBackground = Color(0xFF374151);
  static const Color chipSelectedBackground = Color(0xFF4C1D24);
  static const Color chipText = textSecondary;
  static const Color chipSelectedText = primary;

  // ============================================================================
  // SHADOW COLORS
  // ============================================================================

  static const Color shadow = Color(0x1A000000);
  static const Color shadowLight = Color(0x0D000000);
  static const Color shadowDark = Color(0x33000000);
  static const Color overlay = Color(0x80000000);
  static const Color overlayLight = Color(0x40000000);

  /// Primary shadow (red-tinted)
  static const Color primaryShadow = Color(0x40BA223C);

  // ============================================================================
  // HELPER METHODS
  // ============================================================================

  /// Get tier color by tier name
  static Color getTierColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'free':
      case 'starter':
        return tierFree;
      case 'growth':
        return tierGrowth;
      case 'deep':
        return tierDeep;
      case 'premium':
        return tierPremium;
      default:
        return primary;
    }
  }

  /// Get tier light color by tier name
  static Color getTierLightColor(String tier) {
    switch (tier.toLowerCase()) {
      case 'free':
      case 'starter':
        return tierFreeLight;
      case 'growth':
        return tierGrowthLight;
      case 'deep':
        return tierDeepLight;
      case 'premium':
        return tierPremiumLight;
      default:
        return primarySoft;
    }
  }

  /// Get tier gradient by tier name
  static LinearGradient getTierGradient(String tier) {
    switch (tier.toLowerCase()) {
      case 'free':
      case 'starter':
        return starterGradient;
      case 'growth':
        return growthGradient;
      case 'deep':
        return deepGradient;
      case 'premium':
        return premiumGradient;
      default:
        return primaryGradient;
    }
  }

  /// Get signal tier color for assessments
  static Color getSignalTierColor(String tier) {
    switch (tier.toUpperCase()) {
      case 'STRONG':
        return signalStrong;
      case 'DEVELOPING':
        return signalDeveloping;
      case 'GUARDED':
        return signalGuarded;
      case 'AT_RISK':
        return signalAtRisk;
      case 'RESTORATION':
        return signalRestoration;
      default:
        return textSecondary;
    }
  }

  // ============================================================================
  // LIGHT MODE COLORS (for future light mode support)
  // ============================================================================

  /// Light mode text colors
  static const Color textPrimaryLight = Color(0xFF1A1A1A);
  static const Color textSecondaryLight = Color(0xFF6B7280);
  static const Color textMutedLight = Color(0xFF9CA3AF);
  static const Color textDisabledLight = Color(0xFFD1D5DB);

  /// Light mode background colors
  static const Color backgroundLight = Color(0xFFFFFFFF);
  static const Color backgroundSecondaryLight = Color(0xFFFAFAFA);
  static const Color backgroundTertiaryLight = Color(0xFFF5F5F5);

  /// Light mode surface colors
  static const Color surfaceLightMode = Color(0xFFFFFFFF);
  static const Color surfaceLightLight = Color(0xFFFAFAFA);
  static const Color surfaceElevatedLight = Color(0xFFFFFFFF);
  static const Color cardBackgroundLight = Color(0xFFFFFFFF);

  /// Light mode border colors
  static const Color borderLightMode = Color(0xFFE5E7EB);
  static const Color borderLightLight = Color(0xFFF3F4F6);
  static const Color dividerLight = Color(0xFFF3F4F6);
  static const Color inputBorderLight = Color(0xFFE5E7EB);

  /// Light mode chip colors
  static const Color chipBackgroundLight = Color(0xFFF3F4F6);
  static const Color chipSelectedBackgroundLight = Color(0xFFFDF2F4);

  /// Light mode progress colors
  static const Color progressBackgroundLight = Color(0xFFE5E7EB);

  // ============================================================================
  // THEME-AWARE GETTERS (for future light mode toggle support)
  // ============================================================================

  /// Get background color based on current theme
  static Color getBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? backgroundLight
        : background;
  }

  /// Get secondary background color based on current theme
  static Color getBackgroundSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? backgroundSecondaryLight
        : backgroundSecondary;
  }

  /// Get tertiary background color based on current theme
  static Color getBackgroundTertiary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? backgroundTertiaryLight
        : backgroundTertiary;
  }

  /// Get surface color based on current theme
  static Color getSurface(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? surfaceLightMode
        : surface;
  }

  /// Get card background color based on current theme
  static Color getCardBackground(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? cardBackgroundLight
        : cardBackground;
  }

  /// Get primary text color based on current theme
  static Color getTextPrimary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? textPrimaryLight
        : textPrimary;
  }

  /// Get secondary text color based on current theme
  static Color getTextSecondary(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? textSecondaryLight
        : textSecondary;
  }

  /// Get border color based on current theme
  static Color getBorder(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? borderLightMode
        : border;
  }

  /// Get divider color based on current theme
  static Color getDivider(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? dividerLight
        : divider;
  }

  /// Get muted/tertiary text color based on current theme
  static Color getTextMuted(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? textMutedLight
        : textMuted;
  }

  /// Get text color on dark backgrounds (always white/light in dark mode, dark in light mode)
  static Color getTextOnDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? textPrimaryLight
        : Colors.white;
  }

  /// Get text color on primary/brand color backgrounds (always white/light)
  static Color getTextOnPrimary(BuildContext context) {
    return Colors.white;
  }

  /// Get overlay/semi-transparent dark color based on theme
  static Color getOverlayDark(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.black.withOpacity(0.4)
        : Colors.black.withOpacity(0.6);
  }

  /// Get overlay/semi-transparent light color based on theme
  static Color getOverlayLight(BuildContext context) {
    return Theme.of(context).brightness == Brightness.light
        ? Colors.black.withOpacity(0.05)
        : Colors.white.withOpacity(0.1);
  }
}
