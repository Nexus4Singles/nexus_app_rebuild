import 'package:flutter/material.dart';

import '../../safe_imports.dart';

class AuthGateModal {
  static Future<void> show(
    BuildContext context, {
    required String title,
    required String message,
    required String primaryButtonText,
    VoidCallback? onPrimary,
    String secondaryButtonText = 'Not now',
    VoidCallback? onSecondary,
  }) {
    return showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return SafeArea(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: Theme.of(ctx).scaffoldBackgroundColor,
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(24),
              ),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: Theme.of(ctx).textTheme.titleLarge),
                const SizedBox(height: 12),
                Text(message, style: Theme.of(ctx).textTheme.bodyMedium),
                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onPrimary?.call();
                    },
                    child: Text(primaryButtonText),
                  ),
                ),
                const SizedBox(height: 10),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton(
                    onPressed: () {
                      Navigator.of(ctx).pop();
                      onSecondary?.call();
                    },
                    child: Text(secondaryButtonText),
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  'Guest Mode',
                  style: Theme.of(ctx).textTheme.bodySmall?.copyWith(
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
