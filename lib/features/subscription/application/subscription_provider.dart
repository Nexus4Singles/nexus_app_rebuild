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
final subscriptionStatusProvider = StreamProvider<SubscriptionStatus>((ref) {
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

bool shouldSendSubscriptionActivatedNotification({
  required bool isActive,
  required SubscriptionTier tier,
  required bool existingActive,
  required String? existingTierId,
}) {
  return isActive &&
      tier != SubscriptionTier.free &&
      (!existingActive || existingTierId != tier.id);
}

class SubscriptionNotifier extends StateNotifier<AsyncValue<void>> {
  final String userId;

  SubscriptionNotifier(this.userId) : super(const AsyncValue.data(null));

  /// Update subscription status (called by RevenueCat webhook or purchase flow)
  Future<void> updateSubscription({
    required bool isActive,
    required SubscriptionTier tier,
    DateTime? expiryDate,
    bool autoRenew = true,
    String? revenueCatCustomerId,
    String? revenueCatSubscriptionId,
  }) async {
    state = const AsyncValue.loading();

    try {
      final existingDoc =
          await FirebaseFirestore.instance
              .collection('users')
              .doc(userId)
              .get();
      final existingData = existingDoc.data();
      final existingSubscription =
          existingData?['subscription'] as Map<String, dynamic>?;
      final existingActive =
          existingSubscription?['isActive'] as bool? ?? false;
      final existingTier = existingSubscription?['tier'] as String?;

      final subscription = SubscriptionStatus(
        isActive: isActive,
        tier: tier,
        startDate: isActive ? DateTime.now() : null,
        expiryDate: expiryDate,
        autoRenew: autoRenew,
        revenueCatCustomerId: revenueCatCustomerId,
        revenueCatSubscriptionId: revenueCatSubscriptionId,
      );

      await FirebaseFirestore.instance.collection('users').doc(userId).set({
        'subscription': subscription.toFirestore(),
        'onPremium': isActive, // Legacy flag for backward compatibility
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      // Send notification only when the user transitions to an active premium state.
      final shouldNotify = shouldSendSubscriptionActivatedNotification(
        isActive: isActive,
        tier: tier,
        existingActive: existingActive,
        existingTierId: existingTier,
      );
      if (shouldNotify) {
        await NotificationHelpers.sendSubscriptionActivatedNotification(
          userId: userId,
          tier: tier.name,
        );
      }

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// Cancel subscription (disable auto-renewal)
  Future<void> cancelAutoRenewal() async {
    state = const AsyncValue.loading();

    try {
      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'subscription.autoRenew': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }

  /// ⚠️ DEPRECATED: Do not use! Purchases are now recorded optimistically in UI.
  ///
  /// This method is no longer used. Purchase recording has been moved to:
  /// - [JourneyPurchaseScreen._recordPurchaseOptimistically] for journeys
  /// - [SubscriptionScreen._recordSubscriptionOptimistically] for subscriptions
  ///
  /// These methods record purchases immediately to Firestore, then verify asynchronously
  /// with the backend. This pattern is used by world-class apps (Spotify, Netflix, etc.)
  /// to provide instant UX without blocking on server validation.
  @deprecated
  Future<void> recordJourneyPurchase({
    required String journeyId,
    required String journeyTitle,
    required double pricePaid,
    String currency = 'NGN',
    String? revenueCatTransactionId,
  }) async {
    throw UnsupportedError(
      'recordJourneyPurchase is deprecated. '
      'Purchase recording now happens in JourneyPurchaseScreen._recordPurchaseOptimistically.',
    );
  }
}

final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<void>>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) throw Exception('User not authenticated');
      return SubscriptionNotifier(userId);
    });
