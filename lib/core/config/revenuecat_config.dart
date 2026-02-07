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

  /// Subscription product IDs
  static const String subscriptionMonthlyId = 'nexus_premium_v2';

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
  static const bool enableTestMode = true; // Set to false for production
}
