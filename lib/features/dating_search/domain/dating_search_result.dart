import 'dating_profile.dart';

class DatingSearchResult {
  final List<DatingProfile> items;

  /// Human-friendly hint about which filter likely eliminated results.
  /// Example: "Long distance: No"
  final String? emptyHint;
  
  /// Whether user has hit the daily limit and needs premium to view more
  final bool hitDailyLimit;
  
  /// Total remaining profiles available (before hitting limit)
  final int? totalAvailableCount;
  
  /// When the daily limit was last hit (for tracking 24-hour reset)
  final DateTime? dailyLimitHitAt;
  
  /// Whether no profiles exist in the selected country at all.
  /// If true: no profiles in country (not a filter issue).
  /// If false: profiles exist in country but don't match other preferences.
  final bool noProfilesInCountry;

  const DatingSearchResult({
    required this.items,
    this.emptyHint,
    this.hitDailyLimit = false,
    this.totalAvailableCount,
    this.dailyLimitHitAt,
    this.noProfilesInCountry = false,
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

