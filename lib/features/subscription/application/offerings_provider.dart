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
final subscriptionOfferingProvider = FutureProvider<Offering?>((ref) async {
  try {
    final offerings = await ref.watch(offeringsProvider.future);
    if (offerings == null) return null;
    // 'premium' is the offering identifier for subscriptions
    return offerings.getOffering('premium');
  } catch (e) {
    print('Error fetching subscription offering: $e');
    return null;
  }
});

/// Provider for journey purchase offering
final journeyOfferingProvider = FutureProvider<Offering?>((ref) async {
  try {
    final offerings = await ref.watch(offeringsProvider.future);
    if (offerings == null) return null;
    // 'journeys' is the offering identifier for journey purchases
    return offerings.getOffering('journeys');
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

    // Fetch the monthly subscription package from RevenueCat
    final monthlyPackage = offering.getPackage('\$rc_monthly');
    if (monthlyPackage != null) {
      return monthlyPackage;
    }

    // Fallback: try to find package containing 'monthly' in identifier
    final packages = offering.availablePackages;
    for (final p in packages) {
      if (p.storeProduct.identifier.toLowerCase().contains('monthly')) {
        return p;
      }
    }

    // Last resort: return first available package
    return packages.isNotEmpty ? packages.first : null;
  } catch (e) {
    print('Error fetching subscription package: $e');
    return null;
  }
});
