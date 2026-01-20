import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/compatibility_quiz_answers.dart';
import 'compatibility_quiz_state.dart';
import 'compatibility_quiz_service.dart';

final compatibilityQuizServiceProvider = Provider<CompatibilityQuizService>((
  ref,
) {
  return CompatibilityQuizService(ref);
});

final compatibilityQuizProvider =
    NotifierProvider<CompatibilityQuizNotifier, CompatibilityQuizState>(
      CompatibilityQuizNotifier.new,
    );

class CompatibilityQuizNotifier extends Notifier<CompatibilityQuizState> {
  @override
  CompatibilityQuizState build() => const CompatibilityQuizState(step: 0);

  void goNext() {
    final s = state.step;
    if (s >= 9) return;
    state = state.copyWith(step: s + 1);
  }

  void goBack() {
    final s = state.step;
    if (s <= 0) return;
    state = state.copyWith(step: s - 1);
  }

  void setAnswer(String key, String value) {
    final current =
        state.answers ??
        const CompatibilityQuizAnswers(
          maritalStatus: '',
          haveKids: '',
          genotype: '',
          personalityType: '',
          regularSourceOfIncome: '',
          marrySomeoneNotFS: '',
          longDistance: '',
          believeInCohabiting: '',
          shouldChristianSpeakInTongue: '',
          believeInTithing: '',
        );

    CompatibilityQuizAnswers next = current;

    switch (key) {
      case 'maritalStatus':
        next = current.copyWith(maritalStatus: value);
        break;
      case 'haveKids':
        next = current.copyWith(haveKids: value);
        break;
      case 'genotype':
        next = current.copyWith(genotype: value);
        break;
      case 'personalityType':
        next = current.copyWith(personalityType: value);
        break;
      case 'regularSourceOfIncome':
        next = current.copyWith(regularSourceOfIncome: value);
        break;
      case 'marrySomeoneNotFS':
        next = current.copyWith(marrySomeoneNotFS: value);
        break;
      case 'longDistance':
        next = current.copyWith(longDistance: value);
        break;
      case 'believeInCohabiting':
        next = current.copyWith(believeInCohabiting: value);
        break;
      case 'shouldChristianSpeakInTongue':
        next = current.copyWith(shouldChristianSpeakInTongue: value);
        break;
      case 'believeInTithing':
        next = current.copyWith(believeInTithing: value);
        break;
    }

    state = state.copyWith(answers: next);
  }

  Future<void> submit() async {
    final svc = ref.read(compatibilityQuizServiceProvider);
    final answers = state.answers;
    if (answers == null) return;

    state = state.copyWith(isSubmitting: true, error: null);
    try {
      await svc.saveAnswers(answers);
      state = state.copyWith(isSubmitting: false);
    } catch (e) {
      state = state.copyWith(isSubmitting: false, error: e.toString());
    }
  }
}
