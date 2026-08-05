import 'dart:async';
import 'dart:convert';
import 'dart:io' show Platform;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';
import 'package:purchases_flutter/purchases_flutter.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:http/http.dart' as http;

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
import 'package:nexus_app_v2/core/services/secure_purchase_validation_service.dart';
import 'package:url_launcher/url_launcher.dart';

// Note: Using journeyByIdProvider from journeys_providers.dart (cloud-first with fallback)
// This replaces the old local repository-based loading

// Extension for safer list operations
extension NullableFirstWhere<T> on List<T> {
  T? firstWhereOrNull(bool Function(T) test) {
    try {
      return firstWhere(test);
    } catch (e) {
      return null;
    }
  }
}

const _subscriptionPaymentLinkFunctionUrl =
    'https://us-central1-nexus-visibility-app.cloudfunctions.net/createSubscriptionPaymentLink';

const _showPayOnlineFallback = true;

Future<void> _launchBankTransferUrl(BuildContext context) async {
  final currentUser = FirebaseAuth.instance.currentUser;
  if (currentUser == null) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please sign in to start bank transfer payment.'),
        ),
      );
    }
    return;
  }
  showDialog(
    context: context,
    barrierDismissible: false,
    builder: (context) => const Center(child: CircularProgressIndicator()),
  );

  try {
    final idToken = await currentUser.getIdToken(true);

    final response = await http
        .post(
          Uri.parse(_subscriptionPaymentLinkFunctionUrl),
          headers: {
            'Content-Type': 'application/json',
            'Authorization': 'Bearer $idToken',
          },
          body: jsonEncode({'uid': currentUser.uid}),
        )
        .timeout(
          const Duration(seconds: 20),
          onTimeout:
              () =>
                  throw TimeoutException(
                    'Payment link request timed out. Please check your internet connection and try again.',
                  ),
        );

    if (response.statusCode != 200) {
      final errorMessage =
          response.body.isNotEmpty
              ? response.body
              : 'Unable to create payment link';
      throw Exception(errorMessage);
    }

    final data = jsonDecode(response.body) as Map<String, dynamic>;
    final paymentUrl = data['paymentUrl'] as String?;
    if (paymentUrl == null || paymentUrl.isEmpty) {
      throw Exception('Payment link response was invalid');
    }

    final uri = Uri.parse(paymentUrl);
    Navigator.pop(context);

    final launchedInApp = await launchUrl(uri, mode: LaunchMode.inAppWebView);
    if (launchedInApp) return;

    final launchedExternal = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );

    if (!launchedExternal && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Unable to open the payment link. Please try again.'),
        ),
      );
    }
  } catch (error) {
    if (context.mounted) {
      final navigator = Navigator.of(context);
      if (navigator.canPop()) navigator.pop();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Bank transfer failed: ${error.toString()}'),
          backgroundColor: AppColors.primary,
        ),
      );
    }
  }
}

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
      // EARLY ACCESS: Journey Purchases tab removed — length reduced to 1
      length: 1,
      vsync: this,
      initialIndex: 0,
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
            expandedHeight: 200,
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
              titlePadding: const EdgeInsets.only(left: 20, bottom: 20),
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
                      top: -10,
                      right: -50,
                      child: Icon(
                        Icons.workspace_premium,
                        size: 200,
                        color: Colors.white.withOpacity(0.08),
                      ),
                    ),
                    Positioned(
                      bottom: 50,
                      left: 10,
                      child: Icon(
                        Icons.star,
                        size: 55,
                        color: Colors.amber.withOpacity(0.2),
                      ),
                    ),
                    Positioned(
                      top: 60,
                      left: 20,
                      child: Icon(
                        Icons.star,
                        size: 28,
                        color: Colors.amber.withOpacity(0.12),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // EARLY ACCESS: Journey Purchases tab removed — tab bar hidden
          // Tab bar will be re-enabled when Journey Purchases tab is restored
          // if (!isMarried)
          //   SliverPersistentHeader(
          //     pinned: true,
          //     delegate: _SliverAppBarDelegate(
          //       TabBar(
          //         controller: _tabController,
          //         labelColor: AppColors.primary,
          //         unselectedLabelColor: AppColors.textMuted,
          //         indicatorColor: AppColors.primary,
          //         indicatorWeight: 3,
          //         labelStyle: AppTextStyles.labelLarge.copyWith(
          //           fontWeight: FontWeight.bold,
          //         ),
          //         tabs: const [
          //           Tab(text: 'Dating Features'),
          //           Tab(text: 'Journey Purchases'),
          //         ],
          //       ),
          //     ),
          //   ),

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
                                  style: AppTextStyles.bodySmall.copyWith(
                                    color: Colors.red,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                    // EARLY ACCESS: Journey Purchases tab removed — show Subscriptions content directly (centred)
                    // When Journey Purchases tab is restored, replace the block below with the original TabBarView
                    : subscriptionAsync.when(
                      data:
                          (subscription) => _DatingSubscriptionTab(
                            subscription: subscription,
                          ),
                      loading:
                          () =>
                              const Center(child: CircularProgressIndicator()),
                      error: (error, _) => Center(child: Text('Error: $error')),
                    ),
            // EARLY ACCESS: Original TabBarView commented out below
            // : TabBarView(
            //   controller: _tabController,
            //   children: [
            //     // Dating Subscription Tab
            //     subscriptionAsync.when(
            //       data:
            //           (subscription) => _DatingSubscriptionTab(
            //             subscription: subscription,
            //           ),
            //       loading:
            //           () => const Center(
            //             child: CircularProgressIndicator(),
            //           ),
            //       error:
            //           (error, _) =>
            //               Center(child: Text('Error: $error')),
            //     ),
            //     // Journey Purchases Tab
            //     purchasedJourneysAsync.when(
            //       data: (journeys) {
            //         return _JourneyPurchasesTab(journeys: journeys);
            //       },
            //       loading: () {
            //         return const Center(
            //           child: Column(
            //             mainAxisAlignment: MainAxisAlignment.center,
            //             children: [
            //               CircularProgressIndicator(),
            //               SizedBox(height: 16),
            //               Text('Loading purchased journeys...'),
            //             ],
            //           ),
            //         );
            //       },
            //       error: (error, stackTrace) {
            //         return Center(
            //           child: Padding(
            //             padding: const EdgeInsets.all(20),
            //             child: Column(
            //               mainAxisAlignment: MainAxisAlignment.center,
            //               children: [
            //                 const Icon(
            //                   Icons.error_outline,
            //                   size: 64,
            //                   color: Colors.red,
            //                 ),
            //                 const SizedBox(height: 16),
            //                 Text(
            //                   'Error loading journeys: $error',
            //                   textAlign: TextAlign.center,
            //                   style: AppTextStyles.bodySmall.copyWith(
            //                     color: Colors.red,
            //                   ),
            //                 ),
            //               ],
            //             ),
            //           ),
            //         );
            //       },
            //     ),
            //   ],
            // ),
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Badge Card (compact horizontal layout)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                colors: [AppColors.primary, AppColors.primary.withOpacity(0.7)],
              ),
              borderRadius: BorderRadius.circular(16),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.3),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    size: 28,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Premium Active',
                        style: AppTextStyles.titleMedium.copyWith(
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

          const SizedBox(height: 20),

          // Features Section
          Text(
            'Your Premium Features',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          ...PremiumFeatures.allFeatures.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FeatureTile(feature: feature, isActive: true),
            ),
          ),

          const SizedBox(height: 20),

          // Manage Subscription
          Text(
            'Manage Subscription',
            style: AppTextStyles.titleSmall.copyWith(
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
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Card (compact horizontal layout)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppColors.primary.withOpacity(0.1),
                  AppColors.primary.withOpacity(0.05),
                ],
              ),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: AppColors.primary.withOpacity(0.3),
                width: 1.5,
              ),
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium,
                    size: 28,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Unlock Premium Features',
                        style: AppTextStyles.titleSmall.copyWith(
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

          const SizedBox(height: 16),

          // Features List
          Text(
            'What You Get',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          ...PremiumFeatures.allFeatures.map(
            (feature) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _FeatureTile(feature: feature, isActive: false),
            ),
          ),

          const SizedBox(height: 24),

          // Subscription Plans
          Text(
            'Activate Your Subscription',
            style: AppTextStyles.titleMedium.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 12),

          _SubscriptionPlanCard(
            tier: SubscriptionTier.monthly,
            onSubscribePressed: () {
              _handleSubscriptionPurchase(context, ref);
            },
          ),

          const SizedBox(height: 24),

          // Info
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.getSurface(context),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.getBorder(context)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (_showPayOnlineFallback) ...[
                        Text(
                          'If you have trouble subscribing through Playstore/Appstore, you can subscribe via card or bank transfer using the button below.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                            height: 1.6,
                          ),
                        ),
                        const SizedBox(height: 12),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () => _launchBankTransferUrl(context),
                            icon: const Icon(Icons.open_in_new, size: 18),
                            label: Text(
                              'Pay Online',
                              style: AppTextStyles.bodySmall.copyWith(
                                color: AppColors.primary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            style: OutlinedButton.styleFrom(
                              padding: const EdgeInsets.symmetric(
                                vertical: 14,
                                horizontal: 16,
                              ),
                              side: BorderSide(color: AppColors.primary),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(height: 12),
                        Text.rich(
                          TextSpan(
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextSecondary(context),
                              height: 1.6,
                            ),
                            children: [
                              const TextSpan(
                                text:
                                    'If your subscription is not activated after payment, kindly reach out to us by sending proof of payment to ',
                              ),
                              TextSpan(
                                text: 'contact@nexus4christians.com',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(text: ' or '),
                              TextSpan(
                                text: '@nexus4christians',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                              const TextSpan(
                                text:
                                    ' on Instagram and your subscription will be activated.',
                              ),
                            ],
                          ),
                        ),
                      ] else ...[
                        Text(
                          'This subscription will auto-renew. Cancel anytime from your Playstore or Appstore subscription settings.',
                          style: AppTextStyles.bodySmall.copyWith(
                            color: AppColors.getTextSecondary(context),
                            height: 1.4,
                          ),
                        ),
                      ],
                    ],
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
    // Capture current Firebase UID so it is available in catch blocks.
    final firebaseUid = ref.read(currentUserIdProvider);

    try {
      // NOTE: Do not block purchases when `firebaseUid` is null here.
      // There are legitimate race conditions where RevenueCat may receive
      // the purchase before the client has fully linked the Firebase UID.
      // We still attempt to link and sync after purchase; the server-side
      // webhook will reconcile anonymous App User IDs to Firebase users
      // where possible. For UX, allow the purchase to proceed.
      if (firebaseUid == null) {
        debugPrint(
          '🟡 [Subscription] Warning: firebaseUid is null at purchase time (may be auth race). Proceeding.',
        );
      }
      // Show loading dialog
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      debugPrint('🔵 [Subscription] Fetching RevenueCat offerings...');
      final offerings = await RevenueCatService.getOfferings();

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      if (offerings == null) {
        debugPrint(
          '🔴 [Subscription] offerings is NULL - RevenueCat SDK error',
        );
        _showError(
          context,
          'Unable to load subscription options from store. Please ensure:\n'
          '1. App has internet connection\n'
          '2. RevenueCat is configured in the store\n'
          '3. Subscription products exist in App Store/Play Store\n\n'
          'Try again or contact support if issue persists.',
        );
        return;
      }

      // Get the specific subscription offering based on the RevenueCat offering ID.
      // The offering ID in RevenueCat is configured as `nexus_premium_v2`.
      final preferredOfferingIds = [
        RevenueCatConfig.subscriptionOfferingId,
        'monthly_premium_v2',
        'Premium',
      ];

      Offering? subscriptionOffering;
      for (final offeringId in preferredOfferingIds) {
        subscriptionOffering = offerings.getOffering(offeringId);
        if (subscriptionOffering != null) {
          debugPrint('🟢 [Subscription] Found offering by id: $offeringId');
          break;
        }
      }

      if (subscriptionOffering == null) {
        debugPrint(
          '🟡 [Subscription] preferred offering IDs not available, trying offerings.current',
        );
        subscriptionOffering = offerings.current;
      }

      if (subscriptionOffering == null && Platform.isAndroid) {
        debugPrint(
          '🟡 [Subscription] Trying Android legacy offering keys on Android',
        );
        subscriptionOffering =
            offerings.getOffering('monthly_premium') ??
            offerings.getOffering('monthly');
      }

      if (subscriptionOffering == null) {
        debugPrint('🔴 [Subscription] No subscription offering available');
        _showError(
          context,
          'Subscription offering not configured. This is a backend configuration issue.\n\n'
          'Please contact support.',
        );
        return;
      }

      debugPrint(
        '🟢 [Subscription] Using offering: ${subscriptionOffering.identifier}',
      );

      // Find the monthly subscription package
      final packages = subscriptionOffering.availablePackages;

      if (packages.isEmpty) {
        debugPrint('🔴 [Subscription] Offering has no available packages');
        _showError(
          context,
          'No subscription packages available. This is a backend configuration issue.\n\n'
          'Please contact support.',
        );
        return;
      }

      debugPrint(
        '🟡 [Subscription] Available packages: ${packages.map((p) => p.storeProduct.identifier).toList()}',
      );

      // Find package by product ID and package type, with stronger Android fallback.
      Package? monthlyPackage;
      final targetProductId =
          RevenueCatConfig.getSubscriptionProductId().toLowerCase();

      // Exact product identifier match first
      monthlyPackage = packages.firstWhereOrNull(
        (p) => p.storeProduct.identifier.toLowerCase() == targetProductId,
      );

      // Next try identifier contains match
      if (monthlyPackage == null) {
        monthlyPackage = packages.firstWhereOrNull(
          (p) =>
              p.storeProduct.identifier.toLowerCase().contains(targetProductId),
        );
      }

      // Prefer monthly package types if available
      if (monthlyPackage == null) {
        monthlyPackage = packages.firstWhereOrNull(
          (p) => p.packageType == PackageType.monthly,
        );
      }

      // Last resort: use first available package
      monthlyPackage ??= packages.first;

      debugPrint(
        '🟢 [Subscription] Selected package: ${monthlyPackage.storeProduct.identifier}',
      );

      // Show loading again during purchase
      if (!context.mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        useRootNavigator: true,
        builder: (context) => const Center(child: CircularProgressIndicator()),
      );

      // Make purchase - SDK handles payment sheet display
      // SDK will throw if user cancels, return CustomerInfo if successful
      // (use firebaseUid captured at the top of this method)

      if (firebaseUid != null) {
        try {
          debugPrint('🔧 [SubscriptionScreen] before RevenueCatService.login');
          await RevenueCatService.login(firebaseUid);
          debugPrint(
            '🟢 [SubscriptionPurchase] RevenueCat linked to Firebase user: $firebaseUid',
          );
        } catch (e) {
          debugPrint(
            '⚠️ [SubscriptionPurchase] RevenueCat login before purchase failed: $e',
          );
        }
      } else {
        debugPrint(
          '🟡 [SubscriptionPurchase] No firebaseUid available before purchase; proceeding without RevenueCat login',
        );
      }

      debugPrint(
        '🔧 [SubscriptionScreen] before RevenueCatService.purchasePackage',
      );
      debugPrint(
        '🔧 [SubscriptionScreen] selected package: ${monthlyPackage.storeProduct.identifier}',
      );
      final customerInfo = await RevenueCatService.purchasePackage(
        monthlyPackage,
      );

      if (!context.mounted) return;
      Navigator.of(context, rootNavigator: true).pop(); // Close loading dialog

      // If customerInfo is null, the user cancelled the native purchase UI.
      if (customerInfo == null) {
        debugPrint(
          '🟡 [SubscriptionPurchase] Purchase cancelled by user (null result)',
        );
        return;
      }

      // ====================================================================
      // OPTIMISTIC: Trust the SDK, record immediately (proven by world-class apps)
      // ====================================================================
      // The RevenueCat SDK has already validated the purchase with Apple/Google.
      // We trust this validation and record the purchase immediately.
      // Background async verification happens via our webhook system.

      debugPrint(
        '🟢 [SubscriptionPurchase] SDK validated, recording optimistically',
      );

      // Extract a subscription transaction reference from CustomerInfo.
      // The RevenueCat Flutter SDK does not expose store transaction IDs
      // for subscriptions (only for nonSubscriptionTransactions), so we
      // build a meaningful synthetic identifier for audit purposes.
      String subscriptionTransactionId = '';
      try {
        final activeEntitlements = customerInfo.entitlements.active;
        if (activeEntitlements.isNotEmpty) {
          final entry = activeEntitlements.values.first;
          subscriptionTransactionId =
              'sub_${entry.productIdentifier}_${DateTime.now().millisecondsSinceEpoch}';
        }
      } catch (e) {
        debugPrint(
          '⚠️  [SubscriptionPurchase] Entitlement extraction error: $e',
        );
      }
      if (subscriptionTransactionId.isEmpty) {
        subscriptionTransactionId =
            'sub_${customerInfo.originalAppUserId}_${DateTime.now().millisecondsSinceEpoch}';
      }
      debugPrint(
        '🔐 [SubscriptionPurchase] Transaction reference: $subscriptionTransactionId',
      );

      // Record subscription optimistically (fire-and-forget async verification)
      try {
        await _recordSubscriptionOptimistically(
          packageId: monthlyPackage.storeProduct.identifier,
          transactionId: subscriptionTransactionId,
          tier: SubscriptionTier.monthly.id,
          revenueCatCustomerId: customerInfo.originalAppUserId,
        );
      } catch (e) {
        // Even if local recording fails, the user has the subscription. Don't block.
        debugPrint('⚠️  [SubscriptionPurchase] Local recording error: $e');
      }

      // Sync the active RevenueCat entitlement into Firestore immediately.
      if (firebaseUid != null) {
        try {
          final synced =
              await RevenueCatService.syncActiveSubscriptionToFirestore(
                userId: firebaseUid,
              );
          debugPrint(
            '🟢 [SubscriptionPurchase] RevenueCat entitlement sync completed: $synced',
          );
        } catch (e) {
          debugPrint(
            '⚠️ [SubscriptionPurchase] RevenueCat entitlement sync failed: $e',
          );
        }
      } else {
        debugPrint(
          '🟡 [SubscriptionPurchase] Skipping Firestore entitlement sync (no firebaseUid available)',
        );
      }

      // Show success immediately (user has already paid via SDK validation)
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Subscription unlocked! 🎉'),
            duration: const Duration(seconds: 4),
            backgroundColor: AppColors.success,
          ),
        );
      }

      // Invalidate subscription providers to refresh UI immediately
      ref.invalidate(subscriptionStatusProvider);
      ref.invalidate(isPremiumUserProvider);

      // Fire background verification async (won't block user, not awaited)
      _verifySubscriptionAsync(
        packageId: monthlyPackage.storeProduct.identifier,
        transactionId: subscriptionTransactionId,
        tier: SubscriptionTier.monthly.id,
        revenueCatCustomerId: customerInfo.originalAppUserId,
      );
    } catch (e) {
      if (context.mounted) {
        final navigator = Navigator.of(context, rootNavigator: true);
        if (navigator.canPop()) {
          navigator.pop();
        }
      }

      debugPrint(
        '🔴 [SubscriptionPurchase] Caught exception: ${e.runtimeType}: $e',
      );

      final errorStr = e.toString().toLowerCase();
      if (errorStr.contains('code: 1') &&
          errorStr.contains('usercancelled: true')) {
        debugPrint('🔴 [SubscriptionPurchase] CONFIGURATION ERROR DETECTED!');
        _showError(context, '''
Purchase failed: Product not configured in App Store Connect.

Please verify:
1. Subscription product exists in App Store Connect
2. Bundle ID matches your Xcode project
3. StoreKit configuration is complete
4. RevenueCat dashboard products are synced

Contact support if the issue persists.
''');
      } else if (errorStr.contains('product_already_purchased') ||
          errorStr.contains('already purchased') ||
          errorStr.contains('already owned')) {
        debugPrint(
          '🟠 [SubscriptionPurchase] Existing subscription detected, restoring entitlement',
        );
        await _recoverRevenueCatSubscription(
          context: context,
          ref: ref,
          firebaseUid: firebaseUid,
          feedbackMessage:
              'Subscription is already active. Restored premium access.',
        );
      } else if (e is TimeoutException || errorStr.contains('timed out')) {
        final restored = await _recoverRevenueCatSubscription(
          context: context,
          ref: ref,
          firebaseUid: firebaseUid,
          feedbackMessage:
              'Your payment completed and premium access has now been restored.',
        );
        if (!restored) {
          _showError(
            context,
            'Purchase timed out before the app received confirmation. If you were charged, tap Subscribe again to retry sync or contact support.',
          );
        }
      } else {
        _showError(context, 'Purchase failed: ${e.toString()}');
      }
    }
  }

  Future<bool> _recoverRevenueCatSubscription({
    required BuildContext context,
    required WidgetRef ref,
    required String? firebaseUid,
    required String feedbackMessage,
  }) async {
    if (firebaseUid == null) {
      debugPrint(
        '🟡 [SubscriptionPurchase] Cannot recover Firestore subscription: firebaseUid missing',
      );
      return false;
    }

    try {
      await RevenueCatService.login(firebaseUid);
    } catch (loginError) {
      debugPrint(
        '⚠️ [SubscriptionPurchase] RevenueCat login during recovery failed: $loginError',
      );
    }

    try {
      final customerInfo = await RevenueCatService.getCustomerInfo();
      final activeEntitlements = customerInfo.entitlements.active;
      if (activeEntitlements.isEmpty) {
        debugPrint(
          '🟡 [SubscriptionPurchase] Recovery found no active entitlements for $firebaseUid',
        );
        return false;
      }

      final entitlement =
          activeEntitlements['premium'] ?? activeEntitlements.values.first;
      final packageId = entitlement.productIdentifier;
      final recoveryTransactionId =
          'sub_recovery_${packageId}_${DateTime.now().millisecondsSinceEpoch}';

      await _recordSubscriptionOptimistically(
        packageId: packageId,
        transactionId: recoveryTransactionId,
        tier: SubscriptionTier.monthly.id,
        revenueCatCustomerId: customerInfo.originalAppUserId,
      );

      await RevenueCatService.syncActiveSubscriptionToFirestore(
        userId: firebaseUid,
        customerInfo: customerInfo,
      );

      ref.invalidate(subscriptionStatusProvider);
      ref.invalidate(isPremiumUserProvider);

      _verifySubscriptionAsync(
        packageId: packageId,
        transactionId: recoveryTransactionId,
        tier: SubscriptionTier.monthly.id,
        revenueCatCustomerId: customerInfo.originalAppUserId,
      );

      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(feedbackMessage),
            duration: const Duration(seconds: 4),
            backgroundColor: AppColors.success,
          ),
        );
      }

      debugPrint(
        '🟢 [SubscriptionPurchase] Recovery synced active RevenueCat entitlement for $firebaseUid',
      );
      return true;
    } catch (restoreError) {
      debugPrint(
        '⚠️ [SubscriptionPurchase] Recovery failed: $restoreError',
      );
      return false;
    }
  }

  void _showError(BuildContext context, String message) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(message), backgroundColor: AppColors.primary),
    );
  }

  /// Records subscription optimistically to Firestore
  /// Uses Cloud Firestore directly without waiting for backend validation
  Future<void> _recordSubscriptionOptimistically({
    required String packageId,
    required String transactionId,
    required String tier,
    String? revenueCatCustomerId,
  }) async {
    final user = FirebaseAuth.instance.currentUser;
    if (user == null) {
      debugPrint(
        '🔴 [SubscriptionRecording] CRITICAL: currentUser is null - subscription fields NOT created!',
      );
      return;
    }

    final db = FirebaseFirestore.instance;
    final expiryDate = Timestamp.fromDate(
      DateTime.now().add(const Duration(days: 30)),
    );

    final subscriptionRecord = {
      'isActive': true,
      'tier': tier,
      'startDate': FieldValue.serverTimestamp(),
      // Set expiry to 30 days from now (will be updated by webhook with real expiry)
      'expiryDate': expiryDate,
      'autoRenew': true,
      'revenueCatTransactionId': transactionId,
      'revenueCatCustomerId': revenueCatCustomerId,
      'packageId': packageId,
      'type': 'subscription',
      'verificationStatus':
          'pending', // Will be updated by webhook/async verification
      'optimisticRecord': true, // Marked as optimistic for audit
    };

    // Record subscription merge-safe so purchase state is preserved even if the
    // user document is missing or partially populated.
    await db.collection('users').doc(user.uid).set({
      'subscription': subscriptionRecord,
      'onPremium': true,
      'subExpDate': expiryDate,
      'entitledUser': true,
      'updatedAt': FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  /// Verifies subscription asynchronously with backend (fire-and-forget)
  /// Doesn't block user experience. Called after optimistic record is done.
  void _verifySubscriptionAsync({
    required String packageId,
    required String transactionId,
    required String tier,
    String? revenueCatCustomerId,
  }) {
    // Fire async verification without awaiting
    Future.microtask(() async {
      try {
        debugPrint(
          '🔐 [SubscriptionPurchase] Async verification: Validating with backend',
        );

        await SecurePurchaseValidationService().validateAndRecordSubscription(
          packageId: packageId,
          transactionId: transactionId,
          tier: tier,
          revenueCatCustomerId: revenueCatCustomerId,
        );

        debugPrint('🟢 [SubscriptionPurchase] Async verification successful');
        // Update verification status
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({'subscription.verificationStatus': 'verified'});
        }
      } on PurchaseValidationException catch (e) {
        debugPrint('⚠️  [SubscriptionPurchase] Async verification failed: $e');
        // Mark as verification_failed but don't revoke - user already has access
        final user = FirebaseAuth.instance.currentUser;
        if (user != null) {
          await FirebaseFirestore.instance
              .collection('users')
              .doc(user.uid)
              .update({
                'subscription.verificationStatus': 'verification_failed',
              });
        }
      } catch (e) {
        debugPrint('⚠️  [SubscriptionPurchase] Async verification error: $e');
        // Silent fail - user already has access, verification is just for audit
      }
    });
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
      padding: const EdgeInsets.all(16),
      itemCount: journeys.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
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
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              padding: const EdgeInsets.all(20),
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
                size: 48,
                color: AppColors.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'No Active Journeys',
              style: AppTextStyles.titleMedium.copyWith(
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
            const SizedBox(height: 20),
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
                  horizontal: 20,
                  vertical: 12,
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color:
            isActive
                ? AppColors.primary.withOpacity(0.05)
                : AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color:
              isActive ? AppColors.primary.withOpacity(0.3) : AppColors.border,
        ),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color:
                  isActive
                      ? AppColors.primary
                      : AppColors.primary.withOpacity(0.1),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              _getIcon(),
              color: isActive ? Colors.white : AppColors.primary,
              size: 22,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  feature.title,
                  style: AppTextStyles.titleSmall.copyWith(
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
  @override
  void initState() {
    super.initState();
    // Price is loaded and displayed only in native payment sheet for better UX
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border, width: 1),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 14, 16, 12),
            child: Text(
              widget.tier.displayName,
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
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
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              'This subscription will auto-renew. Cancel anytime from your Playstore or Appstore subscription settings.',
              style: AppTextStyles.bodySmall.copyWith(
                color: AppColors.getTextSecondary(context),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ),
          const SizedBox(height: 12),
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
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(Icons.school, color: AppColors.primary, size: 22),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      journey.journeyTitle,
                      style: AppTextStyles.titleSmall.copyWith(
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
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: AppColors.getBackground(context),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Amount Paid',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                Text(
                  '${journey.currency} ${journey.pricePaid.toStringAsFixed(2)}',
                  style: AppTextStyles.titleSmall.copyWith(
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
                backgroundColor: AppColors.primary,
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

// EARLY ACCESS: _SliverAppBarDelegate kept for future use when tabs are restored
// ignore: unused_element
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
