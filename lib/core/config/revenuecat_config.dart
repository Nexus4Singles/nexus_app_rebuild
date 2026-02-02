/// RevenueCat Configuration for Nexus v2
/// API Keys, Product IDs, and Entitlements

class RevenueCatConfig {
  // ============================================================================
  // API KEYS (SDK Keys - safe to expose in client code)
  // ============================================================================
  static const String androidApiKey = 'sk_YnnxCarcQLFoUrMMacmTfCUsgqeqU';
  static const String iosApiKey = 'sk_YnnxCarcQLFoUrMMacmTfCUsgqeqU';
  
  // ============================================================================
  // SUBSCRIPTION ENTITLEMENTS & PRODUCT IDs
  // ============================================================================
  /// Entitlement for premium dating features (subscriptions only)
  static const String premiumEntitlement = 'premium';
  
  /// Subscription product IDs (same as v1, reuse existing)
  static const String subscriptionMonthlyId = 'nexus_premium_monthly';
  static const String subscriptionQuarterlyId = 'nexus_premium_quarterly';
  static const String subscriptionYearlyId = 'nexus_premium_yearly';
  
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
