import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

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

  /// Remote audio URLs after upload.
  final String? audio1Url;
  final String? audio2Url;
  final String? audio3Url;

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
    this.audio1Url,
    this.audio2Url,
    this.audio3Url,
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
    String? audio1Url,
    String? audio2Url,
    String? audio3Url,
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
      audio1Url: audio1Url ?? this.audio1Url,
      audio2Url: audio2Url ?? this.audio2Url,
      audio3Url: audio3Url ?? this.audio3Url,
      contactInfo: contactInfo ?? this.contactInfo,
    );
  }

  /// Serialize to JSON for persistence
  Map<String, dynamic> toJson() {
    return {
      'age': age,
      'city': city,
      'countryOfResidence': countryOfResidence,
      'nationality': nationality,
      'educationLevel': educationLevel,
      'profession': profession,
      'churchName': churchName,
      'otherChurchName': otherChurchName,
      'hobbies': hobbies,
      'desiredQualities': desiredQualities,
      'photoPaths': photoPaths,
      'audio1Path': audio1Path,
      'audio2Path': audio2Path,
      'audio3Path': audio3Path,
      'audio1Url': audio1Url,
      'audio2Url': audio2Url,
      'audio3Url': audio3Url,
      'contactInfo': contactInfo,
    };
  }

  /// Deserialize from JSON
  factory DatingOnboardingDraft.fromJson(Map<String, dynamic> json) {
    return DatingOnboardingDraft(
      age: json['age'] as int?,
      city: json['city'] as String?,
      countryOfResidence: json['countryOfResidence'] as String?,
      nationality: json['nationality'] as String?,
      educationLevel: json['educationLevel'] as String?,
      profession: json['profession'] as String?,
      churchName: json['churchName'] as String?,
      otherChurchName: json['otherChurchName'] as String?,
      hobbies: (json['hobbies'] as List<dynamic>?)?.cast<String>() ?? [],
      desiredQualities:
          (json['desiredQualities'] as List<dynamic>?)?.cast<String>() ?? [],
      photoPaths: (json['photoPaths'] as List<dynamic>?)?.cast<String>() ?? [],
      audio1Path: json['audio1Path'] as String?,
      audio2Path: json['audio2Path'] as String?,
      audio3Path: json['audio3Path'] as String?,
      audio1Url: json['audio1Url'] as String?,
      audio2Url: json['audio2Url'] as String?,
      audio3Url: json['audio3Url'] as String?,
      contactInfo:
          (json['contactInfo'] as Map<String, dynamic>?)
              ?.cast<String, String>() ??
          {},
    );
  }
}

class DatingOnboardingDraftNotifier
    extends StateNotifier<DatingOnboardingDraft> {
  DatingOnboardingDraftNotifier() : super(const DatingOnboardingDraft()) {
    _loadDraft();
  }

  static const _storageKey = 'dating_onboarding_draft';

  /// Load saved draft from SharedPreferences on init
  Future<void> _loadDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = prefs.getString(_storageKey);
      if (jsonString != null) {
        final json = jsonDecode(jsonString) as Map<String, dynamic>;
        state = DatingOnboardingDraft.fromJson(json);
      }
    } catch (e) {
      // Ignore errors, start fresh
    }
  }

  /// Save draft to SharedPreferences after each change
  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(state.toJson());
      await prefs.setString(_storageKey, jsonString);
    } catch (e) {
      // Ignore save errors
    }
  }

  void setAge(int age) {
    state = state.copyWith(age: age);
    _saveDraft();
  }

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
    _saveDraft();
  }

  void setHobbies(List<String> hobbies) {
    state = state.copyWith(hobbies: hobbies);
    _saveDraft();
  }

  void setDesiredQualities(List<String> qualities) {
    state = state.copyWith(desiredQualities: qualities);
    _saveDraft();
  }

  void setPhotos(List<String> paths) {
    state = state.copyWith(photoPaths: paths);
    _saveDraft();
  }

  void setAudio({String? a1, String? a2, String? a3}) {
    state = state.copyWith(
      audio1Path: a1 ?? state.audio1Path,
      audio2Path: a2 ?? state.audio2Path,
      audio3Path: a3 ?? state.audio3Path,
    );
    _saveDraft();
  }

  void updateAudioUrls({
    String? audio1Url,
    String? audio2Url,
    String? audio3Url,
  }) {
    state = state.copyWith(
      audio1Url: audio1Url ?? state.audio1Url,
      audio2Url: audio2Url ?? state.audio2Url,
      audio3Url: audio3Url ?? state.audio3Url,
    );
    _saveDraft();
  }

  /// Clear all audio recordings (paths and URLs) to start over
  void clearAudios() {
    state = state.copyWith(
      audio1Path: null,
      audio2Path: null,
      audio3Path: null,
      audio1Url: null,
      audio2Url: null,
      audio3Url: null,
    );
    _saveDraft();
  }

  void setContactInfo(Map<String, String> info) {
    state = state.copyWith(contactInfo: info);
    _saveDraft();
  }

  Future<void> reset() async {
    state = const DatingOnboardingDraft();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
    } catch (e) {
      // Ignore errors
    }
  }
}

final datingOnboardingDraftProvider =
    StateNotifierProvider<DatingOnboardingDraftNotifier, DatingOnboardingDraft>(
      (ref) => DatingOnboardingDraftNotifier(),
    );
