import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/user_model.dart';
import '../constants/app_constants.dart';
import 'package:nexus_app_min_test/core/services/firestore_service.dart';
import 'auth_provider.dart';
import 'service_providers.dart';
import 'firestore_service_provider.dart';

/// Stream provider for current user data from Firestore
final userStreamProvider = StreamProvider<UserModel?>((ref) {
  final _userId = ref.watch(currentUserIdProvider);
  if (_userId == null) return Stream.value(null);

  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.streamUser(_userId);
});

/// Provider for current user (as AsyncValue for proper loading/error handling)
final currentUserProvider = Provider<AsyncValue<UserModel?>>((ref) {
  return ref.watch(userStreamProvider);
});

/// Provider to check if user needs Nexus 2.0 onboarding
final needsOnboardingProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.maybeWhen(
    data: (user) => user?.needsNexus2Onboarding ?? false,
    orElse: () => false,
  );
});

/// Provider for user's relationship status (from nexus2)
final userRelationshipStatusProvider = Provider<RelationshipStatus?>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.maybeWhen(
    data: (user) {
      final status = user?.nexus2?.relationshipStatus;
      if (status == null || status.isEmpty) return null;
      return RelationshipStatus.fromValue(status);
    },
    orElse: () => null,
  );
});

/// Provider to check if user is single (for showing Search tab)
final userIsSingleProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.maybeWhen(
    data: (user) => user?.isSingle ?? false,
    orElse: () => false,
  );
});

/// Provider to check if user is married (for navigation)
final userIsMarriedProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.maybeWhen(
    data: (user) => user?.isMarried ?? false,
    orElse: () => false,
  );
});

/// Provider to check if profile is complete for dating features
final isProfileCompleteForDatingProvider = Provider<bool>((ref) {
  final userAsync = ref.watch(currentUserProvider);
  return userAsync.maybeWhen(
    data: (user) => user?.isProfileCompleteForDating ?? false,
    orElse: () => false,
  );
});

/// Provider to fetch any user by ID (for viewing other profiles)
final userByIdProvider = FutureProvider.family<UserModel?, String>((
  ref,
  _userId,
) async {
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.getUser(_userId);
});

/// State notifier for user operations
class UserNotifier extends StateNotifier<AsyncValue<UserModel?>> {
  final FirestoreService _firestoreService;
  final String? _userId;

  UserNotifier(this._firestoreService, this._userId)
    : super(const AsyncValue.loading()) {
    if (_userId != null) {
      _loadUser();
    } else {
      state = const AsyncValue.data(null);
    }
  }

  Future<void> _loadUser() async {
    final userId = _userId;
    if (userId == null) {
      state = const AsyncValue.data(null);
      return;
    }

    try {
      final user = await _firestoreService.getUser(userId);
      state = AsyncValue.data(user);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Reload user data
  Future<void> refresh() async {
    await _loadUser();
  }

  /// Complete Nexus 2.0 onboarding
  Future<void> completeOnboarding({
    required RelationshipStatus relationshipStatus,
    required Gender gender,
    required List<UserGoal> primaryGoals,
  }) async {
    final userId = _userId;
    if (userId == null) return;

    state = const AsyncValue.loading();
    try {
      await _firestoreService.completeOnboarding(
        userId,
        relationshipStatus: relationshipStatus.value,
        gender: gender.value,
        primaryGoals: primaryGoals.map((g) => g.value).toList(),
      );
      await _loadUser();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update specific Nexus 2.0 fields
  Future<void> updateNexus2Fields(Map<String, dynamic> fields) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestoreService.updateNexus2Fields(userId, fields);
      await _loadUser();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Update last active timestamp
  Future<void> updateLastActive() async {
    final userId = _userId;
    if (userId == null) return;
    await _firestoreService.updateLastActive(userId);
  }

  /// Update profile fields
  Future<void> updateProfile(Map<String, dynamic> updates) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestoreService.updateUserFields(userId, updates);
      await _loadUser();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }

  /// Unblock a user
  Future<void> unblockUser(String blockedUserId) async {
    final userId = _userId;
    if (userId == null) return;

    try {
      await _firestoreService.unblockUser(userId, blockedUserId);
      await _loadUser();
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      rethrow;
    }
  }
}

/// Provider for user notifier
final userNotifierProvider =
    StateNotifierProvider<UserNotifier, AsyncValue<UserModel?>>((ref) {
      final firestoreService = ref.watch(firestoreServiceProvider);
      final _userId = ref.watch(currentUserIdProvider);
      return UserNotifier(firestoreService, _userId);
    });

/// Onboarding state for pre-auth survey
class OnboardingState {
  final RelationshipStatus? relationshipStatus;
  final Gender? gender;
  final List<UserGoal> primaryGoals;
  final int currentStep;

  const OnboardingState({
    this.relationshipStatus,
    this.gender,
    this.primaryGoals = const [],
    this.currentStep = 0,
  });

  OnboardingState copyWith({
    RelationshipStatus? relationshipStatus,
    Gender? gender,
    List<UserGoal>? primaryGoals,
    int? currentStep,
  }) {
    return OnboardingState(
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      gender: gender ?? this.gender,
      primaryGoals: primaryGoals ?? this.primaryGoals,
      currentStep: currentStep ?? this.currentStep,
    );
  }

  bool get isComplete =>
      relationshipStatus != null && gender != null && primaryGoals.isNotEmpty;

  /// Get available goals based on relationship status
  List<UserGoal> get availableGoals {
    if (relationshipStatus == null) return [];
    return UserGoal.goalsForStatus(relationshipStatus!);
  }
}

/// State notifier for onboarding flow
class OnboardingNotifier extends StateNotifier<OnboardingState> {
  OnboardingNotifier() : super(const OnboardingState());

  void setRelationshipStatus(RelationshipStatus status) {
    // Clear goals if relationship status changes (goals are status-specific)
    state = state.copyWith(
      relationshipStatus: status,
      primaryGoals: [],
      currentStep: 1,
    );
  }

  void setGender(Gender gender) {
    state = state.copyWith(gender: gender, currentStep: 2);
  }

  void toggleGoal(UserGoal goal) {
    final currentGoals = List<UserGoal>.from(state.primaryGoals);
    if (currentGoals.contains(goal)) {
      currentGoals.remove(goal);
    } else {
      // Limit to 3 primary goals
      if (currentGoals.length < 3) {
        currentGoals.add(goal);
      }
    }
    state = state.copyWith(primaryGoals: currentGoals);
  }

  void setGoals(List<UserGoal> goals) {
    state = state.copyWith(primaryGoals: goals);
  }

  void goToStep(int step) {
    state = state.copyWith(currentStep: step);
  }

  void goBack() {
    if (state.currentStep > 0) {
      state = state.copyWith(currentStep: state.currentStep - 1);
    }
  }

  void reset() {
    state = const OnboardingState();
  }
}

/// Provider for onboarding state
final onboardingProvider =
    StateNotifierProvider<OnboardingNotifier, OnboardingState>((ref) {
      return OnboardingNotifier();
    });
