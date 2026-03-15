import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import '../../../core/config/revenuecat_config.dart';
import '../../../core/services/revenuecat_service.dart';

/// Provider for fetching RevenueCat offerings
/// Offerings contain all available products for purchase
final offeringsProvider = FutureProvider<Offerings?>((ref) async {
  try {
    return await RevenueCatService.getOfferings();
  } catch (e) {
    print('Error fetching offerings: $e');
    return null;
  }
});

/// Provider for subscription offerings (premium dating features)
/// Tries nexus_premium_v2 first, falls back to offerings.current, then old Premium offering
final subscriptionOfferingProvider = FutureProvider<Offering?>((ref) async {
  try {
    final offerings = await ref.watch(offeringsProvider.future);
    if (offerings == null) return null;
    // Try the new nexus_premium_v2 offering first
    return offerings.getOffering('nexus_premium_v2') ??
        offerings.current ??
        offerings.getOffering('Premium');
  } catch (e) {
    print('Error fetching subscription offering: $e');
    return null;
  }
});

/// Provider for journey purchase offering
/// Journey products are in per-category offerings: singles_journey, married_journey, etc.
/// This provider returns the singles_journey offering as a default reference.
final journeyOfferingProvider = FutureProvider<Offering?>((ref) async {
  try {
    final offerings = await ref.watch(offeringsProvider.future);
    if (offerings == null) return null;
    // Try common journey offering identifiers
    return offerings.getOffering('singles_journey') ??
        offerings.getOffering('married_journey') ??
        offerings.getOffering('divorced_journey') ??
        offerings.getOffering('widowed_journey');
  } catch (e) {
    print('Error fetching journey offering: $e');
    return null;
  }
});

/// Provider to get specific package from journey offering
final journeyPackageProvider = FutureProvider<Package?>((ref) async {
  try {
    final offering = await ref.watch(journeyOfferingProvider.future);
    if (offering == null) return null;
    // Get the 'standard' package which contains the journey_unlock product
    return offering.getPackage('standard');
  } catch (e) {
    print('Error fetching journey package: $e');
    return null;
  }
});

/// Provider to get subscription packages (monthly only)
final subscriptionPackagesProvider = FutureProvider<Package?>((ref) async {
  try {
    final offering = await ref.watch(subscriptionOfferingProvider.future);
    if (offering == null) return null;

    final packages = offering.availablePackages;
    if (packages.isEmpty) return null;

    // Try RevenueCat $rc_monthly package type first
    final rcMonthly = offering.getPackage('\$rc_monthly');
    if (rcMonthly != null) return rcMonthly;

    // Try to find by platform-specific product ID
    final targetProductId =
        RevenueCatConfig.getSubscriptionProductId().toLowerCase();
    for (final p in packages) {
      if (p.storeProduct.identifier.toLowerCase() == targetProductId) return p;
    }
    for (final p in packages) {
      if (p.storeProduct.identifier.toLowerCase().contains(targetProductId))
        return p;
    }

    // Last resort: return first available package
    return packages.first;
  } catch (e) {
    print('Error fetching subscription package: $e');
    return null;
  }
});
