import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../theme/app_theme.dart';

/// Theme mode provider - persists user's theme preference
final themeModeProvider = StateNotifierProvider<ThemeModeNotifier, ThemeMode>((
  ref,
) {
  return ThemeModeNotifier();
});

class ThemeModeNotifier extends StateNotifier<ThemeMode> {
  static const String _themeKey = 'theme_mode';

  ThemeModeNotifier() : super(ThemeMode.system) {
    _loadTheme();
  }

  Future<void> _loadTheme() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final themeString = prefs.getString(_themeKey);

      if (themeString == 'dark') {
        state = ThemeMode.dark;
        AppTheme.setDarkSystemUIOverlayStyle();
      } else if (themeString == 'system') {
        state = ThemeMode.system;
      } else {
        state = ThemeMode.light;
        AppTheme.setSystemUIOverlayStyle();
      }
    } catch (e) {
      // Default to light mode
      state = ThemeMode.light;
    }
  }

  Future<void> setThemeMode(ThemeMode mode) async {
    state = mode;

    // Update system UI
    if (mode == ThemeMode.dark) {
      AppTheme.setDarkSystemUIOverlayStyle();
    } else {
      AppTheme.setSystemUIOverlayStyle();
    }

    // Persist preference
    try {
      final prefs = await SharedPreferences.getInstance();
      String themeString;
      switch (mode) {
        case ThemeMode.dark:
          themeString = 'dark';
          break;
        case ThemeMode.system:
          themeString = 'system';
          break;
        default:
          themeString = 'light';
      }
      await prefs.setString(_themeKey, themeString);
    } catch (e) {
    }
  }

  void toggleTheme() {
    final currentBrightness =
        WidgetsBinding.instance.platformDispatcher.platformBrightness;
    // If currently dark (either explicit or via system), switch to light
    if (state == ThemeMode.dark ||
        (state == ThemeMode.system && currentBrightness == Brightness.dark)) {
      setThemeMode(ThemeMode.light);
    } else {
      // Otherwise switch to dark
      setThemeMode(ThemeMode.dark);
    }
  }

  bool get isDarkMode => state == ThemeMode.dark;
}

/// Provider to check if dark mode is currently active
/// Handles system mode by checking actual platform brightness
final isDarkModeProvider = Provider<bool>((ref) {
  final themeMode = ref.watch(themeModeProvider);
  if (themeMode == ThemeMode.system) {
    // When in system mode, check actual device brightness
    return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
        Brightness.dark;
  }
  return themeMode == ThemeMode.dark;
});
