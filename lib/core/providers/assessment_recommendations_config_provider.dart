import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assessment_recommendations_config.dart';
import '../services/assessment_recommendations_config_service.dart';

/// Riverpod provider for the assessment recommendations config service
final assessmentRecommendationsConfigServiceProvider = Provider(
  (ref) => const AssessmentRecommendationsConfigService(),
);

/// Riverpod provider that loads the assessment recommendations config
final assessmentRecommendationsConfigProvider =
    FutureProvider<AssessmentRecommendationsConfig>((ref) async {
      final service = ref.watch(assessmentRecommendationsConfigServiceProvider);
      return service.loadConfig();
    });

/// Riverpod provider to get recommendations for a specific dimension
final dimensionRecommendationsProvider = FutureProvider.family<
  List<JourneyRecommendationItem>,
  ({String assessmentId, String dimensionId})
>((ref, params) async {
  final service = ref.watch(assessmentRecommendationsConfigServiceProvider);
  return service.getRecommendationsForDimension(
    assessmentId: params.assessmentId,
    dimensionId: params.dimensionId,
  );
});

/// Riverpod provider to get all recommendations for an assessment
final assessmentRecommendationsProvider =
    FutureProvider.family<AssessmentRecommendations?, String>((
      ref,
      assessmentId,
    ) async {
      final service = ref.watch(assessmentRecommendationsConfigServiceProvider);
      return service.getAssessmentRecommendations(assessmentId);
    });

/// Riverpod provider to get journey subtitle
final journeySubtitleProvider = FutureProvider.family<String, String>((
  ref,
  journeyId,
) async {
  final service = ref.watch(assessmentRecommendationsConfigServiceProvider);
  return service.getJourneySubtitle(journeyId);
});
