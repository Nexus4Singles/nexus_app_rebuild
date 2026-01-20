class OnboardingListsModel {
  final List<String> hobbies;
  final List<String> desiredQualities;
  final List<String> professions;
  final List<String> educationalLevels;
  final List<String> churches;

  const OnboardingListsModel({
    required this.hobbies,
    required this.desiredQualities,
    required this.professions,
    required this.educationalLevels,
    required this.churches,
  });

  factory OnboardingListsModel.fromJson(Map<String, dynamic> lists) {
    List<String> _asStringList(String key) {
      final raw = lists[key];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return const <String>[];
    }

    return OnboardingListsModel(
      hobbies: _asStringList('hobbies'),
      desiredQualities: _asStringList('desireQualities'),
      professions: _asStringList('professions'),
      educationalLevels: _asStringList('educationalLevels'),
      churches: _asStringList('church'),
    );
  }
}

class SearchFilterListsModel {
  final List<String> countryOfResidenceFilters;
  final List<String> educationLevelFilters;
  final List<String> incomeSourceFilters;
  final List<String> relationshipDistanceFilters;
  final List<String> maritalStatusFilters;
  final List<String> hasKidsFilters;
  final List<String> genotypeFilters;

  const SearchFilterListsModel({
    required this.countryOfResidenceFilters,
    required this.educationLevelFilters,
    required this.incomeSourceFilters,
    required this.relationshipDistanceFilters,
    required this.maritalStatusFilters,
    required this.hasKidsFilters,
    required this.genotypeFilters,
  });

  factory SearchFilterListsModel.fromJson(Map<String, dynamic> lists) {
    List<String> _asStringList(String key) {
      final raw = lists[key];
      if (raw is List) return raw.map((e) => e.toString()).toList();
      return const <String>[];
    }

    return SearchFilterListsModel(
      countryOfResidenceFilters: _asStringList('countryOfResidenceFilters'),
      educationLevelFilters: _asStringList('educationLevelFilters'),
      incomeSourceFilters: _asStringList('incomeSourceFilters'),
      relationshipDistanceFilters: _asStringList('relationshipDistanceFilters'),
      maritalStatusFilters: _asStringList('maritalStatusFilters'),
      hasKidsFilters: _asStringList('hasKidsFilters'),
      genotypeFilters: _asStringList('genotypeFilters'),
    );
  }
}
