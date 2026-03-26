import 'dart:async';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_v2/core/models/story_model.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import 'package:nexus_app_v2/core/providers/firestore_service_provider.dart';
import 'package:nexus_app_v2/core/services/firestore_service.dart';

class StoryReactionsState {
  final Map<String, StoryEngagement> engagementByStoryId;
  final Map<String, List<StoryComment>> commentsByStoryId;
  final Set<String> likedStoryIds;
  final Map<String, Set<String>> likedCommentsByStoryId;

  const StoryReactionsState({
    required this.engagementByStoryId,
    required this.commentsByStoryId,
    required this.likedStoryIds,
    required this.likedCommentsByStoryId,
  });

  factory StoryReactionsState.initial() => const StoryReactionsState(
    engagementByStoryId: {},
    commentsByStoryId: {},
    likedStoryIds: {},
    likedCommentsByStoryId: {},
  );

  StoryReactionsState copyWith({
    Map<String, StoryEngagement>? engagementByStoryId,
    Map<String, List<StoryComment>>? commentsByStoryId,
    Set<String>? likedStoryIds,
    Map<String, Set<String>>? likedCommentsByStoryId,
  }) {
    return StoryReactionsState(
      engagementByStoryId: engagementByStoryId ?? this.engagementByStoryId,
      commentsByStoryId: commentsByStoryId ?? this.commentsByStoryId,
      likedStoryIds: likedStoryIds ?? this.likedStoryIds,
      likedCommentsByStoryId:
          likedCommentsByStoryId ?? this.likedCommentsByStoryId,
    );
  }
}

class StoryReactionsController extends StateNotifier<StoryReactionsState> {
  StoryReactionsController(this._ref, this._firestore)
    : super(StoryReactionsState.initial());

  final Ref _ref;
  final FirestoreService _firestore;

  final Map<String, StreamSubscription> _engagementSubs = {};
  final Map<String, StreamSubscription> _commentsSubs = {};
  final Map<String, StreamSubscription> _likeSubs = {};
  final Map<String, StreamSubscription> _commentLikesSubs = {};

  String? get _userId => _ref.read(currentUserIdProvider);

  Future<String> _getUserName(User user) async {
    // Try to get username from Firestore user profile
    final username = await _firestore.getUserUsername(user.uid);
    if (username != null && username.isNotEmpty) {
      return username;
    }

    // Fall back to displayName or email
    final display = user.displayName?.trim();
    if (display != null && display.isNotEmpty) return display;
    final email = user.email?.trim();
    if (email != null && email.isNotEmpty) return email;
    return 'Nexus user';
  }

  void ensureStory(String storyId) {
    _engagementSubs[storyId] ??= _firestore
        .watchStoryEngagement(storyId)
        .listen((engagement) {
          if (engagement == null) return;
          final next = Map<String, StoryEngagement>.from(
            state.engagementByStoryId,
          );
          next[storyId] = engagement;
          state = state.copyWith(engagementByStoryId: next);
        });

    _commentsSubs[storyId] ??= _firestore.watchStoryComments(storyId).listen((
      comments,
    ) {
      final next = Map<String, List<StoryComment>>.from(
        state.commentsByStoryId,
      );
      next[storyId] = comments;
      state = state.copyWith(commentsByStoryId: next);
    });

    final uid = _userId;
    if (uid != null && !_likeSubs.containsKey(storyId)) {
      _likeSubs[storyId] = _firestore.watchUserLikedStory(storyId, uid).listen((
        liked,
      ) {
        final next = Set<String>.from(state.likedStoryIds);
        if (liked) {
          next.add(storyId);
        } else {
          next.remove(storyId);
        }
        state = state.copyWith(likedStoryIds: next);
      });
    }

    // Watch which comments the user has liked
    if (uid != null && !_commentLikesSubs.containsKey(storyId)) {
      _commentLikesSubs[storyId] = _firestore
          .watchUserLikedComments(storyId, uid)
          .listen((likedCommentIds) {
            final nextLikedMap = Map<String, Set<String>>.from(
              state.likedCommentsByStoryId,
            );
            nextLikedMap[storyId] = likedCommentIds;
            state = state.copyWith(likedCommentsByStoryId: nextLikedMap);
          });
    }
  }

  bool isLiked(String storyId) => state.likedStoryIds.contains(storyId);

  int likeCount(String storyId) =>
      state.engagementByStoryId[storyId]?.likeCount ?? 0;

  int commentCount(String storyId) =>
      state.engagementByStoryId[storyId]?.commentCount ?? 0;

  List<StoryComment> commentsFor(String storyId) =>
      List.unmodifiable(state.commentsByStoryId[storyId] ?? const []);

  bool isCommentLiked(String storyId, String commentId) =>
      state.likedCommentsByStoryId[storyId]?.contains(commentId) ?? false;

  Future<void> toggleLike(String storyId) async {
    ensureStory(storyId);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('User must be signed in to like');
    }

    final liked = state.likedStoryIds.contains(storyId);
    if (liked) {
      await _firestore.unlikeStory(storyId: storyId, userId: user.uid);
    } else {
      final userName = await _getUserName(user);
      await _firestore.likeStory(
        storyId: storyId,
        userId: user.uid,
        userName: userName,
      );
    }
  }

  Future<void> _addCommentInternal(
    String storyId,
    String text, {
    String? parentId,
  }) async {
    ensureStory(storyId);
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('User must be signed in to comment');
    }

    final userName = await _getUserName(user);
    await _firestore.addStoryComment(
      storyId: storyId,
      userId: user.uid,
      userName: userName,
      parentId: parentId,
      text: trimmed,
    );
    // No optimistic insert needed — the watchStoryComments stream
    // (set up in ensureStory) already updates state via Firestore's
    // latency-compensated snapshots() listener.
  }

  Future<void> addComment(String storyId, String text) async {
    await _addCommentInternal(storyId, text, parentId: null);
  }

  Future<void> addReply(String storyId, String parentId, String text) async {
    await _addCommentInternal(storyId, text, parentId: parentId);
  }

  Future<void> deleteComment(String storyId, String commentId) async {
    await _firestore.deleteStoryComment(storyId: storyId, commentId: commentId);
  }

  Future<void> toggleCommentLike(String storyId, String commentId) async {
    ensureStory(storyId);
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous) {
      throw StateError('User must be signed in to like comments');
    }

    // Get current state before making changes
    final currentLikedSet = Set<String>.from(
      state.likedCommentsByStoryId[storyId] ?? const {},
    );
    final isCurrentlyLiked = currentLikedSet.contains(commentId);

    // Prepare optimistic update
    final optimisticSet = Set<String>.from(currentLikedSet);
    if (isCurrentlyLiked) {
      optimisticSet.remove(commentId);
    } else {
      optimisticSet.add(commentId);
    }

    try {
      // Apply optimistic update first for better UX
      final optimisticMap = Map<String, Set<String>>.from(
        state.likedCommentsByStoryId,
      );
      optimisticMap[storyId] = optimisticSet;
      state = state.copyWith(likedCommentsByStoryId: optimisticMap);

      // Now attempt the actual Firestore operation
      if (isCurrentlyLiked) {
        await _firestore.unlikeComment(
          storyId: storyId,
          commentId: commentId,
          userId: user.uid,
        );
      } else {
        await _firestore.likeComment(
          storyId: storyId,
          commentId: commentId,
          userId: user.uid,
        );
      }

      // Firestore operation succeeded
      // Don't call ensureStory() again yet - let stream listener naturally update
      // But also trigger a refresh of comment data to ensure likeCount is in sync
      // The stream listener will handle updating the state with the fresh data
    } catch (e) {
      // Revert optimistic update on failure
      final revertMap = Map<String, Set<String>>.from(
        state.likedCommentsByStoryId,
      );
      revertMap[storyId] = currentLikedSet;
      state = state.copyWith(likedCommentsByStoryId: revertMap);

      // Log and rethrow for user feedback
      print('Error toggling like: $e');
      rethrow;
    }
  }

  Future<void> incrementShare(String storyId) async {
    await _firestore.incrementShareCount(storyId);
  }

  @override
  void dispose() {
    for (final sub in _engagementSubs.values) {
      sub.cancel();
    }
    for (final sub in _commentsSubs.values) {
      sub.cancel();
    }
    for (final sub in _likeSubs.values) {
      sub.cancel();
    }
    for (final sub in _commentLikesSubs.values) {
      sub.cancel();
    }
    super.dispose();
  }
}

final storyReactionsProvider =
    StateNotifierProvider<StoryReactionsController, StoryReactionsState>((ref) {
      final firestore = ref.watch(firestoreServiceProvider);
      return StoryReactionsController(ref, firestore);
    });
