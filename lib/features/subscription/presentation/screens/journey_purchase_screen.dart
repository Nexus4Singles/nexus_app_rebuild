import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'dart:async';

import '../../../../core/theme/theme.dart';
import '../../../../core/services/revenuecat_service.dart';
import '../../../../core/services/journey_entitlements_service.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../challenges/domain/journey_v1_models.dart';
import '../../../challenges/providers/journeys_providers.dart';
import '../../application/subscription_provider.dart';
import '../../../../core/services/secure_purchase_validation_service.dart';

/// Minimal journey purchase screen
class JourneyPurchaseScreen extends ConsumerStatefulWidget {
  final JourneyV1 journey;

  const JourneyPurchaseScreen({super.key, required this.journey});

  @override
  ConsumerState<JourneyPurchaseScreen> createState() =>
      _JourneyPurchaseScreenState();
}

class _JourneyPurchaseScreenState extends ConsumerState<JourneyPurchaseScreen> {
  /// Removes all '**' from the summary string.
  String sanitizeSummary(String summary) {
    return summary.replaceAll('**', '');
  }

  bool _isPurchasing = false;
  double _actualPrice = 0.0;
  String _priceString = '';
  String _currencyCode = '';

  @override
  void initState() {
    super.initState();
    _loadActualPrice();
  }

  Future<void> _loadActualPrice() async {
    try {
      final offerings = await RevenueCatService.getOfferings();
      if (offerings == null) return;

      final journeyWithCategory = ref.read(
        journeyWithCategoryProvider(widget.journey.id),
      );
      final category = journeyWithCategory?.$2 ?? 'singles';
      final productId = _getProductIdForCategory(category);

      Package? journeyPackage;

      // First: search in the dedicated per-category offering (e.g. "singles_journey")
      final categoryOfferingId = '${category.toLowerCase()}_journey';
      final categoryOffering = offerings.getOffering(categoryOfferingId);
      if (categoryOffering != null) {
        for (final p in categoryOffering.availablePackages) {
          if (p.storeProduct.identifier.toLowerCase() ==
              productId.toLowerCase()) {
            journeyPackage = p;
            break;
          }
        }
      }

      // Second: search all offerings (covers any offering layout)
      if (journeyPackage == null) {
        for (final offering in offerings.all.values) {
          for (final p in offering.availablePackages) {
            if (p.storeProduct.identifier.toLowerCase() ==
                productId.toLowerCase()) {
              journeyPackage = p;
              break;
            }
          }
          if (journeyPackage != null) break;
        }
      }

      if (journeyPackage != null && mounted) {
        final pkg = journeyPackage;
        setState(() {
          _actualPrice = pkg.storeProduct.price;
          _priceString = pkg.storeProduct.priceString;
          _currencyCode = pkg.storeProduct.currencyCode;
        });
      }
    } catch (e) {
      debugPrint('⚠️ [JourneyPurchase] Error loading price: $e');
    }
  }

  String _getProductIdForCategory(String category) {
    final categoryLower = category.toLowerCase();
    const categoryToProductId = {
      'singles': 'singles_journey',
      'married': 'married_journey',
      'divorced': 'divorced_journey',
      'widowed': 'widowed_journey',
    };
    return categoryToProductId[categoryLower] ?? 'singles_journey';
  }

  @override
  Widget build(BuildContext context) {
    final isPurchasedAsync = ref.watch(
      isJourneyPurchasedProvider(widget.journey.id),
    );

    return isPurchasedAsync.when(
      loading:
          () => _buildScaffold(context, isPurchased: false, isLoading: true),
      error:
          (_, __) =>
              _buildScaffold(context, isPurchased: false, isLoading: false),
      data:
          (isPurchased) => _buildScaffold(
            context,
            isPurchased: isPurchased,
            isLoading: false,
          ),
    );
  }

  Widget _buildScaffold(
    BuildContext context, {
    required bool isPurchased,
    required bool isLoading,
  }) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Unlock Journey',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    AppColors.primary,
                    AppColors.primary.withOpacity(0.8),
                  ],
                ),
              ),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  Container(
                    width: 48,
                    height: 48,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          widget.journey.title,
                          style: AppTextStyles.titleSmall.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.bold,
                          ),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                        if (widget.journey.subtitle.isNotEmpty) ...[
                          const SizedBox(height: 4),
                          Text(
                            widget.journey.subtitle,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: Colors.white.withOpacity(0.85),
                              height: 1.3,
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ],
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About This Journey',
                    style: AppTextStyles.titleSmall.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    sanitizeSummary(widget.journey.summary),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 16),
                  Row(
                    children: [
                      _Stat(
                        icon: Icons.layers_outlined,
                        label: 'Activities',
                        value: '${widget.journey.missions.length}',
                      ),
                      const SizedBox(width: 12),
                      _Stat(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value:
                            '${(widget.journey.missions.fold<int>(0, (sum, m) => sum + m.timeBoxMinutes) / 60).ceil()} Hours',
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (_actualPrice > 0)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.getSurface(context),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: AppColors.getBorder(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'One-Time Purchase',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.getTextSecondary(context),
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            _priceString.isNotEmpty
                                ? _priceString
                                : '${_currencyCode.isNotEmpty ? _currencyCode : ''} ${_actualPrice.toStringAsFixed(0)}',
                            style: AppTextStyles.headlineSmall.copyWith(
                              fontWeight: FontWeight.bold,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Full access to all Activities',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  const SizedBox(height: 20),
                ],
              ),
            ),
          ],
        ),
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child:
              isPurchased
                  ? InkWell(
                    onTap:
                        () => Navigator.of(
                          context,
                        ).pushNamed('/journey/${widget.journey.id}'),
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(
                          color: Colors.green.withOpacity(0.3),
                        ),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.check_circle,
                            color: Colors.green,
                            size: 22,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  'Journey Purchased',
                                  style: AppTextStyles.labelLarge.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                ),
                                Text(
                                  'Tap to start your journey',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(
                            Icons.arrow_forward_ios_rounded,
                            color: Colors.green,
                            size: 16,
                          ),
                        ],
                      ),
                    ),
                  )
                  : SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed:
                          _isPurchasing || isLoading ? null : _handlePurchase,
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                      child:
                          _isPurchasing
                              ? const SizedBox(
                                height: 20,
                                width: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                  valueColor: AlwaysStoppedAnimation<Color>(
                                    Colors.white,
                                  ),
                                ),
                              )
                              : Text(
                                'Purchase Journey',
                                style: AppTextStyles.labelLarge.copyWith(
                                  color: Colors.white,
                                ),
                              ),
                    ),
                  ),
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    setState(() => _isPurchasing = true);
    try {
      debugPrint('🔵 [JourneyPurchase] Purchase flow started');

      final offerings = await RevenueCatService.getOfferings();
      if (offerings == null) {
        debugPrint('🔴 [JourneyPurchase] CRITICAL: Offerings are null!');
        _showError(
          'Purchase service unavailable. Please check your connection and try again.',
        );
        setState(() => _isPurchasing = false);
        return;
      }

      // Safety check: ensure offerings have packages
      if (offerings.all.isEmpty) {
        debugPrint(
          '🔴 [JourneyPurchase] ERROR: No offerings available at all!',
        );
        _showError(
          'No products available for purchase. Please try again later.',
        );
        setState(() => _isPurchasing = false);
        return;
      }

      debugPrint(
        '🔵 [JourneyPurchase] Offerings loaded: ${offerings.all.length} total, current: ${offerings.current?.identifier ?? "none"}',
      );

      final journeyWithCategory = ref.read(
        journeyWithCategoryProvider(widget.journey.id),
      );
      final category = journeyWithCategory?.$2 ?? 'singles';
      final productId = _getProductIdForCategory(category);

      debugPrint(
        '🔵 [JourneyPurchase] Looking for product: $productId in category: $category',
      );

      Package? journeyPackage;

      // First: check the dedicated per-category offering (e.g. "singles_journey", "married_journey")
      final categoryOfferingId = '${category.toLowerCase()}_journey';
      final categoryOffering = offerings.getOffering(categoryOfferingId);
      if (categoryOffering != null) {
        debugPrint(
          '🔵 [JourneyPurchase] Searching in dedicated offering: $categoryOfferingId (${categoryOffering.availablePackages.length} packages)',
        );
        for (final p in categoryOffering.availablePackages) {
          debugPrint('  - Found package: ${p.storeProduct.identifier}');
          if (p.storeProduct.identifier.toLowerCase() ==
              productId.toLowerCase()) {
            journeyPackage = p;
            debugPrint(
              '🟢 [JourneyPurchase] Matched package in dedicated offering!',
            );
            break;
          }
        }
      }

      // Second: search in offerings.current if not yet found
      if (journeyPackage == null && offerings.current != null) {
        debugPrint(
          '🔵 [JourneyPurchase] Searching in current offering (${offerings.current!.availablePackages.length} packages)',
        );
        for (final p in offerings.current!.availablePackages) {
          debugPrint('  - Found package: ${p.storeProduct.identifier}');
          if (p.storeProduct.identifier.toLowerCase() ==
              productId.toLowerCase()) {
            journeyPackage = p;
            debugPrint(
              '🟢 [JourneyPurchase] Matched package in current offering!',
            );
            break;
          }
        }
      }

      if (journeyPackage == null) {
        debugPrint(
          '🔵 [JourneyPurchase] Package not in current offering, searching all offerings (${offerings.all.length} total)',
        );
        for (final offering in offerings.all.values) {
          debugPrint(
            '  - Searching offering: ${offering.identifier} (${offering.availablePackages.length} packages)',
          );
          for (final p in offering.availablePackages) {
            debugPrint('    - Found package: ${p.storeProduct.identifier}');
            if (p.storeProduct.identifier.toLowerCase() ==
                productId.toLowerCase()) {
              journeyPackage = p;
              debugPrint(
                '🟢 [JourneyPurchase] Matched package in offering: ${offering.identifier}',
              );
              break;
            }
          }
          if (journeyPackage != null) break;
        }
      }

      if (journeyPackage == null) {
        debugPrint('🔴 [JourneyPurchase] Package NOT found: $productId');
        _showError('Journey not available for purchase.');
        setState(() => _isPurchasing = false);
        return;
      }

      // ── Check if this specific JOURNEY is already purchased ──
      // Products are consumable (one product per category, purchased per journey).
      // Each purchase charges the user and unlocks one specific journey.
      // Check Firestore/SharedPreferences to avoid double-charging.
      final alreadyPurchased = await JourneyEntitlementsService().isPurchased(
        widget.journey.id,
      );
      if (alreadyPurchased) {
        debugPrint(
          '🟢 [JourneyPurchase] Journey ${widget.journey.id} already purchased — '
          'restoring access without charging again',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${widget.journey.title} is already unlocked!'),
              duration: const Duration(seconds: 3),
              backgroundColor: AppColors.success,
            ),
          );
          Future.delayed(const Duration(milliseconds: 800), () {
            if (mounted) Navigator.pop(context);
          });
        }
        setState(() => _isPurchasing = false);
        return;
      }

      final userId = ref.read(currentUserIdProvider);
      if (userId == null) {
        _showError('User not authenticated');
        setState(() => _isPurchasing = false);
        return;
      }

      try {
        await RevenueCatService.login(userId);
        debugPrint(
          '🟢 [JourneyPurchase] RevenueCat linked to Firebase user: $userId',
        );
      } catch (e) {
        debugPrint(
          '⚠️ [JourneyPurchase] RevenueCat login before purchase failed: $e',
        );
      }

      debugPrint(
        '🔵 [JourneyPurchase] Calling purchasePackage for: '
        '${journeyPackage.storeProduct.identifier} (journey: ${widget.journey.id})',
      );

      // Consumable purchase — Apple/Google will ALWAYS show the payment sheet
      // because consumables can be purchased multiple times.
      final customerInfo = await RevenueCatService.purchasePackage(
        journeyPackage,
      );

      if (!mounted) return;

      // If customerInfo is null, the user cancelled the native purchase UI.
      if (customerInfo == null) {
        debugPrint(
          '🟡 [JourneyPurchase] Purchase cancelled by user (null result)',
        );
        setState(() => _isPurchasing = false);
        return;
      }

      debugPrint(
        '🟢 [JourneyPurchase] Purchase confirmed. '
        'Active entitlements: ${customerInfo.entitlements.active.keys.toList()}',
      );

      // ====================================================================
      // OPTIMISTIC: Trust the SDK, record immediately
      // ====================================================================
      // The RevenueCat SDK has returned successfully, confirming the purchase.
      debugPrint(
        '🟢 [JourneyPurchase] SDK confirmed purchase for ${widget.journey.id}',
      );

      // ── Write to SharedPreferences FIRST (reliable local cache) ──
      // This must happen before provider invalidation so that the
      // re-triggered isJourneyPurchasedProvider finds it immediately.
      try {
        await JourneyEntitlementsService().markPurchased(widget.journey.id);
        debugPrint(
          '🟢 [JourneyPurchase] SharedPreferences: marked ${widget.journey.id} as purchased',
        );
      } catch (e) {
        debugPrint('⚠️  [JourneyPurchase] SharedPreferences write failed: $e');
      }

      // Invalidate providers so UI re-checks purchase status.
      if (mounted) {
        ref.invalidate(purchasedJourneysProvider);
        ref.invalidate(journeyCatalogProvider);
        ref.invalidate(isJourneyPurchasedProvider(widget.journey.id));
        ref.invalidate(purchasedJourneyIdsProvider);
      }

      // Show success immediately (user has already paid via SDK validation)
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.journey.title} unlocked! 🎉'),
            duration: const Duration(seconds: 4),
            backgroundColor: AppColors.success,
          ),
        );

        // Navigate back to journey detail after brief delay
        Future.delayed(const Duration(milliseconds: 800), () {
          if (mounted) {
            Navigator.pop(context);
          }
        });
      }

      // Extract the transaction ID from the purchase response
      // For consumable purchases, find the most recent transaction for this product
      String transactionId = '';

      debugPrint(
        '🔐 [JourneyPurchase] ===== TRANSACTION EXTRACTION DEBUG =====',
      );
      debugPrint('   Looking for productId: $productId');
      debugPrint(
        '   All nonSubscriptionTransactions: ${customerInfo.nonSubscriptionTransactions.length}',
      );

      try {
        // Step 1: Log all available transactions
        for (
          int i = 0;
          i < customerInfo.nonSubscriptionTransactions.length;
          i++
        ) {
          final t = customerInfo.nonSubscriptionTransactions[i];
          debugPrint('   Transaction $i:');
          debugPrint('     - productIdentifier: ${t.productIdentifier}');
          debugPrint(
            '     - transactionIdentifier: ${t.transactionIdentifier}',
          );
          debugPrint('     - purchaseDate: ${t.purchaseDate}');
        }

        // Step 2: Filter and find matching transaction
        final matchingTransactions =
            customerInfo.nonSubscriptionTransactions.where((t) {
              final matches =
                  t.productIdentifier.toLowerCase() == productId.toLowerCase();
              debugPrint(
                '     Checking ${t.productIdentifier} (${t.productIdentifier.toLowerCase()}) against $productId (${productId.toLowerCase()}): $matches',
              );
              return matches;
            }).toList();

        debugPrint('   Matching transactions: ${matchingTransactions.length}');

        if (matchingTransactions.isEmpty) {
          debugPrint(
            '   ⚠️  NO MATCHING TRANSACTIONS FOUND FOR PRODUCT: $productId',
          );
          debugPrint(
            '   This is CRITICAL - the product must be in nonSubscriptionTransactions',
          );
        } else {
          // Step 3: Get the most recent one
          final recentTransaction = matchingTransactions.fold<StoreTransaction>(
            matchingTransactions.first,
            (latest, current) {
              final currentDate =
                  DateTime.tryParse(current.purchaseDate) ?? DateTime.now();
              final latestDate =
                  DateTime.tryParse(latest.purchaseDate) ?? DateTime.now();
              return currentDate.isAfter(latestDate) ? current : latest;
            },
          );

          transactionId = recentTransaction.transactionIdentifier;
          debugPrint('   ✅ Most recent transaction ID: $transactionId');

          if (transactionId.isEmpty) {
            debugPrint('   ⚠️  CRITICAL: transactionIdentifier is EMPTY!');
          }
        }
      } catch (e) {
        debugPrint('   ⚠️  Exception during extraction: $e');
        debugPrint('   Stack trace: ${StackTrace.current}');
      }

      // Assign to local variables for clarity and validation
      final journeyId = widget.journey.id;
      final journeyTitle = widget.journey.title;
      final packageId = productId;

      debugPrint(
        '🔐 [JourneyPurchase] ===== VALIDATION BEFORE BACKEND CALL =====',
      );
      debugPrint('   journeyId: "$journeyId" (empty: ${journeyId.isEmpty})');
      debugPrint(
        '   journeyTitle: "$journeyTitle" (empty: ${journeyTitle.isEmpty})',
      );
      debugPrint(
        '   transactionId: "$transactionId" (empty: ${transactionId.isEmpty})',
      );
      debugPrint('   packageId: "$packageId" (empty: ${packageId.isEmpty})');
      debugPrint('   userId: "$userId" (empty: ${userId.isEmpty})');

      // Validate all required fields before making backend call
      if (journeyId.isEmpty) {
        debugPrint('🔴 FATAL: journeyId is empty!');
      }

      if (journeyTitle.isEmpty) {
        debugPrint('🔴 FATAL: journeyTitle is empty!');
      }

      if (packageId.isEmpty) {
        debugPrint('🔴 FATAL: packageId is empty!');
      }

      if (transactionId.isEmpty) {
        debugPrint('🔴 FATAL: transactionId is empty! Attempting recovery...');
        // FALLBACK: Use alternative transaction identifier
        if (customerInfo.originalAppUserId.isNotEmpty) {
          transactionId =
              '${customerInfo.originalAppUserId}_${DateTime.now().millisecondsSinceEpoch}';
          debugPrint(
            '   Using generated fallback transactionId: $transactionId',
          );
        } else {
          transactionId = 'local_${DateTime.now().millisecondsSinceEpoch}';
          debugPrint(
            '   Using timestamp-based fallback transactionId: $transactionId',
          );
        }
      }

      // If any critical field is still empty, skip backend but don't block user
      if (journeyId.isEmpty || journeyTitle.isEmpty || packageId.isEmpty) {
        debugPrint(
          '🔴 CRITICAL: One or more required fields are empty - skipping backend verification',
        );
        debugPrint('   User already has access via SharedPreferences.');
      } else {
        debugPrint(
          '🟢 [JourneyPurchase] All validations passed - proceeding to backend',
        );

        // Fire background verification async (won't block user, not awaited)
        _verifyPurchaseAsync(
          journeyId: journeyId,
          journeyTitle: journeyTitle,
          transactionId: transactionId,
          packageId: packageId,
          pricePaid: journeyPackage.storeProduct.price,
          currency: journeyPackage.storeProduct.currencyCode,
          revenueCatCustomerId: customerInfo.originalAppUserId,
        );
      }
    } catch (e) {
      debugPrint(
        '🔴 [JourneyPurchase] Caught exception in purchase flow: ${e.runtimeType}: $e',
      );

      // Check if this is a timeout error (simulator issue)
      if (e is TimeoutException) {
        debugPrint(
          '🟡 [JourneyPurchase] TIMEOUT DETECTED - likely simulator issue',
        );
        if (mounted) {
          _showError('''
Purchase is taking longer than expected. This sometimes happens on the iOS simulator.

Please try:
1. Restart the simulator
2. Test on a real device if possible
3. Check your internet connection

If the issue persists, contact support.
''');
        }
        setState(() => _isPurchasing = false);
        return;
      }

      // Check if this is a configuration error (product not in App Store Connect)
      final errorStr = e.toString();
      if (errorStr.contains('code: 1') &&
          errorStr.contains('userCancelled: true')) {
        debugPrint('🔴 [JourneyPurchase] CONFIGURATION ERROR DETECTED!');
        if (mounted) {
          _showError('''
Purchase failed: Product not configured in App Store Connect.

Please verify:
1. Product IDs exist in App Store Connect (singles_journey, married_journey, divorced_journey, widowed_journey)
2. Bundle ID matches your Xcode project
3. StoreKit configuration is complete
4. RevenueCat dashboard products are synced

Contact support if the issue persists.
''');
        }
        setState(() => _isPurchasing = false);
        return;
      }

      if (mounted) _showError('Purchase failed: ${e.toString()}');
    } finally {
      if (mounted) setState(() => _isPurchasing = false);
    }
  }

  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }

  /// Verifies purchase asynchronously with backend (fire-and-forget).
  /// The Cloud Function validates with RevenueCat and writes the purchase
  /// record to Firestore (Firestore rules block direct client writes).
  void _verifyPurchaseAsync({
    required String journeyId,
    required String journeyTitle,
    required String transactionId,
    required String packageId,
    double? pricePaid,
    String? currency,
    String? revenueCatCustomerId,
  }) {
    // Fire async verification without awaiting
    Future.microtask(() async {
      try {
        debugPrint(
          '🔐 [JourneyPurchase] Async verification: Validating with backend',
        );

        await SecurePurchaseValidationService().validateAndRecordPurchase(
          journeyId: journeyId,
          journeyTitle: journeyTitle,
          transactionId: transactionId,
          packageId: packageId,
          pricePaid: pricePaid,
          currency: currency,
          revenueCatCustomerId: revenueCatCustomerId,
        );

        debugPrint('🟢 [JourneyPurchase] Backend verification successful');
        // The Cloud Function has written the purchase record to Firestore.
        // Invalidate providers so UI picks up the Firestore record.
        // ignore: use_build_context_synchronously
        if (mounted) {
          ref.invalidate(isJourneyPurchasedProvider(journeyId));
          ref.invalidate(purchasedJourneysProvider);
        }
      } catch (e) {
        debugPrint('⚠️  [JourneyPurchase] Async verification error: $e');
        // Silent fail — user already has access via SharedPreferences.
      }
    });
  }
}

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  const _Stat({required this.icon, required this.label, required this.value});
  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.getBorder(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 18),
            const SizedBox(height: 8),
            Text(
              value,
              style: AppTextStyles.titleSmall.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 2),
            Text(
              label,
              style: AppTextStyles.caption.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
