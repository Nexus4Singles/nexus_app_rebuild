import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

// ============================================================================
// SUBSCRIPTION SERVICE
// ============================================================================

/// Subscription plans available in Nexus
enum SubscriptionPlan {
  free('free', 'Free', 0),
  monthly('monthly', 'Monthly Premium', 2999), // NGN
  quarterly('quarterly', 'Quarterly Premium', 6999),
  yearly('yearly', 'Yearly Premium', 19999);

  final String id;
  final String displayName;
  final int priceNGN;

  const SubscriptionPlan(this.id, this.displayName, this.priceNGN);
}

/// Premium features available with subscription
class PremiumFeatures {
  /// Unlimited messaging (free users get 1 free conversation)
  static const unlimitedMessaging = 'unlimited_messaging';

  /// See who liked you
  static const seeWhoLikedYou = 'see_who_liked_you';

  /// Advanced filters
  static const advancedFilters = 'advanced_filters';

  /// Profile boost (appear first in search)
  static const profileBoost = 'profile_boost';

  /// Read receipts
  static const readReceipts = 'read_receipts';

  /// Undo swipe/unlike
  static const undoActions = 'undo_actions';

  /// Super likes
  static const superLikes = 'super_likes';

  /// Incognito mode
  static const incognitoMode = 'incognito_mode';
}

/// Service for managing subscriptions and premium features
class SubscriptionService {
  FirebaseFirestore? _firestore;

  FirebaseFirestore? get _fsOrNull => _firestore;

  /// Check if user has premium subscription
  Future<bool> isPremium(String userId) async {
    try {
      final fs = _fsOrNull;
      if (fs == null) return false;
      final doc = await fs.collection('users').doc(userId).get();
      final data = doc.data();
      if (data == null) return false;

      final onPremium = data['onPremium'] as bool? ?? false;
      if (!onPremium) return false;

      // Check expiration
      final expDate = data['subExpDate'] as Timestamp?;
      if (expDate == null) return false;

      return expDate.toDate().isAfter(DateTime.now());
    } catch (e) {
      return false;
    }
  }

  /// Check if user has used their free message
  Future<bool> hasUsedFreeMessage(String userId) async {
    try {
      final fs = _fsOrNull;
      if (fs == null) return false;
      final doc = await fs.collection('users').doc(userId).get();
      final data = doc.data();
      return data?['usedOneFreeText'] as bool? ?? false;
    } catch (e) {
      return false;
    }
  }

  /// Mark free message as used
  Future<void> markFreeMessageUsed(String userId) async {
    try {
      final fs = _fsOrNull;
      if (fs == null) return;
      await fs.collection('users').doc(userId).update({
        'usedOneFreeText': true,
      });
    } catch (e) {
      throw Exception('Failed to mark free message used: $e');
    }
  }

  /// Get number of unique conversations user has initiated
  Future<int> getConversationCount(String userId) async {
    try {
      final fs = _fsOrNull;
      if (fs == null) return 0;
      final snapshot =
          await fs
              .collection('chats')
              .where('participantIds', arrayContains: userId)
              .get();
      return snapshot.docs.length;
    } catch (e) {
      return 0;
    }
  }

  /// Check if user can send message (premium or has free message)
  Future<MessagePermission> canSendMessage(
    String userId,
    String recipientId,
  ) async {
    // Check if premium
    final premium = await isPremium(userId);
    if (premium) {
      return MessagePermission.allowed;
    }

    // Check if this is an existing conversation
    final existingChat = await _getExistingChat(userId, recipientId);
    if (existingChat != null) {
      // Already have a conversation - check if user initiated it
      final chatData = existingChat.data() as Map<String, dynamic>;
      final firstSenderId = chatData['firstSenderId'] as String?;

      if (firstSenderId == userId) {
        // User started this conversation - they've used their free message
        return MessagePermission.requiresPremium;
      } else {
        // Recipient started the conversation - user can reply freely
        return MessagePermission.allowed;
      }
    }

    // New conversation - check if user has used free message
    final usedFree = await hasUsedFreeMessage(userId);
    if (!usedFree) {
      return MessagePermission.allowedFreeMessage;
    }

    return MessagePermission.requiresPremium;
  }

  Future<DocumentSnapshot?> _getExistingChat(
    String userId1,
    String userId2,
  ) async {
    final fs = _fsOrNull;
    if (fs == null) return null;
    // Chat IDs are created with sorted participant IDs
    final sortedIds = [userId1, userId2]..sort();
    final chatId = '${sortedIds[0]}_${sortedIds[1]}';

    final doc = await fs.collection('chats').doc(chatId).get();
    return doc.exists ? doc : null;
  }

  /// Activate premium subscription
  Future<void> activatePremium({
    required String userId,
    required SubscriptionPlan plan,
    required String subscriberId, // RevenueCat subscriber ID
  }) async {
    final fs = _fsOrNull;
    if (fs == null) return;
    try {
      DateTime expirationDate;
      switch (plan) {
        case SubscriptionPlan.monthly:
          expirationDate = DateTime.now().add(const Duration(days: 30));
          break;
        case SubscriptionPlan.quarterly:
          expirationDate = DateTime.now().add(const Duration(days: 90));
          break;
        case SubscriptionPlan.yearly:
          expirationDate = DateTime.now().add(const Duration(days: 365));
          break;
        default:
          throw Exception('Invalid plan');
      }

      await fs.collection('users').doc(userId).update({
        'onPremium': true,
        'subExpDate': Timestamp.fromDate(expirationDate),
        'subscriberId': subscriberId,
        'prevSubscribed': true,
      });
    } catch (e) {
      throw Exception('Failed to activate premium: $e');
    }
  }

  /// Deactivate premium subscription
  Future<void> deactivatePremium(String userId) async {
    final fs = _fsOrNull;
    if (fs == null) return;
    try {
      await fs.collection('users').doc(userId).update({'onPremium': false});
    } catch (e) {
      throw Exception('Failed to deactivate premium: $e');
    }
  }

  /// Get subscription expiration date
  Future<DateTime?> getExpirationDate(String userId) async {
    final fs = _fsOrNull;
    if (fs == null) return null;
    try {
      final doc = await fs.collection('users').doc(userId).get();
      final data = doc.data();
      final expDate = data?['subExpDate'] as Timestamp?;
      return expDate?.toDate();
    } catch (e) {
      return null;
    }
  }
}

/// Permission result for sending messages
enum MessagePermission {
  /// User can send message
  allowed,

  /// User can send their one free message
  allowedFreeMessage,

  /// User needs premium to send message
  requiresPremium,
}

// ============================================================================
// PROVIDERS
// ============================================================================

/// Provider for subscription service
final subscriptionServiceProvider = Provider<SubscriptionService>((ref) {
  return SubscriptionService();
});

/// Provider for checking if current user is premium
final isPremiumProvider = FutureProvider<bool>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return false;

  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return subscriptionService.isPremium(userId);
});

/// Provider for message permission with a specific user
final messagePermissionProvider =
    FutureProvider.family<MessagePermission, String>((ref, recipientId) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return MessagePermission.requiresPremium;

      final subscriptionService = ref.watch(subscriptionServiceProvider);
      return subscriptionService.canSendMessage(userId, recipientId);
    });

/// Provider for subscription expiration date
final subscriptionExpirationProvider = FutureProvider<DateTime?>((ref) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return null;

  final subscriptionService = ref.watch(subscriptionServiceProvider);
  return subscriptionService.getExpirationDate(userId);
});

/// Quick check provider using cached user data
final isPremiumQuickProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;

  if (user.onPremium != true) return false;
  if (user.subExpDate == null) return false;

  return user.subExpDate!.isAfter(DateTime.now());
});
