import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:io' show Platform;
import 'dart:async';
import 'package:url_launcher/url_launcher.dart';
import 'package:nexus_app_v2/features/subscription/domain/subscription_models.dart';
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
    try {
      await Purchases.logIn(userId).timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          'RevenueCat login timed out. Please check your internet connection and try again.',
        ),
      );

      final customerInfo = await Purchases.getCustomerInfo().timeout(
        const Duration(seconds: 20),
        onTimeout: () => throw TimeoutException(
          'RevenueCat customer info fetch timed out. Please check your internet connection and try again.',
        ),
      );

      final customerId = customerInfo.originalAppUserId;
      if (customerId.isNotEmpty) {
        await FirebaseFirestore.instance.collection('users').doc(userId).set({
          'revenueCat': {
            'customerId': customerId,
            'lastLinkedAt': FieldValue.serverTimestamp(),
          },
        }, SetOptions(merge: true));
      }
    } catch (e) {
      debugPrint(
        '⚠️ [RevenueCatService] Could not persist RevenueCat identity: $e',
      );
      // Do not rethrow here: purchase should still proceed even if user linking
      // or customer info persistence fails.
    }
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
  ///
  /// Throws an exception if purchase fails for any reason other than user cancellation.
  static bool get _isRunningOnIOSSimulator {
    if (!Platform.isIOS) return false;

    final env = Platform.environment;
    final home = env['HOME'] ?? '';
    final tmpDir = env['TMPDIR'] ?? '';
    final hasSimulatorKey = env.keys.any(
      (key) =>
          key.toLowerCase().contains('simulator') ||
          key.toLowerCase().contains('device') ||
          key.startsWith('SIMCTL_CHILD_'),
    );
    final homeIndicatesSimulator =
        home.contains('/Library/Developer/CoreSimulator/');
    final tmpDirIndicatesSimulator =
        tmpDir.contains('/Library/Developer/CoreSimulator/');
    return hasSimulatorKey || homeIndicatesSimulator || tmpDirIndicatesSimulator;
  }

  static Future<CustomerInfo?> purchasePackage(Package package) async {
    final envMap = Platform.environment;
    final home = envMap['HOME'] ?? '';
    final tmpDir = envMap['TMPDIR'] ?? '';
    final envKeys = envMap.keys
        .where(
          (key) =>
              key.toLowerCase().contains('simulator') ||
              key.toLowerCase().contains('device') ||
              key.startsWith('SIMCTL_CHILD_'),
        )
        .toList();
    debugPrint(
      '💡 [RevenueCatService] runtime diagnostics: '
      'os=${Platform.operatingSystem}, '
      'osVersion=${Platform.operatingSystemVersion}, '
      'isIOS=${Platform.isIOS}, '
      'isAndroid=${Platform.isAndroid}, '
      'simulatorEnvKeys=$envKeys, '
      'simulatorEnv=${envMap.entries.where((entry) => entry.key.toLowerCase().contains('simulator') || entry.key.toLowerCase().contains('device')).map((entry) => '${entry.key}=${entry.value}').join(', ')}, '
      'home=$home, '
      'tmpDir=$tmpDir',
    );

    if (_isRunningOnIOSSimulator) {
      throw TimeoutException(
        'Subscriptions cannot be completed on the iOS Simulator. '
        'Please test on a real iOS device or use a sandbox device instead.',
      );
    }

    debugPrintSynchronously('🔧 [RevenueCatService] purchasePackage START');
    print(
      '🔵 [RevenueCatService] Calling Purchases.purchasePackage for: '
      '${package.storeProduct.identifier} (type: ${package.packageType})',
    );

    try {
      debugPrintSynchronously(
        '🔧 [RevenueCatService] before Purchases.purchasePackage',
      );
      final result = await Purchases.purchasePackage(package);
      debugPrintSynchronously(
        '🔧 [RevenueCatService] after Purchases.purchasePackage',
      );
      // ── FORENSIC: capture what the SDK returned ──
      print('🟢 [RevenueCatService] purchasePackage RETURNED (not thrown)');
      print(
        '   Active entitlements: ${result.entitlements.active.keys.toList()}',
      );
      print(
        '   NonSubscriptionTransactions: ${result.nonSubscriptionTransactions.map((t) => '${t.productIdentifier}@${t.purchaseDate}').toList()}',
      );
      return result;
    } on PlatformException catch (e) {
      print(
        '🔴 [RevenueCatService] PlatformException: code=${e.code} message=${e.message}',
      );
      print('   Details type: ${e.details?.runtimeType}');
      print('   Details: ${e.details}');

      // Check for user cancellation
      final errorDetails = e.details as Map?;
      final wasUserCancelled = errorDetails?['userCancelled'] as bool? ?? false;
      final readableErrorCode =
          errorDetails?['readableErrorCode'] as String? ?? '';

      print(
        '   userCancelled=$wasUserCancelled  readableErrorCode=$readableErrorCode',
      );

      if (wasUserCancelled) {
        print('🟡 [RevenueCatService] User cancelled purchase');
        return null;
      }

      // Detect "product already purchased" specifically
      if (readableErrorCode.contains('PRODUCT_ALREADY_PURCHASED') ||
          (e.message ?? '').toLowerCase().contains('already') ||
          e.code == '6') {
        print(
          '🟠 [RevenueCatService] PRODUCT ALREADY PURCHASED – '
          'the Apple ID owns this non-consumable. No payment sheet will appear.',
        );
        // Re-throw so caller can handle this distinctly
        rethrow;
      }

      // Any other error, re-throw it
      rethrow;
    } catch (e) {
      print('🔴 [RevenueCatService] Non-platform exception: ${e.runtimeType}');
      print('   Full error: $e');

      final msg = e.toString().toLowerCase();
      // Only treat as cancellation if it's genuinely a cancel message
      if (msg.contains('user cancel') || msg.contains('purchase cancel')) {
        print('🟡 [RevenueCatService] User cancelled (string match)');
        return null;
      }

      print('🔴 [RevenueCatService] Unexpected error – rethrowing');
      rethrow;
    }
  }

  static Future<Offerings?> getOfferings() async {
    try {
      debugPrint(
        '🔵 [RevenueCatService] Fetching offerings from RevenueCat...',
      );
      final offerings = await Purchases.getOfferings();

      debugPrint('🟢 [RevenueCatService] Offerings received successfully');
      debugPrint(
        '  Current offering: ${offerings.current?.identifier ?? "NONE"}',
      );
      debugPrint('  Total offerings: ${offerings.all.length}');

      if (offerings.all.isEmpty) {
        debugPrint('⚠️ [RevenueCatService] WARNING: No offerings configured!');
        debugPrint(
          '   This means NO products/packages are available for purchase',
        );
        debugPrint(
          '   Check RevenueCat dashboard to ensure offerings are created',
        );
      }

      offerings.all.forEach((key, offering) {
        debugPrint(
          '  - Offering "$key": ${offering.availablePackages.length} packages',
        );
        offering.availablePackages.forEach((package) {
          debugPrint(
            '    - Package: ${package.identifier} → Product: ${package.storeProduct.identifier}',
          );
        });
      });

      return offerings;
    } catch (e, st) {
      debugPrint('🔴 [RevenueCatService] Error fetching offerings');
      debugPrint('   Exception: ${e.runtimeType}');
      debugPrint('   Message: $e');
      debugPrint('   StackTrace: $st');

      // Provide specific diagnostic hints
      if (e.toString().contains('No such file or directory')) {
        debugPrint(
          '   💡 Hint: This may indicate the SDK is not initialized properly',
        );
      } else if (e.toString().toLowerCase().contains('network') ||
          e.toString().toLowerCase().contains('connection')) {
        debugPrint('   💡 Hint: Network error - check internet connection');
      } else if (e.toString().toLowerCase().contains('unauthorized') ||
          e.toString().toLowerCase().contains('forbidden')) {
        debugPrint('   💡 Hint: API key may be wrong or invalid');
      }

      return null;
    }
  }

  static Future<CustomerInfo> getCustomerInfo() async {
    return await Purchases.getCustomerInfo();
  }

  /// Sync active RevenueCat subscription entitlement to Firestore for the
  /// current user. Returns true if a Firestore update was applied.
  static Future<bool> syncActiveSubscriptionToFirestore({
    required String userId,
    CustomerInfo? customerInfo,
  }) async {
    try {
      final info = customerInfo ?? await Purchases.getCustomerInfo();
      final activeEntitlements = info.entitlements.active;

      if (activeEntitlements.isEmpty) {
        debugPrint(
          '[RevenueCatService] No active entitlements to sync for user: $userId',
        );
        return false;
      }

      final entitlement =
          activeEntitlements['premium'] ?? activeEntitlements.values.first;
      final expiryDateStr = entitlement.expirationDate;
      Timestamp? expiryTimestamp;
      if (expiryDateStr != null) {
        final parsed = DateTime.tryParse(expiryDateStr);
        if (parsed != null) {
          expiryTimestamp = Timestamp.fromDate(parsed);
        }
      }

      final subscriptionData = <String, dynamic>{
        'isActive': true,
        'tier': SubscriptionTier.monthly.id,
        'startDate': FieldValue.serverTimestamp(),
        if (expiryTimestamp != null) 'expiryDate': expiryTimestamp,
        'autoRenew': true,
        'revenueCatCustomerId': info.originalAppUserId,
        'revenueCatSubscriptionId': entitlement.productIdentifier,
      };

      final updateData = <String, dynamic>{
        'subscription': subscriptionData,
        'onPremium': true,
        'entitledUser': true,
        'updatedAt': FieldValue.serverTimestamp(),
      };
      if (expiryTimestamp != null) {
        updateData['subExpDate'] = expiryTimestamp;
      }

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .set(updateData, SetOptions(merge: true));

      debugPrint(
        '[RevenueCatService] ✅ Synced active RevenueCat subscription to Firestore for user: $userId',
      );
      return true;
    } catch (e) {
      debugPrint(
        '[RevenueCatService] ⚠️ Failed to sync active RevenueCat subscription: $e',
      );
      return false;
    }
  }

  /// Checks if a non-consumable product is already owned (present in
  /// nonSubscriptionTransactions). On iOS, already-owned non-consumables
  /// won't show a purchase sheet — StoreKit silently returns the existing
  /// purchase. Use this to detect that case and handle it gracefully
  /// (e.g. restore access without calling purchasePackage).
  static Future<bool> isProductOwned(String productId) async {
    try {
      final info = await Purchases.getCustomerInfo();
      return info.nonSubscriptionTransactions.any(
        (t) => t.productIdentifier == productId,
      );
    } catch (e) {
      debugPrint('⚠️ [RevenueCatService] isProductOwned check failed: $e');
      return false;
    }
  }

  /// Opens the native subscription management UI for the platform
  /// (iOS: App Store, Android: Google Play).
  ///
  /// NOTE: We skip `canLaunchUrl` entirely because it requires platform-
  /// specific manifest/plist declarations (`<queries>` on Android 11+,
  /// `LSApplicationQueriesSchemes` on iOS) and returns false even when the
  /// URL is perfectly launchable. Instead we call `launchUrl` directly and
  /// catch failures.
  static Future<void> manageSubscriptions() async {
    try {
      if (Platform.isIOS) {
        // Primary: deep-link into the App Store subscriptions page
        const primary = 'https://apps.apple.com/account/subscriptions';
        print('🟡 [RevenueCatService] Opening iOS subscriptions: $primary');
        final launched = await launchUrl(
          Uri.parse(primary),
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          print('🟢 [RevenueCatService] Successfully opened iOS subscriptions');
          return;
        }
        throw Exception('launchUrl returned false for $primary');
      } else if (Platform.isAndroid) {
        // The applicationId MUST match build.gradle.kts → applicationId
        const appPackage = 'com.nexusapptest.app';
        // Primary: Google Play subscription settings filtered to this app
        const primary =
            'https://play.google.com/store/account/subscriptions?package=$appPackage';
        print('🟡 [RevenueCatService] Opening Android subscriptions: $primary');
        final launched = await launchUrl(
          Uri.parse(primary),
          mode: LaunchMode.externalApplication,
        );
        if (launched) {
          print(
            '🟢 [RevenueCatService] Successfully opened Android subscriptions',
          );
          return;
        }
        // Fallback: generic Play Store subscriptions page (without package filter)
        const fallback = 'https://play.google.com/store/account/subscriptions';
        print('🟡 [RevenueCatService] Trying fallback: $fallback');
        final fallbackLaunched = await launchUrl(
          Uri.parse(fallback),
          mode: LaunchMode.externalApplication,
        );
        if (fallbackLaunched) {
          print('🟢 [RevenueCatService] Successfully opened fallback');
          return;
        }
        throw Exception('Failed to open Google Play subscriptions');
      }
    } catch (e) {
      print('🔴 [RevenueCatService] manageSubscriptions error: $e');
      rethrow;
    }
  }
}
