import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/providers/app_update_provider.dart';
import 'package:nexus_app_v2/core/services/app_update_service.dart';
import 'package:nexus_app_v2/features/app_update/presentation/widgets/app_update_modal.dart';

/// App Update Checker Widget
/// Should be placed at the root of the app (in a Consumer widget)
/// Automatically checks for updates when the app starts and shows modal if available
class AppUpdateChecker extends ConsumerWidget {
  final Widget child;
  final bool enableAutoCheck;

  const AppUpdateChecker({
    super.key,
    required this.child,
    this.enableAutoCheck = true,
  });

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Auto-check for updates on app start
    if (enableAutoCheck) {
      ref.listen(appUpdateProvider, (previous, next) {
        next.whenData((result) {
          if (result.updateAvailable) {
            _showUpdateModal(context, result);
          }
        });
      });
    }

    return child;
  }

  void _showUpdateModal(BuildContext context, AppUpdateResult result) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder:
          (_) => AppUpdateModal(
            latestVersion: result.latestVersion ?? '0.0.0',
            changesSummary: result.changesSummary ?? 'New updates available',
            iosStoreUrl: result.iosStoreUrl,
            androidStoreUrl: result.androidStoreUrl,
            onDismiss: () {
              // Optional: Log dismiss event
            },
          ),
    );
  }
}

/// Manual Update Check Button (for testing or manual refresh)
class ManualUpdateCheckButton extends ConsumerWidget {
  const ManualUpdateCheckButton({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return IconButton(
      icon: const Icon(Icons.system_update),
      onPressed: () async {
        ref.read(appUpdateNotifierProvider.notifier).checkForUpdate();
        final state = ref.watch(appUpdateNotifierProvider);

        if (state.isLoading) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Checking for updates...')),
          );
        } else if (state.hasError) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Error checking for updates')),
          );
        } else if (state.result?.updateAvailable ?? false) {
          final result = state.result!;
          if (context.mounted) {
            showDialog(
              context: context,
              builder:
                  (_) => AppUpdateModal(
                    latestVersion: result.latestVersion ?? '0.0.0',
                    changesSummary:
                        result.changesSummary ?? 'New updates available',
                    iosStoreUrl: result.iosStoreUrl,
                    androidStoreUrl: result.androidStoreUrl,
                  ),
            );
          }
        } else {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('You are on the latest version')),
            );
          }
        }
      },
    );
  }
}
