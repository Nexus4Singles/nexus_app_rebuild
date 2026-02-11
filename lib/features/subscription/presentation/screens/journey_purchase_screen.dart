import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/config/revenuecat_config.dart';
import '../../../../core/services/revenuecat_service.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../challenges/domain/journey_v1_models.dart';
import '../../../challenges/providers/journeys_providers.dart';
import '../../application/subscription_provider.dart' hide isJourneyPurchasedProvider;

/// Minimal journey purchase screen - shows ONE selected journey with price & purchase button
/// Navigated to from challenges_screen when user clicks "Unlock Journey"
class JourneyPurchaseScreen extends ConsumerStatefulWidget {
  final JourneyV1 journey;

  const JourneyPurchaseScreen({super.key, required this.journey});

  @override
  ConsumerState<JourneyPurchaseScreen> createState() =>
      _JourneyPurchaseScreenState();
}

class _JourneyPurchaseScreenState extends ConsumerState<JourneyPurchaseScreen> {
  bool _isPurchasing = false;
  double _actualPrice = 0.0;

  @override
  void initState() {
    super.initState();
    // Fetch the actual price from RevenueCat when screen loads
    _loadActualPrice();
  }

  Future<void> _loadActualPrice() async {
    try {
      print('🟡 [JourneyPurchase] _loadActualPrice starting...');
      
      final offerings = await RevenueCatService.getOfferings();
      if (offerings == null || offerings.current == null) {
        print('🔴 [JourneyPurchase] No offerings available from RevenueCat');
        // If RevenueCat not available, keep price at 0 (won't show pricing card)
        return;
      }

      print('🟢 [JourneyPurchase] Offerings loaded from RevenueCat');

      // Get journey category from provider to find the right product
      final journeyWithCategory = ref.watch(
        journeyWithCategoryProvider(widget.journey.id),
      );
      final category = journeyWithCategory?.$2 ?? 'singles';
      final productId = _getProductIdForCategory(category);
      
      print('🟡 [JourneyPurchase] Looking for product: $productId (category: $category)');

      // Search for package
      Package? journeyPackage;

      // First try current offering
      if (offerings.current != null) {
        print('🟡 [JourneyPurchase] Current offering packages: ${offerings.current!.availablePackages.map((p) => p.storeProduct.identifier).toList()}');
        
        for (final p in offerings.current!.availablePackages) {
          if (p.storeProduct.identifier.toLowerCase() ==
              productId.toLowerCase()) {
            journeyPackage = p;
            print('🟢 [JourneyPurchase] Found package in current offering: ${p.storeProduct.identifier}');
            break;
          }
        }
      }

      // If not found in current, search all offerings
      if (journeyPackage == null) {
        print('🟡 [JourneyPurchase] Not in current, searching all offerings...');
        for (final offering in offerings.all.values) {
          for (final p in offering.availablePackages) {
            if (p.storeProduct.identifier.toLowerCase() ==
                productId.toLowerCase()) {
              journeyPackage = p;
              print('🟢 [JourneyPurchase] Found package in offering: ${p.storeProduct.identifier}');
              break;
            }
          }
          if (journeyPackage != null) break;
        }
      }

      if (journeyPackage != null && mounted) {
        print('🟢 [JourneyPurchase] Setting price to: ${journeyPackage.storeProduct.price}');
        setState(() {
          _actualPrice = journeyPackage!.storeProduct.price;
        });
      } else {
        print('🔴 [JourneyPurchase] Package not found for productId: $productId');
      }
      // If package not found, price remains 0 and pricing card won't show
    } catch (e) {
      print('🔴 [JourneyPurchase] Error loading price: $e');
      // If error occurs, price remains 0 and pricing card won't show
    }
  }

  /// Maps journey category to RevenueCat product ID
  String _getProductIdForCategory(String category) {
    final categoryLower = category.toLowerCase();

    const categoryToProductId = {
      'singles': 'journey_singles',
      'married': 'journey_married',
      'divorced': 'journey_divorced',
      'widowed': 'journey_widowed',
    };

    return categoryToProductId[categoryLower] ??
        'journey_singles'; // Default to singles
  }

  @override
  Widget build(BuildContext context) {
    // Check if journey is already purchased
    final isPurchasedAsync = ref.watch(isJourneyPurchasedProvider(widget.journey.id));
    
    return isPurchasedAsync.when(
      loading: () => _buildScaffold(
        context,
        isPurchased: false,
        isLoading: true,
      ),
      error: (_, __) => _buildScaffold(
        context,
        isPurchased: false,
        isLoading: false,
      ),
      data: (isPurchased) => _buildScaffold(
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
    // Note: priceNGN is fetched from RevenueCat and stored in _actualPrice
    // during the purchase flow. Display price will come from the package.
    final priceNGN = _actualPrice.toInt();

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
        title: const Text('Unlock Journey'),
      ),
      body: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Hero Header
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
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
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Journey icon
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),

                  // Title and subtitle
                  Text(
                    widget.journey.title,
                    style: AppTextStyles.headlineMedium.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    widget.journey.subtitle,
                    style: AppTextStyles.bodyLarge.copyWith(
                      color: Colors.white.withOpacity(0.9),
                    ),
                  ),
                ],
              ),
            ),

            // Content
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Summary
                  Text(
                    'About This Journey',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    widget.journey.summary,
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),

                  // Quick facts
                  Row(
                    children: [
                      _Stat(
                        icon: Icons.layers_outlined,
                        label: 'Sessions',
                        value: '${widget.journey.missions.length}',
                      ),
                      const SizedBox(width: 16),
                      _Stat(
                        icon: Icons.timer_outlined,
                        label: 'Duration',
                        value:
                            '${(widget.journey.missions.fold<int>(0, (sum, m) => sum + m.timeBoxMinutes) / 60).ceil()} Hours',
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Pricing Card (only show if price was loaded from RevenueCat)
                  if (_actualPrice > 0)
                    Container(
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: AppColors.getSurface(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.getBorder(context)),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'One-Time Purchase',
                            style: AppTextStyles.labelMedium.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.baseline,
                            textBaseline: TextBaseline.alphabetic,
                            children: [
                              Text(
                                '₦',
                                style: AppTextStyles.titleSmall.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              Text(
                                priceNGN.toString(),
                                style: AppTextStyles.headlineMedium.copyWith(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'NGN',
                                style: AppTextStyles.bodyMedium.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Full access to all sessions',
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),

                  const SizedBox(height: 32),

                  // Purchase Button or Purchased Status
                  if (isPurchased)
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: Colors.green.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(14),
                        border: Border.all(color: Colors.green.withOpacity(0.3)),
                      ),
                      child: Row(
                        children: [
                          Icon(Icons.check_circle, color: Colors.green, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
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
                                  'You have access to all sessions',
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    )
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed: _isPurchasing || isLoading ? null : _handlePurchase,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.primary,
                          foregroundColor: Colors.white,
                          padding: const EdgeInsets.symmetric(vertical: 16),
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
                                : const Text(
                                  'Purchase Journey',
                                  style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                      ),
                    ),

                  const SizedBox(height: 16),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _handlePurchase() async {
    setState(() => _isPurchasing = true);

    try {
      // Get offerings from RevenueCat
      final offerings = await RevenueCatService.getOfferings();

      if (offerings == null || offerings.current == null) {
        _showError(
          'Unable to load purchase options. RevenueCat offerings not configured. Please check your RevenueCat dashboard.',
        );
        setState(() => _isPurchasing = false);
        return;
      }

      // Get journey category from provider
      final journeyWithCategory = ref.watch(
        journeyWithCategoryProvider(widget.journey.id),
      );
      final category = journeyWithCategory?.$2 ?? 'singles';

      // Get the product ID based on journey category
      final productId = _getProductIdForCategory(category);

      // Search for package in all offerings (not just current)
      Package? journeyPackage;

      // First try current offering if it exists
      if (offerings.current != null) {
        for (final p in offerings.current!.availablePackages) {
          if (p.storeProduct.identifier.toLowerCase() ==
              productId.toLowerCase()) {
            journeyPackage = p;
            break;
          }
        }
      }

      // If not found in current, search all offerings
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

      if (journeyPackage == null) {
        _showError(
          'Journey for $category (product: $productId) is not available for purchase. Please check RevenueCat dashboard.',
        );
        setState(() => _isPurchasing = false);
        return;
      }

      // Extract actual price from the package
      final actualPrice = journeyPackage.storeProduct.price;
      final priceCurrency = journeyPackage.storeProduct.currencyCode;
      
      print('🟡 [JourneyPurchase] Package details:');
      print('   - Product ID: ${journeyPackage.storeProduct.identifier}');
      print('   - Price: $actualPrice');
      print('   - Currency: $priceCurrency');
      print('   - Category: $category');
      
      await RevenueCatService.purchasePackage(journeyPackage);

      if (!mounted) return;

      print('🟢 [JourneyPurchase] Purchase completed, now recording to Firestore...');
      
      // Record journey purchase in Firestore with actual price paid
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        print('🟡 [JourneyPurchase] Recording purchase with:');
        print('   - journeyId: ${widget.journey.id}');
        print('   - pricePaid: $actualPrice');
        print('   - currency: $priceCurrency');
        
        await ref
            .read(subscriptionNotifierProvider.notifier)
            .recordJourneyPurchase(
              journeyId: widget.journey.id,
              journeyTitle: widget.journey.title,
              pricePaid: actualPrice,
              currency: priceCurrency,
              revenueCatTransactionId: journeyPackage.storeProduct.identifier,
            );
        
        print('🟢 [JourneyPurchase] Successfully recorded to Firestore');
      } else {
        print('🔴 [JourneyPurchase] ERROR: userId is null');
      }

      // Invalidate the purchased journeys provider to refresh UI immediately
      ref.invalidate(purchasedJourneysProvider);

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('${widget.journey.title} unlocked! 🎉'),
          backgroundColor: Colors.green,
        ),
      );

      if (mounted) {
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        _showError('Purchase failed: ${e.toString()}');
      }
    } finally {
      if (mounted) {
        setState(() => _isPurchasing = false);
      }
    }
  }
  void _showError(String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// ============================================================================
// STAT WIDGET
// ============================================================================

class _Stat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _Stat({required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppColors.getBorder(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: AppColors.primary, size: 20),
            const SizedBox(height: 10),
            Text(
              value,
              style: AppTextStyles.labelLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 4),
            Text(
              label,
              style: AppTextStyles.labelSmall.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
