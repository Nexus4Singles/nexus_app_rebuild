import 'package:equatable/equatable.dart';

class RecommendationBundle extends Equatable {
  final String profileTitle;
  final String profileSummary;

  /// Dimensions with strongest performance (highest %), ordered.
  final List<DimensionRecommendation> strengths;

  /// Dimensions with weakest performance (lowest %), ordered.
  final List<DimensionRecommendation> growthAreas;

  /// Outcome signals extracted from selected answers (optional; can be shown as key insights).
  final List<String> keySignals;

  /// Next steps (micro-steps) driven by dimension insights (if present).
  final List<String> nextSteps;

  /// Recommended journey id / title to route to (currently derived from lowest dimension insights.recommendedJourney).
  final String? recommendedJourneyId;

  /// Special safety flag (e.g. “I do not feel safe”)
  final bool isSafetyAlert;

  const RecommendationBundle({
    required this.profileTitle,
    required this.profileSummary,
    required this.strengths,
    required this.growthAreas,
    required this.keySignals,
    required this.nextSteps,
    required this.recommendedJourneyId,
    required this.isSafetyAlert,
  });

  @override
  List<Object?> get props => [
    profileTitle,
    profileSummary,
    strengths,
    growthAreas,
    keySignals,
    nextSteps,
    recommendedJourneyId,
    isSafetyAlert,
  ];
}

class DimensionRecommendation extends Equatable {
  final String dimensionId;
  final String dimensionName;
  final int score;
  final int maxScore;
  final int percentage; // 0..100
  final String tier; // STRONG / DEVELOPING / GUARDED / AT_RISK
  final String? insightText;
  final String? microStep;
  final String? recommendedJourney;

  const DimensionRecommendation({
    required this.dimensionId,
    required this.dimensionName,
    required this.score,
    required this.maxScore,
    required this.percentage,
    required this.tier,
    this.insightText,
    this.microStep,
    this.recommendedJourney,
  });

  @override
  List<Object?> get props => [
    dimensionId,
    dimensionName,
    score,
    maxScore,
    percentage,
    tier,
    insightText,
    microStep,
    recommendedJourney,
  ];
}
