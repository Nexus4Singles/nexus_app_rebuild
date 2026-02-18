import 'package:equatable/equatable.dart';

/// Individual journey recommendation item
class JourneyRecommendationItem extends Equatable {
  final String journeyId;
  final String journeyTitle;
  final String rationale;

  const JourneyRecommendationItem({
    required this.journeyId,
    required this.journeyTitle,
    required this.rationale,
  });

  factory JourneyRecommendationItem.fromJson(Map<String, dynamic> json) {
    return JourneyRecommendationItem(
      journeyId: json['journeyId'] as String? ?? '',
      journeyTitle: json['journeyTitle'] as String? ?? '',
      rationale: json['rationale'] as String? ?? '',
    );
  }

  @override
  List<Object?> get props => [journeyId, journeyTitle, rationale];
}

/// Dimension with its recommended journeys
class DimensionRecommendationsMapping extends Equatable {
  final String dimensionId;
  final String dimensionName;
  final List<JourneyRecommendationItem> recommendations;
  final String? clinicalNote;

  const DimensionRecommendationsMapping({
    required this.dimensionId,
    required this.dimensionName,
    required this.recommendations,
    this.clinicalNote,
  });

  factory DimensionRecommendationsMapping.fromJson(Map<String, dynamic> json) {
    final recsJson = json['recommendations'] as List<dynamic>? ?? [];
    return DimensionRecommendationsMapping(
      dimensionId: json['dimensionId'] as String? ?? '',
      dimensionName: json['dimensionName'] as String? ?? '',
      recommendations:
          recsJson
              .map(
                (e) => JourneyRecommendationItem.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
      clinicalNote: json['clinicalNote'] as String?,
    );
  }

  @override
  List<Object?> get props => [
    dimensionId,
    dimensionName,
    recommendations,
    clinicalNote,
  ];
}

/// Individual profile-based recommendation level
class ProfileRecommendationLevel extends Equatable {
  final String description;
  final List<String> recommendations;
  final String? clinicalNote;

  const ProfileRecommendationLevel({
    required this.description,
    required this.recommendations,
    this.clinicalNote,
  });

  factory ProfileRecommendationLevel.fromJson(Map<String, dynamic> json) {
    final recsValue = json['recommendations'];
    final recsArray = <String>[];

    if (recsValue is List) {
      recsArray.addAll(recsValue.map((e) => e.toString()));
    }

    return ProfileRecommendationLevel(
      description: json['description'] as String? ?? '',
      recommendations: recsArray,
      clinicalNote: json['clinicalNote'] as String?,
    );
  }

  @override
  List<Object?> get props => [description, recommendations, clinicalNote];
}

/// Profile-based recommendations (STRONG, DEVELOPING, GUARDED, AT_RISK)
class ProfileBasedRecommendations extends Equatable {
  final ProfileRecommendationLevel? strong;
  final ProfileRecommendationLevel? developing;
  final ProfileRecommendationLevel? guarded;
  final ProfileRecommendationLevel? atRisk;

  const ProfileBasedRecommendations({
    this.strong,
    this.developing,
    this.guarded,
    this.atRisk,
  });

  factory ProfileBasedRecommendations.fromJson(Map<String, dynamic> json) {
    return ProfileBasedRecommendations(
      strong:
          json['STRONG'] != null
              ? ProfileRecommendationLevel.fromJson(
                json['STRONG'] as Map<String, dynamic>,
              )
              : null,
      developing:
          json['DEVELOPING'] != null
              ? ProfileRecommendationLevel.fromJson(
                json['DEVELOPING'] as Map<String, dynamic>,
              )
              : null,
      guarded:
          json['GUARDED'] != null
              ? ProfileRecommendationLevel.fromJson(
                json['GUARDED'] as Map<String, dynamic>,
              )
              : null,
      atRisk:
          json['AT_RISK'] != null
              ? ProfileRecommendationLevel.fromJson(
                json['AT_RISK'] as Map<String, dynamic>,
              )
              : null,
    );
  }

  @override
  List<Object?> get props => [strong, developing, guarded, atRisk];
}

/// Assessment-specific recommendations
class AssessmentRecommendations extends Equatable {
  final String assessmentId;
  final String audience;
  final List<DimensionRecommendationsMapping> dimensionMappings;
  final ProfileBasedRecommendations? profileBasedRecommendations;

  const AssessmentRecommendations({
    required this.assessmentId,
    required this.audience,
    required this.dimensionMappings,
    this.profileBasedRecommendations,
  });

  factory AssessmentRecommendations.fromJson(Map<String, dynamic> json) {
    final mappingsJson = json['dimensionMappings'] as List<dynamic>? ?? [];
    return AssessmentRecommendations(
      assessmentId: json['assessmentId'] as String? ?? '',
      audience: json['audience'] as String? ?? '',
      dimensionMappings:
          mappingsJson
              .map(
                (e) => DimensionRecommendationsMapping.fromJson(
                  e as Map<String, dynamic>,
                ),
              )
              .toList(),
      profileBasedRecommendations:
          json['profileBasedRecommendations'] != null
              ? ProfileBasedRecommendations.fromJson(
                json['profileBasedRecommendations'] as Map<String, dynamic>,
              )
              : null,
    );
  }

  @override
  List<Object?> get props => [
    assessmentId,
    audience,
    dimensionMappings,
    profileBasedRecommendations,
  ];
}

/// Root configuration for assessment journey recommendations
class AssessmentRecommendationsConfig extends Equatable {
  final String documentTitle;
  final String version;
  final String lastUpdated;
  final String methodology;
  final AssessmentRecommendations? singlesReadiness;
  final AssessmentRecommendations marriageHealthCheck;
  final AssessmentRecommendations remarriageDivorced;
  final AssessmentRecommendations remarriageWidowed;

  const AssessmentRecommendationsConfig({
    required this.documentTitle,
    required this.version,
    required this.lastUpdated,
    required this.methodology,
    this.singlesReadiness,
    required this.marriageHealthCheck,
    required this.remarriageDivorced,
    required this.remarriageWidowed,
  });

  factory AssessmentRecommendationsConfig.fromJson(Map<String, dynamic> json) {
    return AssessmentRecommendationsConfig(
      documentTitle: json['documentTitle'] as String? ?? '',
      version: json['version'] as String? ?? '',
      lastUpdated: json['lastUpdated'] as String? ?? '',
      methodology: json['methodology'] as String? ?? '',
      singlesReadiness:
          json['singlesReadiness'] != null
              ? AssessmentRecommendations.fromJson(
                json['singlesReadiness'] as Map<String, dynamic>,
              )
              : null,
      marriageHealthCheck: AssessmentRecommendations.fromJson(
        json['marriageHealthCheck'] as Map<String, dynamic>? ?? {},
      ),
      remarriageDivorced: AssessmentRecommendations.fromJson(
        json['remarriageDivorced'] as Map<String, dynamic>? ?? {},
      ),
      remarriageWidowed: AssessmentRecommendations.fromJson(
        json['remarriageWidowed'] as Map<String, dynamic>? ?? {},
      ),
    );
  }

  @override
  List<Object?> get props => [
    documentTitle,
    version,
    lastUpdated,
    methodology,
    singlesReadiness,
    marriageHealthCheck,
    remarriageDivorced,
    remarriageWidowed,
  ];
}
