import 'package:flutter_riverpod/flutter_riverpod.dart';

class DatingOnboardingDraft {
  final int? age;
  final String? city;
  final String? countryOfResidence;
  final String? nationality;
  final String? educationLevel;
  final String? profession;

  /// Stores either a known church from dropdown OR custom-entered church.
  final String? churchName;
  final String? otherChurchName;

  final List<String> hobbies;
  final List<String> desiredQualities;

  /// Local image file paths for now. Later we store remote URLs.
  final List<String> photoPaths;

  /// Local audio file paths for now. Later we store remote URLs.
  final String? audio1Path;
  final String? audio2Path;
  final String? audio3Path;

  /// User contact details (at least one required).
  /// Example:
  /// {"Instagram": "@name", "WhatsApp": "+234..."}
  final Map<String, String> contactInfo;

  const DatingOnboardingDraft({
    this.age,
    this.city,
    this.countryOfResidence,
    this.nationality,
    this.educationLevel,
    this.profession,
    this.churchName,
    this.otherChurchName,
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
    String? otherChurchName,
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
      otherChurchName: otherChurchName ?? this.otherChurchName,
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

class DatingOnboardingDraftNotifier
    extends StateNotifier<DatingOnboardingDraft> {
  DatingOnboardingDraftNotifier() : super(const DatingOnboardingDraft());

  void setAge(int age) => state = state.copyWith(age: age);

  void setExtraInfo({
    String? city,
    String? countryOfResidence,
    String? nationality,
    String? educationLevel,
    String? profession,
    String? churchName,
    String? otherChurchName,
  }) {
    state = state.copyWith(
      city: city ?? state.city,
      countryOfResidence: countryOfResidence ?? state.countryOfResidence,
      nationality: nationality ?? state.nationality,
      educationLevel: educationLevel ?? state.educationLevel,
      profession: profession ?? state.profession,
      churchName: churchName ?? state.churchName,
      otherChurchName: otherChurchName ?? state.otherChurchName,
    );
  }

  void setHobbies(List<String> hobbies) =>
      state = state.copyWith(hobbies: hobbies);

  void setDesiredQualities(List<String> qualities) =>
      state = state.copyWith(desiredQualities: qualities);

  void setPhotos(List<String> paths) =>
      state = state.copyWith(photoPaths: paths);

  void setAudio({String? a1, String? a2, String? a3}) {
    state = state.copyWith(
      audio1Path: a1 ?? state.audio1Path,
      audio2Path: a2 ?? state.audio2Path,
      audio3Path: a3 ?? state.audio3Path,
    );
  }

  void setContactInfo(Map<String, String> info) {
    state = state.copyWith(contactInfo: info);
  }

  void reset() => state = const DatingOnboardingDraft();
}

final datingOnboardingDraftProvider =
    StateNotifierProvider<DatingOnboardingDraftNotifier, DatingOnboardingDraft>(
      (ref) => DatingOnboardingDraftNotifier(),
    );
