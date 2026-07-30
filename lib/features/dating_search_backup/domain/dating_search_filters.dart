class DatingSearchFilters {
  final int minAge;
  final int maxAge;

  final String? countryOfResidence;
  final List<String>? countryOptions;
  final String? longDistance;
  final String? maritalStatus;
  final String? hasKids;
  final String? genotype;

  const DatingSearchFilters({
    required this.minAge,
    required this.maxAge,
    this.countryOfResidence,
    this.countryOptions,
    this.longDistance,
    this.maritalStatus,
    this.hasKids,
    this.genotype,
  });

  DatingSearchFilters copyWith({
    int? minAge,
    int? maxAge,
    String? countryOfResidence,
    List<String>? countryOptions,
    String? longDistance,
    String? maritalStatus,
    String? hasKids,
    String? genotype,
  }) {
    return DatingSearchFilters(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      countryOfResidence: countryOfResidence ?? this.countryOfResidence,
      countryOptions: countryOptions ?? this.countryOptions,
      longDistance: longDistance ?? this.longDistance,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      hasKids: hasKids ?? this.hasKids,
      genotype: genotype ?? this.genotype,
    );
  }

  @override
  String toString() {
    return 'DatingSearchFilters('
        'minAge=$minAge, maxAge=$maxAge, '
        'countryOfResidence=$countryOfResidence, '
        'longDistance=$longDistance, '
        'maritalStatus=$maritalStatus, '
        'hasKids=$hasKids, '
        'genotype=$genotype'
        ')';
  }
}
