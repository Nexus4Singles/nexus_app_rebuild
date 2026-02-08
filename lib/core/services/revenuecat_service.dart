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

  static Future<void> purchaseSubscription(Package package) async {
    try {
      await Purchases.purchasePackage(package);
    } catch (e) {
      print('Error purchasing subscription: $e');
      rethrow;
    }
  }

  static Future<CustomerInfo> purchasePackage(Package package) async {
    try {
      return await Purchases.purchasePackage(package);
    } catch (e) {
      print('Error purchasing package: $e');
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
        // iOS - Open App Store app to manage subscriptions
        // The URL scheme opens the subscriptions section in Settings
        const url = 'https://apps.apple.com/account/subscriptions';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
        }
      } else if (Platform.isAndroid) {
        // Android - Open Google Play app to manage subscriptions
        // Use the app package name to open Play Store subscriptions
        const appPackage = 'com.nexusapp'; // Replace with your actual package name
        const url = 'https://play.google.com/store/account/subscriptions?package=$appPackage';
        if (await canLaunchUrl(Uri.parse(url))) {
          await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
        } else {
        }
      }
    } catch (e) {
      rethrow;
    }
  }
}
