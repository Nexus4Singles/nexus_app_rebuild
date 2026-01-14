import 'package:flutter_riverpod/flutter_riverpod.dart';

class StoryComment {
  final String id;
  final String text;
  final DateTime createdAt;

  const StoryComment({
    required this.id,
    required this.text,
    required this.createdAt,
  });
}

class StoryReactionsState {
  final Set<String> likedStoryIds;
  final Map<String, List<StoryComment>> commentsByStoryId;

  const StoryReactionsState({
    required this.likedStoryIds,
    required this.commentsByStoryId,
  });

  factory StoryReactionsState.initial() =>
      const StoryReactionsState(likedStoryIds: {}, commentsByStoryId: {});

  StoryReactionsState copyWith({
    Set<String>? likedStoryIds,
    Map<String, List<StoryComment>>? commentsByStoryId,
  }) {
    return StoryReactionsState(
      likedStoryIds: likedStoryIds ?? this.likedStoryIds,
      commentsByStoryId: commentsByStoryId ?? this.commentsByStoryId,
    );
  }
}

class StoryReactionsController extends StateNotifier<StoryReactionsState> {
  StoryReactionsController() : super(StoryReactionsState.initial());

  bool isLiked(String storyId) => state.likedStoryIds.contains(storyId);

  int commentCount(String storyId) =>
      (state.commentsByStoryId[storyId] ?? const []).length;

  List<StoryComment> commentsFor(String storyId) =>
      List.unmodifiable(state.commentsByStoryId[storyId] ?? const []);

  void toggleLike(String storyId) {
    final next = Set<String>.from(state.likedStoryIds);
    if (!next.add(storyId)) next.remove(storyId);
    state = state.copyWith(likedStoryIds: next);
  }

  void addComment(String storyId, String text) {
    final trimmed = text.trim();
    if (trimmed.isEmpty) return;

    final map = Map<String, List<StoryComment>>.from(state.commentsByStoryId);
    final list = List<StoryComment>.from(map[storyId] ?? const []);
    list.insert(
      0,
      StoryComment(
        id: DateTime.now().microsecondsSinceEpoch.toString(),
        text: trimmed,
        createdAt: DateTime.now(),
      ),
    );
    map[storyId] = list;
    state = state.copyWith(commentsByStoryId: map);
  }

  void deleteComment(String storyId, String commentId) {
    final map = Map<String, List<StoryComment>>.from(state.commentsByStoryId);
    final list = List<StoryComment>.from(map[storyId] ?? const []);
    list.removeWhere((c) => c.id == commentId);
    map[storyId] = list;
    state = state.copyWith(commentsByStoryId: map);
  }
}

final storyReactionsProvider =
    StateNotifierProvider<StoryReactionsController, StoryReactionsState>(
      (ref) => StoryReactionsController(),
    );
