import 'package:equatable/equatable.dart';

// ============================================================================
// ONBOARDING LISTS CONFIG
// Used for profile setup dropdowns (hobbies, professions, states, etc.)
// ============================================================================

/// Onboarding configuration loaded from JSON
/// Contains all dropdown lists for profile setup
class OnboardingConfig extends Equatable {
  final int version;
  final List<String> hobbies;
  final List<String> desireQualities;
  final List<String> professions;
  final List<String> educationalLevels;
  final List<String> states;
  final List<String> churches;

  const OnboardingConfig({
    required this.version,
    required this.hobbies,
    required this.desireQualities,
    required this.professions,
    required this.educationalLevels,
    required this.states,
    required this.churches,
  });

  factory OnboardingConfig.fromJson(Map<String, dynamic> json) {
    final lists = json['lists'] as Map<String, dynamic>? ?? {};

    return OnboardingConfig(
      version: json['version'] as int? ?? 1,
      hobbies: _parseStringList(lists['hobbies']),
      desireQualities: _parseStringList(lists['desireQualities']),
      professions: _parseStringList(lists['professions']),
      educationalLevels: _parseStringList(lists['educationalLevels']),
      states: _parseStringList(lists['states']),
      churches: _parseChurchList(lists['church']),
    );
  }

  /// Basic parser for simple string lists
  static List<String> _parseStringList(dynamic data) {
    if (data == null) return const <String>[];
    if (data is List) {
      return data
          .whereType<String>()
          .where((s) => s.isNotEmpty)
          .map((s) => s.trim())
          .toList();
    }
    return const <String>[];
  }

  /// Special parsing for church list which may have corrupted data
  static List<String> _parseChurchList(dynamic data) {
    if (data == null) return defaultChurches;
    if (data is List) {
      final parsed =
          data
              .whereType<String>()
              .where((s) => s.isNotEmpty && s.length > 3 && !s.contains('\\n'))
              .map((s) => s.trim())
              .toList();
      // If parsed list is too short or corrupted, use defaults
      if (parsed.length < 10) return defaultChurches;
      return parsed;
    }
    return defaultChurches;
  }

  /// Comprehensive Nigerian churches list (used as fallback for corrupted JSON)
  static const List<String> defaultChurches = [
    // Major Pentecostal Churches
    'Redeemed Christian Church of God (RCCG)',
    'Living Faith Church / Winners Chapel',
    'Deeper Christian Life Ministry',
    'Mountain of Fire & Miracles Ministries',
    'Christ Embassy / Believers LoveWorld',
    'Salvation Ministries',
    'Streams of Joy International',
    'Koinonia Global / Eternity Network',
    'Commonwealth of Zion Assembly (COZA)',
    'House on the Rock',
    'Daystar Christian Centre',
    'Fountain of Life Church',
    'Covenant Christian Centre',
    'Harvesters International Christian Centre',
    'This Present House',
    'The Elevation Church',
    'Waterbrook Church',
    'Trinity House Church',
    'Latter Rain Assembly',
    'Kingdom Life Network',
    'Guiding Light Assembly',
    'Word of Life Bible Church',
    'Global Impact Church',

    // Traditional/Orthodox Churches
    'Catholic Church',
    'Anglican Church',
    'Methodist Church',
    'Baptist Church',
    'Presbyterian Church',
    'Lutheran Church',
    'Seventh Day Adventist Church',

    // African Indigenous Churches
    'The Apostolic Church',
    'Celestial Church of Christ',
    'Cherubim and Seraphim Church',
    'Christ Apostolic Church (CAC)',
    'The African Church',

    // Other Notable Churches
    'Household of God Church',
    'Sword of the Spirit Ministries',
    'Power Chapel Worldwide',
    'Grace Revolution Church',
    'Jesus House',
    'Liberty Christian Fellowship',
    'New Life Church',
    'HillSong Church',
    'Rhema Bible Church',
    'All Nations Christian Ministry',

    // Default option
    'Other',
  ];

  Map<String, dynamic> toJson() => {
    'version': version,
    'lists': {
      'hobbies': hobbies,
      'desireQualities': desireQualities,
      'professions': professions,
      'educationalLevels': educationalLevels,
      'states': states,
      'church': churches,
    },
  };

  @override
  List<Object?> get props => [
    version,
    hobbies,
    desireQualities,
    professions,
    educationalLevels,
    states,
    churches,
  ];
}

// ============================================================================
// SEARCH/EXPLORE FILTERS CONFIG
// Used for dating section search filters (for singles only)
// ============================================================================

/// Search filters configuration for dating section
/// These are filter options for the Explore/Search page
class SearchFiltersConfig extends Equatable {
  final List<String> countryOfResidenceFilters;
  final List<String> relationshipDistanceFilters;
  final List<String> maritalStatusFilters;
  final List<String> hasKidsFilters;
  final List<String> genotypeFilters;

  const SearchFiltersConfig({
    required this.countryOfResidenceFilters,
    required this.relationshipDistanceFilters,
    required this.maritalStatusFilters,
    required this.hasKidsFilters,
    required this.genotypeFilters,
  });

  factory SearchFiltersConfig.fromJson(Map<String, dynamic> json) {
    final lists = json['lists'] as Map<String, dynamic>? ?? {};

    return SearchFiltersConfig(
      countryOfResidenceFilters: _parseFilterList(
        lists['countryOfResidenceFilters'],
        defaultCountryFilters,
      ),
      relationshipDistanceFilters: _parseFilterList(
        lists['relationshipDistanceFilters'],
        defaultDistanceFilters,
      ),
      maritalStatusFilters: _parseFilterList(
        lists['maritalStatusFilters'],
        defaultMaritalStatusFilters,
      ),
      hasKidsFilters: _parseFilterList(
        lists['hasKidsFilters'],
        defaultHasKidsFilters,
      ),
      genotypeFilters: _parseFilterList(
        lists['genotypeFilters'],
        defaultGenotypeFilters,
      ),
    );
  }

  static List<String> _parseFilterList(dynamic data, List<String> defaults) {
    if (data == null) return defaults;
    if (data is List) {
      final parsed =
          data.whereType<String>().where((s) => s.isNotEmpty).toList();
      return parsed.isNotEmpty ? parsed : defaults;
    }
    return defaults;
  }

  // Default filter options
  static const List<String> defaultCountryFilters = [
    'Nigeria',
    'Diaspora',
    'Any',
  ];
  static const List<String> defaultDistanceFilters = ['Yes', 'No', 'Any'];
  static const List<String> defaultMaritalStatusFilters = [
    'Never Married',
    'Any Status',
  ];
  static const List<String> defaultHasKidsFilters = [
    'No kids',
    'Has kids',
    'Any',
  ];
  static const List<String> defaultGenotypeFilters = ['AA only', 'Anyone'];

  @override
  List<Object?> get props => [
    countryOfResidenceFilters,
    relationshipDistanceFilters,
    maritalStatusFilters,
    hasKidsFilters,
    genotypeFilters,
  ];
}

// ============================================================================
// COUNTRY MODEL
// ============================================================================

/// Country model for country picker
class CountryData extends Equatable {
  final String name;
  final String code; // ISO-2 code
  final String dialCode;
  final String flag;

  const CountryData({
    required this.name,
    required this.code,
    required this.dialCode,
    required this.flag,
  });

  factory CountryData.fromJson(Map<String, dynamic> json) {
    return CountryData(
      name: json['name'] as String? ?? '',
      code: json['code'] as String? ?? '',
      dialCode: json['dial_code'] as String? ?? '',
      flag: json['flag'] as String? ?? '',
    );
  }

  Map<String, dynamic> toJson() => {
    'name': name,
    'code': code,
    'dial_code': dialCode,
    'flag': flag,
  };

  @override
  List<Object?> get props => [name, code];
}
