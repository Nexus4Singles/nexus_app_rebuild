import '../constants/app_constants.dart';
import '../models/assessment_model.dart';
import '../models/recommendation_bundle.dart';

/// Intelligent journey mapping service.
///
/// Maps assessment dimensions and user situations to the most contextually appropriate journeys
/// based on the 2026 journey titles provided by content team. Uses discretion to recommend
/// the best fit, or explicitly mentions when no journey fit exists.
class JourneyMappingService {
  const JourneyMappingService();

  /// Maps growth areas to recommended journey suggestions.
  /// Returns 2-3 journeys ordered by relevance.
  List<JourneyRecommendation> getJourneyRecommendations({
    required List<DimensionRecommendation> growthAreas,
    required AssessmentType assessmentType,
    required bool isSafetyAlert,
    String? assessmentId,
  }) {
    if (isSafetyAlert) {
      // If safety is a concern, prioritize safety-first journeys
      return _mapSafetyJourneys(assessmentType, assessmentId);
    }

    final journeys = <JourneyRecommendation>[];

    // Get up to 3 most impactful growth areas
    final topGrowthAreas = growthAreas.take(3).toList();

    for (final dimension in topGrowthAreas) {
      final recommendations = _mapDimensionToJourney(
        dimension: dimension,
        assessmentType: assessmentType,
        assessmentId: assessmentId,
      );
      journeys.addAll(recommendations);
    }

    // Deduplicate by journey title while preserving order
    final seen = <String>{};
    final deduped = <JourneyRecommendation>[];
    for (final j in journeys) {
      if (seen.add(j.journeyTitle)) {
        deduped.add(j);
      }
    }

    return deduped.take(3).toList();
  }

  /// Maps a single dimension to the best-fit journey for the given assessment type.
  ///
  /// Returns list of journeys (primary + contextually relevant secondary ones).
  /// Returns empty list if no fit is found (discretion applied).
  List<JourneyRecommendation> _mapDimensionToJourney({
    required DimensionRecommendation dimension,
    required AssessmentType assessmentType,
    String? assessmentId,
  }) {
    switch (assessmentType) {
      case AssessmentType.singlesReadiness:
        // Singles are handled by config-driven async path in buildAsync()
        // Return empty to force config usage - let config be the source of truth
        return [];
      case AssessmentType.marriageHealthCheck:
        // Married is also handled by config-driven async path in buildAsync()
        // Return empty to force config usage - let config be the source of truth
        return [];
      case AssessmentType.remarriageReadiness:
        return _mapRemarriageJourney(dimension, assessmentId: assessmentId);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // REMARRIAGE JOURNEY MAPPING (16 journeys available)
  // ═══════════════════════════════════════════════════════════════════════

  List<JourneyRecommendation> _mapRemarriageJourney(
    DimensionRecommendation d, {
    String? assessmentId,
  }) {
    final dimLower = d.dimensionName.toLowerCase();
    final isWidowed = assessmentId?.toLowerCase().contains('widowed') ?? false;
    final recommendations = <JourneyRecommendation>[];

    // Past Wounds / Healing (J1, J2, J3) — Foundation + Processing
    if (dimLower.contains('past') ||
        dimLower.contains('wound') ||
        dimLower.contains('hurt') ||
        dimLower.contains('grief')) {
      if (isWidowed &&
          (dimLower.contains('grief') || dimLower.contains('loss'))) {
        // Widowed: Grief and Loss focus + loneliness
        recommendations.add(
          JourneyRecommendation(
            journeyTitle: 'Navigating Grief and Loss',
            journeyId: 'grief_loss_widowed',
            rationale:
                'Grieving your loss is the foundation for rebuilding and new love.',
            relevantDimension: d.dimensionName,
            dimensionScore: d.percentage,
          ),
        );
        recommendations.add(
          JourneyRecommendation(
            journeyTitle: 'Dealing with Loneliness After Loss',
            journeyId: 'loneliness_widowed',
            rationale: 'Processing both grief and the isolation it brings.',
            relevantDimension: d.dimensionName,
            dimensionScore: d.percentage,
          ),
        );
        return recommendations;
      }
      // Divorced: Past marriage lessons + pain processing
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Understanding What Went Wrong in Your Past Marriage',
          journeyId: 'past_marriage_lessons_remarriage',
          rationale:
              'Learning from past mistakes prevents repeating them in remarriage.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Processing Past Relationship Pain',
          journeyId: 'pain_processing_remarriage',
          rationale: 'Emotional processing is foundational to moving forward.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Identity / Self-worth + Resentment Release (J4, J5)
    if (dimLower.contains('identity') ||
        dimLower.contains('self-worth') ||
        dimLower.contains('self_worth') ||
        dimLower.contains('rebuilding')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Rebuilding Your Identity and Self-worth',
          journeyId: 'identity_rebuilding_remarriage',
          rationale: 'Strong identity precedes healthy remarriage.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      // Secondary: Can't rebuild identity while holding resentment
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Letting Go of Resentment and Lingering Conflict',
          journeyId: 'resentment_for_identity_remarriage',
          rationale:
              'Resentment keeps you bound to the past; release is essential.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Resentment / Conflict (J5) — Letting go
    if (dimLower.contains('resentment') ||
        dimLower.contains('conflict') ||
        dimLower.contains('anger')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Letting Go of Resentment and Lingering Conflict',
          journeyId: 'resentment_release_remarriage',
          rationale: 'Unresolved anger poisons potential new relationships.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Faith / Community (J6) — Support system
    if (dimLower.contains('faith') ||
        dimLower.contains('spiritual') ||
        dimLower.contains('church')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Faith, Church, and Community After Divorce',
          journeyId: 'faith_community_remarriage',
          rationale:
              'Spiritual grounding supports healing and remarriage readiness.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Financial Recovery (J7) — Stability
    if (dimLower.contains('financial') || dimLower.contains('finance')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Financial Recovery After Divorce',
          journeyId: 'financial_recovery_remarriage',
          rationale: 'Financial stability reassures ability to build new life.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Co-parenting / Family (J8, J9) — Practical + emotional
    if (dimLower.contains('parent') || dimLower.contains('child')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Co-parenting with Peace and Stability',
          journeyId: 'coparenting_remarriage',
          rationale:
              'Healthy co-parenting sets stage for remarriage stability.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      // Secondary: Special occasions often trigger co-parenting challenges
      recommendations.add(
        JourneyRecommendation(
          journeyTitle:
              'Navigating Anniversaries & Special Occasions After Divorce',
          journeyId: 'occasions_remarriage',
          rationale:
              'Co-parenting complexities intensify around holidays and milestones.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Trust Rebuilding (J11) — Relational readiness
    if (dimLower.contains('trust')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Developing Trust with the Opposite Sex Again',
          journeyId: 'trust_rebuilding_remarriage',
          rationale: 'Trust capacity must be restored before healthy dating.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Pattern Recognition (J12) + Trust Rebuilding (J11) — Prevention + readiness
    if (dimLower.contains('pattern') ||
        dimLower.contains('toxic') ||
        dimLower.contains('trigger')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Addressing Toxic Patterns Before Remarriage',
          journeyId: 'pattern_awareness_remarriage',
          rationale: 'Recognizing toxic patterns prevents repeating them.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      // Secondary: Recognizing patterns requires trusting your judgment again
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Developing Trust with the Opposite Sex Again',
          journeyId: 'trust_for_patterns_remarriage',
          rationale:
              'Pattern recognition requires trusting your instincts again.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Emotional Readiness (J13) — Gut check
    if (dimLower.contains('emotional') ||
        dimLower.contains('readiness') ||
        dimLower.contains('regulation')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Emotional Readiness for Remarriage',
          journeyId: 'emotional_readiness_remarriage',
          rationale: 'Emotional stability ensures remarriage can be healthy.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Discernment / New Love (J14) — Clarity
    if (dimLower.contains('discern') ||
        dimLower.contains('choice') ||
        dimLower.contains('selection')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Discerning Healthy Love Again',
          journeyId: 'healthy_love_discernment_remarriage',
          rationale: 'Clear discernment prevents repeating past mistakes.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // No strong fit — return empty list
    return recommendations;
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SAFETY-FIRST JOURNEY MAPPINGS
  // ═══════════════════════════════════════════════════════════════════════

  List<JourneyRecommendation> _mapSafetyJourneys(
    AssessmentType type,
    String? assessmentId,
  ) {
    // Safety-first journeys, contextual per assessment type
    final isWidowed = assessmentId?.contains('widowed') ?? false;

    switch (type) {
      case AssessmentType.singlesReadiness:
        return [
          JourneyRecommendation(
            journeyTitle: 'Creating Healthy Boundaries with the Opposite Sex',
            journeyId: 'safety_boundaries_singles',
            rationale:
                'Your responses suggest safety concerns. Healthy boundaries protect you before entering relationships.',
            relevantDimension: 'Safety Alert',
            dimensionScore: 0,
          ),
        ];
      case AssessmentType.marriageHealthCheck:
        return [
          JourneyRecommendation(
            journeyTitle: 'Rebuilding Trust After Hurt or Betrayal in Marriage',
            journeyId: 'safety_trust_married',
            rationale:
                'Your responses suggest safety may be compromised. Rebuilding trust requires intentional steps.',
            relevantDimension: 'Safety Alert',
            dimensionScore: 0,
          ),
        ];
      case AssessmentType.remarriageReadiness:
        // Distinguish between divorced and widowed paths for safety journeys
        if (isWidowed) {
          return [
            JourneyRecommendation(
              journeyTitle: 'Navigating Grief and Loss',
              journeyId: 'safety_grief_widowed',
              rationale:
                  'Your responses suggest grief may be a factor affecting safety. Processing loss is crucial before moving forward.',
              relevantDimension: 'Safety Alert',
              dimensionScore: 0,
            ),
          ];
        } else {
          return [
            JourneyRecommendation(
              journeyTitle: 'Addressing Toxic Patterns Before Remarriage',
              journeyId: 'safety_patterns_divorced',
              rationale:
                  'Your responses suggest safety concerns. Recognizing toxic patterns prevents repeating them.',
              relevantDimension: 'Safety Alert',
              dimensionScore: 0,
            ),
          ];
        }
    }
  }
}

class JourneyRecommendation {
  final String journeyTitle;
  final String journeyId;
  final String rationale;
  final String relevantDimension;
  final int dimensionScore; // 0-100 percentage

  JourneyRecommendation({
    required this.journeyTitle,
    required this.journeyId,
    required this.rationale,
    required this.relevantDimension,
    required this.dimensionScore,
  });
}
