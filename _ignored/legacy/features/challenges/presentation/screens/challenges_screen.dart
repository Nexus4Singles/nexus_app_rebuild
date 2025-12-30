import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/journey_provider.dart';
import '../../../../core/models/user_model.dart';
import '../../../../core/models/journey_model.dart';
import '../../../../core/widgets/app_loading_states.dart';

/// Premium Challenges/Activities Screen with full gamification
/// Loads journey data from JSON config via providers (NOT hardcoded)
class ChallengesScreen extends ConsumerStatefulWidget {
  const ChallengesScreen({super.key});

  @override
  ConsumerState<ChallengesScreen> createState() => _ChallengesScreenState();
}

class _ChallengesScreenState extends ConsumerState<ChallengesScreen>
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
    final user = ref.watch(currentUserProvider).valueOrNull;
    final productsAsync = ref.watch(availableProductsProvider);
    final allProgressAsync = ref.watch(allJourneyProgressProvider);
    
    final relationshipStatus = user?.nexus2?.relationshipStatus?.name;
    final isMarried = relationshipStatus == 'married';

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeIn,
        child: productsAsync.when(
          data: (products) {
            final progress = allProgressAsync.valueOrNull ?? {};
            final purchasedIds = ref.watch(purchasedProductsProvider);
            
            return CustomScrollView(
              physics: const BouncingScrollPhysics(),
              slivers: [
                // Custom App Bar
                _buildAppBar(user, isMarried, progress),
                
                // Content
                SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      // Progress Stats Card
                      _buildProgressStatsCard(progress),
                      const SizedBox(height: 28),
                      
                      // Section Title
                      _buildSectionHeader(
                        isMarried
                            ? 'Strengthen Your Marriage'
                            : 'Prepare for Marriage',
                        'Choose a focus area to begin your journey',
                      ),
                      const SizedBox(height: 16),
                      
                      // Journey Categories (loaded from provider)
                      ...products.asMap().entries.map((entry) {
                        final index = entry.key;
                        final product = entry.value;
                        final productProgress = progress[product.productId];
                        final isPurchased = purchasedIds.contains(product.productId);
                        
                        return Padding(
                          padding: const EdgeInsets.only(bottom: 16),
                          child: _JourneyCard(
                            product: product,
                            progress: productProgress,
                            isPurchased: isPurchased,
                            index: index,
                            onTap: () => context.push('/journey/${product.productId}'),
                          ),
                        );
                      }),
                      
                      const SizedBox(height: 100),
                    ]),
                  ),
                ),
              ],
            );
          },
          loading: () => const AppLoadingScreen(),
          error: (error, _) => AppErrorState(
            message: 'Failed to load journeys',
            onRetry: () => ref.invalidate(availableProductsProvider),
          ),
        ),
      ),
    );
  }

  Widget _buildAppBar(
    UserModel? user,
    bool isMarried,
    Map<String, JourneyProgress> progress,
  ) {
    final name = user?.displayName.split(' ').first ?? 'there';
    final greeting = _getGreeting();
    
    // Calculate total streak from all progress
    int totalStreak = 0;
    for (final p in progress.values) {
      if (p.currentStreak > totalStreak) {
        totalStreak = p.currentStreak;
      }
    }

    return SliverAppBar(
      expandedHeight: 140,
      floating: false,
      pinned: true,
      backgroundColor: AppColors.background,
      elevation: 0,
      flexibleSpace: FlexibleSpaceBar(
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                AppColors.primarySoft,
                AppColors.background,
              ],
            ),
          ),
          child: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              '$greeting, $name 👋',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              isMarried
                                  ? 'Keep investing in your marriage'
                                  : 'What area are you working on today?',
                              style: TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      // Streak badge
                      _StreakBadge(streak: totalStreak),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
      title: const Text(
        'Activities',
        style: TextStyle(
          color: AppColors.textPrimary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _buildProgressStatsCard(Map<String, JourneyProgress> progress) {
    // Calculate stats from actual progress
    int totalStreak = 0;
    int totalCompleted = 0;
    int activeJourneys = 0;
    
    for (final p in progress.values) {
      if (p.currentStreak > totalStreak) {
        totalStreak = p.currentStreak;
      }
      totalCompleted += p.completedSessions;
      if (p.completedSessions > 0) {
        activeJourneys++;
      }
    }

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1F1F2E), Color(0xFF2D2D44)],
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.15),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          // Streak
          Expanded(
            child: _StatItem(
              icon: '🔥',
              value: '$totalStreak',
              label: 'Day Streak',
              color: AppColors.gold,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withOpacity(0.1),
          ),
          // Completed
          Expanded(
            child: _StatItem(
              icon: '✅',
              value: '$totalCompleted',
              label: 'Completed',
              color: AppColors.success,
            ),
          ),
          Container(
            width: 1,
            height: 50,
            color: Colors.white.withOpacity(0.1),
          ),
          // Active Journeys
          Expanded(
            child: _StatItem(
              icon: '🎯',
              value: '$activeJourneys',
              label: 'Journeys',
              color: AppColors.info,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSectionHeader(String title, String subtitle) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: const TextStyle(
            fontSize: 20,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          subtitle,
          style: TextStyle(
            fontSize: 14,
            color: AppColors.textSecondary,
          ),
        ),
      ],
    );
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }
}

// ============================================================================
// SUPPORTING WIDGETS
// ============================================================================

class _StreakBadge extends StatelessWidget {
  final int streak;

  const _StreakBadge({required this.streak});

  @override
  Widget build(BuildContext context) {
    if (streak == 0) {
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.surfaceDark,
          borderRadius: BorderRadius.circular(16),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('🔥', style: TextStyle(fontSize: 18, color: Colors.grey)),
            const SizedBox(width: 6),
            Text(
              '0',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w800,
                color: AppColors.textMuted,
              ),
            ),
          ],
        ),
      );
    }
    
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        gradient: AppColors.streakGradient,
        borderRadius: BorderRadius.circular(16),
        boxShadow: [
          BoxShadow(
            color: AppColors.gold.withOpacity(0.3),
            blurRadius: 12,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('🔥', style: TextStyle(fontSize: 18)),
          const SizedBox(width: 6),
          Text(
            '$streak',
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w800,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }
}

class _StatItem extends StatelessWidget {
  final String icon;
  final String value;
  final String label;
  final Color color;

  const _StatItem({
    required this.icon,
    required this.value,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(icon, style: const TextStyle(fontSize: 20)),
            const SizedBox(width: 6),
            Text(
              value,
              style: const TextStyle(
                fontSize: 24,
                fontWeight: FontWeight.w800,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 12,
            color: Colors.white.withOpacity(0.7),
          ),
        ),
      ],
    );
  }
}

class _JourneyCard extends StatelessWidget {
  final JourneyProduct product;
  final JourneyProgress? progress;
  final bool isPurchased;
  final int index;
  final VoidCallback onTap;

  const _JourneyCard({
    required this.product,
    required this.progress,
    required this.isPurchased,
    required this.index,
    required this.onTap,
  });

  // Get icon for product based on name
  String get _icon {
    final name = product.productName.toLowerCase();
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

  // Get color for product based on index
  Color get _color {
    final colors = [
      AppColors.primary,
      AppColors.tierGrowth,
      AppColors.tierDeep,
      AppColors.info,
      AppColors.tierPremium,
      AppColors.secondary,
    ];
    return colors[index % colors.length];
  }

  // Check if locked (not purchased and not first session free)
  bool get _isLocked {
    if (isPurchased) return false;
    // First session is always free (preview)
    return false; // Allow access to see preview
  }

  // Get completed sessions
  int get _completedSessions => progress?.completedSessions ?? 0;

  // Get total sessions
  int get _totalSessions => product.sessions.length;

  // Get progress percentage
  double get _progressPercent =>
      _totalSessions > 0 ? _completedSessions / _totalSessions : 0;

  // Get current tier based on progress
  String get _currentTier {
    if (_completedSessions == 0) return 'Starter';
    if (_progressPercent < 0.33) return 'Starter';
    if (_progressPercent < 0.66) return 'Growth';
    if (_progressPercent < 0.9) return 'Deep';
    return 'Premium';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isLocked
              ? AppColors.border
              : _color.withOpacity(0.3),
          width: _isLocked ? 1 : 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _isLocked
                ? Colors.black.withOpacity(0.03)
                : _color.withOpacity(0.1),
            blurRadius: 16,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(20),
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Header row
                Row(
                  children: [
                    // Icon container
                    Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        color: _isLocked
                            ? AppColors.surfaceDark
                            : _color.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Center(
                        child: _isLocked
                            ? Icon(
                                Icons.lock,
                                color: AppColors.textMuted,
                                size: 24,
                              )
                            : Text(
                                _icon,
                                style: const TextStyle(fontSize: 28),
                              ),
                      ),
                    ),
                    const SizedBox(width: 16),

                    // Title and tier
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            product.productName,
                            style: TextStyle(
                              fontSize: 17,
                              fontWeight: FontWeight.w700,
                              color: _isLocked
                                  ? AppColors.textMuted
                                  : AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Row(
                            children: [
                              _TierBadge(
                                tier: _currentTier,
                                isLocked: _isLocked,
                              ),
                              if (!_isLocked && _completedSessions > 0) ...[
                                const SizedBox(width: 8),
                                Text(
                                  '$_completedSessions/$_totalSessions',
                                  style: TextStyle(
                                    fontSize: 12,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ],
                            ],
                          ),
                        ],
                      ),
                    ),

                    // Arrow or price
                    !isPurchased && _completedSessions == 0
                        ? Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.tierPremiumLight,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              '₦${product.priceNGN}',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                color: AppColors.tierPremium,
                              ),
                            ),
                          )
                        : Icon(
                            Icons.chevron_right,
                            color: _color,
                          ),
                  ],
                ),

                const SizedBox(height: 12),

                // Description
                Text(
                  '${_totalSessions} sessions • ${product.suggestedWindow ?? "14"} days suggested',
                  style: TextStyle(
                    fontSize: 14,
                    color: _isLocked
                        ? AppColors.textMuted
                        : AppColors.textSecondary,
                    height: 1.4,
                  ),
                ),

                // Progress bar (only if has progress)
                if (!_isLocked && _progressPercent > 0) ...[
                  const SizedBox(height: 16),
                  _ProgressBar(
                    progress: _progressPercent,
                    color: _color,
                  ),
                ],

                // Free preview indicator
                if (!isPurchased) ...[
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    decoration: BoxDecoration(
                      color: AppColors.tierFreeLight,
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.play_circle_outline,
                          size: 16,
                          color: AppColors.tierFree,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          'Day 1 Free Preview',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: AppColors.tierFree,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TierBadge extends StatelessWidget {
  final String tier;
  final bool isLocked;

  const _TierBadge({required this.tier, this.isLocked = false});

  @override
  Widget build(BuildContext context) {
    final color = isLocked ? AppColors.textMuted : AppColors.getTierColor(tier);
    final bgColor =
        isLocked ? AppColors.surfaceDark : AppColors.getTierLightColor(tier);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        tier,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }
}

class _ProgressBar extends StatelessWidget {
  final double progress;
  final Color color;

  const _ProgressBar({required this.progress, required this.color});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Text(
              'Progress',
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
            Text(
              '${(progress * 100).toInt()}%',
              style: TextStyle(
                fontSize: 12,
                fontWeight: FontWeight.w600,
                color: color,
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          height: 8,
          decoration: BoxDecoration(
            color: color.withOpacity(0.15),
            borderRadius: BorderRadius.circular(4),
          ),
          child: FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: progress,
            child: Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [color.withOpacity(0.8), color],
                ),
                borderRadius: BorderRadius.circular(4),
              ),
            ),
          ),
        ),
      ],
    );
  }
}
