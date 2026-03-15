import 'dart:io';

/// RevenueCat Configuration for Nexus v2
/// API Keys, Product IDs, and Entitlements

class RevenueCatConfig {
  // ============================================================================
  // API KEYS (SDK Keys - safe to expose in client code)
  // ============================================================================
  static const String androidApiKey = 'goog_mjvhTsGNNSzgnXyRVrIGjCmXwol';
  static const String iosApiKey = 'appl_dfjYQwnRsUjojfOSnYGqciVcGzx';

  // ============================================================================
  // SUBSCRIPTION ENTITLEMENTS & PRODUCT IDs
  // ============================================================================
  /// Entitlement for premium dating features (subscriptions only)
  static const String premiumEntitlement = 'premium';

  /// Platform-specific subscription product IDs
  /// iOS App Store: nexus_premium_v2
  /// Android Play Store: monthly_premium_v2
  static const String iosSubscriptionProductId = 'nexus_premium_v2';
  static const String androidSubscriptionProductId = 'monthly_premium_v2';

  /// Returns the correct subscription product ID based on platform
  static String getSubscriptionProductId() {
    return Platform.isIOS
        ? iosSubscriptionProductId
        : androidSubscriptionProductId;
  }

  // ============================================================================
  // JOURNEY PURCHASE PRODUCT IDs & ENTITLEMENTS
  // ============================================================================
  /// Single non-consumable product for all journey purchases
  static const String journeyUnlockProductId = 'nexus_journey_unlock';

  /// Entitlement for journey access
  static const String journeyEntitlement = 'journey_access';

  // ============================================================================
  // TEST MODE
  // ============================================================================
  static const bool enableTestMode =
      false; // Set to true for sandbox testing only
}
