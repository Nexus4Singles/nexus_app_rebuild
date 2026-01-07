import '../../../core/constants/app_constants.dart';

import '../../../core/models/assessment_model.dart';

class AssessmentMeta {
  final String title;
  final String tagline;
  final String emoji;

  const AssessmentMeta({
    required this.title,
    required this.tagline,
    required this.emoji,
  });
}

extension AssessmentTypeMetaX on AssessmentType {
  AssessmentMeta get meta {
    switch (this) {
      case AssessmentType.singlesReadiness:
        return const AssessmentMeta(
          title: "Singles Readiness Assessment",
          tagline: "Discover how ready you are for intentional dating & marriage.",
          emoji: "��",
        );
      case AssessmentType.remarriageReadiness:
        return const AssessmentMeta(
          title: "Remarriage Readiness Assessment",
          tagline: "Heal, rebuild confidence, and prepare for love again.",
          emoji: "🌱",
        );
      case AssessmentType.marriageHealthCheck:
        return const AssessmentMeta(
          title: "Marriage Health Check",
          tagline: "Strengthen your marriage with a clear relationship diagnosis.",
          emoji: "💍",
        );
    }
  }
}
