import '../domain/compatibility_quiz_answers.dart';

class CompatibilityQuizState {
  final int step; // 0-9
  final CompatibilityQuizAnswers? answers;
  final bool isSubmitting;
  final String? error;

  const CompatibilityQuizState({
    required this.step,
    this.answers,
    this.isSubmitting = false,
    this.error,
  });

  CompatibilityQuizState copyWith({
    int? step,
    CompatibilityQuizAnswers? answers,
    bool? isSubmitting,
    String? error,
  }) {
    return CompatibilityQuizState(
      step: step ?? this.step,
      answers: answers ?? this.answers,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      error: error,
    );
  }

  bool get isComplete => answers != null;
}
