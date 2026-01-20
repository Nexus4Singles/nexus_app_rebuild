class DatingOnboardingDraft {
  final int? age;

  // Extra info
  final String? city;
  final String? countryOfResidence;
  final String? nationality;
  final String? educationLevel;
  final String? profession;
  final String? churchName;
  final String? churchOtherName;

  // Hobbies / Desired qualities
  final List<String> hobbies; // max 5
  final List<String> desiredQualities; // max 8

  // Photos
  final List<String> photoPaths; // local paths (upload later), min 2

  // Audio recordings (local file paths)
  final String? audio1Path;
  final String? audio2Path;
  final String? audio3Path;

  // Contact info (platform -> handle/url)
  final Map<String, String> contactInfo;

  const DatingOnboardingDraft({
    this.age,
    this.city,
    this.countryOfResidence,
    this.nationality,
    this.educationLevel,
    this.profession,
    this.churchName,
    this.churchOtherName,
    this.hobbies = const [],
    this.desiredQualities = const [],
    this.photoPaths = const [],
    this.audio1Path,
    this.audio2Path,
    this.audio3Path,
    this.contactInfo = const {},
  });

  DatingOnboardingDraft copyWith({
    int? age,
    String? city,
    String? countryOfResidence,
    String? nationality,
    String? educationLevel,
    String? profession,
    String? churchName,
    String? churchOtherName,
    List<String>? hobbies,
    List<String>? desiredQualities,
    List<String>? photoPaths,
    String? audio1Path,
    String? audio2Path,
    String? audio3Path,
    Map<String, String>? contactInfo,
  }) {
    return DatingOnboardingDraft(
      age: age ?? this.age,
      city: city ?? this.city,
      countryOfResidence: countryOfResidence ?? this.countryOfResidence,
      nationality: nationality ?? this.nationality,
      educationLevel: educationLevel ?? this.educationLevel,
      profession: profession ?? this.profession,
      churchName: churchName ?? this.churchName,
      churchOtherName: churchOtherName ?? this.churchOtherName,
      hobbies: hobbies ?? this.hobbies,
      desiredQualities: desiredQualities ?? this.desiredQualities,
      photoPaths: photoPaths ?? this.photoPaths,
      audio1Path: audio1Path ?? this.audio1Path,
      audio2Path: audio2Path ?? this.audio2Path,
      audio3Path: audio3Path ?? this.audio3Path,
      contactInfo: contactInfo ?? this.contactInfo,
    );
  }
}
