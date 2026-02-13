import 'package:flutter/material.dart';

Future<T?> safePushNamed<T>(
  BuildContext context,
  String routeName, {
  Object? arguments,
}) {
  try {
    return Navigator.of(context).pushNamed<T>(routeName, arguments: arguments);
  } catch (_) {
    return Navigator.of(
      context,
    ).pushNamed<T>('/placeholder', arguments: {'title': routeName});
  }
}

Future<T?> safeReplaceNamed<T>(
  BuildContext context,
  String routeName, {
  Object? arguments,
}) {
  try {
    return Navigator.of(
      context,
    ).pushReplacementNamed<T, T>(routeName, arguments: arguments);
  } catch (_) {
    return Navigator.of(context).pushReplacementNamed<T, T>(
      '/placeholder',
      arguments: {'title': routeName},
    );
  }
}

/// Navigate back to home screen with nav bar visible.
/// Use this instead of Navigator.pop() when you want to ensure
/// the user returns to the home screen with the bottom nav bar.
void navigateBackToHome(BuildContext context) {
  try {
    // First, try to pop back to previous screen (preserves AppShell nav bar state)
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else {
      // If we can't pop (first route or deep link), navigate to home
      Navigator.of(context).pushNamedAndRemoveUntil('/home', (_) => false);
    }
  } catch (_) {
    // Last resort: replace with home
    try {
      Navigator.of(context).pushReplacementNamed('/home');
    } catch (_) {
      // If all else fails, pop
      try {
        Navigator.of(context).pop();
      } catch (_) {
        // Silent fail
      }
    }
  }
}
