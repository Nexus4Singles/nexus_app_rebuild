import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../constants/app_constants.dart';

/// Story content block
class ContentBlock extends Equatable {
  final String type;
  final String? text;
  final String? attribution;
  final List<String>? items;

  const ContentBlock({
    required this.type,
    this.text,
    this.attribution,
    this.items,
  });

  factory ContentBlock.fromJson(Map<String, dynamic> json) {
    // Accept both 'text' (legacy) and 'content' (remote) field names
    final blockText = (json['content'] ?? json['text']) as String?;
    return ContentBlock(
      type: json['type'] as String,
      text: blockText,
      attribution: json['attribution'] as String?,
      items:
          (json['items'] as List<dynamic>?)?.map((e) => e.toString()).toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type,
    if (text != null) 'text': text,
    if (attribution != null) 'attribution': attribution,
    if (items != null) 'items': items,
  };

  ContentBlockType get blockType => ContentBlockType.fromValue(type);

  @override
  List<Object?> get props => [type, text, attribution, items];
}

/// Story reflection prompt
class ReflectionPrompt extends Equatable {
  final String promptId;
  final String text;
  final String responseType;
  final int maxChars;

  const ReflectionPrompt({
    required this.promptId,
    required this.text,
    required this.responseType,
    required this.maxChars,
  });

  factory ReflectionPrompt.fromJson(Map<String, dynamic> json) {
    return ReflectionPrompt(
      promptId: json['promptId'] as String,
      text: json['text'] as String,
      responseType: json['responseType'] as String? ?? 'short_text',
      maxChars: json['maxChars'] as int? ?? 200,
    );
  }

  Map<String, dynamic> toJson() => {
    'promptId': promptId,
    'text': text,
    'responseType': responseType,
    'maxChars': maxChars,
  };

  @override
  List<Object?> get props => [promptId, text, responseType, maxChars];
}

/// Story action step
class ActionStep extends Equatable {
  final String title;
  final String instructions;
  final int estimatedMins;
  final String completionSignalTag;

  const ActionStep({
    required this.title,
    required this.instructions,
    required this.estimatedMins,
    required this.completionSignalTag,
  });

  factory ActionStep.fromJson(Map<String, dynamic> json) {
    return ActionStep(
      title: json['title'] as String,
      instructions: json['instructions'] as String,
      estimatedMins: json['estimatedMins'] as int? ?? 5,
      completionSignalTag: json['completionSignalTag'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'title': title,
    'instructions': instructions,
    'estimatedMins': estimatedMins,
    'completionSignalTag': completionSignalTag,
  };

  @override
  List<Object?> get props => [
    title,
    instructions,
    estimatedMins,
    completionSignalTag,
  ];
}

/// Story configuration
class Story extends Equatable {
  final String storyId;
  final int weekNumber;
  final String publishDate;
  final List<String> audiences;
  final List<String> tags;
  final String title;
  final String subtitle;
  final int readingTimeMins;
  final String? heroImage;
  final List<ContentBlock> contentBlocks;
  final List<String> keyLessons;
  final List<ReflectionPrompt> reflectionPrompts;
  final ActionStep? actionStep;
  final String pollId;
  final List<String> recommendedProductIds;
  // Additional fields for UI compatibility
  final String? authorName;
  final String? categoryName;
  final String? openingHookText;
  final String? contentText;

  const Story({
    required this.storyId,
    required this.weekNumber,
    required this.publishDate,
    required this.audiences,
    required this.tags,
    required this.title,
    required this.subtitle,
    required this.readingTimeMins,
    this.heroImage,
    required this.contentBlocks,
    required this.keyLessons,
    required this.reflectionPrompts,
    this.actionStep,
    required this.pollId,
    required this.recommendedProductIds,
    this.authorName,
    this.categoryName,
    this.openingHookText,
    this.contentText,
  });

  // Alias getters for UI compatibility
  String get id => storyId;
  String? get imageUrl => heroImage;
  String get audience => audiences.isNotEmpty ? audiences.first : 'all';
  String? get category => categoryName ?? (tags.isNotEmpty ? tags.first : null);
  int get estimatedReadTime => readingTimeMins;
  String? get author => authorName;
  String? get openingHook => openingHookText;
  String? get content => contentText ?? _buildContentFromBlocks();
  String get readingTime => '$readingTimeMins min read';

  String? _buildContentFromBlocks() {
    if (contentBlocks.isEmpty) return null;
    return contentBlocks
        .where((b) => b.text != null)
        .map((b) => b.text)
        .join('\n\n');
  }

  factory Story.fromJson(Map<String, dynamic> json) {
    return Story(
      storyId: json['storyId'] as String,
      weekNumber: json['weekNumber'] as int,
      publishDate: json['publishDate'] as String,
      audiences:
          (json['audiences'] as List<dynamic>)
              .map((e) => e.toString())
              .toList(),
      tags:
          (json['tags'] as List<dynamic>?)?.map((e) => e.toString()).toList() ??
          [],
      title: json['title'] as String,
      subtitle: json['subtitle'] as String? ?? '',
      readingTimeMins: json['readingTimeMins'] as int? ?? 5,
      heroImage: json['heroImage'] as String?,
      contentBlocks:
          (json['contentBlocks'] as List<dynamic>?)
              ?.map((e) => ContentBlock.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      keyLessons:
          (json['keyLessons'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      reflectionPrompts:
          (json['reflectionPrompts'] as List<dynamic>?)
              ?.map((e) => ReflectionPrompt.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      actionStep:
          json['actionStep'] != null
              ? ActionStep.fromJson(json['actionStep'] as Map<String, dynamic>)
              : null,
      pollId: json['pollId'] as String? ?? '',
      recommendedProductIds:
          (json['recommendedProductIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      authorName: json['author'] as String?,
      categoryName: json['category'] as String?,
      openingHookText: json['openingHook'] as String?,
      contentText: json['content'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'storyId': storyId,
    'weekNumber': weekNumber,
    'publishDate': publishDate,
    'audiences': audiences,
    'tags': tags,
    'title': title,
    'subtitle': subtitle,
    'readingTimeMins': readingTimeMins,
    if (heroImage != null) 'heroImage': heroImage,
    'contentBlocks': contentBlocks.map((e) => e.toJson()).toList(),
    'keyLessons': keyLessons,
    'reflectionPrompts': reflectionPrompts.map((e) => e.toJson()).toList(),
    if (actionStep != null) 'actionStep': actionStep!.toJson(),
    'pollId': pollId,
    'recommendedProductIds': recommendedProductIds,
    if (authorName != null) 'author': authorName,
    if (categoryName != null) 'category': categoryName,
    if (openingHookText != null) 'openingHook': openingHookText,
    if (contentText != null) 'content': contentText,
  };

  bool isVisibleTo(String audience) {
    return audiences.contains(audience) || audiences.contains('all');
  }

  String get formattedReadingTime => '$readingTimeMins min read';

  @override
  List<Object?> get props => [
    storyId,
    weekNumber,
    publishDate,
    audiences,
    tags,
    title,
    subtitle,
    readingTimeMins,
    heroImage,
    contentBlocks,
    keyLessons,
    reflectionPrompts,
    actionStep,
    pollId,
    recommendedProductIds,
  ];
}

/// Stories catalog
class StoriesCatalog extends Equatable {
  final String version;
  final List<Story> stories;

  const StoriesCatalog({required this.version, required this.stories});

  factory StoriesCatalog.fromJson(Map<String, dynamic> json) {
    final rawV = json['version'];
    final versionStr =
        rawV == null ? 'v1' : (rawV is String ? rawV : 'v${rawV.toString()}');
    return StoriesCatalog(
      version: versionStr,
      stories:
          (json['stories'] as List<dynamic>)
              .map((e) => Story.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'stories': stories.map((e) => e.toJson()).toList(),
  };

  Story? findStory(String storyId) {
    try {
      return stories.firstWhere((s) => s.storyId == storyId);
    } catch (_) {
      return null;
    }
  }

  List<Story> getStoriesForAudience(String audience) {
    return stories.where((s) => s.isVisibleTo(audience)).toList();
  }

  Story? get currentStoryOfWeek {
    if (stories.isEmpty) return null;
    final now = DateTime.now();

    final validStories =
        stories.where((s) {
          try {
            final pubDate = DateTime.parse(s.publishDate);
            return pubDate.isBefore(now) || pubDate.isAtSameMomentAs(now);
          } catch (_) {
            return true;
          }
        }).toList();

    if (validStories.isEmpty) return stories.first;

    return validStories.reduce((a, b) {
      try {
        final aDate = DateTime.parse(a.publishDate);
        final bDate = DateTime.parse(b.publishDate);
        return aDate.isAfter(bDate) ? a : b;
      } catch (_) {
        return a.weekNumber > b.weekNumber ? a : b;
      }
    });
  }

  @override
  List<Object?> get props => [version, stories];
}

/// Poll option
class PollOption extends Equatable {
  final String id;
  final String text;
  final List<String> inferredTags;
  final String insightCopy;
  final List<String> recommendedProductIds;
  final int votes;

  const PollOption({
    required this.id,
    required this.text,
    required this.inferredTags,
    required this.insightCopy,
    required this.recommendedProductIds,
    this.votes = 0,
  });

  // Alias getters for UI compatibility
  String get optionId => id;
  int get voteCount => votes;

  factory PollOption.fromJson(Map<String, dynamic> json) {
    return PollOption(
      id: json['id'] as String? ?? json['optionId'] as String? ?? '',
      text: json['text'] as String,
      inferredTags:
          (json['inferredTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      insightCopy: json['insightCopy'] as String? ?? '',
      recommendedProductIds:
          (json['recommendedProductIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      votes: json['votes'] as int? ?? json['voteCount'] as int? ?? 0,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'inferredTags': inferredTags,
    'insightCopy': insightCopy,
    'recommendedProductIds': recommendedProductIds,
    'votes': votes,
  };

  PollOption copyWith({int? votes}) {
    return PollOption(
      id: id,
      text: text,
      inferredTags: inferredTags,
      insightCopy: insightCopy,
      recommendedProductIds: recommendedProductIds,
      votes: votes ?? this.votes,
    );
  }

  @override
  List<Object?> get props => [
    id,
    text,
    inferredTags,
    insightCopy,
    recommendedProductIds,
    votes,
  ];
}

/// Poll configuration
class Poll extends Equatable {
  final String pollId;
  final String storyId;
  final int weekNumber;
  final String question;
  final List<PollOption> options;
  final String defaultInsightCopy;
  final List<String> defaultRecommendedProductIds;

  const Poll({
    required this.pollId,
    required this.storyId,
    required this.weekNumber,
    required this.question,
    required this.options,
    required this.defaultInsightCopy,
    required this.defaultRecommendedProductIds,
  });

  // Alias getter for UI compatibility
  String get id => pollId;

  factory Poll.fromJson(Map<String, dynamic> json) {
    return Poll(
      pollId: json['pollId'] as String? ?? json['id'] as String? ?? '',
      storyId: json['storyId'] as String? ?? '',
      weekNumber: int.tryParse(json['weekNumber'].toString()) ?? 0,
      question: json['question'] as String,
      options:
          (json['options'] as List<dynamic>)
              .map((e) => PollOption.fromJson(e as Map<String, dynamic>))
              .toList(),
      defaultInsightCopy: json['defaultInsightCopy'] as String? ?? '',
      defaultRecommendedProductIds:
          (json['defaultRecommendedProductIds'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  Map<String, dynamic> toJson() => {
    'pollId': pollId,
    'storyId': storyId,
    'weekNumber': weekNumber,
    'question': question,
    'options': options.map((e) => e.toJson()).toList(),
    'defaultInsightCopy': defaultInsightCopy,
    'defaultRecommendedProductIds': defaultRecommendedProductIds,
  };

  PollOption? findOption(String optionId) {
    try {
      return options.firstWhere((o) => o.id == optionId);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [
    pollId,
    storyId,
    weekNumber,
    question,
    options,
    defaultInsightCopy,
    defaultRecommendedProductIds,
  ];
}

/// Polls catalog
class PollsCatalog extends Equatable {
  final String version;
  final List<Poll> polls;

  const PollsCatalog({required this.version, required this.polls});

  factory PollsCatalog.fromJson(Map<String, dynamic> json) {
    return PollsCatalog(
      version: json['version'].toString(),
      polls:
          (json['polls'] as List<dynamic>)
              .map((e) => Poll.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'polls': polls.map((e) => e.toJson()).toList(),
  };

  Poll? findPoll(String pollId) {
    try {
      return polls.firstWhere((p) => p.pollId == pollId);
    } catch (_) {
      return null;
    }
  }

  Poll? findPollForStory(String storyId) {
    try {
      return polls.firstWhere((p) => p.storyId == storyId);
    } catch (_) {
      return null;
    }
  }

  @override
  List<Object?> get props => [version, polls];
}

/// User's poll vote record
class PollVote extends Equatable {
  final String visitorId;
  final String pollId;
  final String storyId;
  final String userId;
  final String selectedOptionId;
  final List<String> inferredTags;
  final DateTime createdAt;

  const PollVote({
    required this.visitorId,
    required this.pollId,
    required this.storyId,
    required this.userId,
    required this.selectedOptionId,
    required this.inferredTags,
    required this.createdAt,
  });

  factory PollVote.fromJson(Map<String, dynamic> json) {
    return PollVote(
      visitorId: json['visitorId'] as String? ?? json['id'] as String? ?? '',
      pollId: json['pollId'] as String,
      storyId: json['storyId'] as String,
      userId: json['userId'] as String,
      selectedOptionId: json['selectedOptionId'] as String,
      inferredTags:
          (json['inferredTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      createdAt:
          json['createdAt'] != null
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  factory PollVote.fromFirestore(Map<String, dynamic> json) {
    return PollVote.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
    'visitorId': visitorId,
    'pollId': pollId,
    'storyId': storyId,
    'userId': userId,
    'selectedOptionId': selectedOptionId,
    'inferredTags': inferredTags,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  Map<String, dynamic> toFirestore() => toJson();

  @override
  List<Object?> get props => [
    visitorId,
    pollId,
    storyId,
    userId,
    selectedOptionId,
    inferredTags,
    createdAt,
  ];
}

/// Poll aggregate results
class PollAggregate extends Equatable {
  final String pollId;
  final int totalVotes;
  final Map<String, int> optionCounts;
  final DateTime updatedAt;

  const PollAggregate({
    required this.pollId,
    required this.totalVotes,
    required this.optionCounts,
    required this.updatedAt,
  });

  factory PollAggregate.fromJson(Map<String, dynamic> json) {
    return PollAggregate(
      pollId: json['pollId'] as String,
      totalVotes: json['totalVotes'] as int? ?? 0,
      optionCounts:
          (json['optionCounts'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(k, v as int),
          ) ??
          {},
      updatedAt:
          json['updatedAt'] != null
              ? (json['updatedAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  factory PollAggregate.fromFirestore(Map<String, dynamic> json) {
    return PollAggregate.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
    'pollId': pollId,
    'totalVotes': totalVotes,
    'optionCounts': optionCounts,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  double getPercentage(String optionId) {
    if (totalVotes == 0) return 0;
    return (optionCounts[optionId] ?? 0) / totalVotes * 100;
  }

  @override
  List<Object?> get props => [pollId, totalVotes, optionCounts, updatedAt];
}

/// User's story progress
class StoryProgress extends Equatable {
  final String storyId;
  final String visitorId;
  final String readStatus; // 'started' | 'completed'
  final bool isSaved;
  final bool reflectionDone;
  final DateTime? completedAt;
  final DateTime? lastOpenedAt;

  const StoryProgress({
    required this.storyId,
    required this.visitorId,
    this.readStatus = 'started',
    this.isSaved = false,
    this.reflectionDone = false,
    this.completedAt,
    this.lastOpenedAt,
  });

  // Alias getters for compatibility
  String get userId => visitorId;
  bool get saved => isSaved;
  bool get reflectionCompleted => reflectionDone;
  bool get isRead => readStatus == 'completed';
  bool get isCompleted => readStatus == 'completed';

  factory StoryProgress.fromJson(Map<String, dynamic> json) {
    return StoryProgress(
      storyId: json['storyId'] as String,
      visitorId:
          json['visitorId'] as String? ?? json['userId'] as String? ?? '',
      readStatus: json['readStatus'] as String? ?? 'started',
      isSaved: json['isSaved'] as bool? ?? json['saved'] as bool? ?? false,
      reflectionDone:
          json['reflectionDone'] as bool? ??
          json['reflectionCompleted'] as bool? ??
          false,
      completedAt:
          json['completedAt'] != null
              ? (json['completedAt'] as Timestamp).toDate()
              : null,
      lastOpenedAt:
          json['lastOpenedAt'] != null
              ? (json['lastOpenedAt'] as Timestamp).toDate()
              : null,
    );
  }

  factory StoryProgress.fromFirestore(Map<String, dynamic> json) {
    return StoryProgress.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
    'storyId': storyId,
    'visitorId': visitorId,
    'readStatus': readStatus,
    'isSaved': isSaved,
    'reflectionDone': reflectionDone,
    if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
    if (lastOpenedAt != null) 'lastOpenedAt': Timestamp.fromDate(lastOpenedAt!),
  };

  Map<String, dynamic> toFirestore() => toJson();

  StoryProgress copyWith({
    String? storyId,
    String? visitorId,
    String? readStatus,
    bool? isSaved,
    bool? reflectionDone,
    DateTime? completedAt,
    DateTime? lastOpenedAt,
  }) {
    return StoryProgress(
      storyId: storyId ?? this.storyId,
      visitorId: visitorId ?? this.visitorId,
      readStatus: readStatus ?? this.readStatus,
      isSaved: isSaved ?? this.isSaved,
      reflectionDone: reflectionDone ?? this.reflectionDone,
      completedAt: completedAt ?? this.completedAt,
      lastOpenedAt: lastOpenedAt ?? this.lastOpenedAt,
    );
  }

  @override
  List<Object?> get props => [
    storyId,
    visitorId,
    readStatus,
    isSaved,
    reflectionDone,
    completedAt,
    lastOpenedAt,
  ];
}

/// Story like record
class StoryLike extends Equatable {
  final String visitorId;
  final String storyId;
  final String userId;
  final String? userName;
  final DateTime createdAt;

  const StoryLike({
    required this.visitorId,
    required this.storyId,
    required this.userId,
    this.userName,
    required this.createdAt,
  });

  String get id => visitorId;

  factory StoryLike.fromJson(Map<String, dynamic> json) {
    return StoryLike(
      visitorId: json['visitorId'] as String? ?? json['id'] as String? ?? '',
      storyId: json['storyId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String?,
      createdAt:
          json['createdAt'] != null
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'visitorId': visitorId,
    'storyId': storyId,
    'userId': userId,
    if (userName != null) 'userName': userName,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  @override
  List<Object?> get props => [visitorId, storyId, userId, userName, createdAt];
}

/// Story comment record
class StoryComment extends Equatable {
  final String visitorId;
  final String storyId;
  final String userId;
  final String userName;
  final String? userPhotoUrl;
  final String? parentId;
  final int likeCount;
  final int replyCount;
  final String text;
  final DateTime createdAt;

  const StoryComment({
    required this.visitorId,
    required this.storyId,
    required this.userId,
    required this.userName,
    this.userPhotoUrl,
    this.parentId,
    this.likeCount = 0,
    this.replyCount = 0,
    required this.text,
    required this.createdAt,
  });

  String get id => visitorId;

  factory StoryComment.fromJson(Map<String, dynamic> json) {
    return StoryComment(
      visitorId: json['visitorId'] as String? ?? json['id'] as String? ?? '',
      storyId: json['storyId'] as String,
      userId: json['userId'] as String,
      userName: json['userName'] as String? ?? 'Anonymous',
      userPhotoUrl: json['userPhotoUrl'] as String?,
      parentId: json['parentId'] as String?,
      likeCount: json['likeCount'] as int? ?? 0,
      replyCount: json['replyCount'] as int? ?? 0,
      text: json['text'] as String,
      createdAt:
          json['createdAt'] != null
              ? (json['createdAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'visitorId': visitorId,
    'storyId': storyId,
    'userId': userId,
    'userName': userName,
    if (userPhotoUrl != null) 'userPhotoUrl': userPhotoUrl,
    if (parentId != null) 'parentId': parentId,
    'likeCount': likeCount,
    'replyCount': replyCount,
    'text': text,
    'createdAt': Timestamp.fromDate(createdAt),
  };

  bool get isReply => parentId != null && parentId!.isNotEmpty;

  @override
  List<Object?> get props => [
    visitorId,
    storyId,
    userId,
    userName,
    userPhotoUrl,
    parentId,
    likeCount,
    replyCount,
    text,
    createdAt,
  ];
}

/// Story engagement aggregate
class StoryEngagement extends Equatable {
  final String storyId;
  final int likeCount;
  final int commentCount;
  final int shareCount;
  final DateTime updatedAt;

  const StoryEngagement({
    required this.storyId,
    this.likeCount = 0,
    this.commentCount = 0,
    this.shareCount = 0,
    required this.updatedAt,
  });

  factory StoryEngagement.fromJson(Map<String, dynamic> json) {
    return StoryEngagement(
      storyId: json['storyId'] as String,
      likeCount: json['likeCount'] as int? ?? 0,
      commentCount: json['commentCount'] as int? ?? 0,
      shareCount: json['shareCount'] as int? ?? 0,
      updatedAt:
          json['updatedAt'] != null
              ? (json['updatedAt'] as Timestamp).toDate()
              : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() => {
    'storyId': storyId,
    'likeCount': likeCount,
    'commentCount': commentCount,
    'shareCount': shareCount,
    'updatedAt': Timestamp.fromDate(updatedAt),
  };

  @override
  List<Object?> get props => [
    storyId,
    likeCount,
    commentCount,
    shareCount,
    updatedAt,
  ];
}
