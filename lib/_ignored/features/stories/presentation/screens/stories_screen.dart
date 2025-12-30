import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/models/story_model.dart';
import '../../../../core/providers/story_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/widgets/app_loading_states.dart';

/// Premium Stories Screen
/// Shows Story of the Week and Weekly Poll with gamification
class StoriesScreen extends ConsumerStatefulWidget {
  const StoriesScreen({super.key});

  @override
  ConsumerState<StoriesScreen> createState() => _StoriesScreenState();
}

class _StoriesScreenState extends ConsumerState<StoriesScreen>
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
    final storyAsync = ref.watch(currentStoryProvider);
    final pollAsync = ref.watch(currentPollProvider);

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Header
            SliverToBoxAdapter(
              child: _buildHeader(context, userAsync),
            ),

            // Content
            SliverPadding(
              padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  // Story of the Week
                  _buildSectionTitle('Story of the Week', '📖'),
                  const SizedBox(height: 12),
                  _buildStoryCard(context, storyAsync),
                  const SizedBox(height: 28),

                  // Weekly Poll
                  _buildSectionTitle('Weekly Poll', '📊'),
                  const SizedBox(height: 12),
                  _buildPollCard(context, pollAsync),
                  const SizedBox(height: 28),

                  // Saved Stories
                  _buildSavedStoriesSection(context),
                  
                  // Past Stories Archive
                  _buildPastStoriesSection(context),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context, AsyncValue<dynamic> userAsync) {
    final name = userAsync.valueOrNull?.displayName?.split(' ').first ?? 'Friend';
    final greeting = _getGreeting();

    return Container(
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
        bottom: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
          child: Row(
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
                      'Grow in wisdom and faith',
                      style: TextStyle(
                        fontSize: 14,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              // Notification bell
              Container(
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: AppColors.border),
                ),
                child: IconButton(
                  onPressed: () {},
                  icon: Stack(
                    children: [
                      Icon(Icons.notifications_outlined, color: AppColors.textPrimary),
                      Positioned(
                        top: 0,
                        right: 0,
                        child: Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                            color: AppColors.primary,
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildSectionTitle(String title, String emoji) {
    return Row(
      children: [
        Text(emoji, style: const TextStyle(fontSize: 20)),
        const SizedBox(width: 8),
        Text(
          title,
          style: const TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w700,
            color: AppColors.textPrimary,
          ),
        ),
      ],
    );
  }

  Widget _buildStoryCard(BuildContext context, AsyncValue<Story?> storyAsync) {
    return storyAsync.when(
      data: (story) {
        if (story == null) {
          return _buildEmptyStoryCard();
        }
        return _StoryCard(
          story: story,
          onTap: () => context.push('/story/${story.storyId}'),
        );
      },
      loading: () => _buildLoadingCard(),
      error: (_, __) => _buildErrorCard('Failed to load story'),
    );
  }

  Widget _buildPollCard(BuildContext context, AsyncValue<Poll?> pollAsync) {
    return pollAsync.when(
      data: (poll) {
        if (poll == null) {
          return _buildEmptyPollCard();
        }
        return _PollCard(poll: poll);
      },
      loading: () => _buildLoadingCard(),
      error: (_, __) => _buildErrorCard('Failed to load poll'),
    );
  }

  Widget _buildSavedStoriesSection(BuildContext context) {
    final savedStoriesAsync = ref.watch(savedStoriesProvider);
    
    return savedStoriesAsync.when(
      data: (savedStories) {
        if (savedStories.isEmpty) return const SizedBox.shrink();
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _buildSectionTitle('Saved Stories', '🔖'),
            const SizedBox(height: 12),
            SizedBox(
              height: 140,
              child: ListView.builder(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                itemCount: savedStories.length,
                itemBuilder: (context, index) {
                  final story = savedStories[index];
                  return Padding(
                    padding: EdgeInsets.only(right: index < savedStories.length - 1 ? 12 : 0),
                    child: _SavedStoryCard(
                      story: story,
                      onTap: () => context.push('/story/${story.storyId}'),
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 28),
          ],
        );
      },
      loading: () => const SizedBox.shrink(),
      error: (_, __) => const SizedBox.shrink(),
    );
  }

  Widget _buildPastStoriesSection(BuildContext context) {
    final pastStoriesAsync = ref.watch(pastStoriesProvider);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            _buildSectionTitle('Past Stories', '📚'),
            TextButton(
              onPressed: () {
                // Could navigate to full archive page
              },
              child: Text(
                'See All',
                style: TextStyle(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 12),
        pastStoriesAsync.when(
          data: (stories) {
            if (stories.isEmpty) {
              return _buildEmptyArchiveCard();
            }
            return Column(
              children: stories.take(5).map((story) {
                final isRead = ref.watch(isStoryReadProvider(story.storyId));
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: _ArchiveStoryCard(
                    story: story,
                    isRead: isRead,
                    onTap: () => context.push('/story/${story.storyId}'),
                  ),
                );
              }).toList(),
            );
          },
          loading: () => _buildLoadingCard(),
          error: (_, __) => _buildErrorCard('Failed to load archive'),
        ),
      ],
    );
  }

  Widget _buildEmptyArchiveCard() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: AppColors.surfaceLight,
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(Icons.auto_stories, color: AppColors.textMuted, size: 24),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'No past stories yet',
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimary,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  'Previous stories will appear here',
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
    );
  }

  Widget _buildEmptyStoryCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text('📖', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'No story this week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back soon for inspiring content',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyPollCard() {
    return Container(
      padding: const EdgeInsets.all(32),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          const Text('📊', style: TextStyle(fontSize: 48)),
          const SizedBox(height: 16),
          const Text(
            'No poll this week',
            style: TextStyle(
              fontSize: 16,
              fontWeight: FontWeight.w600,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Check back soon to share your opinion',
            style: TextStyle(
              fontSize: 14,
              color: AppColors.textSecondary,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLoadingCard() {
    return Container(
      height: 200,
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.border),
      ),
      child: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }

  Widget _buildErrorCard(String message) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: AppColors.error.withOpacity(0.1),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppColors.error.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Icon(Icons.error_outline, color: AppColors.error, size: 40),
          const SizedBox(height: 12),
          Text(
            message,
            style: TextStyle(
              fontSize: 14,
              color: AppColors.error,
            ),
          ),
        ],
      ),
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
// STORY CARD
// ============================================================================

class _StoryCard extends StatelessWidget {
  final Story story;
  final VoidCallback onTap;

  const _StoryCard({required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(20),
          boxShadow: [
            BoxShadow(
              color: AppColors.primary.withOpacity(0.15),
              blurRadius: 20,
              offset: const Offset(0, 8),
            ),
          ],
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(20),
          child: Stack(
            children: [
              // Background gradient
              Container(
                height: 220,
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
              ),

              // Pattern overlay
              Positioned.fill(
                child: Opacity(
                  opacity: 0.1,
                  child: Image.network(
                    'https://www.transparenttextures.com/patterns/cubes.png',
                    repeat: ImageRepeat.repeat,
                    errorBuilder: (_, __, ___) => const SizedBox(),
                  ),
                ),
              ),

              // Content
              Padding(
                padding: const EdgeInsets.all(24),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Tag and reading time
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                          decoration: BoxDecoration(
                            color: Colors.white.withOpacity(0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            story.category ?? 'Faith',
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.white.withOpacity(0.95),
                            ),
                          ),
                        ),
                        const Spacer(),
                        Icon(Icons.schedule, color: Colors.white.withOpacity(0.8), size: 14),
                        const SizedBox(width: 4),
                        Text(
                          '${story.estimatedReadTime ?? 3} min read',
                          style: TextStyle(
                            fontSize: 12,
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
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        color: Colors.white,
                        height: 1.3,
                      ),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const Spacer(),

                    // Bottom row
                    Row(
                      children: [
                        // Author
                        CircleAvatar(
                          radius: 14,
                          backgroundColor: Colors.white.withOpacity(0.2),
                          child: Text(
                            story.author?.isNotEmpty == true ? story.author![0] : 'N',
                            style: const TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Text(
                          story.author ?? 'Nexus Team',
                          style: TextStyle(
                            fontSize: 13,
                            color: Colors.white.withOpacity(0.9),
                          ),
                        ),
                        const Spacer(),

                        // Read button
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                          decoration: BoxDecoration(
                            color: Colors.white,
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Read',
                                style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.primary,
                                ),
                              ),
                              const SizedBox(width: 4),
                              Icon(Icons.arrow_forward, size: 16, color: AppColors.primary),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// POLL CARD
// ============================================================================

class _PollCard extends ConsumerStatefulWidget {
  final Poll poll;

  const _PollCard({required this.poll});

  @override
  ConsumerState<_PollCard> createState() => _PollCardState();
}

class _PollCardState extends ConsumerState<_PollCard> {
  String? _selectedOption;
  bool _hasVoted = false;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
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
          // Question
          Text(
            widget.poll.question,
            style: const TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),

          // Options
          ...widget.poll.options.map((option) {
            final isSelected = _selectedOption == option.optionId;
            final percentage = _hasVoted ? (option.voteCount / _getTotalVotes() * 100) : 0.0;

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: _PollOption(
                text: option.text,
                percentage: percentage,
                isSelected: isSelected,
                hasVoted: _hasVoted,
                onTap: _hasVoted ? null : () => _selectOption(option.optionId),
              ),
            );
          }),

          const SizedBox(height: 8),

          // Vote count and vote button
          Row(
            children: [
              Icon(Icons.people_outline, size: 16, color: AppColors.textMuted),
              const SizedBox(width: 6),
              Text(
                '${_getTotalVotes()} votes',
                style: TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              if (!_hasVoted && _selectedOption != null)
                ElevatedButton(
                  onPressed: _submitVote,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Vote',
                    style: TextStyle(fontWeight: FontWeight.w600),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  void _selectOption(String optionId) {
    HapticFeedback.lightImpact();
    setState(() => _selectedOption = optionId);
  }

  Future<void> _submitVote() async {
    if (_selectedOption == null) return;
    
    HapticFeedback.mediumImpact();
    
    final userId = ref.read(currentUserIdProvider);
    if (userId == null) return;

    try {
      final pollRef = FirebaseFirestore.instance
          .collection('polls')
          .doc(widget.poll.id);

      // Use a transaction to safely increment vote count
      await FirebaseFirestore.instance.runTransaction((transaction) async {
        final pollDoc = await transaction.get(pollRef);
        if (!pollDoc.exists) return;

        final data = pollDoc.data()!;
        final options = List<Map<String, dynamic>>.from(data['options'] ?? []);
        
        // Find and increment the selected option's vote count
        for (var i = 0; i < options.length; i++) {
          if (options[i]['optionId'] == _selectedOption) {
            options[i]['voteCount'] = (options[i]['voteCount'] ?? 0) + 1;
            break;
          }
        }

        // Update poll with new vote count
        transaction.update(pollRef, {
          'options': options,
          'totalVotes': FieldValue.increment(1),
        });

        // Record user's vote to prevent duplicate voting
        transaction.set(
          pollRef.collection('votes').doc(userId),
          {
            'optionId': _selectedOption,
            'votedAt': FieldValue.serverTimestamp(),
          },
        );
      });

      setState(() => _hasVoted = true);
      
      // Refresh polls data
      ref.invalidate(pollsProvider);
      
    } catch (e) {
      debugPrint('Error submitting vote: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: const Text('Failed to submit vote. Please try again.'),
            backgroundColor: AppColors.error,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  int _getTotalVotes() {
    return widget.poll.options.fold(0, (sum, opt) => sum + opt.voteCount);
  }
}

class _PollOption extends StatelessWidget {
  final String text;
  final double percentage;
  final bool isSelected;
  final bool hasVoted;
  final VoidCallback? onTap;

  const _PollOption({
    required this.text,
    required this.percentage,
    required this.isSelected,
    required this.hasVoted,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: isSelected
              ? AppColors.primarySoft
              : hasVoted
                  ? AppColors.surfaceLight
                  : AppColors.surface,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: isSelected ? AppColors.primary : AppColors.border,
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Stack(
          children: [
            // Progress bar (shown after voting)
            if (hasVoted)
              Positioned.fill(
                child: FractionallySizedBox(
                  alignment: Alignment.centerLeft,
                  widthFactor: percentage / 100,
                  child: Container(
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppColors.primary.withOpacity(0.15)
                          : AppColors.surfaceDark.withOpacity(0.5),
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),

            // Content
            Row(
              children: [
                // Radio indicator
                AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  width: 22,
                  height: 22,
                  decoration: BoxDecoration(
                    color: isSelected ? AppColors.primary : Colors.transparent,
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: isSelected ? AppColors.primary : AppColors.textMuted,
                      width: 2,
                    ),
                  ),
                  child: isSelected
                      ? const Icon(Icons.check, size: 14, color: Colors.white)
                      : null,
                ),
                const SizedBox(width: 14),

                // Text
                Expanded(
                  child: Text(
                    text,
                    style: TextStyle(
                      fontSize: 15,
                      fontWeight: isSelected ? FontWeight.w600 : FontWeight.w500,
                      color: isSelected ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                ),

                // Percentage (after voting)
                if (hasVoted)
                  Text(
                    '${percentage.toStringAsFixed(0)}%',
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                      color: isSelected ? AppColors.primary : AppColors.textSecondary,
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SAVED STORY CARD (Horizontal scroll)
// ============================================================================

class _SavedStoryCard extends StatelessWidget {
  final Story story;
  final VoidCallback onTap;

  const _SavedStoryCard({required this.story, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 200,
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.primarySoft,
              AppColors.surface,
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.primary.withOpacity(0.2)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.15),
                    borderRadius: BorderRadius.circular(6),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(Icons.bookmark, size: 12, color: AppColors.primary),
                      const SizedBox(width: 4),
                      Text(
                        'Saved',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.w600,
                          color: AppColors.primary,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Text(
              story.title,
              style: const TextStyle(
                fontSize: 14,
                fontWeight: FontWeight.w600,
                color: AppColors.textPrimary,
              ),
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
            ),
            const Spacer(),
            Row(
              children: [
                Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
                const SizedBox(width: 4),
                Text(
                  story.readingTime,
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ARCHIVE STORY CARD (Vertical list)
// ============================================================================

class _ArchiveStoryCard extends StatelessWidget {
  final Story story;
  final bool isRead;
  final VoidCallback onTap;

  const _ArchiveStoryCard({
    required this.story,
    required this.isRead,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            // Category icon
            Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color: isRead ? AppColors.surfaceLight : AppColors.primarySoft,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Center(
                child: Text(
                  _getCategoryEmoji(story.category),
                  style: const TextStyle(fontSize: 22),
                ),
              ),
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
                          story.title,
                          style: TextStyle(
                            fontSize: 15,
                            fontWeight: FontWeight.w600,
                            color: isRead ? AppColors.textSecondary : AppColors.textPrimary,
                          ),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      if (isRead)
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          decoration: BoxDecoration(
                            color: AppColors.success.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(Icons.check_circle, size: 12, color: AppColors.success),
                              const SizedBox(width: 4),
                              Text(
                                'Read',
                                style: TextStyle(
                                  fontSize: 10,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.success,
                                ),
                              ),
                            ],
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceLight,
                          borderRadius: BorderRadius.circular(4),
                        ),
                        child: Text(
                          story.category,
                          style: TextStyle(
                            fontSize: 10,
                            fontWeight: FontWeight.w500,
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Icon(Icons.schedule, size: 12, color: AppColors.textMuted),
                      const SizedBox(width: 4),
                      Text(
                        story.readingTime,
                        style: TextStyle(
                          fontSize: 11,
                          color: AppColors.textMuted,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            // Arrow
            Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
          ],
        ),
      ),
    );
  }

  String _getCategoryEmoji(String category) {
    switch (category.toLowerCase()) {
      case 'marriage':
        return '💍';
      case 'faith':
        return '🙏';
      case 'singles':
        return '💕';
      case 'parenting':
        return '👨‍👩‍👧';
      case 'finance':
        return '💰';
      case 'communication':
        return '💬';
      default:
        return '📖';
    }
  }
}
