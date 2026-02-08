import "package:nexus_app_min_test/core/session/effective_relationship_status_provider.dart";
import 'dev_relationship_status_provider.dart';
import "firestore_service_provider.dart";
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
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
  final status = ref.watch(effectiveRelationshipStatusProvider);

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

/// Provider for loading the latest assessment result (any type) for current user
final latestAnyAssessmentProvider = FutureProvider<AssessmentResult?>((
  ref,
) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return null;

  final firestoreService = ref.watch(firestoreServiceProvider);
  final allResults = await firestoreService.getAllAssessmentResults(user.id);

  // Return the most recently updated assessment
  if (allResults.isEmpty) return null;
  return allResults.first; // Already sorted by updatedAt desc
});

/// Provider for loading the latest assessment result for a given user and assessment type
final latestAssessmentResultProvider =
    FutureProvider.family<AssessmentResult?, String>((ref, assessmentId) async {
      final user = ref.watch(currentUserProvider).valueOrNull;
      if (user == null) return null;

      final firestoreService = ref.watch(firestoreServiceProvider);
      return firestoreService.getLatestAssessmentResult(user.id, assessmentId);
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
  final bool isNewlySubmitted; // Track if just submitted (first time viewing)
  final String? error;

  const AssessmentState({
    this.config,
    this.currentQuestionIndex = 0,
    this.answers = const {},
    this.isSubmitting = false,
    this.result,
    this.isNewlySubmitted = false,
    this.error,
  });

  AssessmentState copyWith({
    AssessmentConfig? config,
    int? currentQuestionIndex,
    Map<int, AssessmentAnswer>? answers,
    bool? isSubmitting,
    AssessmentResult? result,
    bool? isNewlySubmitted,
    String? error,
  }) {
    return AssessmentState(
      config: config ?? this.config,
      currentQuestionIndex: currentQuestionIndex ?? this.currentQuestionIndex,
      answers: answers ?? this.answers,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      result: result ?? this.result,
      isNewlySubmitted: isNewlySubmitted ?? this.isNewlySubmitted,
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
    if (optionId.trim().isEmpty) return;
    final question = state.currentQuestion;
    if (question == null) return;

    final selectedOption = question.options.firstWhere(
      (o) => o.id.toLowerCase() == optionId.toLowerCase(),
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
      final userId = user?.id ?? "dev_guest";

      // Calculate result
      final result = AssessmentResult.calculate(
        id: userId,
        userId: userId,
        config: state.config!,
        answers: state.answers.values.toList(),
      );

      // Save to Firestore (skip in dev mode if Firebase is unavailable)
      if (_firestoreService.isAvailable) {
        await _firestoreService.saveAssessmentResult(userId, result);
      }

      // Mark as newly submitted so result screen shows "Done" button
      state = state.copyWith(
        isSubmitting: false,
        result: result,
        isNewlySubmitted: true,
      );
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

final assessmentHistoryProvider = StreamProvider<List<AssessmentResult>>((ref) {
  final firestoreService = ref.watch(firestoreServiceProvider);
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return const Stream.empty();
  return firestoreService.watchAssessmentResults(user.id);
});
