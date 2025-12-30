import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/constants/app_constants.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/journey_provider.dart';
import '../../../../core/models/user_model.dart';

/// Premium Profile Screen with relationship status differentiation
/// - Singles: Dating profile, blocked users, search settings
/// - Married: Marriage stats, spouse connection (future), no dating items
/// Theme: Red/White consistent with app branding
class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen>
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
    final userAsync = ref.watch(currentUserProvider);
    final progressAsync = ref.watch(allJourneyProgressProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: userAsync.when(
        data: (user) {
          if (user == null) {
            return const Center(child: Text('Not logged in'));
          }
          return FadeTransition(
            opacity: _fadeIn,
            child: _buildContent(context, user, progressAsync),
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }

  Widget _buildContent(
    BuildContext context,
    UserModel user,
    AsyncValue<Map<String, dynamic>> progressAsync,
  ) {
    final isMarried = user.nexus2?.relationshipStatus == RelationshipStatus.married;
    final progress = progressAsync.valueOrNull ?? {};

    // Calculate stats
    int totalStreak = 0;
    int totalCompleted = 0;
    for (final p in progress.values) {
      if (p.currentStreak > totalStreak) totalStreak = p.currentStreak;
      totalCompleted += p.completedSessions as int;
    }

    return CustomScrollView(
      physics: const BouncingScrollPhysics(),
      slivers: [
        // Profile Header - Red/White theme for all users
        SliverToBoxAdapter(
          child: _buildHeader(context, user, totalStreak, totalCompleted, isMarried),
        ),

        // Menu Items
        SliverPadding(
          padding: const EdgeInsets.all(20),
          sliver: SliverList(
            delegate: SliverChildListDelegate([
              // Profile Section
              _buildSectionTitle('Profile'),
              const SizedBox(height: 12),
              _MenuCard(
                items: [
                  _MenuItem(
                    icon: Icons.person_outline,
                    title: isMarried ? 'Edit Profile' : 'Edit Dating Profile',
                    subtitle: isMarried 
                        ? 'Update your basic information' 
                        : 'Update your photos and dating info',
                    onTap: () => context.push(
                      isMarried ? '/edit-profile-married' : '/edit-profile',
                    ),
                  ),
                  if (!isMarried) ...[
                    _MenuItem(
                      icon: Icons.photo_library_outlined,
                      title: 'Manage Photos',
                      subtitle: '${user.photos.length} photos uploaded',
                      onTap: () => context.push('/edit-profile'),
                    ),
                  ],
                  _MenuItem(
                    icon: Icons.lock_outline,
                    title: 'Privacy & Security',
                    subtitle: 'Password and account settings',
                    onTap: () => context.push('/settings'),
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // Married-specific section
              if (isMarried) ...[
                _buildSectionTitle('Marriage'),
                const SizedBox(height: 12),
                _MenuCard(
                  items: [
                    _MenuItem(
                      icon: Icons.favorite,
                      iconColor: AppColors.primary,
                      title: 'Connect with Spouse',
                      subtitle: 'Share journey progress together',
                      trailing: _buildBadge('Coming Soon', AppColors.textMuted),
                      onTap: () => _showComingSoonDialog(context, 'Spouse Connection'),
                    ),
                    _MenuItem(
                      icon: Icons.celebration,
                      title: 'Anniversary',
                      subtitle: 'Set your wedding anniversary',
                      onTap: () => _showComingSoonDialog(context, 'Anniversary Tracker'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // Singles-specific section
              if (!isMarried) ...[
                _buildSectionTitle('Dating'),
                const SizedBox(height: 12),
                _MenuCard(
                  items: [
                    _MenuItem(
                      icon: Icons.tune,
                      title: 'Search Preferences',
                      subtitle: 'Age, location, and other filters',
                      onTap: () => _showComingSoonDialog(context, 'Search Preferences'),
                    ),
                    _MenuItem(
                      icon: Icons.block_outlined,
                      title: 'Blocked Users',
                      subtitle: 'Manage blocked profiles',
                      onTap: () => context.push('/blocked-users'),
                    ),
                  ],
                ),
                const SizedBox(height: 24),
              ],

              // App Section
              _buildSectionTitle('App'),
              const SizedBox(height: 12),
              _MenuCard(
                items: [
                  _MenuItem(
                    icon: Icons.notifications_outlined,
                    title: 'Notifications',
                    subtitle: 'Manage your alerts',
                    onTap: () => context.push('/settings'),
                  ),
                  _MenuItem(
                    icon: Icons.subscriptions_outlined,
                    title: 'Subscription',
                    subtitle: user.isPremium ? 'Premium Active' : 'Upgrade to Premium',
                    trailing: user.isPremium 
                        ? _buildBadge('PRO', AppColors.gold) 
                        : _buildUpgradeBadge(),
                    onTap: () => context.push('/subscription'),
                  ),
                  _MenuItem(
                    icon: Icons.help_outline,
                    title: 'Help & Support',
                    subtitle: 'FAQs and contact us',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // About Section
              _buildSectionTitle('About'),
              const SizedBox(height: 12),
              _MenuCard(
                items: [
                  _MenuItem(
                    icon: Icons.description_outlined,
                    title: 'Terms of Service',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.privacy_tip_outlined,
                    title: 'Privacy Policy',
                    onTap: () {},
                  ),
                  _MenuItem(
                    icon: Icons.info_outline,
                    title: 'About Nexus',
                    subtitle: 'Version 2.0.0',
                    onTap: () {},
                  ),
                ],
              ),
              const SizedBox(height: 32),

              // Logout button
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: () => _handleLogout(context),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.error,
                    padding: const EdgeInsets.symmetric(vertical: 16),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    side: BorderSide(color: AppColors.error.withOpacity(0.3)),
                  ),
                  icon: const Icon(Icons.logout, size: 20),
                  label: const Text(
                    'Sign Out',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
              ),
              const SizedBox(height: 16),

              // Footer
              Center(
                child: Text(
                  'Made with ❤️ for Godly marriages',
                  style: TextStyle(
                    fontSize: 12,
                    color: AppColors.textMuted,
                  ),
                ),
              ),
              const SizedBox(height: 100),
            ]),
          ),
        ),
      ],
    );
  }

  Widget _buildHeader(
    BuildContext context,
    UserModel user,
    int streak,
    int completed,
    bool isMarried,
  ) {
    final name = user.displayName;
    final photoUrl = user.photos.isNotEmpty ? user.photos.first : null;

    // Red/White theme - same for all users
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient, // Red gradient for all
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          child: Column(
            children: [
              // Settings icon
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: () => context.push('/settings'),
                  child: Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(Icons.settings, color: Colors.white, size: 20),
                  ),
                ),
              ),

              // Avatar
              Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: Colors.white.withOpacity(0.5), width: 2),
                ),
                child: CircleAvatar(
                  radius: 50,
                  backgroundColor: Colors.white.withOpacity(0.2),
                  backgroundImage: photoUrl != null ? NetworkImage(photoUrl) : null,
                  child: photoUrl == null
                      ? const Icon(Icons.person, size: 50, color: Colors.white)
                      : null,
                ),
              ),
              const SizedBox(height: 16),

              // Name
              Text(
                name,
                style: const TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w700,
                  color: Colors.white,
                ),
              ),
              const SizedBox(height: 6),

              // Status badge - Simple labels only
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  _getStatusLabel(user.nexus2?.relationshipStatus),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w500,
                    color: Colors.white,
                  ),
                ),
              ),
              const SizedBox(height: 24),

              // Stats row
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16),
                ),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    _HeaderStat(icon: '🔥', value: '$streak', label: 'Day Streak'),
                    Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
                    _HeaderStat(icon: '✅', value: '$completed', label: 'Completed'),
                    Container(width: 1, height: 40, color: Colors.white.withOpacity(0.2)),
                    _HeaderStat(icon: '⭐', value: '${completed * 10}', label: 'Points'),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title) {
    return Text(
      title,
      style: const TextStyle(
        fontSize: 14,
        fontWeight: FontWeight.w600,
        color: AppColors.textSecondary,
        letterSpacing: 0.5,
      ),
    );
  }

  Widget _buildBadge(String text, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: color.withOpacity(0.15),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w700,
          color: color,
        ),
      ),
    );
  }

  Widget _buildUpgradeBadge() {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        gradient: AppColors.primaryGradient,
        borderRadius: BorderRadius.circular(6),
      ),
      child: const Text(
        'UPGRADE',
        style: TextStyle(
          fontSize: 10,
          fontWeight: FontWeight.w700,
          color: Colors.white,
        ),
      ),
    );
  }

  /// Simple status labels - no extra descriptions
  /// Divorced/Widowed shows as "Single" for sensitivity
  String _getStatusLabel(RelationshipStatus? status) {
    switch (status) {
      case RelationshipStatus.singleNeverMarried:
        return 'Single';
      case RelationshipStatus.divorcedWidowed:
        return 'Single'; // Sensitive - show as Single
      case RelationshipStatus.married:
        return 'Married';
      default:
        return 'Member';
    }
  }

  void _showComingSoonDialog(BuildContext context, String feature) {
    HapticFeedback.lightImpact();
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: Row(
          children: [
            Icon(Icons.rocket_launch, color: AppColors.primary),
            const SizedBox(width: 10),
            const Text('Coming Soon'),
          ],
        ),
        content: Text('$feature will be available in a future update. Stay tuned!'),
        actions: [
          ElevatedButton(
            onPressed: () => Navigator.pop(context),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Got it', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
  }

  void _handleLogout(BuildContext context) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Sign Out'),
        content: const Text('Are you sure you want to sign out?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.error,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      await ref.read(authServiceProvider).signOut();
      if (mounted) context.go(AppRoutes.login);
    }
  }
}

// ============================================================================
// SUPPORTING WIDGETS
// ============================================================================

class _HeaderStat extends StatelessWidget {
  final String icon;
  final String value;
  final String label;

  const _HeaderStat({
    required this.icon,
    required this.value,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(icon, style: const TextStyle(fontSize: 16)),
            const SizedBox(width: 4),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w700,
                color: Colors.white,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: Colors.white.withOpacity(0.8),
          ),
        ),
      ],
    );
  }
}

class _MenuCard extends StatelessWidget {
  final List<_MenuItem> items;

  const _MenuCard({required this.items});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.03),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(
        children: items.asMap().entries.map((entry) {
          final index = entry.key;
          final item = entry.value;
          final isLast = index == items.length - 1;

          return Column(
            children: [
              item,
              if (!isLast)
                Divider(height: 1, indent: 56, color: AppColors.border),
            ],
          );
        }).toList(),
      ),
    );
  }
}

class _MenuItem extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final String? subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _MenuItem({
    required this.icon,
    this.iconColor,
    required this.title,
    this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: (iconColor ?? AppColors.textSecondary).withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: iconColor ?? AppColors.textSecondary, size: 20),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: const TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    if (subtitle != null) ...[
                      const SizedBox(height: 2),
                      Text(
                        subtitle!,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
              if (trailing != null) ...[
                trailing!,
                const SizedBox(width: 8),
              ],
              Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}
