import 'package:equatable/equatable.dart';
import 'user_model.dart';

// ============================================================================
// COMPATIBILITY DATA MODEL
// ============================================================================

/// Compatibility quiz data structure from Nexus 1.0
/// Stored in user.compatibility object
class CompatibilityData extends Equatable {
  final String? maritalStatus;
  final String? haveKids;
  final String? genotype;
  final String? personalityType;
  final String? regularSourceOfIncome;
  final String? marrySomeoneNotFS;
  final String? longDistance;
  final String? believeInCohabiting;
  final String? shouldChristianSpeakInTongue;
  final String? believeInTithing;

  const CompatibilityData({
    this.maritalStatus,
    this.haveKids,
    this.genotype,
    this.personalityType,
    this.regularSourceOfIncome,
    this.marrySomeoneNotFS,
    this.longDistance,
    this.believeInCohabiting,
    this.shouldChristianSpeakInTongue,
    this.believeInTithing,
  });

  factory CompatibilityData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const CompatibilityData();

    return CompatibilityData(
      maritalStatus: map['maritalStatus'] as String?,
      haveKids: map['haveKids'] as String?,
      genotype: map['genotype'] as String?,
      personalityType: map['personalityType'] as String?,
      regularSourceOfIncome: map['regularSourceOfIncome'] as String?,
      marrySomeoneNotFS: map['marrySomeoneNotFS'] as String?,
      longDistance: map['longDistance'] as String?,
      believeInCohabiting:
          map['believeInCohiabiting'] as String?, // Note: typo in original
      shouldChristianSpeakInTongue:
          map['shouldChristianSpeakInTongue'] as String?,
      believeInTithing: map['believeInTithing'] as String?,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      if (maritalStatus != null) 'maritalStatus': maritalStatus,
      if (haveKids != null) 'haveKids': haveKids,
      if (genotype != null) 'genotype': genotype,
      if (personalityType != null) 'personalityType': personalityType,
      if (regularSourceOfIncome != null)
        'regularSourceOfIncome': regularSourceOfIncome,
      if (marrySomeoneNotFS != null) 'marrySomeoneNotFS': marrySomeoneNotFS,
      if (longDistance != null) 'longDistance': longDistance,
      if (believeInCohabiting != null)
        'believeInCohiabiting': believeInCohabiting,
      if (shouldChristianSpeakInTongue != null)
        'shouldChristianSpeakInTongue': shouldChristianSpeakInTongue,
      if (believeInTithing != null) 'believeInTithing': believeInTithing,
    };
  }

  bool get isComplete =>
      maritalStatus != null &&
      haveKids != null &&
      genotype != null &&
      personalityType != null &&
      regularSourceOfIncome != null &&
      marrySomeoneNotFS != null &&
      longDistance != null &&
      believeInCohabiting != null &&
      shouldChristianSpeakInTongue != null &&
      believeInTithing != null;

  @override
  List<Object?> get props => [
    maritalStatus,
    haveKids,
    genotype,
    personalityType,
    regularSourceOfIncome,
    marrySomeoneNotFS,
    longDistance,
    believeInCohabiting,
    shouldChristianSpeakInTongue,
    believeInTithing,
  ];
}

// ============================================================================
// DATING AUDIO RECORDINGS
// ============================================================================

/// Audio recordings for dating profile
/// Stored in user document
class DatingAudioData extends Equatable {
  final String? audio1Url;
  final String? audio2Url;
  final String? audio3Url;
  final bool completed;

  const DatingAudioData({
    this.audio1Url,
    this.audio2Url,
    this.audio3Url,
    this.completed = false,
  });

  factory DatingAudioData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const DatingAudioData();

    // Handle both old format (separate fields) and new format (nested audio object)
    final audioMap = map['audio'] as Map<String, dynamic>?;
    if (audioMap != null) {
      return DatingAudioData(
        audio1Url: audioMap['audio1Url'] as String?,
        audio2Url: audioMap['audio2Url'] as String?,
        audio3Url: audioMap['audio3Url'] as String?,
        completed: audioMap['completed'] as bool? ?? false,
      );
    }

    // Legacy format - check for separate fields
    return DatingAudioData(
      audio1Url: map['audio1Url'] as String?,
      audio2Url: map['audio2Url'] as String?,
      audio3Url: map['audio3Url'] as String?,
      completed: map['audioCompleted'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'audio': {
        'audio1Url': audio1Url,
        'audio2Url': audio2Url,
        'audio3Url': audio3Url,
        'completed': completed,
      },
    };
  }

  bool get isComplete =>
      audio1Url != null &&
      audio2Url != null &&
      audio3Url != null &&
      audio1Url!.isNotEmpty &&
      audio2Url!.isNotEmpty &&
      audio3Url!.isNotEmpty;

  int get completedCount {
    int count = 0;
    if (audio1Url != null && audio1Url!.isNotEmpty) count++;
    if (audio2Url != null && audio2Url!.isNotEmpty) count++;
    if (audio3Url != null && audio3Url!.isNotEmpty) count++;
    return count;
  }

  @override
  List<Object?> get props => [audio1Url, audio2Url, audio3Url, completed];
}

// ============================================================================
// DATING PROFILE COMPLETION SERVICE
// ============================================================================

/// Service to check dating profile completion status
/// Follows exact requirements from Nexus 1.0
class DatingProfileCompletionService {
  /// Check if dating profile is fully complete
  /// Required for: viewing full profiles, starting DMs
  static bool isComplete(UserModel user) {
    return hasBasicInfo(user) &&
        hasPhotos(user) &&
        hasHobbies(user) &&
        hasDesiredQualities(user) &&
        hasAudioRecordings(user) &&
        hasCompatibilityQuiz(user) &&
        hasSocialMedia(user);
  }

  /// Check basic profile info
  static bool hasBasicInfo(UserModel user) {
    return (user.name != null && user.name!.isNotEmpty) &&
        user.age != null &&
        user.age! >= 21 && // Minimum dating age is 21
        (user.gender != null && user.gender!.isNotEmpty);
  }

  /// Check if user has at least 1 photo
  static bool hasPhotos(UserModel user) {
    return user.photos != null && user.photos!.isNotEmpty;
  }

  /// Check if user has hobbies
  static bool hasHobbies(UserModel user) {
    return user.hobbies != null && user.hobbies!.isNotEmpty;
  }

  /// Check if user has desired qualities
  static bool hasDesiredQualities(UserModel user) {
    return user.desiredQualities != null && user.desiredQualities!.isNotEmpty;
  }

  /// Check if user has completed 3 audio recordings
  static bool hasAudioRecordings(UserModel user) {
    // Check for audio data in datingProfile.audio or legacy format
    final datingProfile =
        user.toMap()['datingProfile'] as Map<String, dynamic>?;
    if (datingProfile != null) {
      final audio = DatingAudioData.fromMap(datingProfile);
      return audio.isComplete;
    }

    // Check legacy format in root document
    final audio = DatingAudioData.fromMap(user.toMap());
    return audio.isComplete;
  }

  /// Check if user has completed compatibility quiz
  static bool hasCompatibilityQuiz(UserModel user) {
    return user.compatibilitySetted == true;
  }

  /// Check if user has at least one social media username
  static bool hasSocialMedia(UserModel user) {
    return (user.facebookUsername != null &&
            user.facebookUsername!.isNotEmpty) ||
        (user.instagramUsername != null &&
            user.instagramUsername!.isNotEmpty) ||
        (user.twitterUsername != null && user.twitterUsername!.isNotEmpty) ||
        (user.telegramUsername != null && user.telegramUsername!.isNotEmpty) ||
        (user.snapchatUsername != null && user.snapchatUsername!.isNotEmpty);
  }

  /// Get completion percentage (0-100)
  static int getCompletionPercentage(UserModel user) {
    int completed = 0;
    const total = 7;

    if (hasBasicInfo(user)) completed++;
    if (hasPhotos(user)) completed++;
    if (hasHobbies(user)) completed++;
    if (hasDesiredQualities(user)) completed++;
    if (hasAudioRecordings(user)) completed++;
    if (hasCompatibilityQuiz(user)) completed++;
    if (hasSocialMedia(user)) completed++;

    return ((completed / total) * 100).round();
  }

  /// Get list of missing steps
  static List<DatingProfileStep> getMissingSteps(UserModel user) {
    final missing = <DatingProfileStep>[];

    if (!hasBasicInfo(user)) missing.add(DatingProfileStep.basicInfo);
    if (!hasPhotos(user)) missing.add(DatingProfileStep.photos);
    if (!hasHobbies(user)) missing.add(DatingProfileStep.hobbies);
    if (!hasDesiredQualities(user))
      missing.add(DatingProfileStep.desiredQualities);
    if (!hasAudioRecordings(user))
      missing.add(DatingProfileStep.audioRecordings);
    if (!hasCompatibilityQuiz(user))
      missing.add(DatingProfileStep.compatibility);
    if (!hasSocialMedia(user)) missing.add(DatingProfileStep.socialMedia);

    return missing;
  }

  /// Get first missing step (for navigation)
  static DatingProfileStep? getFirstMissingStep(UserModel user) {
    final missing = getMissingSteps(user);
    return missing.isNotEmpty ? missing.first : null;
  }
}

/// Dating profile onboarding steps
enum DatingProfileStep {
  basicInfo('Basic Info', 'Add your name, age, and gender'),
  photos('Photos', 'Upload at least one photo'),
  hobbies('Hobbies', 'Tell us about your interests'),
  desiredQualities('Partner Qualities', 'What do you look for in a partner?'),
  audioRecordings('Voice Intro', 'Record 3 voice introductions'),
  compatibility('Compatibility', 'Complete the compatibility quiz'),
  socialMedia('Social Media', 'Add at least one social handle');

  final String title;
  final String description;

  const DatingProfileStep(this.title, this.description);
}

// ============================================================================
// SEARCH FILTER OPTIONS (From Nexus 1.0)
// ============================================================================

/// Search filter options for Explore/Search
class SearchFilters extends Equatable {
  final int minAge;
  final int maxAge;
  final String? education;
  final String? church;
  final String? country;
  final String? nationality;
  final String? incomeSource;
  final String? longDistancePreference;
  final String? maritalStatus;
  final String? hasKids;
  final String? genotype;

  const SearchFilters({
    this.minAge = 25,
    this.maxAge = 50,
    this.education,
    this.church,
    this.country,
    this.nationality,
    this.incomeSource,
    this.longDistancePreference,
    this.maritalStatus,
    this.hasKids,
    this.genotype,
  });

  SearchFilters copyWith({
    int? minAge,
    int? maxAge,
    String? education,
    String? church,
    String? country,
    String? nationality,
    String? incomeSource,
    String? longDistancePreference,
    String? maritalStatus,
    String? hasKids,
    String? genotype,
  }) {
    return SearchFilters(
      minAge: minAge ?? this.minAge,
      maxAge: maxAge ?? this.maxAge,
      education: education ?? this.education,
      church: church ?? this.church,
      country: country ?? this.country,
      nationality: nationality ?? this.nationality,
      incomeSource: incomeSource ?? this.incomeSource,
      longDistancePreference:
          longDistancePreference ?? this.longDistancePreference,
      maritalStatus: maritalStatus ?? this.maritalStatus,
      hasKids: hasKids ?? this.hasKids,
      genotype: genotype ?? this.genotype,
    );
  }

  /// Check if user matches these filters
  bool matchesUser(UserModel user) {
    // Age filter
    if (user.age != null) {
      if (user.age! < minAge || user.age! > maxAge) return false;
    }

    // Country filter
    if (country != null && country != 'Any' && country != 'Other') {
      final userCountry = user.location?['country'] as String? ?? user.country;
      if (country == 'Diaspora') {
        if (userCountry == 'Nigeria') return false;
      } else {
        if (userCountry != country) return false;
      }
    }

    // Education filter - "Graduate" or "Any is fine"
    if (education != null && education == 'Graduate') {
      final graduateLevels = [
        'Undergraduate Degree',
        'Postgraduate Degree',
        'Doctorate Degree',
        'Bachelor\'s Degree',
        'Master\'s Degree',
        'Doctorate',
        'Graduate',
        'Bachelors',
        'Masters',
      ];
      if (!graduateLevels.contains(user.educationLevel)) return false;
    }
    // "Any is fine" - no filtering

    // Compatibility-based filters
    final userCompatibility = user.compatibility;
    if (userCompatibility != null) {
      // Income source - "Yes" or "Not Compulsory"
      if (incomeSource != null && incomeSource == 'Yes') {
        final hasIncome = userCompatibility['regularSourceOfIncome'];
        if (hasIncome != 'Yes' && hasIncome != true) return false;
      }
      // "Not Compulsory" - no filtering

      // Long distance
      if (longDistancePreference != null &&
          longDistancePreference!.isNotEmpty) {
        if (longDistancePreference != 'Maybe') {
          if (userCompatibility['longDistance'] != longDistancePreference)
            return false;
        }
      }

      // Marital status - "Never Married" or "Any is fine"
      if (maritalStatus != null && maritalStatus == 'Never Married') {
        final userStatus = userCompatibility['maritalStatus'];
        if (userStatus != 'Never Married' &&
            userStatus != 'Single (Never Married)')
          return false;
      }
      // "Any is fine" - no filtering

      // Has kids - "No kids" or "Any is fine"
      if (hasKids != null && hasKids == 'No kids') {
        final userHasKids = userCompatibility['haveKids'];
        if (userHasKids != 'No' && userHasKids != false) return false;
      }
      // "Any is fine" - no filtering

      // Genotype - "AA only" or "Any"
      if (genotype != null && genotype == 'AA only') {
        if (userCompatibility['genotype'] != 'AA') return false;
      }
      // "Any" - no filtering
    }

    // Nationality filter
    if (nationality != null &&
        nationality!.isNotEmpty &&
        nationality != 'Any') {
      if (user.nationality != nationality) return false;
    }

    return true;
  }

  @override
  List<Object?> get props => [
    minAge,
    maxAge,
    education,
    church,
    country,
    nationality,
    incomeSource,
    longDistancePreference,
    maritalStatus,
    hasKids,
    genotype,
  ];
}

/// Filter dropdown options (from Nexus 1.0)
class SearchFilterOptions {
  static const List<String> educationLevels = [
    'Any',
    'High School',
    'Undergraduate Degree',
    'Postgraduate Degree',
    'Doctorate Degree',
    'Graduate', // Special filter that includes all degrees
  ];

  static const List<String> countries = [
    'Any',
    'Nigeria',
    'Diaspora', // Non-Nigeria
    'United States',
    'United Kingdom',
    'Canada',
    'Ghana',
    'South Africa',
  ];

  static const List<String> incomeOptions = ['Any', 'Yes', 'No', 'Sometimes'];

  static const List<String> yesNoOptions = ['Any', 'Yes', 'No'];

  static const List<String> maritalStatusOptions = [
    'Any',
    'Never Married',
    'Divorced',
    'Widowed',
  ];

  static const List<String> genotypeOptions = [
    'Any',
    'AA',
    'AS',
    'SS',
    'AC',
    'SC',
  ];
}
