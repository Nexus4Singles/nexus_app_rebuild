import 'package:equatable/equatable.dart';

/// Represents a compatibility score between two dating profiles
class CompatibilityScore extends Equatable {
  final int score; // 0-100
  final Map<String, int> fieldScores; // Breakdown by category
  final List<String> topMatches; // "You both believe in tithing"
  final List<String> differences; // "Different views on cohabiting"
  final List<String> badges; // "Faith Aligned", "Adventure Match"

  const CompatibilityScore({
    required this.score,
    required this.fieldScores,
    this.topMatches = const [],
    this.differences = const [],
    this.badges = const [],
  });

  String get displayScore => '$score%';

  @override
  List<Object?> get props => [
    score,
    fieldScores,
    topMatches,
    differences,
    badges,
  ];
}

/// Hobbies-to-traits mapping for quality inference
const Map<String, List<String>> hobbiesToTraitsMapping = {
  'Acting': ['Authentic', 'Communication', 'Confidence'],
  'Art': ['Authentic', 'Creativity', 'Expression'],
  'Beauty': ['Discipline', 'Self-Care', 'Detail-Oriented'],
  'Business': ['Leadership', 'Ambition', 'Intelligence'],
  'Comedy': ['Sense of Humor', 'Authentic', 'Confidence'],
  'Cooking': ['Kindness', 'Creativity', 'Care'],
  'Cycling': ['Discipline', 'Health-Conscious', 'Adventurous'],
  'Dancing': ['Confidence', 'Expressiveness', 'Social'],
  'Design': ['Creativity', 'Intelligence', 'Attention to Detail'],
  'Evangelism': ['Leadership', 'Communication', 'Passionate'],
  'Events Planning': ['Organization', 'Leadership', 'Social'],
  'Fashion': ['Creativity', 'Attention to Detail', 'Confidence'],
  'Fitness': ['Discipline', 'Health-Conscious', 'Committed'],
  'Food': ['Creativity', 'Social', 'Adventurous'],
  'Games': ['Intellectualism', 'Strategic', 'Fun'],
  'Hiking': ['Adventurous', 'Nature-Loving', 'Committed'],
  'Investment': ['Ambition', 'Intelligent', 'Visionary'],
  'Ministry': ['Leadership', 'Kindness', 'Passionate'],
  'Movies': ['Thoughtfulness', 'Entertainment', 'Social'],
  'Music': ['Authentic', 'Emotionally Intelligent', 'Creative'],
  'Languages': ['Intelligence', 'Open-Minded', 'Ambitious'],
  'Philanthropy': ['Kindness', 'Generosity', 'Leadership'],
  'Photography': ['Creativity', 'Attention to Detail', 'Authentic'],
  'Politics': ['Intelligent', 'Passionate', 'Opinionated'],
  'Public Speaking': ['Leadership', 'Communication', 'Confident'],
  'Reading': ['Intelligence', 'Thoughtful', 'Introspective'],
  'Singing': ['Authentic', 'Confident', 'Expressive'],
  'Social Media': ['Social', 'Communication', 'Tech-Savvy'],
  'Sports': ['Discipline', 'Competitive', 'Health-Conscious'],
  'Swimming': ['Health-Conscious', 'Discipline', 'Adventurous'],
  'Teaching': ['Kindness', 'Communication', 'Patience'],
  'Technology': ['Intelligence', 'Innovative', 'Forward-Thinking'],
  'Travel': ['Adventurous', 'Open-Minded', 'Curious'],
  'Volunteering': ['Kindness', 'Generous', 'Community-Oriented'],
  'Writing': ['Authentic', 'Intelligent', 'Thoughtful'],
};

/// Enhanced compatibility scoring algorithm
/// Scores two profiles using 6 dimensions, returns 0-100 score
class EnhancedCompatibilityScorer {
  /// Main entry point: score compatibility between two users
  /// Returns score 0-100 with breakdowns
  static CompatibilityScore scoreMatch({
    // User A's data (viewing user)
    required String? userAMaritalStatus,
    required String? userAHaveKids,
    required String? userABeliefInTithing,
    required String? userAShouldSpeakTongues,
    required String? userABeliefInCohabiting,
    required String? userARegularIncome,
    required String? userALongDistance,
    required String? userAPersonalityType,
    required String? userAGenotype,
    required List<String>? userAHobbies,
    required List<String>? userADesiredQualities,

    // User B's data (candidate)
    required String? userBMaritalStatus,
    required String? userBHaveKids,
    required String? userBBeliefInTithing,
    required String? userBShouldSpeakTongues,
    required String? userBBeliefInCohabiting,
    required String? userBRegularIncome,
    required String? userBLongDistance,
    required String? userBPersonalityType,
    required String? userBGenotype,
    required List<String>? userBHobbies,
    required List<String>? userBDesiredQualities,
  }) {
    int totalScore = 0;
    final fieldScores = <String, int>{};
    final topMatches = <String>[];
    final differences = <String>[];

    // ==== FAITH ALIGNMENT (25 points) ====
    // Christian-only platform: only tithing + tongues beliefs matter
    int faithScore = 0;

    if (_isExactMatch(userABeliefInTithing, userBBeliefInTithing)) {
      faithScore += 12; // 25/2
      topMatches.add('Same beliefs on tithing');
    } else if (userABeliefInTithing != null && userBBeliefInTithing != null) {
      differences.add('Different views on tithing');
    }

    if (_isExactMatch(userAShouldSpeakTongues, userBShouldSpeakTongues)) {
      faithScore += 13; // 25/2, rounded up
      topMatches.add('Same beliefs on speaking in tongues');
    } else if (userAShouldSpeakTongues != null &&
        userBShouldSpeakTongues != null) {
      differences.add('Different views on speaking in tongues');
    }

    // Bonus if all faith matches (but we only have 2 now)
    if (faithScore == 25) {
      fieldScores['faith_aligned_bonus'] = 0; // No bonus, already at max
    }

    fieldScores['faith'] = faithScore;
    totalScore += faithScore;

    // ==== LIFE PARTNERSHIP (35 points) ====
    int lifeScore = 0;

    if (_isExactMatch(userAMaritalStatus, userBMaritalStatus)) {
      lifeScore += 12;
      topMatches.add('Same marital status');
    } else if (userAMaritalStatus != null && userBMaritalStatus != null) {
      differences.add('Different marital status');
    }

    if (_isExactMatch(userAHaveKids, userBHaveKids)) {
      lifeScore += 11;
      topMatches.add('Same stance on children');
    } else if (userAHaveKids != null && userBHaveKids != null) {
      differences.add('Different views on having children');
    }

    if (_isExactMatch(userABeliefInCohabiting, userBBeliefInCohabiting)) {
      lifeScore += 12;
      topMatches.add('Same beliefs on cohabiting');
    } else if (userABeliefInCohabiting != null &&
        userBBeliefInCohabiting != null) {
      differences.add('Different views on cohabiting');
    }

    fieldScores['life_partnership'] = lifeScore;
    totalScore += lifeScore;

    // ==== PRACTICAL ALIGNMENT (15 points) ====
    int practicalScore = 0;

    if (_isExactMatch(userARegularIncome, userBRegularIncome)) {
      practicalScore += 8;
      topMatches.add('Both financially stable');
    }

    if (_isExactMatch(userALongDistance, userBLongDistance)) {
      practicalScore += 7;
      topMatches.add('Both open to long distance');
    }

    fieldScores['practical'] = practicalScore;
    totalScore += practicalScore;

    // ==== PERSONALITY & GENETICS (10 points) ====
    int personalityScore = 0;

    if (_isExactMatch(userAPersonalityType, userBPersonalityType)) {
      personalityScore += 5;
      topMatches.add('Compatible personality types');
    }

    if (_isExactMatch(userAGenotype, userBGenotype)) {
      personalityScore += 5;
      topMatches.add('Compatible genotypes');
    }

    fieldScores['personality'] = personalityScore;
    totalScore += personalityScore;

    // ==== HOBBIES OVERLAP (5 points, proportional) ====
    final hobbiesScore = _calculateHobbyScore(userAHobbies, userBHobbies);
    fieldScores['hobbies'] = hobbiesScore;
    totalScore += hobbiesScore;

    if (hobbiesScore > 0) {
      final sharedHobbies = _getSharedHobbies(userAHobbies, userBHobbies);
      if (sharedHobbies.isNotEmpty) {
        topMatches.add('Shared interests: ${sharedHobbies.join(", ")}');
      }
    }

    // ==== VALUES ALIGNMENT (5 points, proportional) ====
    final valuesScore = _calculateValuesScore(
      userADesiredQualities,
      userBHobbies,
    );
    fieldScores['values'] = valuesScore;
    totalScore += valuesScore;

    // Cap at 100
    totalScore = (totalScore > 100) ? 100 : totalScore;

    // Determine badges
    final badges = _generateBadges(fieldScores, totalScore);

    return CompatibilityScore(
      score: totalScore,
      fieldScores: fieldScores,
      topMatches: topMatches,
      differences: differences,
      badges: badges,
    );
  }

  /// Check if two values are exact matches
  static bool _isExactMatch(String? valueA, String? valueB) {
    if (valueA == null || valueB == null) return false;
    return valueA.toLowerCase().trim() == valueB.toLowerCase().trim();
  }

  /// Calculate hobby overlap score (0-5 points, proportional)
  /// If 2 out of 5 hobbies match: 2 points
  /// If 3 out of 5 match: 3 points, etc.
  static int _calculateHobbyScore(
    List<String>? hobbiesA,
    List<String>? hobbiesB,
  ) {
    if (hobbiesA == null ||
        hobbiesB == null ||
        hobbiesA.isEmpty ||
        hobbiesB.isEmpty) {
      return 0;
    }

    final normalizedA = hobbiesA.map((h) => h.toLowerCase().trim()).toSet();
    final normalizedB = hobbiesB.map((h) => h.toLowerCase().trim()).toSet();

    final shared = normalizedA.intersection(normalizedB);
    if (shared.isEmpty) return 0;

    // Proportional: (shared count / max possible) * 5
    final maxPossible =
        (normalizedA.length > normalizedB.length)
            ? normalizedA.length
            : normalizedB.length;

    final score = ((shared.length / maxPossible) * 5).round();
    return score > 5 ? 5 : score;
  }

  /// Get shared hobbies for display
  static List<String> _getSharedHobbies(
    List<String>? hobbiesA,
    List<String>? hobbiesB,
  ) {
    if (hobbiesA == null || hobbiesB == null) return [];

    final normalizedA = hobbiesA.map((h) => h.toLowerCase().trim()).toSet();
    final normalizedB = hobbiesB.map((h) => h.toLowerCase().trim()).toSet();

    return normalizedA.intersection(normalizedB).toList();
  }

  /// Calculate values score based on desired qualities vs. inferred traits
  /// 0-5 points proportional to match quality
  static int _calculateValuesScore(
    List<String>? desiredQualities,
    List<String>? hobbies,
  ) {
    if (desiredQualities == null || desiredQualities.isEmpty) return 0;
    if (hobbies == null || hobbies.isEmpty) return 0;

    // Extract traits from candidate's hobbies
    final inferredTraits = <String>{};
    for (final hobby in hobbies) {
      final traits =
          hobbiesToTraitsMapping[hobby] ??
          hobbiesToTraitsMapping[_findMatchingKey(hobby)] ??
          [];
      inferredTraits.addAll(traits.map((t) => t.toLowerCase().trim()));
    }

    if (inferredTraits.isEmpty) return 0;

    // Count matches with desired qualities
    int matches = 0;
    for (final quality in desiredQualities) {
      final normalizedQuality = quality.toLowerCase().trim();
      if (inferredTraits.contains(normalizedQuality)) {
        matches++;
      }
    }

    if (matches == 0) return 0;

    // Proportional: (matches / total desired) * 5
    final score = ((matches / desiredQualities.length) * 5).round();
    return score > 5 ? 5 : score;
  }

  /// Find matching hobby key (case-insensitive)
  static String? _findMatchingKey(String hobby) {
    final normalized = hobby.toLowerCase().trim();
    for (final key in hobbiesToTraitsMapping.keys) {
      if (key.toLowerCase() == normalized) return key;
    }
    return null;
  }

  /// Generate achievement badges based on scores
  static List<String> _generateBadges(
    Map<String, int> fieldScores,
    int totalScore,
  ) {
    final badges = <String>[];

    // Faith aligned badge (both fields score >= 10)
    if ((fieldScores['faith'] ?? 0) >= 20) {
      badges.add('✨ Faith Aligned');
    }

    // Life goals aligned badge
    if ((fieldScores['life_partnership'] ?? 0) >= 30) {
      badges.add('🎯 Life Goals Aligned');
    }

    // Adventure match badge
    if ((fieldScores['hobbies'] ?? 0) >= 3) {
      badges.add('🎵 Adventure Match');
    }

    // Values match badge
    if ((fieldScores['values'] ?? 0) >= 3) {
      badges.add('💬 Values Aligned');
    }

    // Overall perfect match
    if (totalScore >= 95) {
      badges.add('⭐ Perfect Match');
    }

    return badges;
  }
}
