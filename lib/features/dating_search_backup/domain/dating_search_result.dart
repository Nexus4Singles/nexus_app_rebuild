import 'dating_profile.dart';

/// Structured breakdown of why no profiles matched.
/// Allows the UI to show specific, actionable feedback.
class NoProfilesBreakdown {
  /// Total profiles fetched from Firestore (before any in-memory filter).
  final int totalFetched;

  /// Profiles remaining after applying the age bracket filter.
  final int afterAgeFilter;

  /// Profiles remaining after applying the country filter.
  final int afterCountryFilter;

  /// The user's selected age range.
  final int minAge;
  final int maxAge;

  /// The user's selected country (display name).
  final String? countryName;

  /// Which filter step caused the result to drop to zero.
  /// null if results are non-empty.
  final String? eliminatingFilter;

  const NoProfilesBreakdown({
    required this.totalFetched,
    required this.afterAgeFilter,
    required this.afterCountryFilter,
    required this.minAge,
    required this.maxAge,
    this.countryName,
    this.eliminatingFilter,
  });

  /// True when there are profiles in the system but none in the age bracket.
  bool get noProfilesInAgeBracket => totalFetched > 0 && afterAgeFilter == 0;

  /// True when there are profiles in the age bracket but none in the country.
  bool get noProfilesInCountry => afterAgeFilter > 0 && afterCountryFilter == 0;

  /// True when both age and country together yield zero.
  bool get noProfilesForAgePlusCountry =>
      totalFetched > 0 && afterAgeFilter == 0 && afterCountryFilter == 0;

  /// True when there are zero profiles system-wide for this gender.
  bool get noProfilesAtAll => totalFetched == 0;
}

class DatingSearchResult {
  final List<DatingProfile> items;

  /// Human-friendly hint about which filter likely eliminated results.
  /// Example: "Long distance: No"
  final String? emptyHint;

  /// Whether no profiles exist in the selected country at all.
  /// If true: no profiles in country (not a filter issue).
  /// If false: profiles exist in country but don't match other preferences.
  final bool noProfilesInCountry;

  /// Max pagination pages for this result set
  /// Prevents infinite scrolling through old inactive profiles
  /// All users: 100 pages (2000 profiles), Admin: 500 pages
  /// When user reaches this limit, they see "End of current search results"
  final int maxPaginationPages;

  /// Structured breakdown of why no profiles were found.
  /// Only populated when items is empty.
  final NoProfilesBreakdown? noProfilesBreakdown;

  /// True when results were expanded beyond the user's selected country because
  /// that country had fewer than the expansion threshold of profiles.
  /// The UI shows a soft informational banner when this is true.
  final bool isExpandedSearch;

  const DatingSearchResult({
    required this.items,
    this.emptyHint,
    this.noProfilesInCountry = false,
    this.maxPaginationPages = 100,
    this.noProfilesBreakdown,
    this.isExpandedSearch = false,
  });

  bool get isEmpty => items.isEmpty;
}
