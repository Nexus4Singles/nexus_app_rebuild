import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_text_styles.dart';
import '../../../../core/services/force_update_service.dart';

/// Non-dismissible full-screen gate shown when the app version is below
/// the server-mandated minimum.  The only action is "Update Now" which
/// opens the App Store / Play Store listing.
class ForceUpdateScreen extends StatelessWidget {
  final ForceUpdateResult result;

  const ForceUpdateScreen({super.key, required this.result});

  @override
  Widget build(BuildContext context) {
    final bgColor = AppColors.getBackground(context);
    final textColor = AppColors.getTextPrimary(context);
    const accentColor = Colors.orange;

    return PopScope(
      canPop: false, // Block back button
      child: Scaffold(
        backgroundColor: bgColor,
        body: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                const Spacer(flex: 2),

                // Icon
                Container(
                  width: 88,
                  height: 88,
                  decoration: BoxDecoration(
                    color: accentColor.withOpacity(0.15),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.system_update_rounded,
                    size: 48,
                    color: accentColor,
                  ),
                ),
                const SizedBox(height: 32),

                // Title
                Text(
                  'Update Required',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 20),

                // Message from Firestore (or default)
                Text(
                  result.message,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: textColor.withOpacity(0.85),
                    height: 1.5,
                  ),
                ),

                const Spacer(flex: 3),

                // Update button - compact width
                ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 280),
                  child: ElevatedButton.icon(
                    onPressed: () => _openStore(),
                    icon: const Icon(Icons.open_in_new_rounded),
                    label: const Text('Update Now'),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: accentColor,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(
                        vertical: 14,
                        horizontal: 32,
                      ),
                      textStyle: const TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 16),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _openStore() async {
    final urlString = Platform.isIOS ? result.iosUrl : result.androidUrl;
    if (urlString == null || urlString.isEmpty) return;

    final uri = Uri.parse(urlString);
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
  }
}
