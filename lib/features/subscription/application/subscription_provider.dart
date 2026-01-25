import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nexus_app_min_test/core/providers/auth_provider.dart';
import 'package:nexus_app_min_test/features/subscription/domain/subscription_models.dart';
import 'package:nexus_app_min_test/core/notifications/notification_service.dart';

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

        // Legacy: check onPremium flag
        final onPremium = data['onPremium'] as bool? ?? false;
        if (onPremium) {
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
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .collection('purchases')
      .where('type', isEqualTo: 'journey')
      .orderBy('purchaseDate', descending: true)
      .snapshots()
      .map((snapshot) {
        return snapshot.docs
            .map((doc) => PurchasedJourney.fromFirestore(doc.data()))
            .toList();
      });
});

/// Provider to check if a specific journey is purchased
final isJourneyPurchasedProvider = Provider.family<bool, String>((
  ref,
  journeyId,
) {
  final purchased = ref.watch(purchasedJourneysProvider);
  return purchased.maybeWhen(
    data:
        (journeys) =>
            journeys.any((j) => j.journeyId == journeyId && j.isActive),
    orElse: () => false,
  );
});

// ============================================================================
// SUBSCRIPTION NOTIFIER (for updates)
// ============================================================================

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
      final subscription = SubscriptionStatus(
        isActive: isActive,
        tier: tier,
        startDate: isActive ? DateTime.now() : null,
        expiryDate: expiryDate,
        autoRenew: autoRenew,
        revenueCatCustomerId: revenueCatCustomerId,
        revenueCatSubscriptionId: revenueCatSubscriptionId,
      );

      await FirebaseFirestore.instance.collection('users').doc(userId).update({
        'subscription': subscription.toFirestore(),
        'onPremium': isActive, // Legacy flag for backward compatibility
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Send notification for new subscription activation
      if (isActive && tier != SubscriptionTier.free) {
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

  /// Record journey purchase
  Future<void> recordJourneyPurchase({
    required String journeyId,
    required String journeyTitle,
    required double pricePaid,
    String currency = 'NGN',
    String? revenueCatTransactionId,
  }) async {
    state = const AsyncValue.loading();

    try {
      final purchase = PurchasedJourney(
        journeyId: journeyId,
        journeyTitle: journeyTitle,
        purchaseDate: DateTime.now(),
        pricePaid: pricePaid,
        currency: currency,
        revenueCatTransactionId: revenueCatTransactionId,
      );

      await FirebaseFirestore.instance
          .collection('users')
          .doc(userId)
          .collection('purchases')
          .doc(journeyId)
          .set({...purchase.toFirestore(), 'type': 'journey'});

      // Send journey purchased notification
      await NotificationHelpers.sendJourneyPurchasedNotification(
        userId: userId,
        journeyTitle: journeyTitle,
      );

      state = const AsyncValue.data(null);
    } catch (e, stack) {
      state = AsyncValue.error(e, stack);
      rethrow;
    }
  }
}

final subscriptionNotifierProvider =
    StateNotifierProvider<SubscriptionNotifier, AsyncValue<void>>((ref) {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) throw Exception('User not authenticated');
      return SubscriptionNotifier(userId);
    });
