import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';

/// Checks Firestore `config/forceUpdate` document to determine if
/// the current app version is below the required minimum.
///
/// Document structure (set via Firebase console or Admin SDK):
/// ```
/// config/forceUpdate {
///   enabled: true,
///   minVersion: "2.0.0",
///   message: "This version of Nexus is no longer available. Update your app to continue.",
///   storeUrl: {
///     ios: "https://apps.apple.com/app/id...",
///     android: "https://play.google.com/store/apps/details?id=..."
///   }
/// }
/// ```
class ForceUpdateService {
  static Future<ForceUpdateResult> check() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('config')
              .doc('forceUpdate')
              .get();

      if (!doc.exists) return ForceUpdateResult.notRequired();

      final data = doc.data();
      if (data == null) return ForceUpdateResult.notRequired();

      final enabled = data['enabled'] as bool? ?? false;
      if (!enabled) return ForceUpdateResult.notRequired();

      final minVersion = data['minVersion'] as String? ?? '0.0.0';
      final message =
          data['message'] as String? ??
          'This version of Nexus is no longer available. Update your app to continue.';

      final storeUrls = data['storeUrl'] as Map<String, dynamic>? ?? {};
      final iosUrl = storeUrls['ios'] as String?;
      final androidUrl = storeUrls['android'] as String?;

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version; // e.g. "2.1.0"

      if (_isVersionBelow(currentVersion, minVersion)) {
        debugPrint(
          '[ForceUpdate] Current version $currentVersion is below '
          'minimum $minVersion — update required',
        );
        return ForceUpdateResult(
          updateRequired: true,
          message: message,
          iosUrl: iosUrl,
          androidUrl: androidUrl,
        );
      }

      return ForceUpdateResult.notRequired();
    } catch (e) {
      // Fail open: if the check fails, don't block the user.
      debugPrint('[ForceUpdate] Check failed (allowing entry): $e');
      return ForceUpdateResult.notRequired();
    }
  }

  /// Compare semantic version strings. Returns true if [current] < [minimum].
  static bool _isVersionBelow(String current, String minimum) {
    final currentParts =
        current.split('.').map((s) => int.tryParse(s) ?? 0).toList();
    final minimumParts =
        minimum.split('.').map((s) => int.tryParse(s) ?? 0).toList();

    // Pad to same length
    while (currentParts.length < 3) currentParts.add(0);
    while (minimumParts.length < 3) minimumParts.add(0);

    for (int i = 0; i < 3; i++) {
      if (currentParts[i] < minimumParts[i]) return true;
      if (currentParts[i] > minimumParts[i]) return false;
    }
    return false; // Equal
  }
}

/// Result of the force-update check.
class ForceUpdateResult {
  final bool updateRequired;
  final String message;
  final String? iosUrl;
  final String? androidUrl;

  ForceUpdateResult({
    required this.updateRequired,
    this.message = '',
    this.iosUrl,
    this.androidUrl,
  });

  factory ForceUpdateResult.notRequired() =>
      ForceUpdateResult(updateRequired: false);
}
