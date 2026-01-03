import "firestore_service_provider.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assessment_model.dart';
import '../constants/app_constants.dart';
import '../services/config_loader_service.dart';
import 'package:nexus_app_min_test/core/services/firestore_service.dart';
import 'config_provider.dart';
import 'user_provider.dart';

// ============================================================================
// ASSESSMENT CONFIG PROVIDERS
// ============================================================================

/// Provider for loading assessment config by type
final assessmentConfigProvider =
    FutureProvider.family<AssessmentConfig?, AssessmentType>((ref, type) async {
      final configLoader = ref.watch(configLoaderProvider);
      return configLoader.loadAssessment(type);
    });

/// Provider for getting recommended assessment based on user's relationship status
final recommendedAssessmentTypeProvider = Provider<AssessmentType?>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user?.nexus2 == null) return null;

  final status = user!.nexus2!.relationshipStatusEnum;

  switch (status) {
    case RelationshipStatus.singleNeverMarried:
      return AssessmentType.singlesReadiness;
    case RelationshipStatus.divorced:
    case RelationshipStatus.widowed:
      return AssessmentType.remarriageReadiness;
    case RelationshipStatus.married:
      return AssessmentType.marriageHealthCheck;
  }
});

/// Provider for recommended assessment config
final recommendedAssessmentProvider = FutureProvider<AssessmentConfig?>((
  ref,
) async {
  final type = ref.watch(recommendedAssessmentTypeProvider);
  if (type == null) return null;
  return ref.watch(assessmentConfigProvider(type).future);
});

// ============================================================================
// ASSESSMENT STATE
// ============================================================================

/// State class for tracking active assessment progress
class AssessmentState {
  final AssessmentConfig? config;
  final int currentQuestionIndex;
  final Map<int, AssessmentAnswer> answers;
  final bool isSubmitting;
  final AssessmentResult? result;
  final String? error;

  const AssessmentState({
    this.config,
    this.currentQuestionIndex = 0,
    this.answers = const {},
    this.isSubmitting = false,
    this.result,
    this.error,
  });

  AssessmentState copyWith({
    AssessmentConfig? config,
    int? currentQuestionIndex,
    Map<int, AssessmentAnswer>? answers,
    bool? isSubmitting,
    AssessmentResult? result,
    String? error,
  }) {
    return AssessmentState(
      config: config ?? this.config,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      answers: answers ?? this.answers,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result ?? this.result,
      error: error,
    );
  }

  /// Current question being displayed
  AssessmentQuestion? get currentQuestion {
    if (config == null) return null;
    if (currentQuestionIndex >= config!.questions.length) return null;
    return config!.questions[currentQuestionIndex];
  }

  /// Total number of questions
  int get totalQuestions => config?.questions.length ?? 0;

  /// Number of questions answered
  int get answeredCount => answers.length;

  /// Progress percentage (0.0 to 1.0)
  double get progress {
    if (totalQuestions == 0) return 0.0;
    return answeredCount / totalQuestions;
  }

  /// Whether current question has been answered
  bool get currentQuestionAnswered => answers.containsKey(currentQuestionIndex);

  /// Whether all questions have been answered
  bool get isComplete => answeredCount == totalQuestions && totalQuestions > 0;

  /// Whether we can go to next question
  bool get canGoNext => currentQuestionIndex < totalQuestions - 1;

  /// Whether we can go to previous question
  bool get canGoBack => currentQuestionIndex > 0;

  /// Whether assessment is in progress (has config but no result)
  bool get isInProgress => config != null && result == null;
}

// ============================================================================
// ASSESSMENT NOTIFIER
// ============================================================================

/// Notifier for managing assessment flow
class AssessmentNotifier extends StateNotifier<AssessmentState> {
  final Ref _ref;
  final FirestoreService _firestoreService;

  AssessmentNotifier(this._ref, this._firestoreService)
    : super(const AssessmentState());

  /// Start a new assessment
  Future<void> startAssessment(AssessmentType type) async {
    try {
      final config = await _ref.read(assessmentConfigProvider(type).future);
      if (config == null) {
        state = state.copyWith(
          error: 'Failed to load assessment configuration',
        );
        return;
      }

      state = AssessmentState(config: config);
    } catch (e) {
      state = state.copyWith(error: 'Error starting assessment: $e');
    }
  }

  /// Start assessment with pre-loaded config
  void startWithConfig(AssessmentConfig config) {
    state = AssessmentState(config: config);
  }

  /// Answer current question
  void answerQuestion(String optionId) {
    final question = state.currentQuestion;
    if (question == null) return;

    final selectedOption = question.options.firstWhere(
      (o) => o.id == optionId,
      orElse: () => question.options.first,
    );

    final answer = AssessmentAnswer(
      questionNumber: question.number,
      dimension: question.dimension,
      selectedOptionId: optionId,
      signalTier: selectedOption.signalTier,
      weight: selectedOption.weight,
    );

    final newAnswers = Map<int, AssessmentAnswer>.from(state.answers);
    newAnswers[state.currentQuestionIndex] = answer;

    state = state.copyWith(answers: newAnswers);
  }

  /// Go to next question
  void nextQuestion() {
    if (state.canGoNext) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex + 1,
      );
    }
  }

  /// Go to previous question
  void previousQuestion() {
    if (state.canGoBack) {
      state = state.copyWith(
        currentQuestionIndex: state.currentQuestionIndex - 1,
      );
    }
  }

  /// Jump to specific question
  void goToQuestion(int index) {
    if (index >= 0 && index < state.totalQuestions) {
      state = state.copyWith(currentQuestionIndex: index);
    }
  }

  /// Submit assessment and calculate results
  Future<void> submitAssessment() async {
    if (!state.isComplete || state.config == null) {
      state = state.copyWith(error: 'Assessment is not complete');
      return;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      // Get current user ID
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user == null) {
        state = state.copyWith(
          isSubmitting: false,
          error: 'User not authenticated',
        );
        return;
      }

      // Calculate result
      final result = AssessmentResult.calculate(
        id: user.id,
        userId: user.id,
        config: state.config!,
        answers: state.answers.values.toList(),
      );

      // Save to Firestore
      await _firestoreService.saveAssessmentResult(user.id, result);

      state = state.copyWith(isSubmitting: false, result: result);
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Failed to save assessment: $e',
      );
    }
  }

  /// Reset assessment state
  void reset() {
    state = const AssessmentState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for assessment state notifier
final assessmentNotifierProvider =
    StateNotifierProvider<AssessmentNotifier, AssessmentState>((ref) {
      final firestoreService = ref.watch(firestoreServiceProvider);
      return AssessmentNotifier(ref, firestoreService);
    });

/// Provider for user's assessment history
final assessmentHistoryProvider = StreamProvider<List<AssessmentResult>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value([]);

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchAssessmentResults(user.id);
});

/// Provider for latest assessment result of a specific type
final latestAssessmentResultProvider =
    FutureProvider.family<AssessmentResult?, String>((ref, assessmentId) async {
      final history = await ref.watch(assessmentHistoryProvider.future);
      try {
        return history.firstWhere((r) => r.assessmentId == assessmentId);
      } catch (_) {
        return null;
      }
    });

/// Provider for checking if user has completed their recommended assessment
final hasCompletedRecommendedAssessmentProvider = FutureProvider<bool>((
  ref,
) async {
  final type = ref.watch(recommendedAssessmentTypeProvider);
  if (type == null) return false;

  final assessmentId = type.toAssessmentId();
  final result = await ref.watch(
    latestAssessmentResultProvider(assessmentId).future,
  );
  return result != null;
});

// ============================================================================
// HELPER EXTENSION
// ============================================================================

extension AssessmentTypeExtension on AssessmentType {
  String toAssessmentId() {
    switch (this) {
      case AssessmentType.singlesReadiness:
        return 'singles_readiness_v1';
      case AssessmentType.remarriageReadiness:
        return 'remarriage_readiness_v1';
      case AssessmentType.marriageHealthCheck:
        return 'marriage_health_check_v1';
    }
  }
}
