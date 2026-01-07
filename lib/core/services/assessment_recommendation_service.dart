import 'dart:math';

import '../models/assessment_model.dart';
import '../models/recommendation_bundle.dart';

/// Deterministic recommendation engine.
///
/// Hybrid approach:
/// - Content lives in JSON (profiles, insights, microSteps, journeys, outcomeSignals).
/// - Ordering + selection logic lives in code.
class AssessmentRecommendationService {
  const AssessmentRecommendationService();

  RecommendationBundle build({
    required AssessmentResult result,
    required AssessmentConfig config,
  }) {
    final isSafetyAlert = _detectSafetyAlert(result);

    final dimensionRecs = _buildDimensionRecs(result: result, config: config);
    dimensionRecs.sort((a, b) => a.percentage.compareTo(b.percentage));

    final growthAreas = dimensionRecs.take(min(3, dimensionRecs.length)).toList();
    final strengths = dimensionRecs.reversed.take(min(3, dimensionRecs.length)).toList();

    final recommendedJourneyId =
        growthAreas.firstWhere((d) => (d.recommendedJourney ?? '').trim().isNotEmpty,
                orElse: () => growthAreas.isNotEmpty ? growthAreas.first : const DimensionRecommendation(
                  dimensionId: '',
                  dimensionName: '',
                  score: 0,
                  maxScore: 1,
                  percentage: 0,
                  tier: 'AT_RISK',
                ))
            .recommendedJourney;

    final nextSteps = _buildNextSteps(growthAreas);

    final keySignals = _extractKeySignals(result: result, config: config);

    final (profileTitle, profileSummary) = _resolveProfile(
      result: result,
      config: config,
      isSafetyAlert: isSafetyAlert,
    );

    return RecommendationBundle(
      profileTitle: profileTitle,
      profileSummary: profileSummary,
      strengths: strengths,
      growthAreas: growthAreas,
      keySignals: keySignals,
      nextSteps: nextSteps,
      recommendedJourneyId: recommendedJourneyId ?? result.recommendedJourneyId,
      isSafetyAlert: isSafetyAlert,
    );
  }

  bool _detectSafetyAlert(AssessmentResult result) {
    for (final a in result.answers) {
      if (a.signalTier.toUpperCase() == 'SAFETY_ALERT') return true;
    }
    return false;
  }

  List<DimensionRecommendation> _buildDimensionRecs({
    required AssessmentResult result,
    required AssessmentConfig config,
  }) {
    final recs = <DimensionRecommendation>[];

    for (final dimScore in result.dimensionScores.values) {
      final pctInt = (dimScore.percentage * 100).round();
      final tierStr = dimScore.overallTier.value;

      final dimension = config.getDimension(dimScore.dimensionName);

      final insightText = dimension?.insights?.getInsightForScore(dimScore.percentage);
      final microStepRaw = dimension?.insights?.microStep;
      final microStep = (microStepRaw ?? '').trim().isEmpty
          ? 'Pick one small action you can practice this week.'
          : microStepRaw;
      final journeyRaw = dimension?.insights?.recommendedJourney;
      final journey = (journeyRaw ?? '').trim().isEmpty
          ? (result.recommendedJourneyId)
          : journeyRaw;

      recs.add(
        DimensionRecommendation(
          dimensionId: dimScore.dimensionId,
          dimensionName: dimScore.dimensionName,
          score: dimScore.totalScore,
          maxScore: max(1, dimScore.maxScore),
          percentage: pctInt,
          tier: tierStr,
          insightText: insightText,
          microStep: microStep,
          recommendedJourney: journey,
        ),
      );
    }

    return recs;
  }

  List<String> _buildNextSteps(List<DimensionRecommendation> growthAreas) {
    final steps = <String>[];
    for (final d in growthAreas) {
      final step = (d.microStep ?? '').trim();
      if (step.isNotEmpty) steps.add(step);
    }
    // Dedupe while preserving order
    final seen = <String>{};
    return steps.where((s) => seen.add(s)).take(3).toList();
  }

  List<String> _extractKeySignals({
    required AssessmentResult result,
    required AssessmentConfig config,
  }) {
    final signals = <String>[];

    for (final answer in result.answers) {
      final q = config.questions.firstWhere(
        (qq) => qq.number == answer.questionNumber,
        orElse: () => throw StateError('Missing question ${answer.questionNumber}'),
      );

      final opt = q.options.firstWhere(
        (o) => o.id == answer.selectedOptionId,
        orElse: () => throw StateError('Missing option ${answer.selectedOptionId} for Q${answer.questionNumber}'),
      );

      final s = opt.outcomeSignal.trim();
      if (s.isNotEmpty) signals.add(s);
    }

    // Dedupe while preserving order
    final seen = <String>{};
    return signals.where((s) => seen.add(s)).take(6).toList();
  }

  (String, String) _resolveProfile({
    required AssessmentResult result,
    required AssessmentConfig config,
    required bool isSafetyAlert,
  }) {
    if (isSafetyAlert) {
      return (
        'Safety First',
        'Your responses suggest that safety may be a concern. The most important next step is to prioritize emotional and physical safety before working on relationship growth.'
      );
    }

    final tierKey = result.overallTier.value;
    final fromJson = config.profiles?.getForTier(tierKey);
    if (fromJson != null &&
        fromJson.title.trim().isNotEmpty &&
        fromJson.summary.trim().isNotEmpty) {
      return (fromJson.title.trim(), fromJson.summary.trim());
    }

    // Fallback deterministic templates
    switch (tierKey) {
      case 'STRONG':
        return (
          'Ready & Grounded',
          'You show strong readiness signals across key areas. Keep strengthening what is already working and build consistency in growth zones.'
        );
      case 'DEVELOPING':
        return (
          'Promising, Still Building',
          'Your foundation is forming well. A few intentional upgrades in key areas can significantly increase your readiness and stability.'
        );
      case 'GUARDED':
        return (
          'Cautious & Uncertain',
          'You have some stable areas, but there are signals that need attention before you feel fully ready and secure. Focus on your weakest two dimensions first.'
        );
      case 'AT_RISK':
      default:
        return (
          'Fragile Foundations',
          'Right now, several areas need support. Take gentle, practical steps to rebuild stability before making major relational decisions.'
        );
    }
  }
}
