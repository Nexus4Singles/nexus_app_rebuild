import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/story_model.dart';
import '../constants/app_constants.dart';
import '../services/config_loader_service.dart';
import 'firestore_service_provider.dart';
import 'package:nexus_app_min_test/core/services/firestore_service.dart';
import 'config_provider.dart';
import 'user_provider.dart';

// ============================================================================
// STORIES CATALOG PROVIDERS
// ============================================================================

/// Provider for stories catalog
final storiesCatalogProvider = FutureProvider<StoriesCatalog?>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadStoriesCatalog();
});

/// Provider for polls catalog
final pollsCatalogProvider = FutureProvider<PollsCatalog?>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadPollsCatalog();
});

/// Provider for current story of the week
final currentStoryProvider = FutureProvider<Story?>((ref) async {
  final catalog = await ref.watch(storiesCatalogProvider.future);
  return catalog?.currentStoryOfWeek;
});

/// Provider for story by ID
final storyByIdProvider = FutureProvider.family<Story?, String>((
  ref,
  storyId,
) async {
  final catalog = await ref.watch(storiesCatalogProvider.future);
  return catalog?.findStory(storyId);
});

/// Provider for poll by story ID
final pollByStoryIdProvider = FutureProvider.family<Poll?, String>((
  ref,
  storyId,
) async {
  final pollsCatalog = await ref.watch(pollsCatalogProvider.future);
  return pollsCatalog?.findPollForStory(storyId);
});

/// Provider for poll by ID
final pollByIdProvider = FutureProvider.family<Poll?, String>((
  ref,
  pollId,
) async {
  final pollsCatalog = await ref.watch(pollsCatalogProvider.future);
  return pollsCatalog?.findPoll(pollId);
});

/// Provider for stories filtered by user's audience
final userStoriesProvider = FutureProvider<List<Story>>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  final catalog = await ref.watch(storiesCatalogProvider.future);

  if (catalog == null) return [];
  final audience = user?.nexus2?.relationshipStatus ?? '';

  if (audience.isEmpty) return catalog.stories;

  return catalog.getStoriesForAudience(audience);
});

/// Provider for past stories (excluding current week)
final pastStoriesProvider = FutureProvider<List<Story>>((ref) async {
  final userStories = await ref.watch(userStoriesProvider.future);
  final now = DateTime.now();

  return userStories.where((s) {
    final publishDate = DateTime.tryParse(s.publishDate);
    if (publishDate == null) return false;
    // Story is in the past if published more than 7 days ago
    return now.difference(publishDate).inDays > 7;
  }).toList();
});

// ============================================================================
// STORY PROGRESS PROVIDERS
// ============================================================================

/// Provider for all story progress for current user
final allStoryProgressProvider = StreamProvider<Map<String, StoryProgress>>((
  ref,
) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value({});

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchAllStoryProgress(user.id);
});

/// Provider for specific story progress
final storyProgressProvider = StreamProvider.family<StoryProgress?, String>((
  ref,
  storyId,
) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchStoryProgress(user.id, storyId);
});

/// Provider for checking if a story is read
final isStoryReadProvider = Provider.family<bool, String>((ref, storyId) {
  final progress = ref.watch(storyProgressProvider(storyId)).valueOrNull;
  return progress?.isRead ?? false;
});

/// Provider for checking if a story is saved
final isStorySavedProvider = Provider.family<bool, String>((ref, storyId) {
  final progress = ref.watch(storyProgressProvider(storyId)).valueOrNull;
  return progress?.saved ?? false;
});

/// Provider for saved stories
final savedStoriesProvider = FutureProvider<List<Story>>((ref) async {
  final allProgress = ref.watch(allStoryProgressProvider).valueOrNull ?? {};
  final catalog = await ref.watch(storiesCatalogProvider.future);

  if (catalog == null) return [];

  final savedIds =
      allProgress.entries
          .where((e) => e.value.saved)
          .map((e) => e.key)
          .toList();

  return catalog.stories.where((s) => savedIds.contains(s.storyId)).toList();
});

// ============================================================================
// POLL VOTING PROVIDERS
// ============================================================================

/// Provider for user's vote on a poll
final userPollVoteProvider = StreamProvider.family<PollVote?, String>((
  ref,
  pollId,
) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value(null);

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchPollVote(pollId, user.id);
});

/// Provider for checking if user has voted on a poll
final hasVotedOnPollProvider = Provider.family<bool, String>((ref, pollId) {
  final vote = ref.watch(userPollVoteProvider(pollId)).valueOrNull;
  return vote != null;
});

/// Provider for poll aggregates (results)
final pollAggregateProvider = StreamProvider.family<PollAggregate?, String>((
  ref,
  pollId,
) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchPollAggregate(pollId);
});

/// Provider for poll results with percentages
final pollResultsProvider = Provider.family<Map<String, double>, String>((
  ref,
  pollId,
) {
  final aggregate = ref.watch(pollAggregateProvider(pollId)).valueOrNull;
  if (aggregate == null) return {};

  final results = <String, double>{};
  for (final optionId in aggregate.optionCounts.keys) {
    results[optionId] = aggregate.getPercentage(optionId);
  }
  return results;
});

// ============================================================================
// STORY ENGAGEMENT PROVIDERS (Like, Comment, Share)
// ============================================================================

/// Provider for story engagement stats
final storyEngagementProvider = StreamProvider.family<StoryEngagement?, String>(
  (ref, storyId) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.watchStoryEngagement(storyId);
  },
);

/// Provider for checking if user has liked a story
final hasUserLikedStoryProvider = StreamProvider.family<bool, String>((
  ref,
  storyId,
) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value(false);

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchUserLikedStory(storyId, user.id);
});

/// Provider for story comments
final storyCommentsProvider = StreamProvider.family<List<StoryComment>, String>(
  (ref, storyId) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.watchStoryComments(storyId);
  },
);

// ============================================================================
// STORY/POLL STATE
// ============================================================================

/// State for viewing a story
class StoryViewState {
  final Story? story;
  final Poll? poll;
  final StoryProgress? progress;
  final PollVote? userVote;
  final PollAggregate? pollAggregate;
  final bool isLoading;
  final String? error;

  const StoryViewState({
    this.story,
    this.poll,
    this.progress,
    this.userVote,
    this.pollAggregate,
    this.isLoading = false,
    this.error,
  });

  StoryViewState copyWith({
    Story? story,
    Poll? poll,
    StoryProgress? progress,
    PollVote? userVote,
    PollAggregate? pollAggregate,
    bool? isLoading,
    String? error,
  }) {
    return StoryViewState(
      story: story ?? this.story,
      poll: poll ?? this.poll,
      progress: progress ?? this.progress,
      userVote: userVote ?? this.userVote,
      pollAggregate: pollAggregate ?? this.pollAggregate,
      isLoading: isLoading ?? this.isLoading,
      error: error,
    );
  }

  /// Whether user has voted
  bool get hasVoted => userVote != null;

  /// Whether story is read
  bool get isRead => progress?.isRead ?? false;

  /// Whether story is saved
  bool get isSaved => progress?.saved ?? false;

  /// Whether reflection is completed
  bool get reflectionCompleted => progress?.reflectionCompleted ?? false;

  /// Get user's selected option from poll
  PollOption? get selectedOption {
    if (poll == null || userVote == null) return null;
    try {
      return poll!.options.firstWhere(
        (o) => o.id == userVote!.selectedOptionId,
      );
    } catch (_) {
      return null;
    }
  }

  /// Get percentage for an option
  double getOptionPercentage(String optionId) {
    return pollAggregate?.getPercentage(optionId) ?? 0.0;
  }
}

// ============================================================================
// STORY VIEW NOTIFIER
// ============================================================================

class StoryViewNotifier extends StateNotifier<StoryViewState> {
  final Ref _ref;
  final FirestoreService _firestoreService;

  StoryViewNotifier(this._ref, this._firestoreService)
    : super(const StoryViewState());

  /// Load a story and its associated poll
  Future<void> loadStory(String storyId) async {
    state = state.copyWith(isLoading: true, error: null);

    try {
      final story = await _ref.read(storyByIdProvider(storyId).future);
      if (story == null) {
        state = state.copyWith(isLoading: false, error: 'Story not found');
        return;
      }

      Poll? poll;
      if (story.pollId.isNotEmpty) {
        poll = await _ref.read(pollByIdProvider(story.pollId).future);
      }

      final user = _ref.read(currentUserProvider).valueOrNull;
      StoryProgress? progress;
      PollVote? userVote;
      PollAggregate? pollAggregate;

      if (user != null) {
        progress = await _ref.read(storyProgressProvider(storyId).future);
        if (poll != null) {
          userVote = await _ref.read(userPollVoteProvider(poll.pollId).future);
          pollAggregate = await _ref.read(
            pollAggregateProvider(poll.pollId).future,
          );
        }
      }

      state = StoryViewState(
        story: story,
        poll: poll,
        progress: progress,
        userVote: userVote,
        pollAggregate: pollAggregate,
      );

      // Mark story as opened if user is logged in
      if (user != null) {
        await _markStoryOpened(user.id, storyId);
      }
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Error loading story: $e',
      );
    }
  }

  /// Mark story as opened
  Future<void> _markStoryOpened(String userId, String storyId) async {
    final progress = StoryProgress(
      storyId: storyId,
      visitorId: userId,
      readStatus: 'opened',
      lastOpenedAt: DateTime.now(),
    );
    await _firestoreService.updateStoryProgress(userId, progress);
  }

  /// Mark story as read (completed)
  Future<void> markAsRead() async {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null || state.story == null) return;

    final progress = StoryProgress(
      storyId: state.story!.storyId,
      visitorId: user.id,
      readStatus: 'completed',
      completedAt: DateTime.now(),
    );
    await _firestoreService.updateStoryProgress(user.id, progress);

    state = state.copyWith(
      progress: (state.progress ??
              StoryProgress(storyId: state.story!.storyId, visitorId: user.id))
          .copyWith(readStatus: 'completed'),
    );
  }

  /// Toggle save status
  Future<void> toggleSaved() async {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null || state.story == null) return;

    final newSavedStatus = !state.isSaved;

    final currentProgress =
        state.progress ??
        StoryProgress(storyId: state.story!.storyId, visitorId: user.id);

    final updatedProgress = currentProgress.copyWith(isSaved: newSavedStatus);
    await _firestoreService.updateStoryProgress(user.id, updatedProgress);

    state = state.copyWith(progress: updatedProgress);
  }

  /// Complete reflection
  Future<void> completeReflection() async {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null || state.story == null) return;

    final currentProgress =
        state.progress ??
        StoryProgress(storyId: state.story!.storyId, visitorId: user.id);

    final updatedProgress = currentProgress.copyWith(reflectionDone: true);
    await _firestoreService.updateStoryProgress(user.id, updatedProgress);

    state = state.copyWith(progress: updatedProgress);
  }

  /// Vote on poll
  Future<void> voteOnPoll(String optionId) async {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null || state.poll == null || state.story == null) return;

    if (state.hasVoted) {
      state = state.copyWith(error: 'You have already voted on this poll');
      return;
    }

    state = state.copyWith(isLoading: true, error: null);

    try {
      final selectedOption = state.poll!.options.firstWhere(
        (o) => o.id == optionId,
        orElse: () => state.poll!.options.first,
      );

      final vote = PollVote(
        visitorId: user.id,
        pollId: state.poll!.pollId,
        storyId: state.story!.storyId,
        userId: user.id,
        selectedOptionId: optionId,
        inferredTags: selectedOption.inferredTags,
        createdAt: DateTime.now(),
      );

      await _firestoreService.savePollVote(vote);

      // Refresh aggregate
      final aggregate = await _ref.refresh(
        pollAggregateProvider(state.poll!.pollId).future,
      );

      state = state.copyWith(
        isLoading: false,
        userVote: vote,
        pollAggregate: aggregate,
      );
    } catch (e) {
      state = state.copyWith(
        isLoading: false,
        error: 'Failed to submit vote: $e',
      );
    }
  }

  /// Reset state
  void reset() {
    state = const StoryViewState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }

  /// Like a story
  Future<void> likeStory() async {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null || state.story == null) return;

    try {
      await _firestoreService.likeStory(
        storyId: state.story!.storyId,
        userId: user.id,
        userName: user.displayName,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to like story: $e');
    }
  }

  /// Unlike a story
  Future<void> unlikeStory() async {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null || state.story == null) return;

    try {
      await _firestoreService.unlikeStory(
        storyId: state.story!.storyId,
        userId: user.id,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to unlike story: $e');
    }
  }

  /// Toggle like status
  Future<bool> toggleLike() async {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null || state.story == null) return false;

    final isLiked = await _firestoreService.hasUserLikedStory(
      state.story!.storyId,
      user.id,
    );

    if (isLiked) {
      await unlikeStory();
      return false;
    } else {
      await likeStory();
      return true;
    }
  }

  /// Add a comment
  Future<StoryComment?> addComment(String text) async {
    final user = _ref.read(currentUserProvider).valueOrNull;
    if (user == null || state.story == null || text.trim().isEmpty) return null;

    try {
      final comment = await _firestoreService.addStoryComment(
        storyId: state.story!.storyId,
        userId: user.id,
        userName: user.displayName,
        userPhotoUrl:
            (user.photos ?? const <String>[]).isNotEmpty
                ? (user.photos ?? const <String>[]).first
                : null,
        text: text.trim(),
      );
      return comment;
    } catch (e) {
      state = state.copyWith(error: 'Failed to add comment: $e');
      return null;
    }
  }

  /// Delete a comment
  Future<void> deleteComment(String commentId) async {
    if (state.story == null) return;

    try {
      await _firestoreService.deleteStoryComment(
        storyId: state.story!.storyId,
        commentId: commentId,
      );
    } catch (e) {
      state = state.copyWith(error: 'Failed to delete comment: $e');
    }
  }

  /// Increment share count
  Future<void> incrementShareCount() async {
    if (state.story == null) return;

    try {
      await _firestoreService.incrementShareCount(state.story!.storyId);
    } catch (e) {
      // Silently fail - sharing is still successful
    }
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for story view notifier
final storyViewNotifierProvider =
    StateNotifierProvider<StoryViewNotifier, StoryViewState>((ref) {
      final firestoreService = ref.watch(firestoreServiceProvider);
      return StoryViewNotifier(ref, firestoreService);
    });

/// Provider for stories with read status enriched
final enrichedStoriesProvider =
    FutureProvider<List<({Story story, bool isRead, bool isSaved})>>((
      ref,
    ) async {
      final stories = await ref.watch(userStoriesProvider.future);
      final allProgress = ref.watch(allStoryProgressProvider).valueOrNull ?? {};

      return stories.map((story) {
        final progress = allProgress[story.storyId];
        return (
          story: story,
          isRead: progress?.isRead ?? false,
          isSaved: progress?.saved ?? false,
        );
      }).toList();
    });

/// Provider for unread story count
final unreadStoryCountProvider = Provider<int>((ref) {
  final enriched = ref.watch(enrichedStoriesProvider).valueOrNull ?? [];
  return enriched.where((e) => !e.isRead).length;
});

/// Provider for stories tab badge visibility
final showStoriesBadgeProvider = Provider<bool>((ref) {
  final unreadCount = ref.watch(unreadStoryCountProvider);
  return unreadCount > 0;
});
