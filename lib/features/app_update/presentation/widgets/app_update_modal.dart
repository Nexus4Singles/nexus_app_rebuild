import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';
import '../../../../core/theme/app_text_styles.dart';

/// Compact update prompt with a single store action and a close control.
class AppUpdateModal extends StatelessWidget {
  final String changesSummary;
  final String? iosStoreUrl;
  final String? androidStoreUrl;
  final VoidCallback? onDismiss;

  const AppUpdateModal({
    super.key,
    required this.changesSummary,
    this.iosStoreUrl,
    this.androidStoreUrl,
    this.onDismiss,
  });

  Future<void> _launchAppStore(BuildContext context) async {
    final url = Platform.isIOS ? iosStoreUrl : androidStoreUrl;

    if (url == null || url.isEmpty) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Store link not available')));
      return;
    }

    try {
      final uri = Uri.parse(url);
      if (await canLaunchUrl(uri)) {
        await launchUrl(uri, mode: LaunchMode.externalApplication);
      } else if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not open app store')),
        );
      }
    } catch (error) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error opening app store: $error')),
        );
      }
    }
  }

  void _close(BuildContext context) {
    Navigator.pop(context);
    onDismiss?.call();
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isThin = MediaQuery.of(context).size.height < 600;

    return Dialog(
      elevation: 0,
      backgroundColor: Colors.transparent,
      insetPadding: EdgeInsets.symmetric(
        horizontal: 20,
        vertical: isThin ? 20 : 32,
      ),
      child: Card(
        margin: EdgeInsets.zero,
        color:
            isDark ? AppColors.cardBackground : AppColors.cardBackgroundLight,
        elevation: 8,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppSpacing.modalRadius),
        ),
        child: Stack(
          children: [
            Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(48, 20, 48, 6),
                  child: Text(
                    'Update Available',
                    textAlign: TextAlign.center,
                    style: AppTextStyles.titleLarge.copyWith(
                      color:
                          isDark
                              ? AppColors.textPrimary
                              : AppColors.textPrimaryLight,
                    ),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 16),
                  child: Text(
                    changesSummary,
                    textAlign: TextAlign.center,
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: AppTextStyles.bodySmall.copyWith(
                      color:
                          isDark
                              ? AppColors.textSecondary
                              : AppColors.textSecondaryLight,
                    ),
                  ),
                ),
                Divider(
                  height: 1,
                  color: isDark ? AppColors.divider : AppColors.dividerLight,
                ),
                Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => _launchAppStore(context),
                      child: const Text('Update App'),
                    ),
                  ),
                ),
              ],
            ),
            Positioned(
              top: 4,
              right: 4,
              child: IconButton(
                tooltip: 'Close',
                onPressed: () => _close(context),
                style: IconButton.styleFrom(
                  backgroundColor:
                      isDark
                          ? AppColors.backgroundTertiary
                          : AppColors.primarySoft,
                  foregroundColor: AppColors.primary,
                  shape: const CircleBorder(),
                  padding: EdgeInsets.zero,
                  minimumSize: const Size(32, 32),
                  fixedSize: const Size(32, 32),
                  tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                ),
                icon: const Icon(Icons.close, size: 18),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
