import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// App Update Service
/// Fetches the latest app version from Firestore and compares with current version.
/// Tracks which version users have been notified about to show update modal exactly once per version.
///
/// Firestore structure (config/appUpdate):
/// ```
/// config/appUpdate {
///   latestVersion: "2.1.0",
///   releaseDate: Timestamp,
///   changesSummary: "Bug fixes and new chat features",
///   storeUrls: {
///     ios: "https://apps.apple.com/app/id...",
///     android: "https://play.google.com/store/apps/details?id=..."
///   }
/// }
/// ```
class AppUpdateService {
  static const String _prefixNotifiedVersion = 'app_update_notified_version';

  /// Checks if a new update is available
  static Future<AppUpdateResult> checkForUpdate() async {
    try {
      final doc =
          await FirebaseFirestore.instance
              .collection('config')
              .doc('appUpdate')
              .get();

      if (!doc.exists) return AppUpdateResult.noUpdateAvailable();

      final data = doc.data();
      if (data == null) return AppUpdateResult.noUpdateAvailable();

      final latestVersion = data['latestVersion'] as String?;
      final changesSummary =
          data['changesSummary'] as String? ?? 'New updates available';

      if (latestVersion == null || latestVersion.isEmpty) {
        return AppUpdateResult.noUpdateAvailable();
      }

      final packageInfo = await PackageInfo.fromPlatform();
      final currentVersion = packageInfo.version;

      // Compare versions
      if (!_isVersionNewer(latestVersion, currentVersion)) {
        return AppUpdateResult.noUpdateAvailable();
      }

      // Check if user has been notified about this version before
      final prefs = await SharedPreferences.getInstance();
      final notifiedVersion = prefs.getString(_prefixNotifiedVersion);

      if (notifiedVersion == latestVersion) {
        // Already showed modal for this version
        return AppUpdateResult.noUpdateAvailable();
      }

      final storeUrls = data['storeUrl'] as Map<String, dynamic>? ?? {};
      final iosUrl = storeUrls['ios'] as String?;
      final androidUrl = storeUrls['android'] as String?;

      return AppUpdateResult.updateAvailable(
        latestVersion: latestVersion,
        changesSummary: changesSummary,
        iosStoreUrl: iosUrl,
        androidStoreUrl: androidUrl,
      );
    } catch (e) {
      debugPrint('[AppUpdateService] Error checking for update: $e');
      return AppUpdateResult.noUpdateAvailable();
    }
  }

  /// Records that the update dialog was shown for [version].
  static Future<void> markVersionNotified(String version) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_prefixNotifiedVersion, version);
  }

  /// Semantic version comparison
  /// Returns true if [newVersion] is newer than [currentVersion]
  static bool _isVersionNewer(String newVersion, String currentVersion) {
    try {
      final newParts = newVersion.split('.').map(int.parse).toList();
      final currentParts = currentVersion.split('.').map(int.parse).toList();

      // Pad with zeros if lengths differ
      while (newParts.length < currentParts.length) {
        newParts.add(0);
      }
      while (currentParts.length < newParts.length) {
        currentParts.add(0);
      }

      // Compare each segment
      for (int i = 0; i < newParts.length; i++) {
        if (newParts[i] > currentParts[i]) return true;
        if (newParts[i] < currentParts[i]) return false;
      }

      return false;
    } catch (e) {
      debugPrint('[AppUpdateService] Version comparison error: $e');
      return false;
    }
  }

  /// Reset the notified version (for testing)
  static Future<void> resetNotificationState() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_prefixNotifiedVersion);
  }
}

/// Result class for update check
class AppUpdateResult {
  final bool updateAvailable;
  final String? latestVersion;
  final String? changesSummary;
  final String? iosStoreUrl;
  final String? androidStoreUrl;

  AppUpdateResult({
    required this.updateAvailable,
    this.latestVersion,
    this.changesSummary,
    this.iosStoreUrl,
    this.androidStoreUrl,
  });

  factory AppUpdateResult.noUpdateAvailable() {
    return AppUpdateResult(updateAvailable: false);
  }

  factory AppUpdateResult.updateAvailable({
    required String latestVersion,
    required String changesSummary,
    String? iosStoreUrl,
    String? androidStoreUrl,
  }) {
    return AppUpdateResult(
      updateAvailable: true,
      latestVersion: latestVersion,
      changesSummary: changesSummary,
      iosStoreUrl: iosStoreUrl,
      androidStoreUrl: androidStoreUrl,
    );
  }
}
