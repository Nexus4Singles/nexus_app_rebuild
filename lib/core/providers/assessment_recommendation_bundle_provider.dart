import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/assessment_model.dart';
import '../models/recommendation_bundle.dart';
import '../services/assessment_recommendation_service.dart';

/// Riverpod family provider for async assessment recommendation bundle
final assessmentRecommendationBundleProvider = FutureProvider.family<
  RecommendationBundle,
  ({AssessmentResult result, AssessmentConfig config, String? gender})
>((ref, params) async {
  final service = const AssessmentRecommendationService();
  return service.buildAsync(
    result: params.result,
    config: params.config,
    gender: params.gender,
  );
});
