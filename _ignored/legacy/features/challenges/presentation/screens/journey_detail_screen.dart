import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/journey_model.dart';
import '../../../../core/providers/journey_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/services/revenuecat_service.dart';
import '../../../../core/widgets/app_loading_states.dart';

/// Premium Journey Detail Screen
/// Shows all sessions within a journey/product with:
/// - Beautiful hero header
/// - Progress tracking
/// - Tier-based session cards
/// - Lock states and purchase prompts
class JourneyDetailScreen extends ConsumerStatefulWidget {
  final String productId;

  const JourneyDetailScreen({super.key, required this.productId});

  @override
  ConsumerState<JourneyDetailScreen> createState() => _JourneyDetailScreenState();
}

class _JourneyDetailScreenState extends ConsumerState<JourneyDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final productAsync = ref.watch(productByIdProvider(widget.productId));
    final progressAsync = ref.watch(journeyProgressProvider(widget.productId));
    final isPurchased = ref.watch(isProductPurchasedProvider(widget.productId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: productAsync.when(
        data: (product) {
          if (product == null) {
            return const AppErrorState(
              title: 'Journey Not Found',
              message: 'This journey may no longer be available.',
            );
          }
          return _buildContent(context, product, progressAsync, isPurchased);
        },
        loading: () => const AppLoadingScreen(),
        error: (e, _) => AppErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(productByIdProvider(widget.productId)),
        ),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    JourneyProduct product,
    AsyncValue<JourneyProgress?> progressAsync,
    bool isPurchased,
  ) {
    final progress = progressAsync.valueOrNull;
    final completedSessions = progress?.completedSessions ?? 0;
    final totalSessions = product.sessions.length;
    final progressPercent = totalSessions > 0 ? completedSessions / totalSessions : 0.0;

    return FadeTransition(
      opacity: _fadeIn,
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Hero Header
          _buildHeroHeader(context, product, progressPercent, completedSessions, totalSessions),

          // Content
          SliverPadding(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Progress card (if started)
                if (completedSessions > 0) ...[
                  _buildProgressCard(progress!, progressPercent, completedSessions, totalSessions),
                  const SizedBox(height: 24),
                ],

                // Purchase prompt (if not purchased and not started)
                if (!isPurchased && completedSessions == 0) ...[
                  _buildPurchasePrompt(context, product),
                  const SizedBox(height: 24),
                ],

                // Sessions section
                _buildSectionHeader('Sessions', '${totalSessions} total'),
                const SizedBox(height: 16),

                // Session list
                ...product.sessions.asMap().entries.map((entry) {
                  final index = entry.key;
                  final session = entry.value;
                  final sessionNumber = index + 1;
                  final isCompleted = index < completedSessions;
                  final isNext = index == completedSessions;
                  final isLocked = !isPurchased && session.lockRule != LockRule.free;

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SessionCard(
                      session: session,
                      sessionNumber: sessionNumber,
                      isCompleted: isCompleted,
                      isNext: isNext,
                      isLocked: isLocked,
                      onTap: () {
                        if (isLocked) {
                          _showPurchaseSheet(context, product);
                        } else {
                          context.push('/journey/${widget.productId}/session/$sessionNumber');
                        }
                      },
                    ),
                  );
                }),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroHeader(
    BuildContext context,
    JourneyProduct product,
    double progressPercent,
    int completed,
    int total,
  ) {
    final icon = _getProductIcon(product.productName);
    
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.2),
            borderRadius: BorderRadius.circular(12),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.primary,
                AppColors.primaryDark,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 60, 20, 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Icon and free badge row
                  Row(
                    children: [
                      Container(
                        width: 56,
                        height: 56,
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(16),
                        ),
                        child: Center(
                          child: Text(icon, style: const TextStyle(fontSize: 28)),
                        ),
                      ),
                      const Spacer(),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.play_circle_outline, color: Colors.white, size: 16),
                            const SizedBox(width: 6),
                            Text(
                              '$total sessions',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: Colors.white.withOpacity(0.95),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const Spacer(),

                  // Title
                  Text(
                    product.productName,
                    style: const TextStyle(
                      fontSize: 26,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 8),

                  // Suggested window
                  Row(
                    children: [
                      Icon(Icons.schedule, color: Colors.white.withOpacity(0.8), size: 16),
                      const SizedBox(width: 6),
                      Text(
                        '${product.suggestedWindow ?? "14 days"} suggested',
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.white.withOpacity(0.85),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Icon(Icons.attach_money, color: Colors.white.withOpacity(0.8), size: 16),
                      Text(
                        '₦${product.priceNGN}',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w600,
                          color: Colors.white.withOpacity(0.95),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildProgressCard(
    JourneyProgress progress,
    double progressPercent,
    int completed,
    int total,
  ) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.04),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Text(
                'Your Progress',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              Text(
                '${(progressPercent * 100).toInt()}%',
                style: TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // Progress bar
          Container(
            height: 10,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(5),
            ),
            child: FractionallySizedBox(
              alignment: Alignment.centerLeft,
              widthFactor: progressPercent,
              child: Container(
                decoration: BoxDecoration(
                  gradient: AppColors.primaryGradient,
                  borderRadius: BorderRadius.circular(5),
                ),
              ),
            ),
          ),
          const SizedBox(height: 16),

          // Stats row
          Row(
            children: [
              _MiniStat(
                icon: Icons.check_circle,
                value: '$completed/$total',
                label: 'Completed',
                color: AppColors.success,
              ),
              const SizedBox(width: 24),
              if (progress.currentStreak > 0)
                _MiniStat(
                  icon: Icons.local_fire_department,
                  value: '${progress.currentStreak}',
                  label: 'Day Streak',
                  color: AppColors.gold,
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPurchasePrompt(BuildContext context, JourneyProduct product) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            AppColors.tierPremium.withOpacity(0.1),
            AppColors.tierPremiumLight,
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.tierPremium.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.tierPremium.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(Icons.lock_open, color: AppColors.tierPremium, size: 24),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'Unlock Full Journey',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Get access to all ${product.sessions.length} sessions',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              Text(
                '₦${product.priceNGN}',
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w800,
                  color: AppColors.tierPremium,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                'one-time',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              ElevatedButton(
                onPressed: () => _showPurchaseSheet(context, product),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.tierPremium,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                  elevation: 0,
                ),
                child: const Text(
                  'Unlock',
                  style: TextStyle(fontWeight: FontWeight.w700),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Row(
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(width: 8),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: AppColors.surfaceLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            subtitle,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondary,
            ),
          ),
        ),
      ],
    );
  }

  void _showPurchaseSheet(BuildContext context, JourneyProduct product) {
    HapticFeedback.lightImpact();
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => _PurchaseSheet(
        product: product,
        onPurchase: () {
          Navigator.pop(context);
          _handlePurchase(context, product);
        },
      ),
    );
  }

  Future<void> _handlePurchase(BuildContext context, JourneyProduct product) async {
    // Check if RevenueCat is enabled (production mode)
    if (!RevenueCatConfig.isEnabled) {
      // Development mode - show coming soon or simulate purchase for testing
      _showDevModePurchaseDialog(context, product);
      return;
    }

    // Production mode - use RevenueCat
    _showPurchasingOverlay(context);

    try {
      final revenueCat = ref.read(revenueCatServiceProvider);
      final offerings = await revenueCat.getOfferings();

      if (offerings == null || offerings.current == null) {
        Navigator.pop(context); // Remove overlay
        _showErrorDialog(context, 'Unable to load purchase options. Please try again.');
        return;
      }

      // Find package matching this product ID
      final packages = offerings.current!.availablePackages;
      final package = packages.where((p) => 
        p.storeProduct.identifier.toLowerCase().contains(product.productId.toLowerCase())
      ).firstOrNull;

      if (package == null) {
        Navigator.pop(context);
        _showErrorDialog(context, 'This journey package is not available for purchase yet.');
        return;
      }

      // Make purchase
      final result = await revenueCat.purchasePackage(package);
      Navigator.pop(context); // Remove overlay

      switch (result) {
        case PurchaseResult.success:
          // Record purchase in Firestore
          await _recordPurchase(product.productId);
          _showSuccessDialog(context, product);
          break;
        case PurchaseResult.cancelled:
          // User cancelled - do nothing
          break;
        case PurchaseResult.failed:
          _showErrorDialog(context, 'Purchase failed. Please try again.');
          break;
      }
    } catch (e) {
      Navigator.pop(context); // Remove overlay if still showing
      _showErrorDialog(context, 'An error occurred. Please try again.');
    }
  }

  Future<void> _recordPurchase(String productId) async {
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'purchasedJourneys': FieldValue.arrayUnion([productId]),
        'lastPurchaseAt': FieldValue.serverTimestamp(),
      });
      
      // Refresh purchased products
      ref.invalidate(purchasedProductsProvider);
    } catch (e) {
      debugPrint('Error recording purchase: $e');
    }
  }

  void _showDevModePurchaseDialog(BuildContext context, JourneyProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.warning.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.construction,
                color: AppColors.warning,
                size: 40,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Coming Soon',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'In-app purchases are not yet enabled. This feature will be available when the app launches.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.surfaceLight,
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                'Product: ${product.productId}',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'monospace',
                  color: AppColors.textMuted,
                ),
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showPurchasingOverlay(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Center(
        child: Container(
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 20),
              Text(
                'Processing...',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _showSuccessDialog(BuildContext context, JourneyProduct product) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.success.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.check_circle,
                color: AppColors.success,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Purchase Complete!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              'You now have full access to "${product.productName}". Start your journey today!',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  // Refresh the screen
                  ref.invalidate(productByIdProvider(widget.productId));
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Start Journey'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _showErrorDialog(BuildContext context, String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration: BoxDecoration(
                color: AppColors.error.withOpacity(0.1),
                shape: BoxShape.circle,
              ),
              child: Icon(
                Icons.error_outline,
                color: AppColors.error,
                size: 48,
              ),
            ),
            const SizedBox(height: 20),
            const Text(
              'Oops!',
              style: TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondary,
                height: 1.5,
              ),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(context),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('OK'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  String _getProductIcon(String productName) {
    final name = productName.toLowerCase();
    if (name.contains('attraction') || name.contains('discernment')) return '💫';
    if (name.contains('emotional') || name.contains('healing')) return '💚';
    if (name.contains('values') || name.contains('priorities')) return '⭐';
    if (name.contains('communication')) return '💬';
    if (name.contains('faith') || name.contains('purpose')) return '✝️';
    if (name.contains('appreciation') || name.contains('friendship')) return '💑';
    if (name.contains('intimacy') || name.contains('closeness')) return '❤️';
    if (name.contains('conflict') || name.contains('repair')) return '🔧';
    if (name.contains('boundaries')) return '🛡️';
    return '🎯';
  }
}

// ============================================================================
// SESSION CARD
// ============================================================================

class _SessionCard extends StatelessWidget {
  final JourneySession session;
  final int sessionNumber;
  final bool isCompleted;
  final bool isNext;
  final bool isLocked;
  final VoidCallback onTap;

  const _SessionCard({
    required this.session,
    required this.sessionNumber,
    required this.isCompleted,
    required this.isNext,
    required this.isLocked,
    required this.onTap,
  });

  Color get _tierColor {
    final tierName = session.tier.name[0].toUpperCase() + session.tier.name.substring(1);
    return AppColors.getTierColor(tierName);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: isLocked ? AppColors.surfaceLight : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isNext
              ? AppColors.primary
              : isCompleted
                  ? AppColors.success.withOpacity(0.3)
                  : AppColors.border,
          width: isNext ? 2 : 1,
        ),
        boxShadow: isNext
            ? [
                BoxShadow(
                  color: AppColors.primary.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                // Session number / status indicator
                _buildStatusIndicator(),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Title row
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              session.title,
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                                color: isLocked
                                    ? AppColors.textMuted
                                    : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          _buildTierBadge(),
                        ],
                      ),
                      const SizedBox(height: 4),

                      // Prompt preview
                      Text(
                        session.prompt.length > 60
                            ? '${session.prompt.substring(0, 60)}...'
                            : session.prompt,
                        style: TextStyle(
                          fontSize: 13,
                          color: isLocked
                              ? AppColors.textDisabled
                              : AppColors.textSecondary,
                          height: 1.4,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Action indicator
                _buildActionIndicator(),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildStatusIndicator() {
    if (isCompleted) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.success.withOpacity(0.1),
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.check, color: AppColors.success, size: 20),
      );
    }

    if (isNext) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          gradient: AppColors.primaryGradient,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Center(
          child: Text(
            '$sessionNumber',
            style: const TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w700,
              color: Colors.white,
            ),
          ),
        ),
      );
    }

    if (isLocked) {
      return Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Icon(Icons.lock, color: AppColors.textMuted, size: 18),
      );
    }

    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Center(
        child: Text(
          '$sessionNumber',
          style: TextStyle(
            fontSize: 16,
            fontWeight: FontWeight.w600,
            color: AppColors.textSecondary,
          ),
        ),
      ),
    );
  }

  Widget _buildTierBadge() {
    final tierName = session.tier.name[0].toUpperCase() + session.tier.name.substring(1);
    final color = isLocked ? AppColors.textMuted : _tierColor;
    final bgColor = isLocked ? AppColors.surfaceDark : AppColors.getTierLightColor(tierName);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tierName,
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildActionIndicator() {
    if (isLocked) {
      // Show free badge for free sessions even if journey not purchased
      if (session.lockRule == LockRule.free) {
        return Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
          decoration: BoxDecoration(
            color: AppColors.tierFreeLight,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Text(
            'FREE',
            style: TextStyle(
              fontSize: 10,
              fontWeight: FontWeight.w700,
              color: AppColors.tierFree,
            ),
          ),
        );
      }
      return Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20);
    }

    if (isCompleted) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.replay, size: 14, color: AppColors.textSecondary),
            const SizedBox(width: 4),
            Text(
              'Redo',
              style: TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w600,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      );
    }

    if (isNext) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: AppColors.primary,
          borderRadius: BorderRadius.circular(10),
        ),
        child: const Text(
          'START',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w700,
            color: Colors.white,
          ),
        ),
      );
    }

    return Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20);
  }
}

// ============================================================================
// MINI STAT
// ============================================================================

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String value;
  final String label;
  final Color color;

  const _MiniStat({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            borderRadius: BorderRadius.circular(10),
          ),
          child: Icon(icon, color: color, size: 18),
        ),
        const SizedBox(width: 10),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              value,
              style: TextStyle(
                fontSize: 16,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
        ),
      ],
    );
  }
}

// ============================================================================
// PURCHASE SHEET
// ============================================================================

class _PurchaseSheet extends StatelessWidget {
  final JourneyProduct product;
  final VoidCallback onPurchase;

  const _PurchaseSheet({
    required this.product,
    required this.onPurchase,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle
          Container(
            margin: const EdgeInsets.only(top: 12),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
              color: AppColors.border,
              borderRadius: BorderRadius.circular(2),
            ),
          ),

          Padding(
            padding: const EdgeInsets.all(24),
            child: Column(
              children: [
                // Icon
                Container(
                  width: 80,
                  height: 80,
                  decoration: BoxDecoration(
                    gradient: AppColors.primaryGradient,
                    borderRadius: BorderRadius.circular(24),
                    boxShadow: [
                      BoxShadow(
                        color: AppColors.primary.withOpacity(0.3),
                        blurRadius: 16,
                        offset: const Offset(0, 6),
                      ),
                    ],
                  ),
                  child: const Center(
                    child: Icon(Icons.lock_open, color: Colors.white, size: 36),
                  ),
                ),
                const SizedBox(height: 20),

                // Title
                Text(
                  'Unlock ${product.productName}',
                  style: const TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textPrimary,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 24),

                // Features
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceLight,
                    borderRadius: BorderRadius.circular(16),
                  ),
                  child: Column(
                    children: [
                      _FeatureItem(text: '${product.sessions.length} guided sessions'),
                      _FeatureItem(text: 'All tier levels (Starter to Premium)'),
                      _FeatureItem(text: 'Lifetime access'),
                      _FeatureItem(text: 'Progress tracking & streaks'),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Price display - shows primary price with alternatives
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                  ),
                  child: Column(
                    children: [
                      // Main price
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(
                            product.formattedPrice,
                            style: TextStyle(
                              fontSize: 36,
                              fontWeight: FontWeight.w800,
                              color: AppColors.primary,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              'one-time',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      // Alternative currencies
                      Text(
                        'or ${product.getFormattedPrice(ProductCurrency.usd)} • ${product.getFormattedPrice(ProductCurrency.gbp)}',
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Purchase button
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: onPurchase,
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      elevation: 4,
                      shadowColor: AppColors.primary.withOpacity(0.3),
                    ),
                    child: const Text(
                      'Purchase Now',
                      style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                
                // Store info
                Text(
                  'Price may vary based on your app store',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                  textAlign: TextAlign.center,
                ),
                const SizedBox(height: 12),

                // Cancel
                TextButton(
                  onPressed: () => Navigator.pop(context),
                  child: Text(
                    'Maybe later',
                    style: TextStyle(
                      color: AppColors.textSecondary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
          ),

          SizedBox(height: MediaQuery.of(context).padding.bottom + 16),
        ],
      ),
    );
  }
}

class _FeatureItem extends StatelessWidget {
  final String text;

  const _FeatureItem({required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          Icon(Icons.check_circle, color: AppColors.success, size: 20),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(
                fontSize: 14,
                color: AppColors.textPrimary,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
