import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';

import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/constants/app_constants.dart';
import 'package:nexus_app_v2/core/session/effective_relationship_status_provider.dart';
import 'package:nexus_app_v2/core/providers/tab_selection_provider.dart';
import 'package:nexus_app_v2/core/config/revenuecat_config.dart';
import 'package:nexus_app_v2/core/services/revenuecat_service.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import 'package:nexus_app_v2/features/subscription/application/subscription_provider.dart';
import 'package:nexus_app_v2/features/subscription/domain/subscription_models.dart';
import 'package:nexus_app_v2/features/challenges/presentation/screens/journey_detail_screen.dart';
import 'package:nexus_app_v2/features/challenges/providers/journeys_providers.dart';

// Note: Using journeyByIdProvider from journeys_providers.dart (cloud-first with fallback)
// This replaces the old local repository-based loading

class SubscriptionScreen extends ConsumerStatefulWidget {
  /// Optional: set initial tab index (0 = Dating Features, 1 = Journey Purchases)
  final int? initialTabIndex;

  const SubscriptionScreen({super.key, this.initialTabIndex});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 2,
      vsync: this,
      initialIndex: widget.initialTabIndex ?? 0,
    );
    print('🟢 [SubscriptionScreen] initState called - TabController created');
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final subscriptionAsync = ref.watch(subscriptionStatusProvider);
    final purchasedJourneysAsync = ref.watch(purchasedJourneysProvider);
    final relationshipStatus = ref.watch(effectiveRelationshipStatusProvider);

    // Debug: Check userId being watched
    final userId = ref.watch(currentUserIdProvider);
    print('🟢 [SubscriptionScreen] BUILD called');
    print('🟢 [SubscriptionScreen] userId=$userId');
    print('🟢 [SubscriptionScreen] relationshipStatus=$relationshipStatus');

    // Log states for debugging
    subscriptionAsync.whenData((sub) {});

    purchasedJourneysAsync.whenData((journeys) {});

    // Married users should only see Journey Purchases tab
    final isMarried = relationshipStatus == RelationshipStatus.married;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      body: CustomScrollView(
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              icon: const Icon(
                Icons.arrow_back_ios_new_rounded,
                color: Colors.white,
              ),
              onPressed: () => Navigator.pop(context),
            ),
            flexibleSpace: FlexibleSpaceBar(
              title: Text(
                isMarried ? 'Journey Purchases' : 'Subscriptions',
                style: AppTextStyles.titleLarge.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
              background: Container(
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
                child: Stack(
                  children: [
                    Positioned(
                      top: 0,
                      right: -50,
                      child: Icon(
                        Icons.workspace_premium,
                        size: 140,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    Positioned(
                      bottom: 5,
                      left: 10,
                      child: Icon(
                        Icons.star,
                        size: 40,
                        color: Colors.amber.withOpacity(0.2),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab Bar (hide for married users)
          if (!isMarried)
            SliverPersistentHeader(
              pinned: true,
              delegate: _SliverAppBarDelegate(
                TabBar(
                  controller: _tabController,
                  labelColor: AppColors.primary,
                  unselectedLabelColor: AppColors.textMuted,
                  indicatorColor: AppColors.primary,
                  indicatorWeight: 3,
                  labelStyle: AppTextStyles.labelLarge.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                  tabs: const [
                    Tab(text: 'Dating Features'),
                    Tab(text: 'Journey Purchases'),
                  ],
                ),
              ),
            ),

          // Content
          SliverFillRemaining(
            child:
                isMarried
                    ? purchasedJourneysAsync.when(
                      data: (journeys) {
                        return _JourneyPurchasesTab(journeys: journeys);
                      },
                      loading: () {
                        return const Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              CircularProgressIndicator(),
                              SizedBox(height: 16),
                              Text('Loading purchased journeys...'),
                            ],
                          ),
                        );
                      },
                      error: (error, stackTrace) {
                        return Center(
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(
                                  Icons.error_outline,
                                  size: 64,
                                  color: Colors.red,
                                ),
                                const SizedBox(height: 16),
                                Text(
                                  'Error loading journeys: $error',
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(color: Colors.red),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                    : TabBarView(
                      controller: _tabController,
                      children: [
                        // Dating Subscription Tab
                        subscriptionAsync.when(
                          data:
                              (subscription) => _DatingSubscriptionTab(
                                subscription: subscription,
                              ),
                          loading:
                              () => const Center(
                                child: CircularProgressIndicator(),
                              ),
                          error:
                              (error, _) =>
                                  Center(child: Text('Error: $error')),
                        ),

                        // Journey Purchases Tab
                        purchasedJourneysAsync.when(
                          data: (journeys) {
                            return _JourneyPurchasesTab(journeys: journeys);
                          },
                          loading: () {
                            return const Center(
                              child: Column(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  CircularProgressIndicator(),
                                  SizedBox(height: 16),
                                  Text('Loading purchased journeys...'),
                                ],
                              ),
                            );
                          },
                          error: (error, stackTrace) {
                            return Center(
                              child: Padding(
                                padding: const EdgeInsets.all(20),
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    const Icon(
                                      Icons.error_outline,
                                      size: 64,
                                      color: Colors.red,
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'Error loading journeys: $error',
                                      textAlign: TextAlign.center,
                                      style: const TextStyle(color: Colors.red),
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                      ],
                    ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// DATING SUBSCRIPTION TAB
// ============================================================================

class _DatingSubscriptionTab extends ConsumerWidget {
  final SubscriptionStatus subscription;

  const _DatingSubscriptionTab({required this.subscription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (subscription.isActive && !subscription.isExpired) {
      return _ActiveSubscriptionView(subscription: subscription);
    } else {
      return const _NoSubscriptionView();
    }
  }
}

// Active Subscription View
class _ActiveSubscriptionView extends ConsumerWidget {
  final SubscriptionStatus subscription;

  const _ActiveSubscriptionView({required this.subscription});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final daysLeft = subscription.daysUntilExpiry;
    final expiryDate = subscription.expiryDate;

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Badge Card (compact horizontal layout)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    size: 40,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium Active',
                        style: AppTextStyles.titleLarge.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subscription.tier.displayName,
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white.withOpacity(0.9),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            const Icon(
                              Icons.check_circle,
                              color: Colors.white,
                              size: 14,
                            ),
                            const SizedBox(width: 6),
                            Text(
                              expiryDate != null
                                  ? 'Expires: ${DateFormat.yMMMd().format(expiryDate)}'
                                  : 'Active',
                              style: AppTextStyles.caption.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
                if (daysLeft > 0 && daysLeft <= 7)
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 10,
                      vertical: 6,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.amber,
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      '$daysLeft d',
                      style: AppTextStyles.caption.copyWith(
                        color: Colors.black87,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
              ],
            ),
          ),

          const SizedBox(height: 28),

          // Features Section
          Text(
            'Your Premium Features',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          ...PremiumFeatures.allFeatures.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FeatureTile(feature: feature, isActive: true),
            ),
          ),

          const SizedBox(height: 28),

          // Manage Subscription
          Text(
            'Manage Subscription',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),
          _CancelAutoRenewalButton(),
        ],
      ),
    );
  }
}

// No Subscription View
class _NoSubscriptionView extends ConsumerWidget {
  const _NoSubscriptionView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Card (compact horizontal layout)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium,
                    size: 32,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unlock Premium Features',
                        style: AppTextStyles.titleMedium.copyWith(
                          color: AppColors.getTextPrimary(context),
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        'Get unlimited access to all dating features',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Features List
          Text(
            'What You Get',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          ...PremiumFeatures.allFeatures.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FeatureTile(feature: feature, isActive: false),
            ),
          ),

          const SizedBox(height: 32),

          // Subscription Plans
          Text(
            'Activate Your Subscription',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _SubscriptionPlanCard(
            tier: SubscriptionTier.monthly,
            onSubscribePressed: () {
              _handleSubscriptionPurchase(context, ref);
            },
          ),

          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.getBorder(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'This subscription will auto-renew. Cancel anytime from your Playstore or Appstore subscription settings.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                      height: 1.4,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleSubscriptionPurchase(
    BuildContext context,
    WidgetRef ref,
  ) async {
    try {
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Get offerings from RevenueCat
      final offerings = await RevenueCatService.getOfferings();

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      if (offerings == null || offerings.current == null) {
        _showError(
          context,
          'Unable to load subscription options. Please try again.',
        );
        return;
      }

      // Find the monthly subscription package
      final packages = offerings.current!.availablePackages;
      final monthlyPackage = packages.firstWhere(
        (p) => p.storeProduct.identifier.toLowerCase().contains(
          RevenueCatConfig.subscriptionMonthlyId.toLowerCase(),
        ),
        orElse: () => packages.first,
      );

      // Show loading again during purchase
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Make purchase
      final customerInfo = await RevenueCatService.purchasePackage(
        monthlyPackage,
      );

      if (!context.mounted) return;
      Navigator.pop(context); // Close loading dialog

      // If `customerInfo` is null, the user cancelled the native purchase
      // sheet. Treat this as a non-error and simply return.
      if (customerInfo == null) {
        return;
      }

      // Record purchase in Firestore
      await ref
          .read(subscriptionNotifierProvider.notifier)
          .updateSubscription(isActive: true, tier: SubscriptionTier.monthly);

      if (!context.mounted) return;

      // Show success snackbar and notify restart
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: const Text(
            'Subscription unlocked! 🎉 Restarting app to activate your subscription...',
          ),
          duration: const Duration(seconds: 3),
          backgroundColor: Colors.green,
        ),
      );

      // Schedule app restart after brief delay to let snackbar display
      Future.delayed(const Duration(seconds: 2), () {
        // Exit app - OS will automatically relaunch it
        SystemNavigator.pop();
      });
    } catch (e) {
      if (context.mounted) {
        final navigator = Navigator.of(context);
        if (navigator.canPop()) {
          navigator.pop();
        }
      }
      _showError(context, 'Purchase failed: ${e.toString()}');
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: Colors.red),
    );
  }
}

// ============================================================================
// JOURNEY PURCHASES TAB
// ============================================================================

class _JourneyPurchasesTab extends StatelessWidget {
  final List<PurchasedJourney> journeys;

  const _JourneyPurchasesTab({required this.journeys});

  @override
  Widget build(BuildContext context) {
    if (journeys.isEmpty) {
      return const _EmptyJourneysView();
    }

    return ListView.separated(
      padding: const EdgeInsets.all(20),
      itemCount: journeys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 12),
      itemBuilder: (context, index) {
        return _JourneyPurchaseCard(journey: journeys[index]);
      },
    );
  }
}

// Empty Journeys View
class _EmptyJourneysView extends ConsumerWidget {
  const _EmptyJourneysView();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(28),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                shape: BoxShape.circle,
                border: Border.all(
                  color: AppColors.getBorder(context),
                  width: 2,
                ),
              ),
              child: Icon(
                Icons.school_outlined,
                size: 64,
                color: AppColors.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Active Journeys',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Purchase journeys to boost your knowledge about relationships and marriages.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () {
                Navigator.pop(context);
                // Navigate to challenges/journeys Tab
                ref.read(selectedTabProvider.notifier).state =
                    NavTab.challenges;
              },
              icon: const Icon(Icons.explore),
              label: const Text('Explore Journeys'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                side: BorderSide(color: AppColors.primary),
                foregroundColor: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// WIDGETS
// ============================================================================

// Feature Tile
class _FeatureTile extends StatelessWidget {
  final PremiumFeature feature;
  final bool isActive;

  const _FeatureTile({required this.feature, required this.isActive});

  IconData _getIcon() {
    switch (feature.icon) {
      case 'chat_bubble_outline':
        return Icons.chat_bubble_outline;
      case 'favorite':
        return Icons.favorite;
      case 'contact_page':
        return Icons.contact_page;
      default:
        return Icons.star;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color:
            isActive
                ? AppColors.primary.withOpacity(0.05)
                : AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color:
              isActive ? AppColors.primary.withOpacity(0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color:
                  isActive
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(
              _getIcon(),
              color: isActive ? Colors.white : AppColors.primary,
              size: 24,
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  feature.description,
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                    height: 1.3,
                  ),
                ),
              ],
            ),
          ),
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.success,
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                'Active',
                style: AppTextStyles.caption.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

// Subscription Plan Card - fetches price from RevenueCat
class _SubscriptionPlanCard extends ConsumerStatefulWidget {
  final SubscriptionTier tier;
  final VoidCallback? onSubscribePressed;

  const _SubscriptionPlanCard({required this.tier, this.onSubscribePressed});

  @override
  ConsumerState<_SubscriptionPlanCard> createState() =>
      _SubscriptionPlanCardState();
}

class _SubscriptionPlanCardState extends ConsumerState<_SubscriptionPlanCard> {
  String _monthlyPrice = '';
  bool _isLoadingPrice = true;

  @override
  void initState() {
    super.initState();
    _loadMonthlyPrice();
  }

  Future<void> _loadMonthlyPrice() async {
    try {
      print('🟡 [SubscriptionCard] Loading monthly price from RevenueCat...');

      final offerings = await RevenueCatService.getOfferings();
      if (offerings == null || offerings.current == null) {
        print('🔴 [SubscriptionCard] No offerings available');
        if (mounted) {
          setState(() => _isLoadingPrice = false);
        }
        return;
      }

      // Find the monthly subscription package
      final packages = offerings.current!.availablePackages;
      print(
        '🟡 [SubscriptionCard] Available packages: ${packages.map((p) => p.storeProduct.identifier).toList()}',
      );

      Package? monthlyPackage;

      // Try 1: Match 'monthly' pattern (e.g., $rc_monthly, nexus_monthly_premium)
      for (final p in packages) {
        if (p.storeProduct.identifier.toLowerCase().contains('monthly')) {
          monthlyPackage = p;
          print(
            '🟢 [SubscriptionCard] Found monthly package: ${p.storeProduct.identifier}',
          );
          break;
        }
      }

      // Try 2: If not found, take first package as fallback
      if (monthlyPackage == null && packages.isNotEmpty) {
        monthlyPackage = packages.first;
        print(
          '🟡 [SubscriptionCard] No "monthly" match found, using first package: ${monthlyPackage.storeProduct.identifier}',
        );
      }

      if (monthlyPackage != null && mounted) {
        print(
          '🟢 [SubscriptionCard] Setting price: ${monthlyPackage.storeProduct.priceString} (currency: ${monthlyPackage.storeProduct.currencyCode})',
        );
        setState(() {
          _monthlyPrice = monthlyPackage!.storeProduct.priceString;
          _isLoadingPrice = false;
        });
      } else if (mounted) {
        print('🔴 [SubscriptionCard] No package found, showing fallback');
        setState(() => _isLoadingPrice = false);
      }
    } catch (e) {
      print('🔴 [SubscriptionCard] Error loading price: $e');
      if (mounted) {
        setState(() => _isLoadingPrice = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        widget.tier.displayName,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      // Show price loaded from store/RevenueCat
                      if (_isLoadingPrice)
                        SizedBox(
                          width: 60,
                          height: 16,
                          child: Container(
                            decoration: BoxDecoration(
                              color: AppColors.getTextSecondary(
                                context,
                              ).withOpacity(0.2),
                              borderRadius: BorderRadius.circular(4),
                            ),
                          ),
                        )
                      else if (_monthlyPrice.isNotEmpty)
                        Text(
                          _monthlyPrice,
                          style: AppTextStyles.titleMedium.copyWith(
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        )
                      else
                        Text(
                          'Price from store',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                          ),
                        ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ElevatedButton(
              onPressed: () async {
                if (widget.onSubscribePressed != null) {
                  widget.onSubscribePressed!();
                }
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Subscribe Now',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: Colors.white,
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// Journey Purchase Card
class _JourneyPurchaseCard extends ConsumerWidget {
  final PurchasedJourney journey;

  const _JourneyPurchaseCard({required this.journey});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final journey = ref.watch(journeyByIdProvider(this.journey.journeyId));

    return InkWell(
      onTap: () {
        if (journey != null) {
          // Navigate to journey detail screen (will fetch via cloud-first journeyByIdProvider)
          Navigator.push(
            context,
            MaterialPageRoute(
              builder:
                  (context) => JourneyDetailScreen(id: this.journey.journeyId),
            ),
          );
        }
      },
      borderRadius: BorderRadius.circular(16),
      child: _buildCard(context),
    );
  }

  Widget _buildCard(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(Icons.school, color: AppColors.primary, size: 24),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journey.journeyTitle,
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Purchased ${DateFormat.yMMMd().format(journey.purchaseDate)}',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color:
                      journey.isActive
                          ? AppColors.success.withOpacity(0.1)
                          : AppColors.error.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  journey.isActive ? 'Active' : 'Expired',
                  style: AppTextStyles.caption.copyWith(
                    color:
                        journey.isActive ? AppColors.success : AppColors.error,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppColors.getBackground(context),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amount Paid',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                Text(
                  '${journey.currency} ${journey.pricePaid.toStringAsFixed(2)}',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// Cancel Auto-Renewal Button
class _CancelAutoRenewalButton extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ElevatedButton.icon(
      onPressed: () async {
        try {
          // Open native subscription management UI (iOS: App Store, Android: Google Play)
          // Users must manage subscriptions through the app store's native UI
          await RevenueCatService.manageSubscriptions();
        } catch (e) {
          if (context.mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text('Error opening subscription settings: $e'),
                backgroundColor: Colors.red,
              ),
            );
          }
        }
      },
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.error.withOpacity(0.1),
        foregroundColor: AppColors.error,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 12),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        side: BorderSide(color: AppColors.error.withOpacity(0.3)),
      ),
      icon: const Icon(Icons.settings_outlined),
      label: const Text('Manage Subscription'),
    );
  }
}

// ============================================================================
// HELPER CLASSES
// ============================================================================

class _SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  _SliverAppBarDelegate(this._tabBar);

  final TabBar _tabBar;

  @override
  double get minExtent => _tabBar.preferredSize.height;
  @override
  double get maxExtent => _tabBar.preferredSize.height;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return Container(color: AppColors.background, child: _tabBar);
  }

  @override
  bool shouldRebuild(_SliverAppBarDelegate oldDelegate) {
    return false;
  }
}
