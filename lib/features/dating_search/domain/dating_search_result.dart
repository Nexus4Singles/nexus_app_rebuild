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

  /// Whether user has hit the daily limit and needs premium to view more
  /// ONLY applies to FREE users. Premium users have unlimited access.
  final bool hitDailyLimit;

  /// Total remaining profiles available (before hitting limit)
  final int? totalAvailableCount;

  /// When the daily limit was last hit (for tracking 24-hour reset)
  /// Persisted to Firestore to survive app restarts
  final DateTime? dailyLimitHitAt;

  /// Whether no profiles exist in the selected country at all.
  /// If true: no profiles in country (not a filter issue).
  /// If false: profiles exist in country but don't match other preferences.
  final bool noProfilesInCountry;

  /// For FREE users: Whether all available profiles have been shown today
  /// If true + hitDailyLimit: show "No new profiles, check back tomorrow!"
  /// If false + hitDailyLimit: show "More profiles available, upgrade to see all"
  final bool allAvailableShownToday;

  /// Persisted profile IDs shown to free user today (for deduplication)
  final List<String> shownProfileIds;

  /// Max pagination pages for this result set
  /// Prevents infinite scrolling through old inactive profiles
  /// Free users: 25 pages, Subscribed: 100 pages, Admin: 500 pages
  /// When user reaches this limit, they see "End of current search results"
  final int maxPaginationPages;

  /// Structured breakdown of why no profiles were found.
  /// Only populated when items is empty.
  final NoProfilesBreakdown? noProfilesBreakdown;

  const DatingSearchResult({
    required this.items,
    this.emptyHint,
    this.hitDailyLimit = false,
    this.totalAvailableCount,
    this.dailyLimitHitAt,
    this.noProfilesInCountry = false,
    this.allAvailableShownToday = false,
    this.shownProfileIds = const [],
    this.maxPaginationPages = 100,
    this.noProfilesBreakdown,
  });

  bool get isEmpty => items.isEmpty;

  /// Check if 24 hours have passed since the daily limit was hit
  /// Returns true if limit should be reset (24+ hours have passed)
  bool get isDailyLimitExpired {
    if (!hitDailyLimit || dailyLimitHitAt == null) return false;

    final now = DateTime.now();
    final hoursSinceLimitHit = now.difference(dailyLimitHitAt!).inHours;

    return hoursSinceLimitHit >= 24;
  }
}
