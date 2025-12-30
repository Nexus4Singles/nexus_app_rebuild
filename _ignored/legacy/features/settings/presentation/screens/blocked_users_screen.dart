import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/models/user_model.dart';

/// Provider for blocked users list with user details
final blockedUsersDetailsProvider = FutureProvider<List<UserModel>>((ref) async {
  final currentUser = ref.watch(currentUserProvider).valueOrNull;
  if (currentUser == null) return [];

  final blockedIds = currentUser.blocked ?? [];
  if (blockedIds.isEmpty) return [];

  final firestoreService = ref.watch(firestoreServiceProvider);
  final users = <UserModel>[];

  for (final userId in blockedIds) {
    final user = await firestoreService.getUser(userId);
    if (user != null) {
      users.add(user);
    }
  }

  return users;
});

/// Premium Blocked Users Screen
class BlockedUsersScreen extends ConsumerStatefulWidget {
  const BlockedUsersScreen({super.key});

  @override
  ConsumerState<BlockedUsersScreen> createState() => _BlockedUsersScreenState();
}

class _BlockedUsersScreenState extends ConsumerState<BlockedUsersScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 500),
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
    final blockedUsersAsync = ref.watch(blockedUsersDetailsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Premium App Bar
            SliverAppBar(
              expandedHeight: 120,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(60, 16, 20, 20),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.end,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Blocked Users',
                            style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Manage users you\'ve blocked',
                            style: TextStyle(
                              fontSize: 14,
                              color: Colors.white.withOpacity(0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Content
            blockedUsersAsync.when(
              data: (users) {
                if (users.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(),
                  );
                }
                return SliverPadding(
                  padding: const EdgeInsets.all(20),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) => _BlockedUserTile(
                        user: users[index],
                        onUnblock: () => _handleUnblock(users[index]),
                      ),
                      childCount: users.length,
                    ),
                  ),
                );
              },
              loading: () => SliverFillRemaining(
                hasScrollBody: false,
                child: Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      CircularProgressIndicator(color: AppColors.primary),
                      const SizedBox(height: 16),
                      Text(
                        'Loading blocked users...',
                        style: TextStyle(color: AppColors.textSecondary),
                      ),
                    ],
                  ),
                ),
              ),
              error: (e, _) => SliverFillRemaining(
                hasScrollBody: false,
                child: _buildErrorState(e.toString()),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildEmptyState() {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 100,
            height: 100,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.block, size: 48, color: AppColors.textMuted),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Blocked Users',
            style: TextStyle(
              fontSize: 20,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Users you block will appear here.\nThey won\'t be able to see your profile\nor send you messages.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(String error) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 80,
            height: 80,
            decoration: BoxDecoration(
              color: AppColors.error.withOpacity(0.1),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.error_outline, size: 40, color: AppColors.error),
          ),
          const SizedBox(height: 24),
          const Text(
            'Something went wrong',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Failed to load blocked users',
            style: TextStyle(color: AppColors.textSecondary),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 24),
          ElevatedButton.icon(
            onPressed: () => ref.refresh(blockedUsersDetailsProvider),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            icon: const Icon(Icons.refresh, size: 18),
            label: const Text('Try Again'),
          ),
        ],
      ),
    );
  }

  Future<void> _handleUnblock(UserModel user) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Unblock User'),
        content: Text(
          'Are you sure you want to unblock ${user.displayName}?\n\nThey will be able to see your profile and send you messages again.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
            child: const Text('Unblock', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirm == true && mounted) {
      HapticFeedback.lightImpact();
      try {
        await ref.read(userNotifierProvider.notifier).unblockUser(user.uid);
        ref.refresh(blockedUsersDetailsProvider);

        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('${user.displayName} has been unblocked'),
              backgroundColor: AppColors.success,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text('Failed to unblock user'),
              backgroundColor: AppColors.error,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
      }
    }
  }
}

// ============================================================================
// BLOCKED USER TILE
// ============================================================================

class _BlockedUserTile extends StatelessWidget {
  final UserModel user;
  final VoidCallback onUnblock;

  const _BlockedUserTile({required this.user, required this.onUnblock});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
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
      child: Row(
        children: [
          // Avatar
          Container(
            width: 56,
            height: 56,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              shape: BoxShape.circle,
              border: Border.all(color: AppColors.border),
              image: user.photos.isNotEmpty
                  ? DecorationImage(
                      image: NetworkImage(user.photos.first),
                      fit: BoxFit.cover,
                    )
                  : null,
            ),
            child: user.photos.isEmpty
                ? Icon(Icons.person, color: AppColors.textMuted, size: 28)
                : null,
          ),
          const SizedBox(width: 14),

          // User info
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  user.displayName,
                  style: const TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 2),
                Row(
                  children: [
                    Icon(Icons.block, size: 14, color: AppColors.textMuted),
                    const SizedBox(width: 4),
                    Text(
                      'Blocked',
                      style: TextStyle(
                        fontSize: 13,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),

          // Unblock button
          TextButton(
            onPressed: onUnblock,
            style: TextButton.styleFrom(
              foregroundColor: AppColors.primary,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(10),
                side: BorderSide(color: AppColors.primary.withOpacity(0.3)),
              ),
            ),
            child: const Text(
              'Unblock',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }
}
