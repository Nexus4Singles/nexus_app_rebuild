import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/providers/app_update_provider.dart';
import 'package:nexus_app_v2/core/notifications/notification_service.dart'
    show navigatorKey;
import 'package:nexus_app_v2/core/services/app_update_service.dart';
import 'package:nexus_app_v2/features/app_update/presentation/widgets/app_update_modal.dart';

/// App Update Checker Widget
/// Should be placed at the root of the app (in a Consumer widget)
/// Automatically checks for updates when the app starts and shows modal if available
class AppUpdateChecker extends ConsumerStatefulWidget {
  final Widget child;
  final bool enableAutoCheck;

  const AppUpdateChecker({
    super.key,
    required this.child,
    this.enableAutoCheck = true,
  });

  @override
  ConsumerState<AppUpdateChecker> createState() => _AppUpdateCheckerState();
}

class _AppUpdateCheckerState extends ConsumerState<AppUpdateChecker> {
  bool _isShowingUpdate = false;
  bool _hasScheduledDialogRetry = false;

  @override
  Widget build(BuildContext context) {
    // Auto-check for updates on app start
    if (widget.enableAutoCheck) {
      ref.listen(appUpdateProvider, (previous, next) {
        next.whenData((result) {
          if (result.updateAvailable && !_isShowingUpdate) {
            _showUpdateModal(context, result);
          }
        });
      });
    }

    return widget.child;
  }

  void _showUpdateModal(BuildContext context, AppUpdateResult result) {
    final navigatorContext = navigatorKey.currentState?.context;
    if (navigatorContext == null || result.latestVersion == null) {
      if (mounted &&
          result.latestVersion != null &&
          !_hasScheduledDialogRetry) {
        _hasScheduledDialogRetry = true;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _showUpdateModal(context, result);
        });
      }
      return;
    }

    _hasScheduledDialogRetry = false;
    _isShowingUpdate = true;

    showDialog(
      context: navigatorContext,
      barrierDismissible: true,
      builder:
          (_) => AppUpdateModal(
            changesSummary: result.changesSummary ?? 'New updates available',
            iosStoreUrl: result.iosStoreUrl,
            androidStoreUrl: result.androidStoreUrl,
          ),
    ).then((_) async {
      try {
        await AppUpdateService.markVersionNotified(result.latestVersion!);
      } finally {
        _isShowingUpdate = false;
      }
    });
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
