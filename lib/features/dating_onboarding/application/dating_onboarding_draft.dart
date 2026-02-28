import 'dart:async';
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

  /// Remote photo URLs after upload.
  final List<String> photoUrls;

  /// Local audio file paths for now. Later we store remote URLs.
  final String? audio1Path;
  final String? audio2Path;
  final String? audio3Path;

  /// Remote audio URLs after upload.
  final String? audio1Url;
  final String? audio2Url;
  final String? audio3Url;

  /// Audio durations in seconds (captured during recording).
  final int? audio1Duration;
  final int? audio2Duration;
  final int? audio3Duration;

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
    this.photoUrls = const [],
    this.audio1Path,
    this.audio2Path,
    this.audio3Path,
    this.audio1Url,
    this.audio2Url,
    this.audio3Url,
    this.audio1Duration,
    this.audio2Duration,
    this.audio3Duration,
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
    List<String>? photoUrls,
    String? audio1Path,
    String? audio2Path,
    String? audio3Path,
    String? audio1Url,
    String? audio2Url,
    String? audio3Url,
    int? audio1Duration,
    int? audio2Duration,
    int? audio3Duration,
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
      photoUrls: photoUrls ?? this.photoUrls,
      audio1Path: audio1Path ?? this.audio1Path,
      audio2Path: audio2Path ?? this.audio2Path,
      audio3Path: audio3Path ?? this.audio3Path,
      audio1Url: audio1Url ?? this.audio1Url,
      audio2Url: audio2Url ?? this.audio2Url,
      audio3Url: audio3Url ?? this.audio3Url,
      audio1Duration: audio1Duration ?? this.audio1Duration,
      audio2Duration: audio2Duration ?? this.audio2Duration,
      audio3Duration: audio3Duration ?? this.audio3Duration,
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
      'photoUrls': photoUrls,
      'audio1Path': audio1Path,
      'audio2Path': audio2Path,
      'audio3Path': audio3Path,
      'audio1Url': audio1Url,
      'audio2Url': audio2Url,
      'audio3Url': audio3Url,
      'audio1Duration': audio1Duration,
      'audio2Duration': audio2Duration,
      'audio3Duration': audio3Duration,
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
      photoUrls: (json['photoUrls'] as List<dynamic>?)?.cast<String>() ?? [],
      audio1Path: json['audio1Path'] as String?,
      audio2Path: json['audio2Path'] as String?,
      audio3Path: json['audio3Path'] as String?,
      audio1Url: json['audio1Url'] as String?,
      audio2Url: json['audio2Url'] as String?,
      audio3Url: json['audio3Url'] as String?,
      audio1Duration: json['audio1Duration'] as int?,
      audio2Duration: json['audio2Duration'] as int?,
      audio3Duration: json['audio3Duration'] as int?,
      contactInfo:
          (json['contactInfo'] as Map<String, dynamic>?)
              ?.cast<String, String>() ??
          {},
    );
  }
}

// Removed duplicate class definition. setPhotoUrls will be added to the main class below.

class DatingOnboardingDraftNotifier
    extends StateNotifier<DatingOnboardingDraft> {
  DatingOnboardingDraftNotifier() : super(const DatingOnboardingDraft()) {
    _initLoad();
  }

  final Completer<void> _loadCompleter = Completer<void>();

  /// Await this before reading state to ensure SharedPreferences draft is loaded.
  Future<void> ensureLoaded() => _loadCompleter.future;

  void _initLoad() {
    _loadDraft()
        .then((_) {
          if (!_loadCompleter.isCompleted) _loadCompleter.complete();
        })
        .catchError((_) {
          if (!_loadCompleter.isCompleted) _loadCompleter.complete();
        });
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
        print(
          '[DRAFT] 📥 Loaded from SharedPreferences: age=${state.age}, city=${state.city}, country=${state.countryOfResidence}, hobbies=${state.hobbies.length}, qualities=${state.desiredQualities.length}',
        );
      } else {
        print('[DRAFT] 📭 No saved draft found - starting fresh');
      }
    } catch (e) {
      print('[DRAFT] ❌ Error loading draft: $e');
    }
  }

  // ...existing code...

  void setPhotoUrls(List<String> urls) {
    state = state.copyWith(photoUrls: urls);
    _saveDraft();
  }

  /// Save draft to SharedPreferences after each change
  Future<void> _saveDraft() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final jsonString = jsonEncode(state.toJson());
      await prefs.setString(_storageKey, jsonString);
      print(
        '[DRAFT] 💾 Saved to SharedPreferences: age=${state.age}, city=${state.city}, hobbies=${state.hobbies.length}, qualities=${state.desiredQualities.length}',
      );
    } catch (e) {
      print('[DRAFT] ❌ Error saving draft: $e');
    }
  }

  void setAge(int age) {
    print('[DRAFT] ✏️ Updating age: ${state.age} → $age');
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
    print('[DRAFT] ✏️ Updating extra info:');
    if (city != null) print('  city: ${state.city} → $city');
    if (countryOfResidence != null)
      print('  country: ${state.countryOfResidence} → $countryOfResidence');
    if (nationality != null)
      print('  nationality: ${state.nationality} → $nationality');
    if (educationLevel != null)
      print('  education: ${state.educationLevel} → $educationLevel');
    if (profession != null)
      print('  profession: ${state.profession} → $profession');
    if (churchName != null)
      print('  church: ${state.churchName} → $churchName');
    if (otherChurchName != null)
      print('  otherChurch: ${state.otherChurchName} → $otherChurchName');

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
    print('[DRAFT] ✏️ Updating hobbies: ${state.hobbies} → $hobbies');
    state = state.copyWith(hobbies: hobbies);
    _saveDraft();
  }

  void setDesiredQualities(List<String> qualities) {
    print(
      '[DRAFT] ✏️ Updating desired qualities: ${state.desiredQualities} → $qualities',
    );
    state = state.copyWith(desiredQualities: qualities);
    _saveDraft();
  }

  void setPhotos(List<String> paths) {
    state = state.copyWith(photoPaths: paths);
    _saveDraft();
  }

  void setAudio({
    String? a1,
    String? a2,
    String? a3,
    int? d1,
    int? d2,
    int? d3,
  }) {
    state = state.copyWith(
      audio1Path: a1 ?? state.audio1Path,
      audio2Path: a2 ?? state.audio2Path,
      audio3Path: a3 ?? state.audio3Path,
      audio1Duration: d1 ?? state.audio1Duration,
      audio2Duration: d2 ?? state.audio2Duration,
      audio3Duration: d3 ?? state.audio3Duration,
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
    state = DatingOnboardingDraft(
      age: state.age,
      city: state.city,
      countryOfResidence: state.countryOfResidence,
      nationality: state.nationality,
      educationLevel: state.educationLevel,
      profession: state.profession,
      churchName: state.churchName,
      otherChurchName: state.otherChurchName,
      hobbies: state.hobbies,
      desiredQualities: state.desiredQualities,
      photoPaths: state.photoPaths,
      photoUrls: state.photoUrls,
      // audio paths/urls/durations all null by default
      contactInfo: state.contactInfo,
    );
    _saveDraft();
  }

  /// Clear a single audio recording (path and URL) for re-recording
  void clearSingleAudio(int questionNumber) {
    switch (questionNumber) {
      case 1:
        state = DatingOnboardingDraft(
          age: state.age,
          city: state.city,
          countryOfResidence: state.countryOfResidence,
          nationality: state.nationality,
          educationLevel: state.educationLevel,
          profession: state.profession,
          churchName: state.churchName,
          otherChurchName: state.otherChurchName,
          hobbies: state.hobbies,
          desiredQualities: state.desiredQualities,
          photoPaths: state.photoPaths,
          photoUrls: state.photoUrls,
          audio1Path: null, // Clear
          audio2Path: state.audio2Path,
          audio3Path: state.audio3Path,
          audio1Url: null, // Clear
          audio2Url: state.audio2Url,
          audio3Url: state.audio3Url,
          audio1Duration: null, // Clear
          audio2Duration: state.audio2Duration,
          audio3Duration: state.audio3Duration,
          contactInfo: state.contactInfo,
        );
        break;
      case 2:
        state = DatingOnboardingDraft(
          age: state.age,
          city: state.city,
          countryOfResidence: state.countryOfResidence,
          nationality: state.nationality,
          educationLevel: state.educationLevel,
          profession: state.profession,
          churchName: state.churchName,
          otherChurchName: state.otherChurchName,
          hobbies: state.hobbies,
          desiredQualities: state.desiredQualities,
          photoPaths: state.photoPaths,
          photoUrls: state.photoUrls,
          audio1Path: state.audio1Path,
          audio2Path: null, // Clear
          audio3Path: state.audio3Path,
          audio1Url: state.audio1Url,
          audio2Url: null, // Clear
          audio3Url: state.audio3Url,
          audio1Duration: state.audio1Duration,
          audio2Duration: null, // Clear
          audio3Duration: state.audio3Duration,
          contactInfo: state.contactInfo,
        );
        break;
      case 3:
        state = DatingOnboardingDraft(
          age: state.age,
          city: state.city,
          countryOfResidence: state.countryOfResidence,
          nationality: state.nationality,
          educationLevel: state.educationLevel,
          profession: state.profession,
          churchName: state.churchName,
          otherChurchName: state.otherChurchName,
          hobbies: state.hobbies,
          desiredQualities: state.desiredQualities,
          photoPaths: state.photoPaths,
          photoUrls: state.photoUrls,
          audio1Path: state.audio1Path,
          audio2Path: state.audio2Path,
          audio3Path: null, // Clear
          audio1Url: state.audio1Url,
          audio2Url: state.audio2Url,
          audio3Url: null, // Clear
          audio1Duration: state.audio1Duration,
          audio2Duration: state.audio2Duration,
          audio3Duration: null, // Clear
          contactInfo: state.contactInfo,
        );
        break;
    }
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
      print('[DRAFT] Draft cleared and reset to empty state');
    } catch (e) {
      print('[DRAFT] Error resetting draft: $e');
    }
  }

  /// Clear all draft data when user deletes their existing profile or starts fresh
  /// This is called:
  /// - When entering the dating profile creation flow
  /// - When user deletes their existing dating profile
  /// - When user explicitly exits/discards the creation process
  Future<void> clearDraftForFreshStart() async {
    state = const DatingOnboardingDraft();
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.remove(_storageKey);
      print('[DRAFT] Draft cleared for fresh profile creation start');
    } catch (e) {
      print('[DRAFT] Error clearing draft for fresh start: $e');
    }
  }
}

final datingOnboardingDraftProvider =
    StateNotifierProvider<DatingOnboardingDraftNotifier, DatingOnboardingDraft>(
      (ref) => DatingOnboardingDraftNotifier(),
    );
