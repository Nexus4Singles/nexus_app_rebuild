import 'dating_profile.dart';

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
