import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import '../../../../core/theme/theme.dart';
import '../../../../core/services/revenuecat_service.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../challenges/domain/journey_v1_models.dart';
import '../../../challenges/providers/journeys_providers.dart';
import '../../application/subscription_provider.dart'
    hide isJourneyPurchasedProvider;

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

  @override
  void initState() {
    super.initState();
    _loadActualPrice();
  }

  Future<void> _loadActualPrice() async {
    try {
      final offerings = await RevenueCatService.getOfferings();
      if (offerings == null || offerings.current == null) return;

      final journeyWithCategory = ref.watch(
        journeyWithCategoryProvider(widget.journey.id),
      );
      final category = journeyWithCategory?.$2 ?? 'singles';
      final productId = _getProductIdForCategory(category);

      Package? journeyPackage;
      if (offerings.current != null) {
        for (final p in offerings.current!.availablePackages) {
          if (p.storeProduct.identifier.toLowerCase() ==
              productId.toLowerCase()) {
            journeyPackage = p;
            break;
          }
        }
      }

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
        setState(() {
          _actualPrice = journeyPackage!.storeProduct.price;
        });
      }
    } catch (_) {}
  }

  String _getProductIdForCategory(String category) {
    final categoryLower = category.toLowerCase();
    const categoryToProductId = {
      'singles': 'journey_singles',
      'married': 'journey_married',
      'divorced': 'journey_divorced',
      'widowed': 'journey_widowed',
    };
    return categoryToProductId[categoryLower] ?? 'journey_singles';
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
                  Container(
                    width: 80,
                    height: 80,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.15),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white.withOpacity(0.3)),
                    ),
                    child: const Icon(
                      Icons.school_rounded,
                      color: Colors.white,
                      size: 40,
                    ),
                  ),
                  const SizedBox(height: 20),
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
            Padding(
              padding: const EdgeInsets.all(24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'About This Journey',
                    style: AppTextStyles.titleMedium.copyWith(
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 12),
                  Text(
                    sanitizeSummary(widget.journey.summary),
                    style: AppTextStyles.bodyMedium.copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.6,
                    ),
                  ),
                  const SizedBox(height: 28),
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
                  if (isPurchased)
                    InkWell(
                      onTap:
                          () => Navigator.of(
                            context,
                          ).pushNamed('/journey/${widget.journey.id}'),
                      borderRadius: BorderRadius.circular(14),
                      child: Container(
                        padding: const EdgeInsets.all(16),
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
                              size: 24,
                            ),
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
                                    'Tap to start your journey',
                                    style: AppTextStyles.bodySmall.copyWith(
                                      color: AppColors.getTextSecondary(
                                        context,
                                      ),
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
                  else
                    SizedBox(
                      width: double.infinity,
                      child: ElevatedButton(
                        onPressed:
                            _isPurchasing || isLoading ? null : _handlePurchase,
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
      final offerings = await RevenueCatService.getOfferings();
      if (offerings == null || offerings.current == null) {
        _showError('Unable to load purchase options.');
        setState(() => _isPurchasing = false);
        return;
      }
      final journeyWithCategory = ref.watch(
        journeyWithCategoryProvider(widget.journey.id),
      );
      final category = journeyWithCategory?.$2 ?? 'singles';
      final productId = _getProductIdForCategory(category);
      Package? journeyPackage;
      if (offerings.current != null) {
        for (final p in offerings.current!.availablePackages) {
          if (p.storeProduct.identifier.toLowerCase() ==
              productId.toLowerCase()) {
            journeyPackage = p;
            break;
          }
        }
      }
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
        _showError('Journey not available for purchase.');
        setState(() => _isPurchasing = false);
        return;
      }
      final actualPrice = journeyPackage.storeProduct.price;
      final priceCurrency = journeyPackage.storeProduct.currencyCode;
      final customerInfo = await RevenueCatService.purchasePackage(
        journeyPackage,
      );
      if (!mounted) return;
      if (customerInfo == null) return;
      final userId = ref.read(currentUserIdProvider);
      if (userId != null) {
        await ref
            .read(subscriptionNotifierProvider.notifier)
            .recordJourneyPurchase(
              journeyId: widget.journey.id,
              journeyTitle: widget.journey.title,
              pricePaid: actualPrice,
              currency: priceCurrency,
              revenueCatTransactionId: journeyPackage.storeProduct.identifier,
            );
      }
      ref.invalidate(purchasedJourneysProvider);
      ref.invalidate(journeyCatalogProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('${widget.journey.title} unlocked! 🎉'),
            duration: const Duration(seconds: 4),
            backgroundColor: AppColors.success,
          ),
        );
      }
    } catch (e) {
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
