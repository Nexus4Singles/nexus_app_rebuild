import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/firestore_instance_provider.dart';
import '../models/chat_models.dart';
import 'auth_provider.dart';

/// ---------------------------------------------------------------------------
/// Providers
/// ---------------------------------------------------------------------------

/// Stream of user conversations
final chatsProvider = StreamProvider<List<ChatConversation>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();

  final firestore = ref.watch(firestoreInstanceProvider);
  if (firestore == null) return const Stream.empty();

  return ChatService(firestore).streamUserConversations(userId);
});

/// Messages for a given chat
final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((
  ref,
  chatId,
) {
  final firestore = ref.watch(firestoreInstanceProvider);
  if (firestore == null) return const Stream.empty();

  return ChatService(firestore).streamMessages(chatId);
});

/// Total unread messages count
final unreadMessageCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return const Stream.empty();

  final firestore = ref.watch(firestoreInstanceProvider);
  if (firestore == null) return const Stream.empty();

  return ChatService(firestore).streamTotalUnreadCount(userId);
});

/// Get or create a conversation with another user
final getOrCreateChatProvider = FutureProvider.family<String?, String>((
  ref,
  otherUserId,
) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) return null;

  final firestore = ref.watch(firestoreInstanceProvider);
  if (firestore == null) return null;

  return ChatService(
    firestore,
  ).getOrCreateConversation(currentUserId, otherUserId);
});

/// ---------------------------------------------------------------------------
/// ChatService (Firestore-backed, nullable-safe)
/// ---------------------------------------------------------------------------

class ChatService {
  final FirebaseFirestore _firestore;

  ChatService(this._firestore);

  /// Stream all conversations for a user
  Stream<List<ChatConversation>> streamUserConversations(String userId) {
    return _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .orderBy('lastMessageAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ChatConversation.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  /// Stream messages for a chat (default limit = 50)
  Stream<List<ChatMessage>> streamMessages(String chatId, {int limit = 50}) {
    return _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs.map((doc) {
            return ChatMessage.fromFirestore(doc.data(), doc.id);
          }).toList();
        });
  }

  /// Stream unread count across all chats for a user
  Stream<int> streamTotalUnreadCount(String userId) {
    return _firestore
        .collectionGroup('messages')
        .where('receiverId', isEqualTo: userId)
        .where('isRead', isEqualTo: false)
        .snapshots()
        .map((snapshot) => snapshot.size);
  }

  /// Create or fetch existing conversation between two users
  Future<String> getOrCreateConversation(
    String currentUserId,
    String otherUserId,
  ) async {
    final participants = [currentUserId, otherUserId]..sort();

    final existing =
        await _firestore
            .collection('chats')
            .where('participantKey', isEqualTo: participants.join('_'))
            .limit(1)
            .get();

    if (existing.docs.isNotEmpty) {
      return existing.docs.first.id;
    }

    final doc = await _firestore.collection('chats').add({
      'participants': participants,
      'participantKey': participants.join('_'),
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
    });

    return doc.id;
  }
}
