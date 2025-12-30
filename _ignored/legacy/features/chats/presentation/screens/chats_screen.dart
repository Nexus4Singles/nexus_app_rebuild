import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/chat_provider.dart';
import '../../../../core/widgets/app_loading_states.dart';

/// Premium Chats Screen
/// Shows conversation list with modern messaging UI
class ChatsScreen extends ConsumerStatefulWidget {
  const ChatsScreen({super.key});

  @override
  ConsumerState<ChatsScreen> createState() => _ChatsScreenState();
}

class _ChatsScreenState extends ConsumerState<ChatsScreen>
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
    final chatsAsync = ref.watch(chatsProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: _buildHeader(context),
            ),

            // Content
            chatsAsync.when(
              data: (chats) {
                if (chats.isEmpty) {
                  return SliverFillRemaining(
                    hasScrollBody: false,
                    child: _buildEmptyState(context),
                  );
                }
                
                return SliverPadding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
                  sliver: SliverList(
                    delegate: SliverChildBuilderDelegate(
                      (context, index) {
                        final chat = chats[index];
                        return _ChatTile(
                          name: chat.otherUserName,
                          lastMessage: chat.lastMessage ?? 'Start a conversation',
                          time: chat.formattedTime,
                          unreadCount: chat.unreadCount,
                          isOnline: chat.isOnline,
                          avatarUrl: chat.otherUserPhoto,
                          onTap: () => context.push('/chat/${chat.otherUserId}'),
                        );
                      },
                      childCount: chats.length,
                    ),
                  ),
                );
              },
              loading: () => const SliverFillRemaining(
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => SliverFillRemaining(
                child: AppErrorState(
                  title: 'Failed to load chats',
                  message: e.toString(),
                  onRetry: () => ref.invalidate(chatsProvider),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.background,
      ),
      child: SafeArea(
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 16),
          child: Row(
            children: [
              const Text(
                'Messages',
                style: TextStyle(
                  fontSize: 28,
                  fontWeight: FontWeight.w800,
                  color: AppColors.textPrimary,
                ),
              ),
              const Spacer(),
              // Search button
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surfaceLight,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: Icon(Icons.search, color: AppColors.textSecondary),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildEmptyState(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(40),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          // Illustration
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              shape: BoxShape.circle,
            ),
            child: Icon(
              Icons.chat_bubble_outline,
              size: 56,
              color: AppColors.primary,
            ),
          ),
          const SizedBox(height: 32),

          const Text(
            'No conversations yet',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 12),

          Text(
            'Start connecting with other members.\nYour conversations will appear here.',
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.5,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),

          ElevatedButton.icon(
            onPressed: () => context.go('/search'),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 16),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(14),
              ),
              elevation: 0,
            ),
            icon: const Icon(Icons.search, size: 20),
            label: const Text(
              'Find People',
              style: TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// CHAT TILE
// ============================================================================

class _ChatTile extends StatelessWidget {
  final String name;
  final String lastMessage;
  final String time;
  final int unreadCount;
  final bool isOnline;
  final String? avatarUrl;
  final VoidCallback onTap;

  const _ChatTile({
    required this.name,
    required this.lastMessage,
    required this.time,
    required this.unreadCount,
    required this.isOnline,
    this.avatarUrl,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: unreadCount > 0 ? AppColors.primarySoft : AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: unreadCount > 0 ? AppColors.primary.withOpacity(0.2) : AppColors.border,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                // Avatar with online indicator
                Stack(
                  children: [
                    CircleAvatar(
                      radius: 28,
                      backgroundColor: AppColors.surfaceLight,
                      backgroundImage: avatarUrl != null ? NetworkImage(avatarUrl!) : null,
                      child: avatarUrl == null
                          ? Text(
                              name.isNotEmpty ? name[0].toUpperCase() : '?',
                              style: TextStyle(
                                fontSize: 20,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            )
                          : null,
                    ),
                    if (isOnline)
                      Positioned(
                        right: 2,
                        bottom: 2,
                        child: Container(
                          width: 14,
                          height: 14,
                          decoration: BoxDecoration(
                            color: AppColors.success,
                            shape: BoxShape.circle,
                            border: Border.all(color: Colors.white, width: 2),
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(width: 14),

                // Content
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              name,
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: unreadCount > 0 ? FontWeight.w700 : FontWeight.w600,
                                color: AppColors.textPrimary,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          Text(
                            time,
                            style: TextStyle(
                              fontSize: 12,
                              color: unreadCount > 0 ? AppColors.primary : AppColors.textMuted,
                              fontWeight: unreadCount > 0 ? FontWeight.w600 : FontWeight.normal,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              lastMessage,
                              style: TextStyle(
                                fontSize: 14,
                                color: unreadCount > 0
                                    ? AppColors.textPrimary
                                    : AppColors.textSecondary,
                                fontWeight: unreadCount > 0 ? FontWeight.w500 : FontWeight.normal,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                          if (unreadCount > 0) ...[
                            const SizedBox(width: 8),
                            Container(
                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                              decoration: BoxDecoration(
                                color: AppColors.primary,
                                borderRadius: BorderRadius.circular(10),
                              ),
                              child: Text(
                                '$unreadCount',
                                style: const TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                ),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
