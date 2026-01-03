class DatingSearchFilters {
  final int minAge;
  final int maxAge;

  final String? countryOfResidence;
  final String? educationLevel;
  final String? regularSourceOfIncome;
  final String? longDistance;
  final String? maritalStatus;
  final String? hasKids;
  final String? genotype;

  const DatingSearchFilters({
    required this.minAge,
    required this.maxAge,
    this.countryOfResidence,
    this.educationLevel,
    this.regularSourceOfIncome,
    this.longDistance,
    this.maritalStatus,
    this.hasKids,
    this.genotype,
  });

  DatingSearchFilters copyWith({
    int? minAge,
    int? maxAge,
    String? countryOfResidence,
    String? educationLevel,
    String? regularSourceOfIncome,
    String? longDistance,
    String? maritalStatus,
    String? hasKids,
    String? genotype,
  }) {
    return DatingSearchFilters(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      countryOfResidence: countryOfResidence ?? this.countryOfResidence,
      educationLevel: educationLevel ?? this.educationLevel,
      regularSourceOfIncome:
          regularSourceOfIncome ?? this.regularSourceOfIncome,
      longDistance: longDistance ?? this.longDistance,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      hasKids: hasKids ?? this.hasKids,
      genotype: genotype ?? this.genotype,
    );
  }
}
