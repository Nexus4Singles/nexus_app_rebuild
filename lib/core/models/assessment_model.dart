import 'package:equatable/equatable.dart';
import '../constants/app_constants.dart';

/// Assessment dimension (e.g., "Emotional Regulation", "Conflict Posture")
class AssessmentDimension extends Equatable {
  final String id;
  final String name;
  final DimensionInsights? insights;

  const AssessmentDimension({
    required this.id,
    required this.name,
    this.insights,
  });

  factory AssessmentDimension.fromJson(Map<String, dynamic> json) {
    return AssessmentDimension(
      id: json['id'] as String,
      name: json['name'] as String,
      insights:
          json['insights'] != null && (json['insights'] as Map).isNotEmpty
              ? DimensionInsights.fromJson(
                json['insights'] as Map<String, dynamic>,
              )
              : null,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'name': name,
    if (insights != null) 'insights': insights!.toJson(),
  };

  @override
  List<Object?> get props => [id, name, insights];
}

/// Insights for a dimension (low/medium/high feedback)
class DimensionInsights extends Equatable {
  final String? low;
  final String? medium;
  final String? high;
  final String? microStep;
  final String? recommendedJourney;

  const DimensionInsights({
    this.low,
    this.medium,
    this.high,
    this.microStep,
    this.recommendedJourney,
  });

  factory DimensionInsights.fromJson(Map<String, dynamic> json) {
    return DimensionInsights(
      low: json['low'] as String?,
      medium: json['medium'] as String?,
      high: json['high'] as String?,
      microStep: json['microStep'] as String?,
      recommendedJourney: json['recommendedJourney'] as String?,
    );
  }

  Map<String, dynamic> toJson() => {
    if (low != null) 'low': low,
    if (medium != null) 'medium': medium,
    if (high != null) 'high': high,
    if (microStep != null) 'microStep': microStep,
    if (recommendedJourney != null) 'recommendedJourney': recommendedJourney,
  };

  String? getInsightForScore(double percentage) {
    if (percentage >= AppConfig.strongThreshold) return high;
    if (percentage >= AppConfig.developingThreshold) return medium;
    return low;
  }

  @override
  List<Object?> get props => [low, medium, high, microStep, recommendedJourney];
}

/// Assessment question option
class AssessmentOption extends Equatable {
  final String id;
  final String text;
  final String signalTier;
  final int weight;
  final String outcomeSignal;

  const AssessmentOption({
    required this.id,
    required this.text,
    required this.signalTier,
    required this.weight,
    required this.outcomeSignal,
  });

  factory AssessmentOption.fromJson(Map<String, dynamic> json) {
    return AssessmentOption(
      id: json['id'] as String,
      text: json['text'] as String,
      signalTier: json['signalTier'] as String,
      weight: json['weight'] as int,
      outcomeSignal: json['outcomeSignal'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'text': text,
    'signalTier': signalTier,
    'weight': weight,
    'outcomeSignal': outcomeSignal,
  };

  SignalTier get tier => SignalTier.fromValue(signalTier);

  @override
  List<Object?> get props => [id, text, signalTier, weight, outcomeSignal];
}

/// Assessment question
class AssessmentQuestion extends Equatable {
  final int number;
  final String dimension;
  final String text;
  final List<AssessmentOption> options;

  const AssessmentQuestion({
    required this.number,
    required this.dimension,
    required this.text,
    required this.options,
  });

  factory AssessmentQuestion.fromJson(Map<String, dynamic> json) {
    return AssessmentQuestion(
      number: json['number'] as int,
      dimension: json['dimension'] as String,
      text: json['text'] as String,
      options:
          (json['options'] as List<dynamic>)
              .map((e) => AssessmentOption.fromJson(e as Map<String, dynamic>))
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'number': number,
    'dimension': dimension,
    'text': text,
    'options': options.map((e) => e.toJson()).toList(),
  };

  @override
  List<Object?> get props => [number, dimension, text, options];
}

/// Complete assessment configuration
class AssessmentConfig extends Equatable {
  final String assessmentId;
  final String audience;
  final String title;
  final String version;
  final int questionCount;
  final List<AssessmentDimension> dimensions;
  final List<AssessmentQuestion> questions;

  const AssessmentConfig({
    required this.assessmentId,
    required this.audience,
    required this.title,
    required this.version,
    required this.questionCount,
    required this.dimensions,
    required this.questions,
  });

  factory AssessmentConfig.fromJson(Map<String, dynamic> json) {
    return AssessmentConfig(
      assessmentId: json['assessmentId'] as String,
      audience: json['audience'] as String,
      title: json['title'] as String,
      version: json['version'] as String,
      questionCount: json['questionCount'] as int,
      dimensions:
          (json['dimensions'] as List<dynamic>)
              .map(
                (e) => AssessmentDimension.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
      questions:
          (json['questions'] as List<dynamic>)
              .map(
                (e) => AssessmentQuestion.fromJson(e as Map<String, dynamic>),
              )
              .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'assessmentId': assessmentId,
    'audience': audience,
    'title': title,
    'version': version,
    'questionCount': questionCount,
    'dimensions': dimensions.map((e) => e.toJson()).toList(),
    'questions': questions.map((e) => e.toJson()).toList(),
  };

  /// Get dimension by name
  AssessmentDimension? getDimension(String name) {
    try {
      return dimensions.firstWhere(
        (d) => d.name.toLowerCase() == name.toLowerCase(),
      );
    } catch (_) {
      return null;
    }
  }

  /// Get maximum possible score
  int get maxScore => questionCount * AppConfig.maxScorePerQuestion;

  /// Alias for title (UI compatibility)
  String get assessmentName => title;

  @override
  List<Object?> get props => [
    assessmentId,
    audience,
    title,
    version,
    questionCount,
    dimensions,
    questions,
  ];
}

/// User's answer to a question
class AssessmentAnswer extends Equatable {
  final int questionNumber;
  final String selectedOptionId;
  final int weight;
  final String signalTier;
  final String dimension;

  const AssessmentAnswer({
    required this.questionNumber,
    required this.selectedOptionId,
    required this.weight,
    required this.signalTier,
    required this.dimension,
  });

  factory AssessmentAnswer.fromJson(Map<String, dynamic> json) {
    return AssessmentAnswer(
      questionNumber: json['questionNumber'] as int,
      selectedOptionId: json['selectedOptionId'] as String,
      weight: json['weight'] as int,
      signalTier: json['signalTier'] as String,
      dimension: json['dimension'] as String,
    );
  }

  Map<String, dynamic> toJson() => {
    'questionNumber': questionNumber,
    'selectedOptionId': selectedOptionId,
    'weight': weight,
    'signalTier': signalTier,
    'dimension': dimension,
  };

  @override
  List<Object?> get props => [
    questionNumber,
    selectedOptionId,
    weight,
    signalTier,
    dimension,
  ];
}

/// Dimension score summary
class DimensionScore extends Equatable {
  final String dimensionId;
  final String dimensionName;
  final int totalScore;
  final int maxScore;
  final int questionCount;
  final List<AssessmentAnswer> answers;

  const DimensionScore({
    required this.dimensionId,
    required this.dimensionName,
    required this.totalScore,
    required this.maxScore,
    required this.questionCount,
    required this.answers,
  });

  double get percentage => maxScore > 0 ? totalScore / maxScore : 0;

  SignalTier get overallTier {
    final pct = percentage;
    if (pct >= AppConfig.strongThreshold) return SignalTier.strong;
    if (pct >= AppConfig.developingThreshold) return SignalTier.developing;
    if (pct >= AppConfig.guardedThreshold) return SignalTier.guarded;
    return SignalTier.atRisk;
  }

  /// Alias for overallTier (UI compatibility)
  SignalTier get tier => overallTier;

  @override
  List<Object?> get props => [
    dimensionId,
    dimensionName,
    totalScore,
    maxScore,
    questionCount,
    answers,
  ];
}

/// Complete assessment result
class AssessmentResult extends Equatable {
  final String id;
  final String assessmentId;
  final String userId;
  final int totalScore;
  final int maxScore;
  final double percentage;
  final SignalTier overallTier;
  final List<AssessmentAnswer> answers;
  final Map<String, DimensionScore> dimensionScores;
  final DateTime completedAt;
  final DateTime? createdAt;
  final DateTime? updatedAt;
  final String? recommendedJourneyId;
  final List<String> inferredTags;

  const AssessmentResult({
    required this.id,
    required this.assessmentId,
    required this.userId,
    required this.totalScore,
    required this.maxScore,
    required this.percentage,
    required this.overallTier,
    required this.answers,
    required this.dimensionScores,
    required this.completedAt,
    this.createdAt,
    this.updatedAt,
    this.recommendedJourneyId,
    this.inferredTags = const [],
  });

  /// Alias for percentage (UI compatibility)
  double get overallPercentage => percentage;

  factory AssessmentResult.fromJson(Map<String, dynamic> json) {
    return AssessmentResult(
      id: json['id'] as String? ?? '',
      assessmentId: json['assessmentId'] as String,
      userId: json['userId'] as String,
      totalScore: json['totalScore'] as int,
      maxScore: json['maxScore'] as int,
      percentage: (json['percentage'] as num).toDouble(),
      overallTier: SignalTier.fromValue(json['overallTier'] as String),
      answers:
          (json['answers'] as List<dynamic>?)
              ?.map((e) => AssessmentAnswer.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      dimensionScores:
          (json['dimensionScores'] as Map<String, dynamic>?)?.map(
            (k, v) => MapEntry(
              k,
              DimensionScore(
                dimensionId: v['dimensionId'] as String,
                dimensionName: v['dimensionName'] as String,
                totalScore: v['totalScore'] as int,
                maxScore: v['maxScore'] as int,
                questionCount: v['questionCount'] as int,
                answers: [],
              ),
            ),
          ) ??
          {},
      completedAt: DateTime.parse(json['completedAt'] as String),
      createdAt:
          json['createdAt'] != null
              ? DateTime.parse(json['createdAt'] as String)
              : null,
      updatedAt:
          json['updatedAt'] != null
              ? DateTime.parse(json['updatedAt'] as String)
              : null,
      recommendedJourneyId: json['recommendedJourneyId'] as String?,
      inferredTags:
          (json['inferredTags'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }

  factory AssessmentResult.calculate({
    required String id,
    required AssessmentConfig config,
    required String userId,
    required List<AssessmentAnswer> answers,
  }) {
    // Calculate total score
    final totalScore = answers.fold<int>(0, (sum, a) => sum + a.weight);
    final maxScore = config.maxScore;
    final percentage = maxScore > 0 ? totalScore / maxScore : 0.0;

    // Calculate dimension scores
    final dimensionScores = <String, DimensionScore>{};
    for (final dimension in config.dimensions) {
      final dimensionAnswers =
          answers
              .where(
                (a) =>
                    a.dimension.toLowerCase() == dimension.name.toLowerCase(),
              )
              .toList();

      if (dimensionAnswers.isEmpty) continue;

      final dimTotal = dimensionAnswers.fold<int>(
        0,
        (sum, a) => sum + a.weight,
      );
      final dimMax = dimensionAnswers.length * AppConfig.maxScorePerQuestion;

      dimensionScores[dimension.id] = DimensionScore(
        dimensionId: dimension.id,
        dimensionName: dimension.name,
        totalScore: dimTotal,
        maxScore: dimMax,
        questionCount: dimensionAnswers.length,
        answers: dimensionAnswers,
      );
    }

    // Determine overall tier
    SignalTier overallTier;
    if (percentage >= AppConfig.strongThreshold) {
      overallTier = SignalTier.strong;
    } else if (percentage >= AppConfig.developingThreshold) {
      overallTier = SignalTier.developing;
    } else if (percentage >= AppConfig.guardedThreshold) {
      overallTier = SignalTier.guarded;
    } else {
      overallTier = SignalTier.atRisk;
    }

    // Collect inferred tags from at-risk or guarded dimensions
    final inferredTags = <String>[];
    for (final dimScore in dimensionScores.values) {
      if (dimScore.overallTier == SignalTier.atRisk ||
          dimScore.overallTier == SignalTier.guarded) {
        inferredTags.add(dimScore.dimensionId);
      }
    }

    // Find lowest scoring dimension for journey recommendation
    String? recommendedJourneyId;
    if (dimensionScores.isNotEmpty) {
      final lowestDim = dimensionScores.values.reduce(
        (a, b) => a.percentage < b.percentage ? a : b,
      );
      final dimension = config.getDimension(lowestDim.dimensionName);
      recommendedJourneyId = dimension?.insights?.recommendedJourney;
    }

    return AssessmentResult(
      id: id,
      assessmentId: config.assessmentId,
      userId: userId,
      totalScore: totalScore,
      maxScore: maxScore,
      percentage: percentage,
      overallTier: overallTier,
      answers: answers,
      dimensionScores: dimensionScores,
      completedAt: DateTime.now(),
      recommendedJourneyId: recommendedJourneyId,
      inferredTags: inferredTags,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'assessmentId': assessmentId,
    'userId': userId,
    'totalScore': totalScore,
    'maxScore': maxScore,
    'percentage': percentage,
    'overallTier': overallTier.value,
    'answers': answers.map((a) => a.toJson()).toList(),
    'dimensionScores': dimensionScores.map(
      (k, v) => MapEntry(k, {
        'dimensionId': v.dimensionId,
        'dimensionName': v.dimensionName,
        'totalScore': v.totalScore,
        'maxScore': v.maxScore,
        'questionCount': v.questionCount,
        'percentage': v.percentage,
        'overallTier': v.overallTier.value,
      }),
    ),
    'completedAt': completedAt.toIso8601String(),
    if (createdAt != null) 'createdAt': createdAt!.toIso8601String(),
    if (updatedAt != null) 'updatedAt': updatedAt!.toIso8601String(),
    if (recommendedJourneyId != null)
      'recommendedJourneyId': recommendedJourneyId,
    'inferredTags': inferredTags,
  };

  @override
  List<Object?> get props => [
    id,
    assessmentId,
    userId,
    totalScore,
    maxScore,
    percentage,
    overallTier,
    answers,
    dimensionScores,
    completedAt,
    createdAt,
    updatedAt,
    recommendedJourneyId,
    inferredTags,
  ];
}
