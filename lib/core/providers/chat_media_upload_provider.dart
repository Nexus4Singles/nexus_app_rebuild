import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:nexus_app_v2/core/storage/chat_media_upload_service.dart';
import 'package:nexus_app_v2/core/services/media_service.dart';
import 'package:nexus_app_v2/core/services/chat_service.dart';
import 'package:nexus_app_v2/core/providers/service_providers.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Riverpod provider for ChatMediaUploadService.
/// Handles background uploads of media files with crash recovery.
final chatMediaUploadServiceProvider = Provider((ref) {
  final mediaService = ref.watch(mediaServiceProvider);
  return ChatMediaUploadServiceImpl(mediaService: mediaService);
});

/// Implementation of ChatQueueDatabaseService using Firestore
class ChatMediaUploadServiceImpl extends ChatMediaUploadService {
  ChatMediaUploadServiceImpl({required MediaService mediaService})
    : super(mediaService: mediaService, chatDb: _FirestoreChatDb());
}

class _FirestoreChatDb implements ChatQueueDatabaseService {
  final _db = FirebaseFirestore.instance;

  @override
  Future<void> updateMessageContent(
    String chatId,
    String messageId,
    String cloudUrl, {
    String? uploadStatus,
  }) async {
    final messagesRef = _db
        .collection('nexus2_chats')
        .doc(chatId)
        .collection('messages');

    await messagesRef.doc(messageId).update({
      'content': cloudUrl,
      'metadata.uploadStatus': uploadStatus ?? 'uploaded',
    });
    // Note: Let exceptions propagate so caller can handle retry/failure
  }

  @override
  Future<void> updateMessageStatus(
    String chatId,
    String messageId,
    String status,
  ) async {
    final messagesRef = _db
        .collection('nexus2_chats')
        .doc(chatId)
        .collection('messages');

    await messagesRef.doc(messageId).update({'metadata.uploadStatus': status});
  }
}

/// Riverpod provider to resume pending uploads on app startup
final resumePendingUploadsProvider = FutureProvider((ref) async {
  final uploadService = ref.watch(chatMediaUploadServiceProvider);
  final currentUser = FirebaseAuth.instance.currentUser;

  if (currentUser != null) {
    await uploadService.resumePendingUploads(currentUser.uid);
  }

  return true;
});

/// Get pending upload count for UI (e.g., badge on chat button)
final pendingUploadCountProvider = FutureProvider.family<int, String>((
  ref,
  userId,
) async {
  final uploadService = ref.watch(chatMediaUploadServiceProvider);
  return uploadService.getPendingCount(userId);
});
