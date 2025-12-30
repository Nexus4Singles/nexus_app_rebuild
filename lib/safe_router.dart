import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/safe_imports.dart';

/// Safe, minimal routing (no GoRouter, no providers, no backend).
///
/// IMPORTANT: This file must NOT import or reference AppShell
/// to avoid circular dependencies.
Route<dynamic>? safeOnGenerateRoute(RouteSettings settings) {
  final name = settings.name ?? '/';

  if (name == '/placeholder') {
    final args = settings.arguments as Map<String, dynamic>?;
    final title = (args?['title'] as String?) ?? 'Placeholder';

    return MaterialPageRoute(
      builder: (_) => PlaceholderScreen(title: title),
    );
  }

  // Default fallback
  return MaterialPageRoute(
    builder: (_) => const PlaceholderScreen(title: 'Not Found'),
  );
}

class PlaceholderScreen extends StatelessWidget {
  final String title;
  const PlaceholderScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(title, style: AppTextStyles.headlineLarge),
      ),
      body: Center(
        child: Text(
          'This screen will be implemented later.',
          style: AppTextStyles.bodyMedium,
        ),
      ),
    );
  }
}
