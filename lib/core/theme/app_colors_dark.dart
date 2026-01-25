import 'package:flutter/material.dart';

/// Dark mode color palette for Nexus
class AppColorsDark {
  AppColorsDark._();

  // ============================================================================
  // BRAND COLORS (Same as light mode)
  // ============================================================================
  static const Color primary = Color(0xFFBA223C);
  static const Color primaryLight = Color(0xFFD64A60);
  static const Color primaryDark = Color(0xFF8E1A2E);
  static const Color primarySoft = Color(0xFF2A1518);
  static const Color primaryMuted = Color(0xFF3A1B20);

  static const Color secondary = Color(0xFFE85A6B);
  static const Color secondaryLight = Color(0xFFFF8A94);
  static const Color secondaryDark = Color(0xFFB23A48);

  static const Color accent = Color(0xFFFFB800);
  static const Color gold = Color(0xFFFFB800);
  static const Color goldLight = Color(0xFFFFD54F);
  static const Color goldDark = Color(0xFFC79100);

  // ============================================================================
  // TIER COLORS (Same as light mode)
  // ============================================================================
  static const Color tierFree = Color(0xFF22C55E);
  static const Color tierFreeLight = Color(0xFF1A3A28);
  static const Color tierFreeDark = Color(0xFF16A34A);

  static const Color tierGrowth = Color(0xFFF97316);
  static const Color tierGrowthLight = Color(0xFF3A2314);
  static const Color tierGrowthDark = Color(0xFFEA580C);

  static const Color tierDeep = Color(0xFF8B5CF6);
  static const Color tierDeepLight = Color(0xFF2A1F3A);
  static const Color tierDeepDark = Color(0xFF7C3AED);

  static const Color tierPremium = Color(0xFFFFB800);
  static const Color tierPremiumLight = Color(0xFF3A2F14);
  static const Color tierPremiumDark = Color(0xFFD97706);

  // ============================================================================
  // SEMANTIC COLORS
  // ============================================================================
  static const Color success = Color(0xFF22C55E);
  static const Color successLight = Color(0xFF1A3A28);
  static const Color successDark = Color(0xFF16A34A);

  static const Color warning = Color(0xFFF97316);
  static const Color warningLight = Color(0xFF3A2314);
  static const Color warningDark = Color(0xFFEA580C);

  static const Color error = Color(0xFFEF4444);
  static const Color errorLight = Color(0xFF3A1818);
  static const Color errorDark = Color(0xFFDC2626);

  static const Color info = Color(0xFF3B82F6);
  static const Color infoLight = Color(0xFF1A2538);
  static const Color infoDark = Color(0xFF2563EB);

  // ============================================================================
  // NEUTRAL COLORS (Inverted for dark mode)
  // ============================================================================
  static const Color textPrimary = Color(0xFFF5F5F5);
  static const Color textSecondary = Color(0xFFD1D5DB);
  static const Color textMuted = Color(0xFF9CA3AF);
  static const Color textDisabled = Color(0xFF6B7280);
  static const Color textOnPrimary = Color(0xFFFFFFFF);
  static const Color textOnSecondary = Color(0xFFFFFFFF);
  static const Color textOnDark = Color(0xFFFFFFFF);
  static const Color textTertiary = Color(0xFF9CA3AF);

  /// Background colors (Dark)
  static const Color background = Color(0xFF0F0F0F);
  static const Color backgroundSecondary = Color(0xFF171717);
  static const Color backgroundTertiary = Color(0xFF1F1F1F);
  static const Color backgroundWarm = Color(0xFF1A1514);

  /// Surface colors (Dark)
  static const Color surface = Color(0xFF1A1A1A);
  static const Color surfaceLight = Color(0xFF242424);
  static const Color surfaceDark = Color(0xFF121212);
  static const Color surfaceElevated = Color(0xFF242424);
  static const Color surfaceVariant = Color(0xFF262626);
  static const Color cardBackground = Color(0xFF1A1A1A);

  /// Border colors (Dark)
  static const Color border = Color(0xFF2A2A2A);
  static const Color borderLight = Color(0xFF262626);
  static const Color borderDark = Color(0xFF3A3A3A);
  static const Color divider = Color(0xFF262626);
  static const Color inputBorder = Color(0xFF2A2A2A);
  static const Color inputFocusBorder = primary;

  // ============================================================================
  // SPECIAL USE
  // ============================================================================
  static const Color shimmerBase = Color(0xFF1F1F1F);
  static const Color shimmerHighlight = Color(0xFF2A2A2A);

  static const Color overlay = Color(0xCC000000);
  static const Color scrim = Color(0x99000000);

  static const Color progressBackground = Color(0xFF262626);
  static const Color progressForeground = primary;

  static const Color skeleton = Color(0xFF242424);
  static const Color skeletonShimmer = Color(0xFF2A2A2A);
}
