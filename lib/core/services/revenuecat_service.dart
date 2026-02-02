import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:io' show Platform;
import '../config/revenuecat_config.dart';

class RevenueCatService {
  static Future<void> init() async {
    // Determine platform and configure RevenueCat
    final configuration = PurchasesConfiguration(
      Platform.isIOS ? RevenueCatConfig.iosApiKey : RevenueCatConfig.androidApiKey,
    );
    
    await Purchases.configure(configuration);
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

  static Future<Offerings?> getOfferings() async {
    try {
      return await Purchases.getOfferings();
    } catch (e) {
      print('Error fetching offerings: $e');
      return null;
    }
  }

  static Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }
}
