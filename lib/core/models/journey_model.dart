import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../constants/app_constants.dart';

/// Journey session step
class SessionStep extends Equatable {
  final String stepId;
  final String title;
  final String contentType; // teaching, reflection, action, prayer, journal
  final String? content;
  final String? responseType;
  final List<String>? options;
  final int? minSelect;
  final int? maxSelect;
  final String? placeholder;
  final int? maxChars;
  final String? actionInstructions;
  final int? estimatedMins;

  const SessionStep({
    required this.stepId,
    required this.title,
    required this.contentType,
    this.content,
    this.responseType,
    this.options,
    this.minSelect,
    this.maxSelect,
    this.placeholder,
    this.maxChars,
    this.actionInstructions,
    this.estimatedMins,
  });

  factory SessionStep.fromJson(Map<String, dynamic> json) {
    return SessionStep(
      stepId: json['stepId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      contentType: json['contentType'] as String? ?? 'teaching',
      content: json['content'] as String?,
      responseType: json['responseType'] as String?,
      options: (json['options'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList(),
      minSelect: json['minSelect'] as int?,
      maxSelect: json['maxSelect'] as int?,
      placeholder: json['placeholder'] as String?,
      maxChars: json['maxChars'] as int?,
      actionInstructions: json['actionInstructions'] as String?,
      estimatedMins: json['estimatedMins'] as int?,
    );
  }

  Map<String, dynamic> toJson() => {
    'stepId': stepId,
    'title': title,
    'contentType': contentType,
    if (content != null) 'content': content,
    if (responseType != null) 'responseType': responseType,
    if (options != null) 'options': options,
    if (minSelect != null) 'minSelect': minSelect,
    if (maxSelect != null) 'maxSelect': maxSelect,
    if (placeholder != null) 'placeholder': placeholder,
    if (maxChars != null) 'maxChars': maxChars,
    if (actionInstructions != null) 'actionInstructions': actionInstructions,
    if (estimatedMins != null) 'estimatedMins': estimatedMins,
  };

  @override
  List<Object?> get props => [
    stepId, title, contentType, content, responseType, 
    options, minSelect, maxSelect, placeholder, maxChars,
    actionInstructions, estimatedMins,
  ];
}

/// Journey session
class JourneySession extends Equatable {
  final String sessionId;
  final int sessionNumber;
  final String title;
  final String subtitle;
  final String tier; // Starter, Growth, Deep, Premium
  final String lockRule; // Free, Locked
  final String? unlockCondition;
  final int estimatedMins;
  final String? badgeOnComplete;
  final List<SessionStep> steps;
  final String? completionMessage;

  const JourneySession({
    required this.sessionId,
    required this.sessionNumber,
    required this.title,
    required this.subtitle,
    required this.tier,
    required this.lockRule,
    this.unlockCondition,
    required this.estimatedMins,
    this.badgeOnComplete,
    required this.steps,
    this.completionMessage,
  });

  bool get isFree => lockRule.toLowerCase() == 'free';

  /// Get primary response type from first step with a responseType
  ResponseType get responseType {
    for (final step in steps) {
      if (step.responseType != null) {
        return ResponseType.fromValue(step.responseType!);
      }
    }
    return ResponseType.reflection; // Default
  }

  factory JourneySession.fromJson(Map<String, dynamic> json) {
    return JourneySession(
      sessionId: json['sessionId'] as String? ?? '',
      sessionNumber: json['sessionNumber'] as int? ?? 0,
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      tier: json['tier'] as String? ?? 'Starter',
      lockRule: json['lockRule'] as String? ?? 'Locked',
      unlockCondition: json['unlockCondition'] as String?,
      estimatedMins: json['estimatedMins'] as int? ?? 10,
      badgeOnComplete: json['badgeOnComplete'] as String?,
      steps: (json['steps'] as List<dynamic>?)
          ?.map((e) => SessionStep.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      completionMessage: json['completionMessage'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'sessionId': sessionId,
    'sessionNumber': sessionNumber,
    'title': title,
    'subtitle': subtitle,
    'tier': tier,
    'lockRule': lockRule,
    if (unlockCondition != null) 'unlockCondition': unlockCondition,
    'estimatedMins': estimatedMins,
    if (badgeOnComplete != null) 'badgeOnComplete': badgeOnComplete,
    'steps': steps.map((e) => e.toJson()).toList(),
    if (completionMessage != null) 'completionMessage': completionMessage,
  };

  @override
  List<Object?> get props => [
    sessionId, sessionNumber, title, subtitle, tier, lockRule,
    unlockCondition, estimatedMins, badgeOnComplete, steps, completionMessage,
  ];
}

/// Journey product
class JourneyProduct extends Equatable {
  final String productId;
  final String title;
  final String subtitle;
  final String description;
  final List<String> audiences;
  final List<String> goalTags;
  final String? thumbnailUrl;
  final String tier; // Free, Bonus, Premium
  final String? revenuecatProductId;
  final int totalSessions;
  final int estimatedWeeks;
  final List<String> outcomes;
  final List<JourneySession> sessions;
  final String? completionBadge;
  final String? completionCertText;

  const JourneyProduct({
    required this.productId,
    required this.title,
    required this.subtitle,
    required this.description,
    required this.audiences,
    required this.goalTags,
    this.thumbnailUrl,
    required this.tier,
    this.revenuecatProductId,
    required this.totalSessions,
    required this.estimatedWeeks,
    required this.outcomes,
    required this.sessions,
    this.completionBadge,
    this.completionCertText,
  });

  bool get isFree => tier.toLowerCase() == 'free';
  bool get isPremium => tier.toLowerCase() == 'premium';

  /// Get session by number
  JourneySession? getSession(int sessionNumber) {
    try {
      return sessions.firstWhere((s) => s.sessionNumber == sessionNumber);
    } catch (_) {
      return null;
    }
  }

  /// Get session by ID
  JourneySession? getSessionById(String sessionId) {
    try {
      return sessions.firstWhere((s) => s.sessionId == sessionId);
    } catch (_) {
      return null;
    }
  }

  factory JourneyProduct.fromJson(Map<String, dynamic> json) {
    return JourneyProduct(
      productId: json['productId'] as String? ?? '',
      title: json['title'] as String? ?? '',
      subtitle: json['subtitle'] as String? ?? '',
      description: json['description'] as String? ?? '',
      audiences: (json['audiences'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      goalTags: (json['goalTags'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      thumbnailUrl: json['thumbnailUrl'] as String?,
      tier: json['tier'] as String? ?? 'Free',
      revenuecatProductId: json['revenuecatProductId'] as String?,
      totalSessions: json['totalSessions'] as int? ?? 0,
      estimatedWeeks: json['estimatedWeeks'] as int? ?? 1,
      outcomes: (json['outcomes'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      sessions: (json['sessions'] as List<dynamic>?)
          ?.map((e) => JourneySession.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
      completionBadge: json['completionBadge'] as String?,
      completionCertText: json['completionCertText'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    'productId': productId,
    'title': title,
    'subtitle': subtitle,
    'description': description,
    'audiences': audiences,
    'goalTags': goalTags,
    if (thumbnailUrl != null) 'thumbnailUrl': thumbnailUrl,
    'tier': tier,
    if (revenuecatProductId != null) 'revenuecatProductId': revenuecatProductId,
    'totalSessions': totalSessions,
    'estimatedWeeks': estimatedWeeks,
    'outcomes': outcomes,
    'sessions': sessions.map((e) => e.toJson()).toList(),
    if (completionBadge != null) 'completionBadge': completionBadge,
    if (completionCertText != null) 'completionCertText': completionCertText,
  };

  @override
  List<Object?> get props => [
    productId, title, subtitle, description, audiences, goalTags,
    thumbnailUrl, tier, revenuecatProductId, totalSessions, estimatedWeeks,
    outcomes, sessions, completionBadge, completionCertText,
  ];
}

/// Journey catalog
class JourneyCatalog extends Equatable {
  final String version;
  final String audience;
  final List<JourneyProduct> products;

  const JourneyCatalog({
    required this.version,
    required this.audience,
    required this.products,
  });

  factory JourneyCatalog.fromJson(Map<String, dynamic> json) {
    return JourneyCatalog(
      version: json['version'] as String? ?? 'v1',
      audience: json['audience'] as String? ?? '',
      products: (json['products'] as List<dynamic>?)
          ?.map((e) => JourneyProduct.fromJson(e as Map<String, dynamic>))
          .toList() ?? [],
    );
  }

  Map<String, dynamic> toJson() => {
    'version': version,
    'audience': audience,
    'products': products.map((e) => e.toJson()).toList(),
  };

  JourneyProduct? findProduct(String productId) {
    try {
      return products.firstWhere((p) => p.productId == productId);
    } catch (_) {
      return null;
    }
  }

  List<JourneyProduct> getProductsForGoal(String goalTag) {
    return products.where((p) => p.goalTags.contains(goalTag)).toList();
  }

  @override
  List<Object?> get props => [version, audience, products];
}

/// Session response from user
class SessionResponse extends Equatable {
  final String visitorId;
  final String sessionId;
  final String stepId;
  final String userId;
  final String productId;
  final String responseType;
  final dynamic value;
  final DateTime createdAt;
  final int? rating;
  final int? confidenceRating;

  const SessionResponse({
    required this.visitorId,
    required this.sessionId,
    required this.stepId,
    required this.userId,
    required this.productId,
    required this.responseType,
    required this.value,
    required this.createdAt,
    this.rating,
    this.confidenceRating,
  });

  String get id => visitorId;

  factory SessionResponse.fromJson(Map<String, dynamic> json) {
    return SessionResponse(
      visitorId: json['visitorId'] as String? ?? json['id'] as String? ?? '',
      sessionId: json['sessionId'] as String,
      stepId: json['stepId'] as String,
      userId: json['userId'] as String,
      productId: json['productId'] as String,
      responseType: json['responseType'] as String,
      value: json['value'],
      createdAt: json['createdAt'] != null
          ? (json['createdAt'] as Timestamp).toDate()
          : DateTime.now(),
      rating: json['rating'] as int?,
      confidenceRating: json['confidenceRating'] as int?,
    );
  }

  factory SessionResponse.fromFirestore(Map<String, dynamic> json) {
    return SessionResponse.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
    'visitorId': visitorId,
    'sessionId': sessionId,
    'stepId': stepId,
    'userId': userId,
    'productId': productId,
    'responseType': responseType,
    'value': value,
    'createdAt': Timestamp.fromDate(createdAt),
    if (rating != null) 'rating': rating,
    if (confidenceRating != null) 'confidenceRating': confidenceRating,
  };

  Map<String, dynamic> toFirestore() => toJson();

  @override
  List<Object?> get props => [
    visitorId, sessionId, stepId, userId, productId,
    responseType, value, createdAt, rating, confidenceRating,
  ];
}

/// User's journey progress
class JourneyProgress extends Equatable {
  final String visitorId;
  final String visitorUid;
  final String productId;
  final String productName;
  final bool purchased;
  final DateTime? purchasedAt;
  final int completedSessionCount;
  final int totalSessions;
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastSessionAt;
  final DateTime? startedAt;
  final bool isCompleted;
  final DateTime? completedAt;
  final List<String> earnedBadges;
  final List<String> completedSessionIdsList;
  final Map<String, dynamic>? metadata;

  const JourneyProgress({
    required this.visitorId,
    required this.visitorUid,
    required this.productId,
    required this.productName,
    this.purchased = false,
    this.purchasedAt,
    this.completedSessionCount = 0,
    this.totalSessions = 0,
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastSessionAt,
    this.startedAt,
    this.isCompleted = false,
    this.completedAt,
    this.earnedBadges = const [],
    this.completedSessionIdsList = const [],
    this.metadata,
  });

  // Alias getters for compatibility
  String get id => visitorId;
  String get userId => visitorUid;
  int get completedSessions => completedSessionCount;
  bool get completed => isCompleted;
  List<String> get completedSessionIds => completedSessionIdsList;

  double get progressPercent =>
      totalSessions > 0 ? completedSessionCount / totalSessions : 0;

  bool canAccessSession(int sessionNumber, bool isFree) {
    if (isFree) return true;
    if (!purchased) return false;
    return sessionNumber <= completedSessionCount + 1;
  }

  factory JourneyProgress.fromJson(Map<String, dynamic> json) {
    return JourneyProgress(
      visitorId: json['visitorId'] as String? ?? json['id'] as String? ?? '',
      visitorUid: json['visitorUid'] as String? ?? json['userId'] as String? ?? '',
      productId: json['productId'] as String,
      productName: json['productName'] as String? ?? '',
      purchased: json['purchased'] as bool? ?? false,
      purchasedAt: json['purchasedAt'] != null
          ? (json['purchasedAt'] as Timestamp).toDate()
          : null,
      completedSessionCount: json['completedSessionCount'] as int? ?? json['completedSessions'] as int? ?? 0,
      totalSessions: json['totalSessions'] as int? ?? 0,
      currentStreak: json['currentStreak'] as int? ?? 0,
      longestStreak: json['longestStreak'] as int? ?? 0,
      lastSessionAt: json['lastSessionAt'] != null
          ? (json['lastSessionAt'] as Timestamp).toDate()
          : null,
      startedAt: json['startedAt'] != null
          ? (json['startedAt'] as Timestamp).toDate()
          : null,
      isCompleted: json['isCompleted'] as bool? ?? json['completed'] as bool? ?? false,
      completedAt: json['completedAt'] != null
          ? (json['completedAt'] as Timestamp).toDate()
          : null,
      earnedBadges: (json['earnedBadges'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      completedSessionIdsList: (json['completedSessionIdsList'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? (json['completedSessionIds'] as List<dynamic>?)
          ?.map((e) => e.toString())
          .toList() ?? [],
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  factory JourneyProgress.fromFirestore(Map<String, dynamic> json) {
    return JourneyProgress.fromJson(json);
  }

  Map<String, dynamic> toJson() => {
    'visitorId': visitorId,
    'visitorUid': visitorUid,
    'productId': productId,
    'productName': productName,
    'purchased': purchased,
    if (purchasedAt != null) 'purchasedAt': Timestamp.fromDate(purchasedAt!),
    'completedSessionCount': completedSessionCount,
    'totalSessions': totalSessions,
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    if (lastSessionAt != null) 'lastSessionAt': Timestamp.fromDate(lastSessionAt!),
    if (startedAt != null) 'startedAt': Timestamp.fromDate(startedAt!),
    'isCompleted': isCompleted,
    if (completedAt != null) 'completedAt': Timestamp.fromDate(completedAt!),
    'earnedBadges': earnedBadges,
    'completedSessionIdsList': completedSessionIdsList,
    if (metadata != null) 'metadata': metadata,
  };

  Map<String, dynamic> toFirestore() => toJson();

  JourneyProgress copyWith({
    String? visitorId,
    String? visitorUid,
    String? productId,
    String? productName,
    bool? purchased,
    DateTime? purchasedAt,
    int? completedSessionCount,
    int? totalSessions,
    int? currentStreak,
    int? longestStreak,
    DateTime? lastSessionAt,
    DateTime? startedAt,
    bool? isCompleted,
    DateTime? completedAt,
    List<String>? earnedBadges,
    List<String>? completedSessionIdsList,
    Map<String, dynamic>? metadata,
  }) {
    return JourneyProgress(
      visitorId: visitorId ?? this.visitorId,
      visitorUid: visitorUid ?? this.visitorUid,
      productId: productId ?? this.productId,
      productName: productName ?? this.productName,
      purchased: purchased ?? this.purchased,
      purchasedAt: purchasedAt ?? this.purchasedAt,
      completedSessionCount: completedSessionCount ?? this.completedSessionCount,
      totalSessions: totalSessions ?? this.totalSessions,
      currentStreak: currentStreak ?? this.currentStreak,
      longestStreak: longestStreak ?? this.longestStreak,
      lastSessionAt: lastSessionAt ?? this.lastSessionAt,
      startedAt: startedAt ?? this.startedAt,
      isCompleted: isCompleted ?? this.isCompleted,
      completedAt: completedAt ?? this.completedAt,
      earnedBadges: earnedBadges ?? this.earnedBadges,
      completedSessionIdsList: completedSessionIdsList ?? this.completedSessionIdsList,
      metadata: metadata ?? this.metadata,
    );
  }

  @override
  List<Object?> get props => [
    visitorId, visitorUid, productId, productName, purchased, purchasedAt,
    completedSessionCount, totalSessions, currentStreak, longestStreak,
    lastSessionAt, startedAt, isCompleted, completedAt, earnedBadges,
    completedSessionIdsList,
  ];
}
