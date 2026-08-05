import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import 'package:nexus_app_v2/features/subscription/domain/subscription_models.dart';
import 'package:nexus_app_v2/core/notifications/notification_service.dart';

// ============================================================================
// SUBSCRIPTION PROVIDERS
// ============================================================================

/// Provider for user's current subscription status
final localOptimisticSubscriptionProvider = StateProvider<SubscriptionStatus?>((ref) => null);

final subscriptionStatusProvider = StreamProvider<SubscriptionStatus>((ref) {
  // Short-lived in-memory optimistic override set by the UI after a
  // successful client-side purchase. This avoids attempting to write the
  // protected `subscription` field from the client (security rules deny it),
  // while still providing immediate UX feedback until the backend confirms
  // and writes the canonical subscription document.
  final optimistic = ref.watch(localOptimisticSubscriptionProvider);
  if (optimistic != null) {
    // If an optimistic override exists, return a combined stream that first
    // yields the optimistic value and then forwards the canonical Firestore
    // stream. This ensures the UI shows immediate premium access but still
    // reconciles with the backend update as soon as it arrives.
    if (optimistic.isActive && !optimistic.isExpired) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return Stream.value(SubscriptionStatus.free());

      Stream<SubscriptionStatus> combined() async* {
        yield optimistic;
        yield* FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .snapshots()
            .map((doc) {
              if (!doc.exists) return SubscriptionStatus.free();
              final data = doc.data();
              if (data == null) return SubscriptionStatus.free();
              final subscriptionData = data['subscription'] as Map<String, dynamic>?;
              if (subscriptionData != null) {
                final backendStatus = SubscriptionStatus.fromFirestore(subscriptionData);
                // If we had an optimistic override, clear it now that the
                // backend has written the canonical subscription state.
                final optimisticNow = ref.read(localOptimisticSubscriptionProvider);
                if (optimisticNow != null && backendStatus.isActive) {
                  ref.read(localOptimisticSubscriptionProvider.notifier).state = null;
                }
                return backendStatus;
              }
              final onPremium = data['onPremium'] as bool? ?? false;
              if (onPremium) {
                final subExpDate = data['subExpDate'] as Timestamp?;
                if (subExpDate == null || subExpDate.toDate().isBefore(DateTime.now())) {
                  return SubscriptionStatus.free();
                }
                return const SubscriptionStatus(isActive: true, tier: SubscriptionTier.monthly);
              }
              return SubscriptionStatus.free();
            });
            }

          return combined();
    }
  }

  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(SubscriptionStatus.free());

  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return SubscriptionStatus.free();

        final data = doc.data();
        if (data == null) return SubscriptionStatus.free();

        // Check both new structure and legacy
        final subscriptionData = data['subscription'] as Map<String, dynamic>?;
        if (subscriptionData != null) {
          return SubscriptionStatus.fromFirestore(subscriptionData);
        }

        // Legacy: check onPremium flag + expiry
        // Must have a valid, non-expired subExpDate to be premium.
        // This aligns with ChatService._isPremiumUser() and
        // SubscriptionService.isPremium() which both require subExpDate.
        final onPremium = data['onPremium'] as bool? ?? false;
        if (onPremium) {
          final subExpDate = data['subExpDate'] as Timestamp?;
          if (subExpDate == null ||
              subExpDate.toDate().isBefore(DateTime.now())) {
            return SubscriptionStatus.free();
          }
          return const SubscriptionStatus(
            isActive: true,
            tier: SubscriptionTier.monthly,
          );
        }

        return SubscriptionStatus.free();
      });
});

/// Provider to check if user has active premium subscription
final isPremiumUserProvider = Provider<bool>((ref) {
  final subscriptionStatus = ref.watch(subscriptionStatusProvider);
  return subscriptionStatus.maybeWhen(
    data: (status) => status.isActive && !status.isExpired,
    orElse: () => false,
  );
});

/// Provider for purchased journeys
final purchasedJourneysProvider = StreamProvider<List<PurchasedJourney>>((ref) {
  print('🔴 [purchasedJourneysProvider] PROVIDER FUNCTION CALLED');

  final userId = ref.watch(currentUserIdProvider);

  print('🔴 [purchasedJourneysProvider] ===== PROVIDER INIT =====');
  print('🔴 [purchasedJourneysProvider] userId: "$userId"');
  print('🔴 [purchasedJourneysProvider] userId is null: ${userId == null}');
  print('🔴 [purchasedJourneysProvider] userId type: ${userId.runtimeType}');

  if (userId == null) {
    print(
      '🔴 [purchasedJourneysProvider] ❌ userId IS NULL, returning empty list stream',
    );
    return Stream.value([]);
  }

  print('🔴 [purchasedJourneysProvider] ✅ userId is NOT null: "$userId"');
  print(
    '🔴 [purchasedJourneysProvider] Creating Firestore listener for /users/$userId/purchases',
  );

  // Read from purchases subcollection - stores journey purchase records
  final stream =
      FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('purchases')
          .snapshots();

  print(
    '🔴 [purchasedJourneysProvider] Stream created, waiting for first event...',
  );

  return stream
      .map((snapshot) {
        print(
          '🔴 [purchasedJourneysProvider] 📦 Snapshot received: ${snapshot.docs.length} documents',
        );
        final journeys =
            snapshot.docs
                .map((doc) {
                  try {
                    return PurchasedJourney.fromFirestore(doc.data());
                  } catch (e) {
                    print(
                      '🔴 [purchasedJourneysProvider] Error parsing journey ${doc.id}: $e',
                    );
                    return null;
                  }
                })
                .whereType<PurchasedJourney>()
                .toList();

        // Sort by purchaseDate descending on Dart side
        journeys.sort((a, b) => b.purchaseDate.compareTo(a.purchaseDate));

        print(
          '🔴 [purchasedJourneysProvider] ✅ Loaded ${journeys.length} purchased journeys',
        );
        return journeys;
      })
      .handleError((error, stackTrace) {
        print('🔴 [purchasedJourneysProvider] ❌ Stream error: $error');
        print('🔴 [purchasedJourneysProvider] Stack: $stackTrace');
        // If collection doesn't exist yet, return empty list instead of error
        if (error.toString().contains('permission-denied') ||
            error.toString().contains('not-found')) {
          return <PurchasedJourney>[];
        }
        // For other errors, still return empty list to avoid infinite loading
        return <PurchasedJourney>[];
      });
});

// NOTE: isJourneyPurchasedProvider is defined in
// lib/features/challenges/providers/journeys_providers.dart
// (FutureProvider.family<bool, String>) as the single source of truth.
// Do NOT re-define it here to avoid dual-provider ambiguity.

// ============================================================================
// SUBSCRIPTION NOTIFIER (for updates)
// ============================================================================
// Minimal SubscriptionNotifier to allow programmatic refreshes from UI/tests
class SubscriptionNotifier extends StateNotifier<AsyncValue<void>> {
  final String userId;
  SubscriptionNotifier(this.userId) : super(const AsyncValue.data(null));

  Future<void> refresh() async {
    state = const AsyncValue.loading();
    try {
      // Trigger a shallow read to warm caches; real work is driven by providers
      await FirebaseFirestore.instance.collection('users').doc(userId).get();
      state = const AsyncValue.data(null);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<void>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) throw Exception('User not authenticated');
  return SubscriptionNotifier(userId);
});
