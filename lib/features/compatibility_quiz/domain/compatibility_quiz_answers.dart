class CompatibilityQuizAnswers {
  final String maritalStatus;
  final String haveKids;
  final String genotype;
  final String personalityType;
  final String regularSourceOfIncome;
  final String marrySomeoneNotFS;
  final String longDistance;
  final String believeInCohabiting;
  final String shouldChristianSpeakInTongue;
  final String believeInTithing;

  const CompatibilityQuizAnswers({
    required this.maritalStatus,
    required this.haveKids,
    required this.genotype,
    required this.personalityType,
    required this.regularSourceOfIncome,
    required this.marrySomeoneNotFS,
    required this.longDistance,
    required this.believeInCohabiting,
    required this.shouldChristianSpeakInTongue,
    required this.believeInTithing,
  });

  CompatibilityQuizAnswers copyWith({
    String? maritalStatus,
    String? haveKids,
    String? genotype,
    String? personalityType,
    String? regularSourceOfIncome,
    String? marrySomeoneNotFS,
    String? longDistance,
    String? believeInCohabiting,
    String? shouldChristianSpeakInTongue,
    String? believeInTithing,
  }) {
    return CompatibilityQuizAnswers(
      maritalStatus: maritalStatus ?? this.maritalStatus,
      haveKids: haveKids ?? this.haveKids,
      genotype: genotype ?? this.genotype,
      personalityType: personalityType ?? this.personalityType,
      regularSourceOfIncome:
          regularSourceOfIncome ?? this.regularSourceOfIncome,
      marrySomeoneNotFS: marrySomeoneNotFS ?? this.marrySomeoneNotFS,
      longDistance: longDistance ?? this.longDistance,
      believeInCohabiting: believeInCohabiting ?? this.believeInCohabiting,
      shouldChristianSpeakInTongue:
          shouldChristianSpeakInTongue ?? this.shouldChristianSpeakInTongue,
      believeInTithing: believeInTithing ?? this.believeInTithing,
    );
  }

  Map<String, dynamic> toMap() => {
    'maritalStatus': maritalStatus,
    'haveKids': haveKids,
    'genotype': genotype,
    'personalityType': personalityType,
    'regularSourceOfIncome': regularSourceOfIncome,
    'marrySomeoneNotFS': marrySomeoneNotFS,
    'longDistance': longDistance,
    'believeInCohabiting': believeInCohabiting,
    'shouldChristianSpeakInTongue': shouldChristianSpeakInTongue,
    'believeInTithing': believeInTithing,
  };

  static CompatibilityQuizAnswers? fromMap(Map<String, dynamic>? map) {
    if (map == null) return null;
    try {
      return CompatibilityQuizAnswers(
        maritalStatus: map['maritalStatus'] ?? '',
        haveKids: map['haveKids'] ?? '',
        genotype: map['genotype'] ?? '',
        personalityType: map['personalityType'] ?? '',
        regularSourceOfIncome: map['regularSourceOfIncome'] ?? '',
        marrySomeoneNotFS: map['marrySomeoneNotFS'] ?? '',
        longDistance: map['longDistance'] ?? '',
        believeInCohabiting: map['believeInCohabiting'] ?? '',
        shouldChristianSpeakInTongue: map['shouldChristianSpeakInTongue'] ?? '',
        believeInTithing: map['believeInTithing'] ?? '',
      );
    } catch (_) {
      return null;
    }
  }

  /// Read a field by key (used by UI).
  String? valueFor(String key) {
    switch (key) {
      case 'maritalStatus':
        return maritalStatus;
      case 'haveKids':
        return haveKids;
      case 'genotype':
        return genotype;
      case 'personalityType':
        return personalityType;
      case 'regularSourceOfIncome':
        return regularSourceOfIncome;
      case 'marrySomeoneNotFS':
        return marrySomeoneNotFS;
      case 'longDistance':
        return longDistance;
      case 'believeInCohabiting':
        return believeInCohabiting;
      case 'shouldChristianSpeakInTongue':
        return shouldChristianSpeakInTongue;
      case 'believeInTithing':
        return believeInTithing;
      default:
        return null;
    }
  }
}
