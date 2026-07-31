import 'package:flutter_test/flutter_test.dart';
import 'package:nexus_app_v2/features/subscription/application/subscription_provider.dart';
import 'package:nexus_app_v2/features/subscription/domain/subscription_models.dart';

void main() {
  group('shouldSendSubscriptionActivatedNotification', () {
    test('returns false for free or inactive subscriptions', () {
      expect(
        shouldSendSubscriptionActivatedNotification(
          isActive: false,
          tier: SubscriptionTier.free,
          existingActive: false,
          existingTierId: null,
        ),
        isFalse,
      );
    });

    test('returns true when a user transitions to an active premium tier', () {
      expect(
        shouldSendSubscriptionActivatedNotification(
          isActive: true,
          tier: SubscriptionTier.monthly,
          existingActive: false,
          existingTierId: null,
        ),
        isTrue,
      );
    });

    test('returns false when the same premium tier is already active', () {
      expect(
        shouldSendSubscriptionActivatedNotification(
          isActive: true,
          tier: SubscriptionTier.monthly,
          existingActive: true,
          existingTierId: SubscriptionTier.monthly.id,
        ),
        isFalse,
      );
    });

    test('returns true when the tier changes from one premium plan to another', () {
      expect(
        shouldSendSubscriptionActivatedNotification(
          isActive: true,
          tier: SubscriptionTier.monthly,
          existingActive: true,
          existingTierId: 'legacy_plan',
        ),
        isTrue,
      );
    });
  });
}
