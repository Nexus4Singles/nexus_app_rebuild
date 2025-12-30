// revenuecat_stub.dart
// Temporary stub while RevenueCat is disabled.

class RevenueCatService {
  static Future<void> init() async {
    // disabled
  }

  static Future<void> login(String userId) async {
    // disabled
  }

  static Future<void> logout() async {
    // disabled
  }

  static Future<bool> hasActiveSubscription() async {
    return false;
  }

  static Future<void> purchaseSubscription() async {
    throw Exception("Subscriptions are temporarily disabled.");
  }
}


