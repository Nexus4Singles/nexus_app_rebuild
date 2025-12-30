import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_provider.dart';
import 'user_provider.dart';

// ============================================================================
// CHAT MODELS
// ============================================================================

/// Represents a chat conversation
class ChatConversation {
  final String id;
  final String otherUserId;
  final String otherUserName;
  final String? otherUserPhoto;
  final String? lastMessage;
  final DateTime? lastMessageTime;
  final int unreadCount;
  final bool isOnline;

  const ChatConversation({
    required this.id,
    required this.otherUserId,
    required this.otherUserName,
    this.otherUserPhoto,
    this.lastMessage,
    this.lastMessageTime,
    this.unreadCount = 0,
    this.isOnline = false,
  });

  factory ChatConversation.fromFirestore(
    DocumentSnapshot doc, 
    String currentUserId,
    Map<String, dynamic>? otherUserData,
  ) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    final participants = List<String>.from(data['participants'] ?? []);
    final otherUserId = participants.firstWhere(
      (id) => id != currentUserId,
      orElse: () => '',
    );

    return ChatConversation(
      id: doc.id,
      otherUserId: otherUserId,
      otherUserName: otherUserData?['username'] as String? ?? 
                     otherUserData?['fullName'] as String? ?? 
                     'User',
      otherUserPhoto: otherUserData?['photos'] != null && 
                      (otherUserData!['photos'] as List).isNotEmpty
          ? (otherUserData['photos'] as List).first as String?
          : null,
      lastMessage: data['lastMessage'] as String?,
      lastMessageTime: data['lastMessageTime'] != null
          ? (data['lastMessageTime'] as Timestamp).toDate()
          : null,
      unreadCount: (data['unreadCount_$currentUserId'] as int?) ?? 0,
      isOnline: otherUserData?['isOnline'] as bool? ?? false,
    );
  }

  /// Format time for display
  String get formattedTime {
    if (lastMessageTime == null) return '';
    
    final now = DateTime.now();
    final diff = now.difference(lastMessageTime!);
    
    if (diff.inMinutes < 1) return 'now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m';
    if (diff.inHours < 24) return '${diff.inHours}h';
    if (diff.inDays < 7) return '${diff.inDays}d';
    
    return '${lastMessageTime!.day}/${lastMessageTime!.month}';
  }
}

/// Represents a single message
class ChatMessage {
  final String id;
  final String senderId;
  final String text;
  final DateTime sentAt;
  final bool isRead;
  final String? imageUrl;

  const ChatMessage({
    required this.id,
    required this.senderId,
    required this.text,
    required this.sentAt,
    this.isRead = false,
    this.imageUrl,
  });

  factory ChatMessage.fromFirestore(DocumentSnapshot doc) {
    final data = doc.data() as Map<String, dynamic>? ?? {};
    return ChatMessage(
      id: doc.id,
      senderId: data['senderId'] as String? ?? '',
      text: data['text'] as String? ?? '',
      sentAt: data['sentAt'] != null
          ? (data['sentAt'] as Timestamp).toDate()
          : DateTime.now(),
      isRead: data['isRead'] as bool? ?? false,
      imageUrl: data['imageUrl'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() => {
    'senderId': senderId,
    'text': text,
    'sentAt': Timestamp.fromDate(sentAt),
    'isRead': isRead,
    if (imageUrl != null) 'imageUrl': imageUrl,
  };
}

// ============================================================================
// CHAT PROVIDERS
// ============================================================================

/// Provider for all chat conversations
final chatsProvider = StreamProvider<List<ChatConversation>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value([]);

  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: userId)
      .orderBy('lastMessageTime', descending: true)
      .snapshots()
      .asyncMap((snapshot) async {
        final conversations = <ChatConversation>[];
        
        for (final doc in snapshot.docs) {
          final data = doc.data();
          final participants = List<String>.from(data['participants'] ?? []);
          final otherUserId = participants.firstWhere(
            (id) => id != userId,
            orElse: () => '',
          );
          
          if (otherUserId.isEmpty) continue;
          
          // Get other user's data
          try {
            final userDoc = await FirebaseFirestore.instance
                .collection('users')
                .doc(otherUserId)
                .get();
            
            conversations.add(ChatConversation.fromFirestore(
              doc, 
              userId, 
              userDoc.data(),
            ));
          } catch (e) {
            conversations.add(ChatConversation.fromFirestore(doc, userId, null));
          }
        }
        
        return conversations;
      });
});

/// Provider for messages in a specific chat
final chatMessagesProvider = StreamProvider.family<List<ChatMessage>, String>((ref, chatId) {
  return FirebaseFirestore.instance
      .collection('chats')
      .doc(chatId)
      .collection('messages')
      .orderBy('sentAt', descending: true)
      .limit(50)
      .snapshots()
      .map((snapshot) => snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc))
          .toList());
});

/// Provider for chat service (sending messages, etc.)
final chatServiceProvider = Provider<ChatService>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return ChatService(userId);
});

/// Provider to get or create a chat with a user
final getOrCreateChatProvider = FutureProvider.family<String, String>((ref, otherUserId) async {
  final currentUserId = ref.watch(currentUserIdProvider);
  if (currentUserId == null) throw Exception('Not authenticated');
  
  final chatService = ref.read(chatServiceProvider);
  return chatService.getOrCreateChat(otherUserId);
});

// ============================================================================
// CHAT SERVICE
// ============================================================================

class ChatService {
  final String? userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  ChatService(this.userId);

  /// Get or create a chat between current user and another user
  Future<String> getOrCreateChat(String otherUserId) async {
    if (userId == null) throw Exception('Not authenticated');
    
    // Check for existing chat
    final existingChats = await _firestore
        .collection('chats')
        .where('participants', arrayContains: userId)
        .get();
    
    for (final doc in existingChats.docs) {
      final participants = List<String>.from(doc.data()['participants'] ?? []);
      if (participants.contains(otherUserId)) {
        return doc.id;
      }
    }
    
    // Create new chat
    final chatRef = await _firestore.collection('chats').add({
      'participants': [userId, otherUserId],
      'createdAt': FieldValue.serverTimestamp(),
      'lastMessageTime': FieldValue.serverTimestamp(),
    });
    
    return chatRef.id;
  }

  /// Send a message
  Future<void> sendMessage({
    required String chatId,
    required String text,
    String? imageUrl,
  }) async {
    if (userId == null) throw Exception('Not authenticated');
    
    final message = ChatMessage(
      id: '',
      senderId: userId!,
      text: text,
      sentAt: DateTime.now(),
      imageUrl: imageUrl,
    );
    
    final batch = _firestore.batch();
    
    // Add message
    final messageRef = _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .doc();
    batch.set(messageRef, message.toFirestore());
    
    // Update chat metadata
    final chatRef = _firestore.collection('chats').doc(chatId);
    batch.update(chatRef, {
      'lastMessage': text,
      'lastMessageTime': FieldValue.serverTimestamp(),
      'lastSenderId': userId,
    });
    
    await batch.commit();
    
    // Create notification for other user
    final chatDoc = await chatRef.get();
    final participants = List<String>.from(chatDoc.data()?['participants'] ?? []);
    final otherUserId = participants.firstWhere((id) => id != userId, orElse: () => '');
    
    if (otherUserId.isNotEmpty) {
      await _createMessageNotification(otherUserId, chatId);
    }
  }

  /// Create a notification for the recipient
  Future<void> _createMessageNotification(String recipientId, String chatId) async {
    if (userId == null) return;
    
    try {
      // Get sender info
      final senderDoc = await _firestore.collection('users').doc(userId).get();
      final senderData = senderDoc.data();
      final senderName = senderData?['username'] as String? ?? 
                         senderData?['fullName'] as String? ?? 
                         'Someone';
      final senderPhoto = senderData?['photos'] != null && 
                          (senderData!['photos'] as List).isNotEmpty
          ? (senderData['photos'] as List).first as String?
          : null;
      
      await _firestore
          .collection('users')
          .doc(recipientId)
          .collection('notifications')
          .add({
        'type': 'message',
        'senderId': userId,
        'senderName': senderName,
        'senderPhoto': senderPhoto,
        'chatId': chatId,
        'read': false,
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('Error creating message notification: $e');
    }
  }

  /// Mark messages as read
  Future<void> markAsRead(String chatId) async {
    if (userId == null) return;
    
    // Mark all unread messages from other user as read
    final messages = await _firestore
        .collection('chats')
        .doc(chatId)
        .collection('messages')
        .where('isRead', isEqualTo: false)
        .get();
    
    final batch = _firestore.batch();
    for (final doc in messages.docs) {
      if (doc.data()['senderId'] != userId) {
        batch.update(doc.reference, {'isRead': true});
      }
    }
    
    // Reset unread count
    batch.update(
      _firestore.collection('chats').doc(chatId),
      {'unreadCount_$userId': 0},
    );
    
    await batch.commit();
  }
}

/// Provider for unread message count
final unreadMessageCountProvider = StreamProvider<int>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value(0);

  return FirebaseFirestore.instance
      .collection('chats')
      .where('participants', arrayContains: userId)
      .snapshots()
      .map((snapshot) {
        int total = 0;
        for (final doc in snapshot.docs) {
          final unread = doc.data()['unreadCount_$userId'] as int? ?? 0;
          total += unread;
        }
        return total;
      });
});
