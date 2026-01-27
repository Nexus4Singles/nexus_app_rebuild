import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/subscription/application/subscription_provider.dart';
import 'package:nexus_app_min_test/features/subscription/domain/subscription_models.dart';

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
              title: Text(
                'Subscriptions',
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
                      top: 40,
                      right: -30,
                      child: Icon(
                        Icons.workspace_premium,
                        size: 180,
                        color: Colors.white.withOpacity(0.1),
                      ),
                    ),
                    Positioned(
                      bottom: 20,
                      left: 20,
                      child: Icon(
                        Icons.star,
                        size: 60,
                        color: Colors.amber.withOpacity(0.3),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),

          // Tab Bar
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
            child: TabBarView(
              controller: _tabController,
              children: [
                // Dating Subscription Tab
                subscriptionAsync.when(
                  data:
                      (subscription) =>
                          _DatingSubscriptionTab(subscription: subscription),
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Error: $error')),
                ),

                // Journey Purchases Tab
                purchasedJourneysAsync.when(
                  data: (journeys) => _JourneyPurchasesTab(journeys: journeys),
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (error, _) => Center(child: Text('Error: $error')),
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
          // Premium Badge Card
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24),
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
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.workspace_premium,
                    size: 48,
                    color: Colors.white,
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Premium Active',
                  style: AppTextStyles.headlineMedium.copyWith(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subscription.tier.displayName,
                  style: AppTextStyles.titleMedium.copyWith(
                    color: Colors.white.withOpacity(0.9),
                  ),
                ),
                const SizedBox(height: 16),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.white.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.schedule, color: Colors.white, size: 18),
                      const SizedBox(width: 8),
                      Text(
                        expiryDate != null
                            ? 'Expires: ${DateFormat.yMMMd().format(expiryDate)}'
                            : 'Active subscription',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: Colors.white,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                if (daysLeft > 0 && daysLeft <= 7)
                  Padding(
                    padding: const EdgeInsets.only(top: 12),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.amber,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        '$daysLeft days left',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: Colors.black87,
                          fontWeight: FontWeight.bold,
                        ),
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
          if (subscription.autoRenew) ...[
            Text(
              'Manage Subscription',
              style: AppTextStyles.titleMedium.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 12),
            _CancelAutoRenewalButton(),
          ] else ...[
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.getBorder(context)),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.getTextSecondary(context)),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      'Auto-renewal has been cancelled. Your subscription will expire on ${expiryDate != null ? DateFormat.yMMMd().format(expiryDate) : "expiry date"}.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}

// No Subscription View
class _NoSubscriptionView extends StatelessWidget {
  const _NoSubscriptionView();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Premium Card
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
            child: Column(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Icon(
                    Icons.workspace_premium,
                    size: 40,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  'Unlock Premium Features',
                  style: AppTextStyles.titleLarge.copyWith(
                    color: AppColors.getTextPrimary(context),
                    fontWeight: FontWeight.bold,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 4),
                Text(
                  'Get unlimited access to all dating features',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                  textAlign: TextAlign.center,
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
            'Choose Your Plan',
            style: AppTextStyles.titleLarge.copyWith(
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 16),

          _SubscriptionPlanCard(tier: SubscriptionTier.monthly),
          const SizedBox(height: 12),
          _SubscriptionPlanCard(
            tier: SubscriptionTier.quarterly,
            isMostPopular: true,
          ),
          const SizedBox(height: 12),
          _SubscriptionPlanCard(tier: SubscriptionTier.yearly),

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
                    'All subscriptions auto-renew. Cancel anytime from this screen. Prices may vary by country.',
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
class _EmptyJourneysView extends StatelessWidget {
  const _EmptyJourneysView();

  @override
  Widget build(BuildContext context) {
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
                border: Border.all(color: AppColors.getBorder(context), width: 2),
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
                // Navigate to challenges/journeys screen
                Navigator.pushNamed(context, '/challenges');
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
            isActive ? AppColors.primary.withOpacity(0.05) : AppColors.getSurface(context),
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

// Subscription Plan Card
class _SubscriptionPlanCard extends StatelessWidget {
  final SubscriptionTier tier;
  final bool isMostPopular;

  const _SubscriptionPlanCard({required this.tier, this.isMostPopular = false});

  @override
  Widget build(BuildContext context) {
    final pricePerMonth =
        tier == SubscriptionTier.monthly
            ? tier.priceNGN
            : tier == SubscriptionTier.quarterly
            ? (tier.priceNGN / 3).round()
            : (tier.priceNGN / 12).round();

    final savings =
        tier == SubscriptionTier.quarterly
            ? 'Save ₦${(2999 * 3) - tier.priceNGN}'
            : tier == SubscriptionTier.yearly
            ? 'Save ₦${(2999 * 12) - tier.priceNGN}'
            : null;

    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isMostPopular ? AppColors.primary : AppColors.border,
          width: isMostPopular ? 2 : 1,
        ),
        boxShadow:
            isMostPopular
                ? [
                  BoxShadow(
                    color: AppColors.primary.withOpacity(0.2),
                    blurRadius: 12,
                    offset: const Offset(0, 4),
                  ),
                ]
                : null,
      ),
      child: Column(
        children: [
          if (isMostPopular)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.primary,
                borderRadius: const BorderRadius.only(
                  topLeft: Radius.circular(19),
                  topRight: Radius.circular(19),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Icon(Icons.star, color: Colors.amber, size: 16),
                  const SizedBox(width: 6),
                  Text(
                    'MOST POPULAR',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.bold,
                      letterSpacing: 1,
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        tier.displayName,
                        style: AppTextStyles.titleLarge.copyWith(
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        '₦$pricePerMonth/month',
                        style: AppTextStyles.bodyMedium.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                      if (savings != null) ...[
                        const SizedBox(height: 6),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 8,
                            vertical: 4,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            savings,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.success,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
                Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text(
                      '₦${tier.priceNGN}',
                      style: AppTextStyles.headlineMedium.copyWith(
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    Text(
                      'total',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
            child: ElevatedButton(
              onPressed: () {
                // TODO: Implement RevenueCat purchase flow
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text(
                      'Purchase flow coming soon with RevenueCat integration',
                    ),
                  ),
                );
              },
              style: ElevatedButton.styleFrom(
                backgroundColor:
                    isMostPopular ? AppColors.primary : AppColors.getSurface(context),
                foregroundColor:
                    isMostPopular ? Colors.white : AppColors.primary,
                elevation: 0,
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                  side:
                      isMostPopular
                          ? BorderSide.none
                          : BorderSide(color: AppColors.primary),
                ),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    'Subscribe Now',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: isMostPopular ? Colors.white : AppColors.primary,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(width: 8),
                  Icon(
                    Icons.arrow_forward,
                    size: 18,
                    color: isMostPopular ? Colors.white : AppColors.primary,
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
class _JourneyPurchaseCard extends StatelessWidget {
  final PurchasedJourney journey;

  const _JourneyPurchaseCard({required this.journey});

  @override
  Widget build(BuildContext context) {
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
    return OutlinedButton.icon(
      onPressed: () async {
        final confirm = await showDialog<bool>(
          context: context,
          builder:
              (ctx) => AlertDialog(
                title: const Text('Cancel Auto-Renewal?'),
                content: const Text(
                  'Your subscription will remain active until the end of the current billing period, but it will not renew automatically.',
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, false),
                    child: const Text('Keep Subscription'),
                  ),
                  TextButton(
                    onPressed: () => Navigator.pop(ctx, true),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.error,
                    ),
                    child: const Text('Cancel Auto-Renewal'),
                  ),
                ],
              ),
        );

        if (confirm == true && context.mounted) {
          try {
            await ref
                .read(subscriptionNotifierProvider.notifier)
                .cancelAutoRenewal();
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                const SnackBar(
                  content: Text('Auto-renewal cancelled successfully'),
                  backgroundColor: AppColors.success,
                ),
              );
            }
          } catch (e) {
            if (context.mounted) {
              ScaffoldMessenger.of(context).showSnackBar(
                SnackBar(
                  content: Text('Error: $e'),
                  backgroundColor: AppColors.error,
                ),
              );
            }
          }
        }
      },
      icon: const Icon(Icons.cancel_outlined),
      label: const Text('Cancel Auto-Renewal'),
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.error,
        side: BorderSide(color: AppColors.error),
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
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
