// lib/core/services/revenuecat_service.dart
//
// RevenueCat DISABLED temporarily.
// This stub ensures the app compiles and runs without purchases_flutter.

class RevenueCatService {
  static Future<void> init() async {
    // RevenueCat disabled
  }

  static Future<void> login(String userId) async {
    // RevenueCat disabled
  }

  static Future<void> logout() async {
    // RevenueCat disabled
  }

  static Future<bool> hasActiveSubscription() async {
    // Always false while disabled
    return false;
  }

  static Future<void> purchaseSubscription() async {
    throw Exception("Subscriptions are temporarily disabled.");
  }
}
