import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';

import '../providers/auth_provider.dart';
import '../providers/user_provider.dart';

// ============================================================================
// SUBSCRIPTION SERVICE
// ============================================================================

/// Premium feature constants (prices managed by RevenueCat/Store configs)

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

      // Check new subscription structure first
      final subscriptionData = data['subscription'] as Map<String, dynamic>?;
      if (subscriptionData != null) {
        final isActive = subscriptionData['isActive'] as bool? ?? false;
        if (!isActive) return false;

        // Check expiration date
        final expiryDate = subscriptionData['expiryDate'];
        if (expiryDate != null) {
          if (expiryDate is Timestamp) {
            return expiryDate.toDate().isAfter(DateTime.now());
          } else if (expiryDate is DateTime) {
            return expiryDate.isAfter(DateTime.now());
          }
        }
        return isActive;
      }

      // Fallback: Check legacy onPremium flag with expiration
      final onPremium = data['onPremium'] as bool? ?? false;
      if (!onPremium) return false;

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

/// Provider for checking if current user is premium in real-time
///
/// ✅ NOW: StreamProvider - watches user premium status in real-time
/// ✅ BEFORE: FutureProvider - checked once, cached stale status
final isPremiumProvider = StreamProvider<bool>((ref) async* {
  // Watch current user provider which streams real-time updates from Firestore
  final currentUserAsync = ref.watch(currentUserProvider);

  await for (final userOrNull
      in currentUserAsync.valueOrNull != null
          ? Stream.value(currentUserAsync.valueOrNull).asBroadcastStream()
          : Stream.empty()) {
    if (userOrNull == null) {
      yield false;
      continue;
    }

    // Use subscription service to check if premium
    final subscriptionService = ref.watch(subscriptionServiceProvider);
    try {
      final isPremium = await subscriptionService.isPremium(userOrNull.uid);
      print(
        '[isPremiumProvider] ✓ Real-time update: isPremium=$isPremium for uid=${userOrNull.uid}',
      );
      yield isPremium;
    } catch (e) {
      print('[isPremiumProvider] Error checking premium: $e');
      // Fallback to quick check
      final isPremium =
          userOrNull.onPremium == true &&
          (userOrNull.subExpDate?.isAfter(DateTime.now()) ?? false);
      yield isPremium;
    }
  }
});

/// Provider for message permission with a specific user
final messagePermissionProvider =
    FutureProvider.family<MessagePermission, String>((ref, recipientId) async {
      final userId = ref.watch(currentUserIdProvider);
      if (userId == null) return MessagePermission.requiresPremium;

      final subscriptionService = ref.watch(subscriptionServiceProvider);
      return subscriptionService.canSendMessage(userId, recipientId);
    });

/// Provider for subscription expiration date in real-time
///
/// ✅ NOW: StreamProvider - watches expiration date in real-time
/// ✅ BEFORE: FutureProvider - checked once, could show stale date
final subscriptionExpirationProvider = StreamProvider<DateTime?>((ref) async* {
  // Watch current user provider which streams real-time updates from Firestore
  final currentUserAsync = ref.watch(currentUserProvider);

  await for (final userOrNull
      in currentUserAsync.valueOrNull != null
          ? Stream.value(currentUserAsync.valueOrNull).asBroadcastStream()
          : Stream.empty()) {
    if (userOrNull == null) {
      yield null;
      continue;
    }

    // Use subscription service to get expiration date
    final subscriptionService = ref.watch(subscriptionServiceProvider);
    try {
      final expDate = await subscriptionService.getExpirationDate(
        userOrNull.uid,
      );
      print(
        '[subscriptionExpirationProvider] ✓ Real-time update: expDate=$expDate for uid=${userOrNull.uid}',
      );
      yield expDate;
    } catch (e) {
      print('[subscriptionExpirationProvider] Error getting expiration: $e');
      // Fallback to user's cached expiration date
      yield userOrNull.subExpDate;
    }
  }
});

/// Quick check provider using cached user data
final isPremiumQuickProvider = Provider<bool>((ref) {
  final user = ref.watch(currentUserProvider).valueOrNull;
  if (user == null) return false;

  if (user.onPremium != true) return false;
  if (user.subExpDate == null) return false;

  return user.subExpDate!.isAfter(DateTime.now());
});
