import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/story_model.dart';
import '../../../../core/providers/story_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/widgets/app_loading_states.dart';

/// Premium Story Detail Screen
/// Immersive reading experience with reflection prompts
class StoryDetailScreen extends ConsumerStatefulWidget {
  final String storyId;

  const StoryDetailScreen({super.key, required this.storyId});

  @override
  ConsumerState<StoryDetailScreen> createState() => _StoryDetailScreenState();
}

class _StoryDetailScreenState extends ConsumerState<StoryDetailScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  final ScrollController _scrollController = ScrollController();
  double _scrollProgress = 0;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();

    _scrollController.addListener(_onScroll);
  }

  void _onScroll() {
    if (_scrollController.hasClients) {
      final maxScroll = _scrollController.position.maxScrollExtent;
      final currentScroll = _scrollController.position.pixels;
      setState(() {
        _scrollProgress = maxScroll > 0 ? (currentScroll / maxScroll).clamp(0.0, 1.0) : 0;
      });
    }
  }

  @override
  void dispose() {
    _animController.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final storyAsync = ref.watch(storyByIdProvider(widget.storyId));

    return Scaffold(
      backgroundColor: AppColors.background,
      body: storyAsync.when(
        data: (story) {
          if (story == null) {
            return const AppErrorState(
              title: 'Story Not Found',
              message: 'This story may no longer be available.',
            );
          }
          return _buildContent(context, story);
        },
        loading: () => const AppLoadingScreen(),
        error: (e, _) => AppErrorState(
          message: e.toString(),
          onRetry: () => ref.invalidate(storyByIdProvider(widget.storyId)),
        ),
      ),
    );
  }

  Widget _buildContent(BuildContext context, Story story) {
    return FadeTransition(
      opacity: _fadeIn,
      child: Stack(
        children: [
          // Main content
          CustomScrollView(
            controller: _scrollController,
            physics: const BouncingScrollPhysics(),
            slivers: [
              // Hero header
              _buildHeroHeader(context, story),

              // Content
              SliverPadding(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 100),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([
                    // Story content
                    _buildStoryContent(story),
                    const SizedBox(height: 32),

                    // Key lessons
                    if (story.keyLessons?.isNotEmpty == true) ...[
                      _buildKeyLessons(story),
                      const SizedBox(height: 32),
                    ],

                    // Reflection prompts
                    if (story.reflectionPrompts?.isNotEmpty == true) ...[
                      _buildReflectionSection(story),
                      const SizedBox(height: 32),
                    ],

                    // Share card - replaced with engagement section
                    _buildEngagementSection(story),
                    const SizedBox(height: 40),
                  ]),
                ),
              ),
            ],
          ),

          // Progress bar at top
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: _buildProgressBar(),
          ),

          // Floating engagement bar at bottom
          Positioned(
            bottom: 0,
            left: 0,
            right: 0,
            child: _buildFloatingEngagementBar(story),
          ),
        ],
      ),
    );
  }

  Widget _buildProgressBar() {
    return SafeArea(
      child: Container(
        height: 3,
        margin: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.3),
          borderRadius: BorderRadius.circular(2),
        ),
        child: FractionallySizedBox(
          alignment: Alignment.centerLeft,
          widthFactor: _scrollProgress,
          child: Container(
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(2),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeroHeader(BuildContext context, Story story) {
    final isSaved = ref.watch(isStorySavedProvider(story.storyId));
    
    return SliverAppBar(
      expandedHeight: 300,
      pinned: true,
      backgroundColor: AppColors.primary,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: Container(
          padding: const EdgeInsets.all(8),
          decoration: BoxDecoration(
            color: Colors.black.withOpacity(0.3),
            borderRadius: BorderRadius.circular(10),
          ),
          child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
        ),
      ),
      actions: [
        // Bookmark button
        IconButton(
          onPressed: () => _toggleBookmark(story.storyId, isSaved),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: isSaved ? Colors.white : Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(
              isSaved ? Icons.bookmark : Icons.bookmark_border,
              color: isSaved ? AppColors.primary : Colors.white,
              size: 20,
            ),
          ),
        ),
        // Share button
        IconButton(
          onPressed: () => _shareStory(story),
          icon: Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.3),
              borderRadius: BorderRadius.circular(10),
            ),
            child: const Icon(Icons.share, color: Colors.white, size: 20),
          ),
        ),
        const SizedBox(width: 8),
      ],
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
              padding: const EdgeInsets.fromLTRB(24, 60, 24, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  // Category and reading time
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          story.category ?? 'Faith',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: Colors.white.withOpacity(0.95),
                          ),
                        ),
                      ),
                      const Spacer(),
                      Icon(Icons.schedule, color: Colors.white.withOpacity(0.8), size: 16),
                      const SizedBox(width: 4),
                      Text(
                        '${story.estimatedReadTime ?? 3} min read',
                        style: TextStyle(
                          fontSize: 13,
                          color: Colors.white.withOpacity(0.8),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),

                  // Title
                  Text(
                    story.title,
                    style: const TextStyle(
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      color: Colors.white,
                      height: 1.2,
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Author
                  Row(
                    children: [
                      CircleAvatar(
                        radius: 16,
                        backgroundColor: Colors.white.withOpacity(0.2),
                        child: Text(
                          story.author?.isNotEmpty == true ? story.author![0] : 'N',
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w600,
                            color: Colors.white,
                          ),
                        ),
                      ),
                      const SizedBox(width: 10),
                      Text(
                        story.author ?? 'Nexus Team',
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w500,
                          color: Colors.white.withOpacity(0.9),
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

  Widget _buildStoryContent(Story story) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 24),

        // Opening hook
        if (story.openingHook != null) ...[
          Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: AppColors.primarySoft,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.primary.withOpacity(0.2)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('✨', style: const TextStyle(fontSize: 24)),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    story.openingHook!,
                    style: TextStyle(
                      fontSize: 16,
                      fontStyle: FontStyle.italic,
                      color: AppColors.primary,
                      height: 1.6,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
        ],

        // Main content
        Text(
          story.content ?? 'Content not available.',
          style: const TextStyle(
            fontSize: 17,
            color: AppColors.textPrimary,
            height: 1.8,
          ),
        ),
      ],
    );
  }

  Widget _buildKeyLessons(Story story) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('💡', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text(
              'Key Lessons',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        ...story.keyLessons!.asMap().entries.map((entry) {
          final index = entry.key;
          final lesson = entry.value;
          return Container(
            margin: const EdgeInsets.only(bottom: 12),
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Container(
                  width: 28,
                  height: 28,
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Center(
                    child: Text(
                      '${index + 1}',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                        color: AppColors.primary,
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    lesson,
                    style: const TextStyle(
                      fontSize: 15,
                      color: AppColors.textPrimary,
                      height: 1.5,
                    ),
                  ),
                ),
              ],
            ),
          );
        }),
      ],
    );
  }

  Widget _buildReflectionSection(Story story) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            const Text('🤔', style: TextStyle(fontSize: 20)),
            const SizedBox(width: 8),
            const Text(
              'Reflect on This',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.w700,
                color: AppColors.textPrimary,
              ),
            ),
          ],
        ),
        const SizedBox(height: 16),

        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                AppColors.tierDeepLight,
                AppColors.tierDeepLight.withOpacity(0.5),
              ],
            ),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.tierDeep.withOpacity(0.2)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: story.reflectionPrompts!.map((prompt) {
              return Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(Icons.help_outline, color: AppColors.tierDeep, size: 18),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        prompt,
                        style: TextStyle(
                          fontSize: 15,
                          color: AppColors.tierDeepDark,
                          height: 1.5,
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),
        ),
      ],
    );
  }

  Widget _buildEngagementSection(Story story) {
    final engagementAsync = ref.watch(storyEngagementProvider(story.storyId));
    final isLikedAsync = ref.watch(hasUserLikedStoryProvider(story.storyId));
    final commentsAsync = ref.watch(storyCommentsProvider(story.storyId));

    final engagement = engagementAsync.valueOrNull;
    final isLiked = isLikedAsync.valueOrNull ?? false;
    final comments = commentsAsync.valueOrNull ?? [];

    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          // Engagement stats
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceAround,
            children: [
              _EngagementStat(
                icon: Icons.favorite,
                count: engagement?.likeCount ?? 0,
                label: 'Likes',
                isActive: isLiked,
              ),
              _EngagementStat(
                icon: Icons.comment,
                count: comments.length,
                label: 'Comments',
              ),
              _EngagementStat(
                icon: Icons.share,
                count: engagement?.shareCount ?? 0,
                label: 'Shares',
              ),
            ],
          ),
          const SizedBox(height: 24),
          
          const Divider(),
          const SizedBox(height: 16),

          const Text(
            '📖',
            style: TextStyle(fontSize: 36),
          ),
          const SizedBox(height: 12),
          const Text(
            'What did you think?',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Share your thoughts with the community',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 20),
          
          // Action buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _ActionButton(
                icon: isLiked ? Icons.favorite : Icons.favorite_border,
                label: isLiked ? 'Liked' : 'Like',
                isActive: isLiked,
                onTap: () => _toggleLike(story.storyId),
              ),
              const SizedBox(width: 12),
              _ActionButton(
                icon: Icons.comment_outlined,
                label: 'Comment',
                onTap: () => _showCommentsSheet(context, story),
              ),
              const SizedBox(width: 12),
              _ActionButton(
                icon: Icons.share,
                label: 'Share',
                onTap: () => _shareStory(story),
              ),
            ],
          ),
          
          // Recent comments preview
          if (comments.isNotEmpty) ...[
            const SizedBox(height: 24),
            const Divider(),
            const SizedBox(height: 16),
            
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Recent Comments',
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                TextButton(
                  onPressed: () => _showCommentsSheet(context, story),
                  child: Text(
                    'See all (${comments.length})',
                    style: TextStyle(
                      fontSize: 13,
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            
            // Show first 2 comments
            ...comments.take(2).map((comment) => Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _CommentTile(comment: comment, compact: true),
            )),
          ],
        ],
      ),
    );
  }

  Widget _buildFloatingEngagementBar(Story story) {
    final isLikedAsync = ref.watch(hasUserLikedStoryProvider(story.storyId));
    final isSaved = ref.watch(isStorySavedProvider(story.storyId));
    final isLiked = isLikedAsync.valueOrNull ?? false;

    return Container(
      padding: EdgeInsets.fromLTRB(20, 12, 20, MediaQuery.of(context).padding.bottom + 12),
      decoration: BoxDecoration(
        color: AppColors.surface,
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.08),
            blurRadius: 16,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _FloatingBarButton(
            icon: isLiked ? Icons.favorite : Icons.favorite_border,
            label: 'Like',
            isActive: isLiked,
            onTap: () => _toggleLike(story.storyId),
          ),
          _FloatingBarButton(
            icon: Icons.comment_outlined,
            label: 'Comment',
            onTap: () => _showCommentsSheet(context, story),
          ),
          _FloatingBarButton(
            icon: isSaved ? Icons.bookmark : Icons.bookmark_border,
            label: 'Save',
            isActive: isSaved,
            onTap: () => _toggleBookmark(story.storyId, isSaved),
          ),
          _FloatingBarButton(
            icon: Icons.share_outlined,
            label: 'Share',
            onTap: () => _shareStory(story),
          ),
        ],
      ),
    );
  }

  Future<void> _toggleLike(String storyId) async {
    HapticFeedback.lightImpact();
    try {
      final notifier = ref.read(storyViewNotifierProvider.notifier);
      final isNowLiked = await notifier.toggleLike();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(isNowLiked ? 'You liked this story! ❤️' : 'Like removed'),
            backgroundColor: isNowLiked ? AppColors.primary : AppColors.textSecondary,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update like'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  void _shareStory(Story story) async {
    HapticFeedback.lightImpact();
    
    try {
      await Share.share(
        '📖 "${story.title}"\n\n${story.subtitle}\n\nRead more on Nexus - Faith-Based Dating & Marriage',
        subject: story.title,
      );
      
      // Increment share count
      ref.read(storyViewNotifierProvider.notifier).incrementShareCount();
    } catch (e) {
      // Silently fail
    }
  }

  void _showCommentsSheet(BuildContext context, Story story) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _CommentsSheet(
        storyId: story.storyId,
        storyTitle: story.title,
      ),
    );
  }

  Future<void> _toggleBookmark(String storyId, bool currentlySaved) async {
    HapticFeedback.lightImpact();
    
    try {
      await ref.read(storyViewNotifierProvider.notifier).toggleSaved();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              currentlySaved ? 'Story removed from saved' : 'Story saved!',
            ),
            backgroundColor: currentlySaved ? AppColors.textSecondary : AppColors.success,
            behavior: SnackBarBehavior.floating,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to update bookmark'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }
}

// ============================================================================
// ENGAGEMENT WIDGETS
// ============================================================================

class _EngagementStat extends StatelessWidget {
  final IconData icon;
  final int count;
  final String label;
  final bool isActive;

  const _EngagementStat({
    required this.icon,
    required this.count,
    required this.label,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        Icon(
          icon,
          size: 24,
          color: isActive ? AppColors.primary : AppColors.textMuted,
        ),
        const SizedBox(height: 4),
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: isActive ? AppColors.primary : AppColors.textPrimary,
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
    );
  }
}

class _ActionButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _ActionButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        decoration: BoxDecoration(
          color: isActive ? AppColors.primarySoft : AppColors.surfaceLight,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: isActive ? AppColors.primary : AppColors.border,
          ),
        ),
        child: Row(
          children: [
            Icon(
              icon,
              size: 20,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
            const SizedBox(width: 8),
            Text(
              label,
              style: TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: isActive ? AppColors.primary : AppColors.textPrimary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FloatingBarButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  const _FloatingBarButton({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            icon,
            size: 24,
            color: isActive ? AppColors.primary : AppColors.textSecondary,
          ),
          const SizedBox(height: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w500,
              color: isActive ? AppColors.primary : AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }
}

class _CommentTile extends StatelessWidget {
  final StoryComment comment;
  final bool compact;

  const _CommentTile({
    required this.comment,
    this.compact = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.all(compact ? 12 : 16),
      decoration: BoxDecoration(
        color: AppColors.surfaceLight,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: compact ? 16 : 20,
            backgroundColor: AppColors.primary.withOpacity(0.1),
            backgroundImage: comment.userPhotoUrl != null
                ? NetworkImage(comment.userPhotoUrl!)
                : null,
            child: comment.userPhotoUrl == null
                ? Text(
                    comment.userName.isNotEmpty ? comment.userName[0].toUpperCase() : '?',
                    style: TextStyle(
                      color: AppColors.primary,
                      fontWeight: FontWeight.w600,
                      fontSize: compact ? 12 : 14,
                    ),
                  )
                : null,
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      comment.userName,
                      style: TextStyle(
                        fontSize: compact ? 13 : 14,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(width: 8),
                    Text(
                      _formatTime(comment.createdAt),
                      style: TextStyle(
                        fontSize: 11,
                        color: AppColors.textMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  comment.text,
                  style: TextStyle(
                    fontSize: compact ? 13 : 14,
                    color: AppColors.textSecondary,
                    height: 1.4,
                  ),
                  maxLines: compact ? 2 : null,
                  overflow: compact ? TextOverflow.ellipsis : null,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  String _formatTime(DateTime time) {
    final diff = DateTime.now().difference(time);
    if (diff.inMinutes < 1) return 'Just now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    return '${time.day}/${time.month}';
  }
}

// ============================================================================
// COMMENTS SHEET
// ============================================================================

class _CommentsSheet extends ConsumerStatefulWidget {
  final String storyId;
  final String storyTitle;

  const _CommentsSheet({
    required this.storyId,
    required this.storyTitle,
  });

  @override
  ConsumerState<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends ConsumerState<_CommentsSheet> {
  final _commentController = TextEditingController();
  bool _isSubmitting = false;

  @override
  void dispose() {
    _commentController.dispose();
    super.dispose();
  }

  Future<void> _submitComment() async {
    final text = _commentController.text.trim();
    if (text.isEmpty) return;

    setState(() => _isSubmitting = true);

    try {
      final notifier = ref.read(storyViewNotifierProvider.notifier);
      await notifier.addComment(text);
      
      _commentController.clear();
      FocusScope.of(context).unfocus();
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Comment added! 💬'),
            backgroundColor: AppColors.success,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to add comment'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _isSubmitting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final commentsAsync = ref.watch(storyCommentsProvider(widget.storyId));
    final user = ref.watch(currentUserProvider).valueOrNull;

    return Container(
      height: MediaQuery.of(context).size.height * 0.75,
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      child: Column(
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

          // Header
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Comments',
                        style: TextStyle(
                          fontSize: 20,
                          fontWeight: FontWeight.w700,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        widget.storyTitle,
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  onPressed: () => Navigator.pop(context),
                  icon: Icon(Icons.close, color: AppColors.textMuted),
                ),
              ],
            ),
          ),

          const Divider(height: 1),

          // Comments list
          Expanded(
            child: commentsAsync.when(
              data: (comments) {
                if (comments.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(
                          Icons.chat_bubble_outline,
                          size: 48,
                          color: AppColors.textMuted,
                        ),
                        const SizedBox(height: 16),
                        Text(
                          'No comments yet',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textPrimary,
                          ),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Be the first to share your thoughts!',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ],
                    ),
                  );
                }

                return ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: comments.length,
                  itemBuilder: (context, index) {
                    final comment = comments[index];
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 12),
                      child: _CommentTile(comment: comment),
                    );
                  },
                );
              },
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, _) => Center(child: Text('Error: $e')),
            ),
          ),

          // Comment input
          if (user != null)
            Container(
              padding: EdgeInsets.fromLTRB(16, 12, 16, MediaQuery.of(context).padding.bottom + 12),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withOpacity(0.05),
                    blurRadius: 10,
                    offset: const Offset(0, -2),
                  ),
                ],
              ),
              child: Row(
                children: [
                  CircleAvatar(
                    radius: 18,
                    backgroundColor: AppColors.primary.withOpacity(0.1),
                    backgroundImage: user.photos.isNotEmpty
                        ? NetworkImage(user.photos.first)
                        : null,
                    child: user.photos.isEmpty
                        ? Text(
                            user.displayName.isNotEmpty ? user.displayName[0].toUpperCase() : '?',
                            style: TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.w600,
                            ),
                          )
                        : null,
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: TextField(
                      controller: _commentController,
                      maxLines: null,
                      maxLength: 500,
                      decoration: InputDecoration(
                        hintText: 'Write a comment...',
                        hintStyle: TextStyle(color: AppColors.textMuted),
                        filled: true,
                        fillColor: AppColors.surfaceLight,
                        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(24),
                          borderSide: BorderSide.none,
                        ),
                        counterText: '',
                      ),
                    ),
                  ),
                  const SizedBox(width: 12),
                  GestureDetector(
                    onTap: _isSubmitting ? null : _submitComment,
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        shape: BoxShape.circle,
                      ),
                      child: _isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(
                              Icons.send,
                              size: 20,
                              color: Colors.white,
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
