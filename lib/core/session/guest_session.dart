import '../constants/app_constants.dart';

class GuestSession {
  final RelationshipStatus relationshipStatus;
  final String? gender; // "male" | "female"
  final List<String> goals;

  const GuestSession({
    required this.relationshipStatus,
    this.gender,
    this.goals = const [],
  });

  GuestSession copyWith({
    RelationshipStatus? relationshipStatus,
    String? gender,
    List<String>? goals,
  }) {
    return GuestSession(
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      gender: gender ?? this.gender,
      goals: goals ?? this.goals,
    );
  }
}
