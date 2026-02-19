import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart';
import 'dart:io' show Platform;
import 'package:url_launcher/url_launcher.dart';
import '../config/revenuecat_config.dart';

class RevenueCatService {
  static Future<void> init() async {
    try {
      // Determine platform and configure RevenueCat
      final configuration = PurchasesConfiguration(
        Platform.isIOS
            ? RevenueCatConfig.iosApiKey
            : RevenueCatConfig.androidApiKey,
      );

      await Purchases.configure(configuration);
    } catch (e) {
      rethrow;
    }
  }

  static Future<void> login(String userId) async {
    await Purchases.logIn(userId);
  }

  static Future<void> logout() async {
    await Purchases.logOut();
  }

  static Future<bool> hasActiveSubscription() async {
    try {
      final customerInfo = await Purchases.getCustomerInfo();
      // Check if user has any active entitlements
      return customerInfo.entitlements.active.isNotEmpty;
    } catch (e) {
      print('Error checking subscription status: $e');
      return false;
    }
  }

  /// Purchase a subscription package. Returns the [CustomerInfo] on success,
  /// or `null` when the user cancels the platform purchase sheet.
  static Future<CustomerInfo?> purchaseSubscription(Package package) async {
    return purchasePackage(package);
  }

  /// Purchase a package (subscriptions or one-time). Returns [CustomerInfo]
  /// on success, or `null` if the user cancelled the native purchase UI.
  static Future<CustomerInfo?> purchasePackage(Package package) async {
    try {
      return await Purchases.purchasePackage(package);
    } catch (e) {
      final msg = e.toString().toLowerCase();
      // Heuristic checks for user-initiated cancellation messages from
      // platform SDKs. If detected, return null to indicate a cancelled
      // purchase (not an error the user needs to see).
      if (msg.contains('cancel') ||
          msg.contains('user cancelled') ||
          msg.contains('user canceled') ||
          msg.contains('purchase cancelled') ||
          msg.contains('purchase canceled')) {
        print('🟡 [RevenueCatService] Purchase cancelled by user: $e');
        return null;
      }

      print('🔴 [RevenueCatService] Error purchasing package: $e');
      rethrow;
    }
  }

  static Future<Offerings?> getOfferings() async {
    try {
      final offerings = await Purchases.getOfferings();
      return offerings;
    } catch (e) {
      return null;
    }
  }

  static Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }

  /// Opens the native subscription management UI for the platform
  /// (iOS: App Store, Android: Google Play)
  static Future<void> manageSubscriptions() async {
    try {
      if (Platform.isIOS) {
        // iOS - Try multiple URL schemes in order of preference
        const urls = [
          // Primary: Settings app deep link (iOS 15.1+)
          'itms-apps://apps.apple.com/account/subscriptions',
          // Fallback: Web URL
          'https://apps.apple.com/account/subscriptions',
        ];

        for (final url in urls) {
          try {
            print('🟡 [RevenueCatService] Trying iOS URL: $url');
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              print('🟢 [RevenueCatService] Successfully opened: $url');
              return;
            } else {
              print('🔴 [RevenueCatService] Cannot launch URL: $url');
            }
          } catch (e) {
            print('🔴 [RevenueCatService] Error with URL $url: $e');
          }
        }

        throw Exception(
          'Failed to open App Store subscriptions management on iOS. None of the URL schemes worked.',
        );
      } else if (Platform.isAndroid) {
        // Android - Try multiple approaches
        const appPackage = 'com.nexusapp';
        const urls = [
          // Primary: Google Play subscriptions
          'https://play.google.com/store/account/subscriptions?package=$appPackage',
          // Fallback: Direct Google Play Store link
          'https://play.google.com/store/apps/details?id=$appPackage',
        ];

        for (final url in urls) {
          try {
            print('🟡 [RevenueCatService] Trying Android URL: $url');
            final uri = Uri.parse(url);
            if (await canLaunchUrl(uri)) {
              await launchUrl(uri, mode: LaunchMode.externalApplication);
              print('🟢 [RevenueCatService] Successfully opened: $url');
              return;
            } else {
              print('🔴 [RevenueCatService] Cannot launch URL: $url');
            }
          } catch (e) {
            print('🔴 [RevenueCatService] Error with URL $url: $e');
          }
        }

        throw Exception(
          'Failed to open Google Play subscriptions management on Android. None of the URL schemes worked.',
        );
      }
    } catch (e) {
      print('🔴 [RevenueCatService] manageSubscriptions error: $e');
      rethrow;
    }
  }
}
