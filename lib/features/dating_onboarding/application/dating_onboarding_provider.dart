import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../domain/dating_onboarding_draft.dart';

final datingOnboardingProvider =
    StateNotifierProvider<DatingOnboardingNotifier, DatingOnboardingDraft>(
      (ref) => DatingOnboardingNotifier(),
    );

class DatingOnboardingNotifier extends StateNotifier<DatingOnboardingDraft> {
  DatingOnboardingNotifier() : super(const DatingOnboardingDraft());

  void setAge(int age) => state = state.copyWith(age: age);

  void setExtraInfo({
    required String city,
    required String countryOfResidence,
    required String nationality,
    required String educationLevel,
    required String profession,
    required String churchName,
    String? churchOtherName,
  }) {
    state = state.copyWith(
      city: city,
      countryOfResidence: countryOfResidence,
      nationality: nationality,
      educationLevel: educationLevel,
      profession: profession,
      churchName: churchName,
      churchOtherName: churchOtherName,
    );
  }

  void setHobbies(List<String> items) => state = state.copyWith(hobbies: items);
  void setDesiredQualities(List<String> items) =>
      state = state.copyWith(desiredQualities: items);

  void setPhotos(List<String> paths) =>
      state = state.copyWith(photoPaths: paths);

  void setAudio({String? a1, String? a2, String? a3}) {
    state = state.copyWith(
      audio1Path: a1 ?? state.audio1Path,
      audio2Path: a2 ?? state.audio2Path,
      audio3Path: a3 ?? state.audio3Path,
    );
  }

  void setContactInfo(Map<String, String> info) =>
      state = state.copyWith(contactInfo: info);

  void reset() => state = const DatingOnboardingDraft();
}
