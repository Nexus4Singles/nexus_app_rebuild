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
        return _mapSinglesJourney(dimension);
      case AssessmentType.marriageHealthCheck:
        return _mapMarriedJourney(dimension);
      case AssessmentType.remarriageReadiness:
        return _mapRemarriageJourney(dimension, assessmentId: assessmentId);
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // SINGLES JOURNEY MAPPING (21 journeys available)
  // ═══════════════════════════════════════════════════════════════════════

  List<JourneyRecommendation> _mapSinglesJourney(DimensionRecommendation d) {
    final dimLower = d.dimensionName.toLowerCase();
    final recommendations = <JourneyRecommendation>[];

    // Attachment Security (J1) — Core readiness
    if (dimLower.contains('attachment') || dimLower.contains('security')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Understanding Your Identity and Self-Worth',
          journeyId: 'identity_self_worth_singles',
          rationale:
              'Secure attachment starts with understanding your own worth.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Emotional Regulation (J6) — Core competency + readiness
    if (dimLower.contains('emotional') && dimLower.contains('regulation')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Developing Emotional Intelligence and Maturity',
          journeyId: 'emotional_intelligence_singles',
          rationale:
              'Managing emotions is foundational for healthy relationships.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      // Secondary: Emotional readiness for marriage
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Building Emotional Readiness for Marriage',
          journeyId: 'emotional_readiness_singles',
          rationale:
              'Emotional regulation matures into broader relationship readiness.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Conflict Posture / Conflict Resolution (J10) + Confidence (J7)
    if (dimLower.contains('conflict')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Communicate Better, Love Better',
          journeyId: 'communication_skills_singles',
          rationale:
              'Healthy conflict management starts with clear communication.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      // Secondary: Confidence for assertive communication
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Building Secure Confidence for Healthy Dating',
          journeyId: 'confidence_dating_singles',
          rationale:
              'Clear communication requires confidence in your perspective.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Family Background / Learned Patterns (J4) + Healing (J3)
    if (dimLower.contains('family') || dimLower.contains('pattern')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Addressing Unhealthy Family Background Patterns',
          journeyId: 'family_patterns_singles',
          rationale:
              'Past family dynamics shape current relationship readiness.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      // Secondary: Healing from family wounds
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Healing from Past Relationship Wounds',
          journeyId: 'family_healing_singles',
          rationale:
              'Family patterns often created emotional wounds needing healing.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Past Relationship Integration / Unresolved Wounds (J3)
    if (dimLower.contains('past') &&
        (dimLower.contains('wound') || dimLower.contains('hurt'))) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Healing from Past Relationship Wounds',
          journeyId: 'past_healing_singles',
          rationale:
              'Unresolved past hurts block present readiness and future growth.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Spiritual Consistency / Leadership Understanding (J17)
    if (dimLower.contains('spiritual')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Faith and Spiritual Alignment',
          journeyId: 'faith_alignment_singles',
          rationale:
              'Shared spiritual foundation strengthens marriage readiness.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Trigger Handling / Red Flags (J8, J13) — Awareness + boundaries
    if (dimLower.contains('trigger')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Identifying Your Toxic Triggers Before Marriage',
          journeyId: 'trigger_awareness_singles',
          rationale:
              'Knowing your triggers prevents reactive relationship patterns.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Boundaries / Safety (J11) + Red Flags (J13)
    if (dimLower.contains('boundary') || dimLower.contains('boundaries')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Creating Healthy Boundaries with the Opposite Sex',
          journeyId: 'boundaries_singles',
          rationale: 'Healthy boundaries protect you in dating relationships.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      // Secondary: Red flags recognition
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Spotting Red Flags and Toxic Behaviors',
          journeyId: 'red_flags_singles',
          rationale:
              'Setting boundaries is easier when you recognize warning signs.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Marriage Expectations (J2) — Clarity on myths
    if (dimLower.contains('expectation') || dimLower.contains('expectat')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Breaking Free from Cultural Lies About Marriage',
          journeyId: 'cultural_myths_singles',
          rationale:
              'Unrealistic expectations cause marriage conflict; clarity helps.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Partner Discernment / Choosing Wisely (J14)
    if (dimLower.contains('partner') ||
        dimLower.contains('discernment') ||
        dimLower.contains('choice')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Discerning Compatibility and Values',
          journeyId: 'compatibility_singles',
          rationale: 'Clear discernment prevents poor partner choices.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Decision-Making Alignment (J10)
    if (dimLower.contains('decision')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Communicate Better, Love Better',
          journeyId: 'communication_singles',
          rationale: 'Good decisions require clear communication of values.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Priority Management (J15)
    if (dimLower.contains('priorit')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Dating with Purpose and Covenant Mindset',
          journeyId: 'covenant_mindset_singles',
          rationale: 'Clear priorities keep dating focused and purposeful.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Sexual Integrity (J16) + Purity (J18)
    if (dimLower.contains('sexual') || dimLower.contains('chemistry')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Managing Sexual Chemistry and Attachment',
          journeyId: 'sexual_integrity_singles',
          rationale: 'Sexual boundaries are essential for healthy dating.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      // Secondary: Purity and discipline
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Purity and Sexual Discipline',
          journeyId: 'purity_singles',
          rationale:
              'Managing chemistry requires discipline and covenant clarity.',
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
  // MARRIED JOURNEY MAPPING (18 journeys available)
  // ═══════════════════════════════════════════════════════════════════════

  List<JourneyRecommendation> _mapMarriedJourney(DimensionRecommendation d) {
    final dimLower = d.dimensionName.toLowerCase();
    final recommendations = <JourneyRecommendation>[];

    // Conflict Resolution (J1) + Pattern Breaking (J2) — Core work
    if (dimLower.contains('conflict')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Communication and Conflict Resolution in Marriage',
          journeyId: 'conflict_resolution_married',
          rationale: 'Conflict skills are foundational for lasting marriage.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      // Secondary: If conflict is chronic, pattern-breaking is needed
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Breaking Harmful Conflict Patterns in Marriage',
          journeyId: 'conflict_patterns_married',
          rationale:
              'Repeated conflicts often follow patterns that need breaking, not just managing.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Emotional Connection (J3) + Trust Repair (J7) — Often linked
    if (dimLower.contains('attachment') ||
        dimLower.contains('emotional') ||
        dimLower.contains('connection')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Restoring Friendship and Emotional Connection',
          journeyId: 'emotional_connection_married',
          rationale: 'Emotional intimacy is the core of marriage satisfaction.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      // Secondary: Lost connection often stems from trust issues
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Rebuilding Trust After Hurt or Betrayal in Marriage',
          journeyId: 'trust_for_connection_married',
          rationale:
              'Reconnection requires addressing underlying trust issues first.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Physical/Sexual Intimacy (J4) + Trust Repair (J7) — Trust barrier
    if (dimLower.contains('intimacy') ||
        dimLower.contains('physical') ||
        dimLower.contains('sexual')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Strengthening Emotional and Physical Intimacy',
          journeyId: 'physical_intimacy_married',
          rationale:
              'Physical intimacy strengthens overall marriage connection.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      // Secondary: Physical barriers often stem from trust/safety
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Rebuilding Trust After Hurt or Betrayal in Marriage',
          journeyId: 'trust_for_intimacy_married',
          rationale:
              'Physical intimacy requires feeling safe and trusted first.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Trust Issues / Hurt (J7) — Core repair
    if (dimLower.contains('trust') ||
        dimLower.contains('hurt') ||
        dimLower.contains('betrayal')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Rebuilding Trust After Hurt or Betrayal in Marriage',
          journeyId: 'trust_repair_married',
          rationale: 'Broken trust requires intentional rebuilding work.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Financial Management (J12) — Teamwork foundation
    if (dimLower.contains('financial') || dimLower.contains('finance')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Managing Finances as a Team',
          journeyId: 'finances_married',
          rationale: 'Financial unity prevents major marriage stress.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Parenting / Family (J13) — Shared purpose
    if (dimLower.contains('parent') || dimLower.contains('child')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Parenting as a United Team',
          journeyId: 'parenting_married',
          rationale: 'United parenting approach strengthens marriage.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Spiritual / Faith (J17) — Shared foundation
    if (dimLower.contains('spiritual') || dimLower.contains('faith')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Faith and Spiritual Unity in Marriage',
          journeyId: 'spiritual_unity_married',
          rationale: 'Spiritual alignment gives marriage lasting purpose.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Boundaries / Extended Family (J15) — Protection
    if (dimLower.contains('boundary') && dimLower.contains('family')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Healthy Boundaries with Extended Family',
          journeyId: 'family_boundaries_married',
          rationale:
              'Clear boundaries protect marriage from external interference.',
          relevantDimension: d.dimensionName,
          dimensionScore: d.percentage,
        ),
      );
      return recommendations;
    }

    // Romance / Attraction (J5) — Engagement
    if (dimLower.contains('romance') ||
        dimLower.contains('attraction') ||
        dimLower.contains('long_term')) {
      recommendations.add(
        JourneyRecommendation(
          journeyTitle: 'Keeping Romance Alive After Years Together',
          journeyId: 'romance_married',
          rationale: 'Intentionality keeps romance and attraction alive.',
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
