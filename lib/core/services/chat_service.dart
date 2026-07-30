import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import 'package:nexus_app_v2/core/storage/chat_media_upload_queue.dart';

/// Chat message model
class ChatMessage {
  final String id;
  final String chatId;
  final String senderId;
  final String receiverId;
  final String content;
  final MessageType type;
  final DateTime sentAt;
  final DateTime? readAt;
  final bool isRead;
  final Map<String, dynamic>? metadata;
  final bool isDeclined;
  final DateTime? declinedAt;
  final String? declineReason;

  const ChatMessage({
    required this.id,
    required this.chatId,
    required this.senderId,
    required this.receiverId,
    required this.content,
    this.type = MessageType.text,
    required this.sentAt,
    this.readAt,
    this.isRead = false,
    this.metadata,
    this.isDeclined = false,
    this.declinedAt,
    this.declineReason,
  });

  factory ChatMessage.fromFirestore(Map<String, dynamic> data, String id) {
    return ChatMessage(
      id: id,
      chatId: data['chatId'] as String? ?? '',
      senderId: data['senderId'] as String? ?? '',
      receiverId: data['receiverId'] as String? ?? '',
      content: data['content'] as String? ?? '',
      type: MessageType.fromString(data['type'] as String?),
      sentAt: (data['sentAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      readAt: (data['readAt'] as Timestamp?)?.toDate(),
      isRead: data['isRead'] as bool? ?? false,
      metadata: data['metadata'] as Map<String, dynamic>?,
      isDeclined: data['isDeclined'] as bool? ?? false,
      declinedAt: (data['declinedAt'] as Timestamp?)?.toDate(),
      declineReason: data['declineReason'] as String?,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'chatId': chatId,
      'senderId': senderId,
      'receiverId': receiverId,
      'content': content,
      'type': type.name,
      'sentAt': FieldValue.serverTimestamp(),
      'readAt': readAt != null ? Timestamp.fromDate(readAt!) : null,
      'isRead': isRead,
      'metadata': metadata,
      'isDeclined': isDeclined,
      'declinedAt': declinedAt != null ? Timestamp.fromDate(declinedAt!) : null,
      'declineReason': declineReason,
    };
  }

  ChatMessage copyWith({
    String? id,
    String? chatId,
    String? senderId,
    String? receiverId,
    String? content,
    MessageType? type,
    DateTime? sentAt,
    DateTime? readAt,
    bool? isRead,
    Map<String, dynamic>? metadata,
    bool? isDeclined,
    DateTime? declinedAt,
    String? declineReason,
  }) {
    return ChatMessage(
      id: id ?? this.id,
      chatId: chatId ?? this.chatId,
      senderId: senderId ?? this.senderId,
      receiverId: receiverId ?? this.receiverId,
      content: content ?? this.content,
      type: type ?? this.type,
      sentAt: sentAt ?? this.sentAt,
      readAt: readAt ?? this.readAt,
      isRead: isRead ?? this.isRead,
      metadata: metadata ?? this.metadata,
      isDeclined: isDeclined ?? this.isDeclined,
      declinedAt: declinedAt ?? this.declinedAt,
      declineReason: declineReason ?? this.declineReason,
    );
  }
}

enum MessageType {
  text,
  image,
  audio,
  video,
  file,
  system;

  static MessageType fromString(String? value) {
    return MessageType.values.firstWhere(
      (e) => e.name == value,
      orElse: () => MessageType.text,
    );
  }
}

/// Chat conversation model (metadata for a chat between two users)
class ChatConversation {
  final String id;
  final List<String> participantIds;
  final String? lastMessage;
  final DateTime? lastMessageAt;
  final String? lastMessageSenderId;
  final Map<String, int> unreadCounts;
  final Map<String, DateTime?> lastReadAt;
  final DateTime createdAt;
  final DateTime? updatedAt;
  final bool isActive;

  const ChatConversation({
    required this.id,
    required this.participantIds,
    this.lastMessage,
    this.lastMessageAt,
    this.lastMessageSenderId,
    this.unreadCounts = const {},
    this.lastReadAt = const {},
    required this.createdAt,
    this.updatedAt,
    this.isActive = true,
  });

  factory ChatConversation.fromFirestore(Map<String, dynamic> data, String id) {
    // Participants can appear in multiple shapes across versions:
    // - participantIds: List<String> (v2 canonical)
    // - participants: List<String> (legacy)
    // - participants: Map<uid, true> (legacy)
    // - memberIds/members: List<String> (legacy)
    // As a last resort, infer from deterministic chatId "<uidA>_<uidB>".
    final p = <String>{};

    void addStr(dynamic v) {
      if (v is String) {
        final t = v.trim();
        if (t.isNotEmpty) p.add(t);
      } else if (v != null) {
        final t = v.toString().trim();
        if (t.isNotEmpty) p.add(t);
      }
    }

    void addList(dynamic v) {
      if (v is List) {
        for (final e in v) {
          addStr(e);
        }
      }
    }

    void addMapKeys(dynamic v) {
      if (v is Map) {
        for (final k in v.keys) {
          addStr(k);
        }
      }
    }

    // Canonical
    addList(data['participantIds']);
    // Legacy
    addList(data['participants']);
    addMapKeys(data['participants']);
    addList(data['memberIds']);
    addList(data['members']);
    addMapKeys(data['members']);

    // Fallback: infer from chatId if it looks like "<a>_<b>"
    if (p.isEmpty && id.contains('_')) {
      final parts = id.split('_');
      if (parts.length == 2) {
        addStr(parts[0]);
        addStr(parts[1]);
      }
    }

    final participantIds = p.toList();

    // unreadCounts can be Map<dynamic,dynamic> in practice
    final rawUnread = data['unreadCounts'];
    final unreadCounts =
        (rawUnread is Map)
            ? Map<String, int>.fromEntries(
              rawUnread.entries.map((e) {
                final k = e.key?.toString() ?? '';
                final v = e.value;
                final n =
                    (v is num)
                        ? v.toInt()
                        : int.tryParse(v?.toString() ?? '') ?? 0;
                return MapEntry(k, n);
              }),
            )
            : <String, int>{};

    // lastReadAt can be Map<dynamic,dynamic> with Timestamp values
    final rawRead = data['lastReadAt'];
    final lastReadAt =
        (rawRead is Map)
            ? Map<String, DateTime?>.fromEntries(
              rawRead.entries.map((e) {
                final k = e.key?.toString() ?? '';
                final v = e.value;
                if (v is Timestamp) return MapEntry(k, v.toDate());
                return MapEntry(k, null);
              }),
            )
            : <String, DateTime?>{};

    return ChatConversation(
      id: id,
      participantIds: participantIds,
      lastMessage: data['lastMessage'] as String?,
      lastMessageAt: (data['lastMessageAt'] as Timestamp?)?.toDate(),
      lastMessageSenderId: data['lastMessageSenderId'] as String?,
      unreadCounts: unreadCounts,
      lastReadAt: lastReadAt,
      createdAt: (data['createdAt'] as Timestamp?)?.toDate() ?? DateTime.now(),
      updatedAt: (data['updatedAt'] as Timestamp?)?.toDate(),
      isActive: data['isActive'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toFirestore() {
    return {
      'participantIds': participantIds,
      'lastMessage': lastMessage,
      'lastMessageAt':
          lastMessageAt != null ? Timestamp.fromDate(lastMessageAt!) : null,
      'lastMessageSenderId': lastMessageSenderId,
      'unreadCounts': unreadCounts,
      'lastReadAt': lastReadAt.map(
        (key, value) =>
            MapEntry(key, value != null ? Timestamp.fromDate(value) : null),
      ),
      'createdAt': Timestamp.fromDate(createdAt),
      'updatedAt': FieldValue.serverTimestamp(),
      'isActive': isActive,
    };
  }

  /// Get the other participant's ID
  String getOtherParticipantId(String currentUserId) {
    final me = currentUserId.trim();
    if (me.isEmpty) return '';

    for (final id in participantIds) {
      final t = id.trim();
      if (t.isNotEmpty && t != me) return t;
    }
    return '';
  }

  /// Get unread count for a user
  int getUnreadCount(String userId) {
    return unreadCounts[userId] ?? 0;
  }
}

/// Service for managing chat functionality
class ChatService {
  static const int _kFreeChatPartnerLimit = 3;

  String _chatIdFor(String u1, String u2) {
    final a = u1.trim();
    final b = u2.trim();
    final ids = [a, b]..sort();
    return '${ids[0]}_${ids[1]}';
  }

  /// True if there's evidence sender has previously sent a message in this chat.
  /// This is used to avoid blocking *existing* partners after gating logic changes.
  Future<bool> _hasPreviouslyMessagedPartner({
    required String senderId,
    required String receiverId,
  }) async {
    try {
      final chatId = _chatIdFor(senderId, receiverId);
      final q =
          await _messagesRef(
            chatId,
          ).where('senderId', isEqualTo: senderId).limit(1).get();
      return q.docs.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  // ============================================================================
  // PREMIUM CHECK
  // ============================================================================
  // ============================================================================
  // FREE-TIER GATING (SEND-TIME ONLY)
  //
  // Rule:
  // - Free users can OPEN chats with anyone (createConversation allowed).
  // - Free users can SEND messages to UP TO ONE partner.
  // - Lock happens on FIRST message send to a new partner.
  //
  // Storage:
  // - users/{uid}.chat.freeChatPartnerIds : List<String> (preferred)
  // - users/{uid}.chat.freeChatPartnerId  : String (legacy fallback for backward-compat)
  // ============================================================================

  /// Read-only pre-check: can this user send a message to this receiver?
  /// Returns normally if allowed, throws [ChatException] if blocked.
  /// Does NOT record the partner or modify any data — safe to call
  /// before opening the image picker or starting audio recording.
  Future<void> checkCanSendToReceiver({
    required String senderId,
    required String receiverId,
  }) async {
    if (senderId.trim().isEmpty || receiverId.trim().isEmpty) return;

    final meRef = _fs.collection('users').doc(senderId);
    final snap = await meRef.get();
    final meData = snap.data();

    // --- Premium check (mirrors _enforceFreeTierOnSend) ---
    final subscriptionData = meData?['subscription'] as Map<String, dynamic>?;
    if (subscriptionData != null) {
      final isActive = subscriptionData['isActive'] as bool? ?? false;
      if (isActive) {
        final expiryDate = subscriptionData['expiryDate'];
        if (expiryDate != null) {
          if (expiryDate is Timestamp &&
              expiryDate.toDate().isAfter(DateTime.now()))
            return;
          if (expiryDate is DateTime && expiryDate.isAfter(DateTime.now())) {
            return;
          }
        } else {
          return; // No expiry — indefinite premium
        }
      }
    } else {
      final onPremium = meData?['onPremium'] as bool? ?? false;
      if (onPremium) {
        final expDate = meData?['subExpDate'] as Timestamp?;
        if (expDate != null && expDate.toDate().isAfter(DateTime.now())) {
          return;
        }
      }
    }

    // --- Free-tier partner check (read-only, no writes) ---
    final chatMap = (meData?['chat'] is Map) ? (meData!['chat'] as Map) : null;

    List<String> freeList = <String>[];
    final rawList = chatMap?['freeChatPartnerIds'];
    if (rawList is List) {
      freeList =
          rawList
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
    }

    if (freeList.isEmpty) {
      final legacy1 = chatMap?['freeChatPartnerId']?.toString().trim();
      if (legacy1 != null && legacy1.isNotEmpty) {
        freeList = [legacy1];
      } else {
        final legacy2 = meData?['freeChatPartnerId']?.toString().trim();
        if (legacy2 != null && legacy2.isNotEmpty) {
          freeList = [legacy2];
        }
      }
    }

    freeList = freeList.toSet().toList()..removeWhere((e) => e.trim().isEmpty);

    // Already-allowed partner — OK
    if (freeList.contains(receiverId)) return;

    // At limit — only allow if there's message history
    if (freeList.length >= _kFreeChatPartnerLimit) {
      final okBecauseHistory = await _hasPreviouslyMessagedPartner(
        senderId: senderId,
        receiverId: receiverId,
      );
      if (okBecauseHistory) return;

      throw ChatException(
        'You can only chat with $_kFreeChatPartnerLimit people for free. '
        'Subscribe to chat with more users.',
      );
    }

    // Under limit — user can still send (partner will be recorded on actual send)
  }

  Future<void> _enforceFreeTierOnSend({
    required String senderId,
    required String receiverId,
  }) async {
    // Enforce free-tier chat partner limit ONLY when sending a message.
    // ⚠️ OPTIMIZED: Single Firestore read (was 2 reads: isPremiumUser + meRef.get)
    // Storage:
    // - users/{uid}.chat.freeChatPartnerIds : List<String> (preferred)
    // - users/{uid}.chat.freeChatPartnerId  : String (legacy fallback)
    //
    // Behavior for free users:
    // - If receiverId is already in the allowed list => allow
    // - Else if list has room (< limit) => add receiverId and allow
    // - Else => throw a friendly ChatException, *unless* sender has previously
    //   messaged this receiver (back-compat for older chats).

    if (senderId.trim().isEmpty || receiverId.trim().isEmpty) {
      // Be safe: if ids are missing, don't enforce here; the send will fail elsewhere anyway.
      return;
    }

    final meRef = _fs.collection('users').doc(senderId);

    // ⚠️ SINGLE READ: Get user doc once (was doing this + isPremiumUser check separately)
    final snap = await meRef.get();
    final meData = snap.data();

    // Check premium status inline (was calling _isPremiumUser which did another read)
    // ⚠️ CRITICAL: If new subscription structure exists, use ONLY that, never check legacy
    final subscriptionData = meData?['subscription'] as Map<String, dynamic>?;
    if (subscriptionData != null) {
      // New subscription structure exists - validate it (don't check legacy)
      final isActive = subscriptionData['isActive'] as bool? ?? false;
      if (isActive) {
        // Subscription is active - check expiration date
        final expiryDate = subscriptionData['expiryDate'];
        if (expiryDate != null) {
          if (expiryDate is Timestamp) {
            if (expiryDate.toDate().isAfter(DateTime.now())) {
              return; // Premium subscription valid
            }
            // Expired - treat as free tier (don't check legacy)
          } else if (expiryDate is DateTime) {
            if (expiryDate.isAfter(DateTime.now())) {
              return; // Premium subscription valid
            }
            // Expired - treat as free tier (don't check legacy)
          }
        } else {
          return; // No expiry - indefinite premium
        }
      }
      // If we reach here, subscription exists but user is NOT premium
      // (either isActive=false or subscription expired)
      // Do NOT check legacy - user has opted into new subscription system
    } else {
      // No new subscription structure - check legacy premium logic only
      final onPremium = meData?['onPremium'] as bool? ?? false;
      if (onPremium) {
        final expDate = meData?['subExpDate'] as Timestamp?;
        if (expDate != null && expDate.toDate().isAfter(DateTime.now())) {
          return; // Premium legacy
        }
      }
    }

    // User is free tier, continue with enforcement checks

    final chatMap = (meData?['chat'] is Map) ? (meData!['chat'] as Map) : null;

    // Preferred list field
    List<String> freeList = <String>[];
    final rawList = chatMap?['freeChatPartnerIds'];
    if (rawList is List) {
      freeList =
          rawList
              .map((e) => e.toString().trim())
              .where((e) => e.isNotEmpty)
              .toList();
    }

    // Backward-compat: if list empty, try legacy single id
    if (freeList.isEmpty) {
      final legacy1 = chatMap?['freeChatPartnerId']?.toString().trim();
      if (legacy1 != null && legacy1.isNotEmpty) {
        freeList = [legacy1];
      } else {
        final legacy2 = meData?['freeChatPartnerId']?.toString().trim();
        if (legacy2 != null && legacy2.isNotEmpty) {
          freeList = [legacy2];
        }
      }
    }

    // Normalize: unique + no empties
    freeList = freeList.toSet().toList()..removeWhere((e) => e.trim().isEmpty);

    // If already allowed, good.
    if (freeList.contains(receiverId)) return;

    // If at limit, allow *existing partner* if sender previously messaged them.
    if (freeList.length >= _kFreeChatPartnerLimit) {
      final okBecauseHistory = await _hasPreviouslyMessagedPartner(
        senderId: senderId,
        receiverId: receiverId,
      );
      if (okBecauseHistory) return;

      throw ChatException(
        'You can only chat with $_kFreeChatPartnerLimit people for free. Subscribe to chat with more users.',
      );
    }

    // Otherwise, transactionally add receiverId to the free-tier partner list.
    // Transaction re-checks the limit to catch any concurrent writes, then atomically
    // adds receiverId to ensure consistency.
    await _fs.runTransaction((tx) async {
      final cur = await tx.get(meRef);
      final curData = cur.data();

      final curChatMap =
          (curData?['chat'] is Map) ? (curData!['chat'] as Map) : null;

      List<String> curList = <String>[];
      final curRaw = curChatMap?['freeChatPartnerIds'];
      if (curRaw is List) {
        curList =
            curRaw
                .map((e) => e.toString().trim())
                .where((e) => e.isNotEmpty)
                .toList();
      }

      if (curList.isEmpty) {
        final legacy1 = curChatMap?['freeChatPartnerId']?.toString().trim();
        if (legacy1 != null && legacy1.isNotEmpty) {
          curList = [legacy1];
        } else {
          final legacy2 = curData?['freeChatPartnerId']?.toString().trim();
          if (legacy2 != null && legacy2.isNotEmpty) {
            curList = [legacy2];
          }
        }
      }

      curList = curList.toSet().toList()..removeWhere((e) => e.trim().isEmpty);

      if (curList.contains(receiverId)) return;

      if (curList.length >= _kFreeChatPartnerLimit) {
        // Another concurrent write may have filled the list.
        // Same logic as pre-transaction: check history before denying.
        final okBecauseHistory = await _hasPreviouslyMessagedPartner(
          senderId: senderId,
          receiverId: receiverId,
        );
        if (!okBecauseHistory) {
          throw ChatException(
            'You can only chat with $_kFreeChatPartnerLimit people for free. Subscribe to chat with more users.',
          );
        }
        // User has history, allow the message
        return;
      }

      curList.add(receiverId);
      curList = curList.toSet().toList()..removeWhere((e) => e.trim().isEmpty);

      tx.set(meRef, {
        'chat': <String, dynamic>{'freeChatPartnerIds': curList},
      }, SetOptions(merge: true));
    });
  }

  FirebaseFirestore? _firestore;

  FirebaseFirestore get _fs =>
      _firestore ?? (throw StateError('Firestore not ready'));
  ChatService({FirebaseFirestore? firestore}) : _firestore = firestore;

  // Collection references
  CollectionReference<Map<String, dynamic>> get _chatsRef =>
      _fs.collection('nexus2_chats');

  CollectionReference<Map<String, dynamic>> _messagesRef(String chatId) =>
      _chatsRef.doc(chatId).collection('messages');

  // ============================================================================
  // ACCOUNT DISABLED GUARDS
  // ============================================================================
  Future<bool> _isUserDisabled(String uid) async {
    final doc = await _fs.collection('users').doc(uid).get();
    final data = doc.data();
    if (data == null) return false;

    // v2 canonical disable flag — matches currentUserDisabledProvider field name
    final account = (data['account'] is Map) ? (data['account'] as Map) : null;
    if (account != null) {
      if (account['disabled'] == true) return true;
      if (account['isDisabled'] == true)
        return true; // legacy field name fallback
      final acctStatus = account['status']?.toString().toLowerCase();
      if (acctStatus == 'disabled') return true;
    }

    // Legacy fallbacks (safe for older docs)
    final accountStatus = data['accountStatus']?.toString().toLowerCase();
    if (accountStatus == 'disabled') return true;

    final status = data['status']?.toString().toLowerCase();
    if (status == 'disabled') return true;

    final disabled = data['disabled'];
    if (disabled == true) return true;

    return false;
  }

  Future<void> _assertUsersNotDisabled(List<String> uids) async {
    for (final uid in uids) {
      if (await _isUserDisabled(uid)) {
        throw ChatException('Account disabled by admin');
      }
    }
  }

  // ============================================================================

  // ============================================================================
  // GENDER GUARDS
  // ============================================================================
  String? _normalizeGender(dynamic value) {
    final s = value?.toString().trim().toLowerCase();
    if (s == null || s.isEmpty) return null;

    // Accept v1/v2 variants by normalization.
    if (s == 'male') return 'male';
    if (s == 'female') return 'female';

    return null;
  }

  Future<void> _assertOppositeGender(String userId1, String userId2) async {
    final d1 = await _fs.collection('users').doc(userId1).get();
    final d2 = await _fs.collection('users').doc(userId2).get();

    final m1 = d1.data();
    final m2 = d2.data();

    // Priority: nexus2.gender > dating.profile.gender > dating.gender > root gender.
    // nexus2.gender is the canonical v2 source of truth; root/dating may be stale
    // from v1 migrations.
    String? _extractGender(Map<String, dynamic>? m) {
      if (m == null) return null;

      final nexus2 =
          (m['nexus2'] is Map)
              ? (m['nexus2'] as Map).cast<String, dynamic>()
              : null;
      final n2G = _normalizeGender(nexus2?['gender']);
      if (n2G != null) return n2G;

      final dating =
          (m['dating'] is Map)
              ? (m['dating'] as Map).cast<String, dynamic>()
              : null;
      final datingProfile =
          (dating?['profile'] is Map)
              ? (dating!['profile'] as Map).cast<String, dynamic>()
              : null;
      final dpG = _normalizeGender(
        datingProfile?['gender'] ?? dating?['gender'],
      );
      if (dpG != null) return dpG;

      return _normalizeGender(m['gender']);
    }

    final g1 = _extractGender(m1);
    final g2 = _extractGender(m2);

    // Auto-normalize: write the resolved gender back to all fields so
    // stale v1 data doesn't cause future mismatches. Fire-and-forget.
    Future<void> _normalizeUserGender(String uid, String resolvedGender) async {
      try {
        await _fs.collection('users').doc(uid).set(<String, dynamic>{
          'gender': resolvedGender,
          'nexus2': <String, dynamic>{'gender': resolvedGender},
          'dating': <String, dynamic>{
            'gender': resolvedGender,
            'profile': <String, dynamic>{'gender': resolvedGender},
          },
        }, SetOptions(merge: true));
      } catch (_) {
        // Best-effort normalization; don't block the chat flow.
      }
    }

    // Normalize both users in parallel (fire-and-forget, non-blocking for UX).
    final futures = <Future<void>>[];
    if (g1 != null) futures.add(_normalizeUserGender(userId1, g1));
    if (g2 != null) futures.add(_normalizeUserGender(userId2, g2));
    unawaited(Future.wait(futures));

    final isOpposite =
        (g1 == 'male' && g2 == 'female') || (g1 == 'female' && g2 == 'male');

    // Strict product rule: only male<->female chats are allowed.
    // Unknown/missing genders are rejected.
    if (!isOpposite) {
      throw ChatException(
        'You can only start chats with users of the opposite gender.',
      );
    }
  }

  // CONVERSATION MANAGEMENT
  // ============================================================================

  /// Create a new chat conversation between two users
  /// Returns the chat ID

  /// Create or open a chat conversation between two users.
  ///
  /// Deterministic chatId: "<smallerUid>_<largerUid>".
  /// Premium rule (v2): free users can chat with only ONE partner.
  /// We enforce this WITHOUT querying nexus2_chats (queries can be denied by rules).
  Future<String> createConversation(String userId1, String userId2) async {
    final a = userId1.trim();
    final b = userId2.trim();
    if (a.isEmpty || b.isEmpty) {
      throw ChatException('Invalid user id(s).');
    }
    if (a == b) {
      throw ChatException('You cannot start a chat with yourself.');
    }

    final ids = <String>[a, b]..sort();
    final chatId = '${ids[0]}_${ids[1]}';

    final chatRef = _chatsRef.doc(chatId);
    final chatDoc = <String, dynamic>{
      'participantIds': ids,
      'createdAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
      'lastMessageAt': FieldValue.serverTimestamp(),
      'lastMessagePreview': '',
      'unreadCounts': <String, dynamic>{ids[0]: 0, ids[1]: 0},
      'isActive': true,
    };

    try {
      await _assertUsersNotDisabled([a, b]);

      await _assertOppositeGender(a, b);

      return await _fs.runTransaction((tx) async {
        final existing = await tx.get(chatRef);
        if (existing.exists) return chatId;

        // Premium gating is enforced ONLY on send, not on opening/creating chats.

        tx.set(chatRef, chatDoc);
        return chatId;
      });
    } catch (e) {
      rethrow;
    }
  }

  /// Get conversation between two users
  Future<ChatConversation?> getConversationBetween(
    String userId1,
    String userId2,
  ) async {
    try {
      final sortedIds = [userId1, userId2]..sort();

      final query =
          await _chatsRef
              .where('participantIds', isEqualTo: sortedIds)
              .limit(1)
              .get();

      if (query.docs.isEmpty) return null;

      return ChatConversation.fromFirestore(
        query.docs.first.data(),
        query.docs.first.id,
      );
    } catch (e) {
      return null;
    }
  }

  /// Get conversation by ID
  Future<ChatConversation?> getConversation(String chatId) async {
    try {
      final doc = await _chatsRef.doc(chatId).get();
      if (!doc.exists || doc.data() == null) return null;
      return ChatConversation.fromFirestore(doc.data()!, doc.id);
    } catch (e) {
      return null;
    }
  }

  /// Get all conversations for a user
  Future<List<ChatConversation>> getUserConversations(String userId) async {
    try {
      // NOTE: Do NOT filter by `isActive` in Firestore.
      // Older chat docs may not have the field, and Firestore would exclude them.
      // NOTE: No orderBy here — avoids needing a composite index. Sort client-side.
      final query =
          await _chatsRef.where('participantIds', arrayContains: userId).get();

      final all =
          query.docs
              .map((doc) => ChatConversation.fromFirestore(doc.data(), doc.id))
              .toList();

      // Client-side filter and sort.
      return all.where((c) => c.isActive).toList()..sort(
        (a, b) => (b.lastMessageAt ?? DateTime(0)).compareTo(
          a.lastMessageAt ?? DateTime(0),
        ),
      );
    } catch (e) {
      throw ChatException('Failed to get conversations: $e');
    }
  }

  /// Stream all conversations for a user (real-time)
  Stream<List<ChatConversation>> streamUserConversations(String userId) {
    // NOTE: Do NOT filter by `isActive` in Firestore.
    // Older chat docs may not have the field, and Firestore would exclude them.
    // NOTE: No orderBy here — avoids needing a composite index. Sort client-side.
    return _chatsRef
        .where('participantIds', arrayContains: userId)
        .snapshots()
        .map((snapshot) {
          final all =
              snapshot.docs
                  .map(
                    (doc) => ChatConversation.fromFirestore(doc.data(), doc.id),
                  )
                  .toList();

          // Client-side filter and sort: newest first.
          return all.where((c) => c.isActive).toList()..sort(
            (a, b) => (b.lastMessageAt ?? DateTime(0)).compareTo(
              a.lastMessageAt ?? DateTime(0),
            ),
          );
        });
  }

  /// Delete/deactivate a conversation
  Future<void> deleteConversation(String chatId) async {
    try {
      // Clean up any pending media uploads for this chat
      await ChatMediaUploadQueueDb.deleteByChat(chatId);

      await _chatsRef.doc(chatId).update({
        'isActive': false,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw ChatException('Failed to delete conversation: $e');
    }
  }

  // ============================================================================
  // MESSAGE OPERATIONS
  // ============================================================================

  /// Record a free-tier chat partner ONLY after a message is successfully sent.
  /// This guarantees: opening chats / failed sends do not consume free slots.
  /// Send a text message
  Future<ChatMessage> sendMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String content,
    MessageType type = MessageType.text,
    Map<String, dynamic>? metadata,
  }) async {
    // Free-tier gating happens ONLY on send.
    await _enforceFreeTierOnSend(senderId: senderId, receiverId: receiverId);

    try {
      await _assertUsersNotDisabled([senderId, receiverId]);

      final messageRef = _messagesRef(chatId).doc();

      final message = ChatMessage(
        id: messageRef.id,
        chatId: chatId,
        senderId: senderId,
        receiverId: receiverId,
        content: content,
        type: type,
        sentAt: DateTime.now(),
        metadata: metadata,
      );

      // Use batch for atomic operation
      final batch = _fs.batch();

      // Add message
      batch.set(messageRef, message.toFirestore());

      // Update conversation metadata
      batch.update(_chatsRef.doc(chatId), {
        'lastMessage':
            type == MessageType.text ? content : _getMessageTypePreview(type),
        'lastMessageAt': FieldValue.serverTimestamp(),
        'lastMessageSenderId': senderId,
        'unreadCounts.$receiverId': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      });

      await batch.commit();
      // Note: Free-tier partner was already recorded in _enforceFreeTierOnSend transaction,
      // so no need for additional recording here. The transaction atomically reserves the slot
      // before the message is written.
      return message;
    } catch (e) {
      // Preserve user-facing gating/errors.
      if (e is ChatException) rethrow;
      // Otherwise keep a generic error.
      throw ChatException('Message failed to send. Please try again.');
    }

    // DEAD_CODE_REMOVED: throw ChatException('Message failed to send. Please try again.');
  }

  String _getMessageTypePreview(MessageType type) {
    switch (type) {
      case MessageType.image:
        return '📷 Photo';
      case MessageType.audio:
        return '🎵 Voice message';
      case MessageType.video:
        return '🎥 Video';
      case MessageType.file:
        return '📎 File';
      case MessageType.system:
        return 'System message';
      default:
        return '';
    }
  }

  /// Send a quick text message (convenience method)
  Future<ChatMessage> sendTextMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String text,
  }) async {
    return sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      content: text,
      type: MessageType.text,
    );
  }

  /// Send an image message
  Future<ChatMessage> sendImageMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String imageUrl,
    String? caption,
  }) async {
    return sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      content: imageUrl,
      type: MessageType.image,
      metadata: {
        if (caption != null) 'caption': caption,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Send an audio message
  Future<ChatMessage> sendAudioMessage({
    required String chatId,
    required String senderId,
    required String receiverId,
    required String audioUrl,
    required int durationSeconds,
  }) async {
    return sendMessage(
      chatId: chatId,
      senderId: senderId,
      receiverId: receiverId,
      content: audioUrl,
      type: MessageType.audio,
      metadata: {
        'duration': durationSeconds,
        'uploadedAt': DateTime.now().toIso8601String(),
      },
    );
  }

  /// Update message content (used when media upload completes in background)
  /// This allows sending messages immediately and uploading media asynchronously
  Future<void> updateMessageContent(
    String chatId,
    String messageId,
    String newContent,
  ) async {
    try {
      await _messagesRef(chatId).doc(messageId).update({
        'content': newContent,
        'updatedAt': FieldValue.serverTimestamp(),
      });
      debugPrint('[ChatService] Message $messageId updated with new content');
    } catch (e) {
      debugPrint('[ChatService] Failed to update message content: $e');
      // Non-critical: message already sent with original content
      // User can see local preview, cloud URL update is a background enhancement
    }
  }

  /// Get messages for a chat
  Future<List<ChatMessage>> getMessages(
    String chatId, {
    int limit = 50,
    DocumentSnapshot? startAfter,
  }) async {
    try {
      Query<Map<String, dynamic>> query = _messagesRef(
        chatId,
      ).orderBy('sentAt', descending: true).limit(limit);

      if (startAfter != null) {
        query = query.startAfterDocument(startAfter);
      }

      final snapshot = await query.get();

      return snapshot.docs
          .map((doc) => ChatMessage.fromFirestore(doc.data(), doc.id))
          .toList();
    } catch (e) {
      throw ChatException('Failed to get messages: $e');
    }
  }

  /// Stream messages for a chat (real-time)
  Stream<List<ChatMessage>> streamMessages(String chatId, {int limit = 50}) {
    return _messagesRef(chatId)
        .orderBy('sentAt', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) =>
              snapshot.docs
                  .map((doc) => ChatMessage.fromFirestore(doc.data(), doc.id))
                  .toList(),
        );
  }

  /// Delete a message
  Future<void> deleteMessage(String chatId, String messageId) async {
    try {
      await _messagesRef(chatId).doc(messageId).delete();
    } catch (e) {
      throw ChatException('Failed to delete message: $e');
    }
  }

  // ============================================================================
  // READ STATUS
  // ============================================================================

  /// Mark messages as read
  Future<void> markMessagesAsRead(String chatId, String userId) async {
    try {
      // Update unread count in conversation
      await _chatsRef.doc(chatId).update({
        'unreadCounts.$userId': 0,
        'lastReadAt.$userId': FieldValue.serverTimestamp(),
      });

      // Optionally mark individual messages as read
      final unreadMessages =
          await _messagesRef(chatId)
              .where('receiverId', isEqualTo: userId)
              .where('isRead', isEqualTo: false)
              .get();

      if (unreadMessages.docs.isEmpty) return;

      final batch = _fs.batch();
      for (final doc in unreadMessages.docs) {
        batch.update(doc.reference, {
          'isRead': true,
          'readAt': FieldValue.serverTimestamp(),
        });
      }
      await batch.commit();
    } catch (e) {}
  }

  /// Get total unread count for a user across all chats
  Future<int> getTotalUnreadCount(String userId) async {
    try {
      final chats = await getUserConversations(userId);
      int total = 0;
      for (final chat in chats) {
        total += chat.getUnreadCount(userId);
      }
      return total;
    } catch (e) {
      return 0;
    }
  }

  /// Stream total unread count
  Stream<int> streamTotalUnreadCount(String userId) {
    return streamUserConversations(userId).map((chats) {
      int total = 0;
      for (final chat in chats) {
        total += chat.getUnreadCount(userId);
      }
      return total;
    });
  }

  // ============================================================================
  // TYPING INDICATORS (Optional)
  // ============================================================================

  /// Set typing status
  Future<void> setTypingStatus(
    String chatId,
    String userId,
    bool isTyping,
  ) async {
    try {
      await _chatsRef.doc(chatId).update({'typingUsers.$userId': isTyping});
    } catch (e) {}
  }

  /// Stream typing users
  Stream<List<String>> streamTypingUsers(String chatId) {
    return _chatsRef.doc(chatId).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return <String>[];

      final typingUsers = data['typingUsers'] as Map<String, dynamic>? ?? {};
      return typingUsers.entries
          .where((e) => e.value == true)
          .map((e) => e.key)
          .toList();
    });
  }

  // ============================================================================
  // SEARCH & FILTERING
  // ============================================================================

  /// Search messages in a chat
  Future<List<ChatMessage>> searchMessages(
    String chatId,
    String query, {
    int limit = 20,
  }) async {
    try {
      // Note: Firestore doesn't support full-text search
      // This is a basic implementation - for production, use Algolia or similar
      final messages = await getMessages(chatId, limit: 200);

      final queryLower = query.toLowerCase();
      return messages
          .where((m) => m.content.toLowerCase().contains(queryLower))
          .take(limit)
          .toList();
    } catch (e) {
      return [];
    }
  }

  // ============================================================================
  // MESSAGE READ STATUS
  // ============================================================================

  /// Mark a message as read by updating readAt timestamp
  /// Called when message is viewed in chat thread
  Future<void> markMessageAsRead(String chatId, String messageId) async {
    try {
      await _messagesRef(chatId).doc(messageId).update({
        'isRead': true,
        'readAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[ChatService] Error marking message as read: $e');
      // Don't throw - read status is non-critical
    }
  }

  // ============================================================================
  // LAST ACTIVE STATUS
  // ============================================================================

  /// Update user's last active timestamp (called when app comes to foreground)
  Future<void> updateUserLastActive(String userId) async {
    if (userId.trim().isEmpty) return;

    try {
      await _fs.collection('users').doc(userId).update({
        'lastActiveAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      print('[ChatService] Error updating last active: $e');
      // Don't throw - this is non-critical
    }
  }

  /// Get user's last active timestamp
  Future<DateTime?> getUserLastActive(String userId) async {
    if (userId.trim().isEmpty) return null;

    try {
      final doc = await _fs.collection('users').doc(userId).get();
      final data = doc.data();
      if (data?['lastActiveAt'] is Timestamp) {
        return (data!['lastActiveAt'] as Timestamp).toDate();
      }
      return null;
    } catch (e) {
      print('[ChatService] Error fetching last active: $e');
      return null;
    }
  }

  /// Format last active for display
  static String formatLastActive(DateTime? lastActive) {
    if (lastActive == null) return 'Offline';

    final now = DateTime.now();
    final diff = now.difference(lastActive);

    if (diff.inMinutes < 1) return 'Active now';
    if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
    if (diff.inHours < 24) return '${diff.inHours}h ago';
    if (diff.inDays < 7) return '${diff.inDays}d ago';
    if (diff.inDays < 30) {
      final weeks = (diff.inDays / 7).floor();
      return '${weeks}w ago';
    }

    return 'Long time ago';
  }

  /// Exception for chat operations
}

class ChatException implements Exception {
  final String message;
  ChatException(this.message);

  @override
  String toString() => message;
}
