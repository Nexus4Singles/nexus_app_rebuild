import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/assessment_model.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/journey_model.dart';
import '../constants/app_constants.dart';
import '../services/config_loader_service.dart';
import 'package:nexus_app_min_test/core/services/firestore_service.dart';
import 'firestore_service_provider.dart';
import 'config_provider.dart';
import 'user_provider.dart';
import "assessment_provider.dart";

// ============================================================================
// JOURNEY CATALOG PROVIDERS
// ============================================================================

/// Provider for singles (never married) journey catalog
final singlesNeverMarriedCatalogProvider = FutureProvider<JourneyCatalog?>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadSinglesNeverMarriedJourneyCatalog();
});

/// Provider for divorced/widowed journey catalog (includes parenting content)
final divorcedWidowedCatalogProvider = FutureProvider<JourneyCatalog?>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadDivorcedWidowedJourneyCatalog();
});

/// Provider for married journey catalog (includes parenting content)
final marriedJourneyCatalogProvider = FutureProvider<JourneyCatalog?>((ref) async {
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.loadMarriedJourneyCatalog();
});

/// Provider for journey catalog based on user's relationship status
/// Each status gets relationship-appropriate content:
/// - Singles (never married): Dating/readiness focused
/// - Divorced/Widowed: Healing + co-parenting content
/// - Married: Marriage enrichment + parenting content
final userJourneyCatalogProvider = FutureProvider<JourneyCatalog?>((ref) async {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user?.nexus2 == null) return null;
  
  final statusStr = user!.nexus2!.relationshipStatus;
  if (statusStr == null || statusStr.isEmpty) return null;
  
  final status = RelationshipStatus.fromValue(statusStr);
  final configLoader = ref.watch(configLoaderProvider);
  return configLoader.getJourneyCatalogForStatus(status);
});

/// Provider for all available products for current user
final availableProductsProvider = FutureProvider<List<JourneyProduct>>((ref) async {
  final catalog = await ref.watch(userJourneyCatalogProvider.future);
  return catalog?.products ?? [];
});

/// Provider for a specific product by ID
final productByIdProvider = FutureProvider.family<JourneyProduct?, String>(
  (ref, productId) async {
    final catalog = await ref.watch(userJourneyCatalogProvider.future);
    return catalog?.findProduct(productId);
  },
);

// ============================================================================
// JOURNEY PROGRESS PROVIDERS
// ============================================================================

/// Provider for all user's journey progress
final allJourneyProgressProvider = StreamProvider<Map<String, JourneyProgress>>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return Stream.value({});
  
  final firestoreService = ref.watch(firestoreServiceProvider);
  return firestoreService.watchAllJourneyProgress(user.id);
});

/// Provider for specific journey progress
final journeyProgressProvider = StreamProvider.family<JourneyProgress?, String>(
  (ref, productId) {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return Stream.value(null);
    
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.watchJourneyProgress(user.id, productId);
  },
);

/// Provider for checking if a product is purchased
final isProductPurchasedProvider = Provider.family<bool, String>((ref, productId) {
  final progress = ref.watch(journeyProgressProvider(productId)).valueOrNull;
  return progress?.purchased ?? false;
});

/// Provider for products user has purchased/started
final purchasedProductsProvider = Provider<List<String>>((ref) {
  final allProgress = ref.watch(allJourneyProgressProvider).valueOrNull ?? {};
  return allProgress.entries
      .where((e) => e.value.purchased)
      .map((e) => e.key)
      .toList();
});

/// Provider for active journeys (purchased but not completed)
final activeJourneysProvider = FutureProvider<List<JourneyProduct>>((ref) async {
  final allProgress = ref.watch(allJourneyProgressProvider).valueOrNull ?? {};
  final catalog = await ref.watch(userJourneyCatalogProvider.future);
  if (catalog == null) return [];
  
  final activeIds = allProgress.entries
      .where((e) => e.value.purchased && e.value.completedSessions < e.value.totalSessions)
      .map((e) => e.key)
      .toList();
  
  return catalog.products.where((p) => activeIds.contains(p.productId)).toList();
});

/// Provider for recommended products based on assessment results
final recommendedProductsProvider = FutureProvider<List<JourneyProduct>>((ref) async {
  final catalog = await ref.watch(userJourneyCatalogProvider.future);
  if (catalog == null || catalog.products.isEmpty) return [];

  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return catalog.products.take(5).toList();

  // Restore assessment-driven recommendations
  final history = await ref.watch(assessmentHistoryProvider.future);
  if (history.isEmpty) return catalog.products.take(5).toList();

  final recommended = <JourneyProduct>[];
  final inferredTags = <String>{};

  // Collect inferred tags + any explicitly recommended journey IDs from recent results
  final recent = history.take(3);
  for (final result in recent) {
    inferredTags.addAll(result.inferredTags);

    final recId = result.recommendedJourneyId;
    if (recId != null && recId.trim().isNotEmpty) {
      JourneyProduct? match;
      for (final p in catalog.products) {
        final haystack = " ".toLowerCase();
        if (haystack.contains(recId.toLowerCase())) {
          match = p;
          break;
        }
      }
      if (match != null && !recommended.contains(match)) {
        recommended.add(match);
      }
    }
  }

  // Tag-based matching fallback
  for (final p in catalog.products) {
    if (recommended.length >= 5) break;
    if (recommended.contains(p)) continue;

    final haystack = " ".toLowerCase();
    for (final tag in inferredTags) {
      if (haystack.contains(tag.toLowerCase())) {
        recommended.add(p);
        break;
      }
    }
  }

  // Final fallback if nothing matched
  if (recommended.isEmpty) return catalog.products.take(5).toList();
  return recommended;
});

// ============================================================================
// SESSION STATE
// ============================================================================

/// State for active session
class SessionState {
  final JourneyProduct? product;
  final JourneySession? session;
  final JourneyProgress? progress;
  final dynamic responseValue;
  final int? difficultyRating;
  final int? confidenceRating;
  final bool isSubmitting;
  final bool isComplete;
  final String? error;

  const SessionState({
    this.product,
    this.session,
    this.progress,
    this.responseValue,
    this.difficultyRating,
    this.confidenceRating,
    this.isSubmitting = false,
    this.isComplete = false,
    this.error,
  });

  SessionState copyWith({
    JourneyProduct? product,
    JourneySession? session,
    JourneyProgress? progress,
    dynamic responseValue,
    int? difficultyRating,
    int? confidenceRating,
    bool? isSubmitting,
    bool? isComplete,
    String? error,
  }) {
    return SessionState(
      product: product ?? this.product,
      session: session ?? this.session,
      progress: progress ?? this.progress,
      responseValue: responseValue ?? this.responseValue,
      difficultyRating: difficultyRating ?? this.difficultyRating,
      confidenceRating: confidenceRating ?? this.confidenceRating,
      isSubmitting: isSubmitting ?? this.isSubmitting,
      isComplete: isComplete ?? this.isComplete,
      error: error,
    );
  }

  /// Whether this is a free preview session
  bool get isFreeSession => session?.lockRule == LockRule.free;

  /// Whether session can be started (free or purchased)
  bool get canStart => isFreeSession || (progress?.purchased ?? false);

  /// Whether response has been provided
  bool get hasResponse => responseValue != null;

  /// Whether check-in ratings have been provided
  bool get hasCheckIn => difficultyRating != null || confidenceRating != null;
}

// ============================================================================
// SESSION NOTIFIER
// ============================================================================

class SessionNotifier extends StateNotifier<SessionState> {
  final Ref _ref;
  final FirestoreService _firestoreService;

  SessionNotifier(this._ref, this._firestoreService) : super(const SessionState());

  /// Start a session
  Future<void> startSession(String productId, int sessionNumber) async {
    try {
      final product = await _ref.read(productByIdProvider(productId).future);
      if (product == null) {
        state = state.copyWith(error: 'Product not found');
        return;
      }

      final session = product.getSession(sessionNumber);
      if (session == null) {
        state = state.copyWith(error: 'Session not found');
        return;
      }

      final progress = await _ref.read(journeyProgressProvider(productId).future);

      state = SessionState(
        product: product,
        session: session,
        progress: progress,
      );
    } catch (e) {
      state = state.copyWith(error: 'Error starting session: $e');
    }
  }

  /// Set response value (varies by response type)
  void setResponse(dynamic value) {
    state = state.copyWith(responseValue: value);
  }

  /// Set difficulty rating (1-5)
  void setDifficultyRating(int rating) {
    state = state.copyWith(difficultyRating: rating.clamp(1, 5));
  }

  /// Set confidence rating (1-5)
  void setConfidenceRating(int rating) {
    state = state.copyWith(confidenceRating: rating.clamp(1, 5));
  }

  /// Complete and save session
  Future<void> completeSession() async {
    if (state.product == null || state.session == null) {
      state = state.copyWith(error: 'No active session');
      return;
    }

    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user == null) {
        state = state.copyWith(isSubmitting: false, error: 'User not authenticated');
        return;
      }

      final sessionId = 'session_${state.session!.sessionNumber}';
      final stepId = 'step_${state.session!.responseType.value}';

      // Create session response
      final response = SessionResponse(
        visitorId: user.id,
        userId: user.id,
        productId: state.product!.productId,
        sessionId: sessionId,
        stepId: stepId,
        responseType: state.session!.responseType.value,
        value: state.responseValue,
        createdAt: DateTime.now(),
        rating: state.difficultyRating,
        confidenceRating: state.confidenceRating,
      );

      // Save response
      await _firestoreService.saveSessionResponse(user.id, response);

      // Update journey progress
      await _firestoreService.updateJourneyProgress(
        user.id,
        state.product!.productId,
        state.session!.sessionNumber,
      );

      state = state.copyWith(
        isSubmitting: false,
        isComplete: true,
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Failed to save session: $e',
      );
    }
  }

  /// Submit a response for a session step (used by UI)
  Future<void> submitResponse({
    required String productId,
    required int sessionNumber,
    required ResponseType responseType,
    String? selectedOption,
    List<String>? selectedMultiple,
    int? scaleValue,
    String? textResponse,
    double? checkInValue,
  }) async {
    state = state.copyWith(isSubmitting: true, error: null);

    try {
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user == null) {
        state = state.copyWith(isSubmitting: false, error: 'User not authenticated');
        return;
      }
      // Encode response value based on type
      dynamic responseValue;
      switch (responseType) {
        case ResponseType.singleSelect:
          responseValue = selectedOption;
          break;
        case ResponseType.multiSelect:
          responseValue = selectedMultiple;
          break;
        case ResponseType.scale3:
          responseValue = scaleValue ?? checkInValue;
          break;
        case ResponseType.reflection:
        case ResponseType.shortText:
          responseValue = textResponse;
          break;
        default:
          responseValue = textResponse;
      }

      final sessionId = 'session_$sessionNumber';
      final stepId = 'step_${responseType.value}';

      // Create session response
      final response = SessionResponse(
        visitorId: user.id,
        userId: user.id,
        productId: productId,
        sessionId: sessionId,
        stepId: stepId,
        responseType: responseType.value,
        value: responseValue,
        createdAt: DateTime.now(),
        rating: state.difficultyRating,
        confidenceRating: state.confidenceRating,
      );

      // Save response
      await _firestoreService.saveSessionResponse(user.id, response);

      // Update journey progress
      await _firestoreService.updateJourneyProgress(
        user.id,
        productId,
        sessionNumber,
      );

      state = state.copyWith(
        isSubmitting: false,
        isComplete: true,
      );
    } catch (e) {
      state = state.copyWith(
        isSubmitting: false,
        error: 'Failed to submit response: $e',
      );
    }
  }

  /// Encode response value for storage
  String? _encodeResponse(dynamic value, ResponseType type) {
    if (value == null) return null;
    
    switch (type) {
      case ResponseType.scale3:
        return (value as PulseValue).name;
      case ResponseType.singleSelect:
        return value as String;
      case ResponseType.multiSelect:
        return (value as List<String>).join(',');
      case ResponseType.shortText:
        // Don't store long text responses per spec
        return null;
      case ResponseType.challenge:
        return (value as bool) ? 'completed' : 'skipped';
      case ResponseType.ranking:
        return (value as List<String>).join(',');
      default:
        return null;
    }
  }

  /// Reset session state
  void reset() {
    state = const SessionState();
  }

  /// Clear error
  void clearError() {
    state = state.copyWith(error: null);
  }
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for session state notifier
final sessionNotifierProvider = StateNotifierProvider<SessionNotifier, SessionState>(
  (ref) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return SessionNotifier(ref, firestoreService);
  },
);

/// Provider for session responses for a product
final sessionResponsesProvider = FutureProvider.family<List<SessionResponse>, String>(
  (ref, productId) async {
    final user = ref.watch(currentUserProvider).valueOrNull;
    if (user == null) return [];
    
    final firestoreService = ref.watch(firestoreServiceProvider);
    return firestoreService.getSessionResponses(user.id, productId);
  },
);

/// Provider for checking if a specific session is completed
final isSessionCompletedProvider = Provider.family<bool, ({String productId, int sessionNumber})>(
  (ref, params) {
    final progress = ref.watch(journeyProgressProvider(params.productId)).valueOrNull;
    if (progress == null) return false;
    return progress.completedSessions >= params.sessionNumber;
  },
);

/// Provider for next available session in a journey
final nextSessionProvider = FutureProvider.family<JourneySession?, String>(
  (ref, productId) async {
    final product = await ref.watch(productByIdProvider(productId).future);
    if (product == null) return null;
    
    final progress = ref.watch(journeyProgressProvider(productId)).valueOrNull;
    final nextNumber = (progress?.completedSessions ?? 0) + 1;
    
    return product.getSession(nextNumber);
  },
);

// ============================================================================
// PURCHASE PROVIDER
// ============================================================================

/// Notifier for handling product purchases
class PurchaseNotifier extends StateNotifier<AsyncValue<void>> {
  final Ref _ref;
  final FirestoreService _firestoreService;

  PurchaseNotifier(this._ref, this._firestoreService) : super(const AsyncValue.data(null));

  /// Purchase a product (creates journey progress record)
  Future<bool> purchaseProduct(String productId) async {
    state = const AsyncValue.loading();

    try {
      final user = _ref.read(currentUserProvider).valueOrNull;
      if (user == null) {
        state = AsyncValue.error('User not authenticated', StackTrace.current);
        return false;
      }

      final product = await _ref.read(productByIdProvider(productId).future);
      if (product == null) {
        state = AsyncValue.error('Product not found', StackTrace.current);
        return false;
      }

      // Create initial journey progress
      final progress = JourneyProgress(
        visitorId: user.id,
        visitorUid: user.id,
        productId: productId,
        productName: product.title,
        purchased: true,
        purchasedAt: DateTime.now(),
        totalSessions: product.sessions.length,
      );

      await _firestoreService.createJourneyProgress(user.id, progress);

      state = const AsyncValue.data(null);
      return true;
    } catch (e, st) {
      state = AsyncValue.error(e, st);
      return false;
    }
  }
}

/// Provider for purchase notifier
final purchaseNotifierProvider = StateNotifierProvider<PurchaseNotifier, AsyncValue<void>>(
  (ref) {
    final firestoreService = ref.watch(firestoreServiceProvider);
    return PurchaseNotifier(ref, firestoreService);
  },
);
