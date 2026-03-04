import 'dart:io';
import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:nexus_app_v2/core/storage/chat_media_upload_queue.dart';
import 'package:nexus_app_v2/core/services/media_service.dart';
import 'package:nexus_app_v2/core/services/chat_service.dart';

/// Media upload service with crash recovery and exponential backoff.
///
/// Handles:
/// - Uploading media files to cloud storage
/// - Retrying failed uploads with exponential backoff
/// - Persisting upload state across app crashes
/// - Updating Firestore with cloud URLs
/// - Never showing errors to users (silent failures)
class ChatMediaUploadService {
  final MediaService _mediaService;
  final ChatQueueDatabaseService _chatDb;

  // Backoff strategy: 2s, 4s, 8s, 16s, 32s (for up to 5 retries)
  static const Map<int, Duration> retryDelays = {
    0: Duration(seconds: 2), // 1st retry: 2s
    1: Duration(seconds: 4), // 2nd retry: 4s
    2: Duration(seconds: 8), // 3rd retry: 8s
    3: Duration(seconds: 16), // 4th retry: 16s
    4: Duration(seconds: 32), // 5th retry: 32s
  };

  ChatMediaUploadService({
    required MediaService mediaService,
    required ChatQueueDatabaseService chatDb,
  }) : _mediaService = mediaService,
       _chatDb = chatDb;

  /// Upload a media file to cloud storage with retry logic.
  ///
  /// Returns the cloud URL on success, or null on permanent failure.
  /// Failures are silent - never shown to users.
  Future<String?> uploadMedia({
    required String chatId,
    required String messageId,
    required String localFilePath,
    required String userId,
    required String mediaType,
  }) async {
    final uploadId = await ChatMediaUploadQueueDb.insert(
      ChatMediaUploadQueue(
        chatId: chatId,
        messageId: messageId,
        localFilePath: localFilePath,
        userId: userId,
        mediaType: mediaType,
      ),
    );

    return _uploadWithRetry(uploadId);
  }

  /// Internal: Upload with exponential backoff retry
  Future<String?> _uploadWithRetry(String uploadId) async {
    final upload = await ChatMediaUploadQueueDb.getById(uploadId);
    if (upload == null) {
      debugPrint('[ChatMediaUpload] ⚠️ Upload $uploadId not found');
      return null;
    }

    // Check if we've exceeded max retries
    if (upload.retryCount >= upload.maxRetries) {
      debugPrint(
        '[ChatMediaUpload] 🔴 Upload $uploadId: '
        'Max retries (${upload.maxRetries}) exceeded. Giving up.',
      );
      await ChatMediaUploadQueueDb.updateStatus(
        uploadId,
        'failed',
        lastError: 'Max retries exceeded',
      );

      // Also mark Firestore so the UI shows the failed state (not a spinner)
      try {
        await _chatDb.updateMessageStatus(
          upload.chatId,
          upload.messageId,
          'failed',
        );
      } catch (_) {}

      return null;
    }

    // Update to "uploading" status
    await ChatMediaUploadQueueDb.updateStatus(uploadId, 'uploading');

    try {
      // Validate file exists
      final file = File(upload.localFilePath);
      if (!await file.exists()) {
        debugPrint(
          '[ChatMediaUpload] ⚠️ Upload $uploadId: '
          'Local file no longer exists: ${upload.localFilePath}',
        );
        await ChatMediaUploadQueueDb.updateStatus(
          uploadId,
          'failed',
          retryCount: upload.maxRetries, // Permanent — no point retrying
          lastError: 'Local file deleted',
        );

        // Mark Firestore so UI shows failed state instead of spinner
        try {
          await _chatDb.updateMessageStatus(
            upload.chatId,
            upload.messageId,
            'failed',
          );
        } catch (_) {}

        return null;
      }

      debugPrint(
        '[ChatMediaUpload] ⬆️ Uploading ${upload.mediaType}: '
        '${upload.localFilePath} (attempt ${upload.retryCount + 1}/${upload.maxRetries})',
      );

      // Attempt upload
      final cloudUrl =
          upload.mediaType == 'image'
              ? await _mediaService.uploadChatImage(
                userId: upload.userId,
                chatId: upload.chatId,
                imageFile: file,
              )
              : await _mediaService.uploadChatAudio(
                userId: upload.userId,
                chatId: upload.chatId,
                filePath: upload.localFilePath,
              );

      if (cloudUrl.isEmpty) {
        throw Exception('Upload returned empty URL');
      }

      // Success! File uploaded to cloud. Now update message in Firestore.
      debugPrint('[ChatMediaUpload] ✅ File upload successful: $cloudUrl');

      // Try to update Firestore with cloud URL (with retries)
      try {
        await _updateMessageWithCloudUrl(
          upload.chatId,
          upload.messageId,
          cloudUrl,
        );

        // Firestore update succeeded - mark as uploaded and clean up
        await ChatMediaUploadQueueDb.updateStatus(uploadId, 'uploaded');
        await ChatMediaUploadQueueDb.delete(uploadId);

        return cloudUrl;
      } catch (e) {
        // Firestore update failed - keep in queue for retry
        debugPrint(
          '[ChatMediaUpload] 🔴 Failed to update message in Firestore: $e. '
          'Upload will be re-attempted on app restart.',
        );

        await ChatMediaUploadQueueDb.updateStatus(
          uploadId,
          'failed',
          lastError: 'Firestore update failed: $e',
        );
        // Don't delete from queue - will retry on app restart

        return null; // Mark as failure despite file being uploaded
      }
    } on SocketException catch (e) {
      return _handleUploadFailure(
        uploadId,
        upload,
        'Network error: $e',
        isRetryable: true,
      );
    } on TimeoutException catch (e) {
      return _handleUploadFailure(
        uploadId,
        upload,
        'Timeout: $e',
        isRetryable: true,
      );
    } catch (e) {
      // Check if this is a retryable error
      final isRetryable = _isRetryableError(e);
      return _handleUploadFailure(
        uploadId,
        upload,
        e.toString(),
        isRetryable: isRetryable,
      );
    }
  }

  /// Handle upload failure with retry scheduling
  Future<String?> _handleUploadFailure(
    String uploadId,
    ChatMediaUploadQueue upload,
    String errorMessage, {
    required bool isRetryable,
  }) async {
    if (!isRetryable || upload.retryCount >= upload.maxRetries) {
      debugPrint(
        '[ChatMediaUpload] 🔴 Upload $uploadId: '
        'Giving up after ${upload.retryCount} attempts. Error: $errorMessage',
      );

      await ChatMediaUploadQueueDb.updateStatus(
        uploadId,
        'failed',
        retryCount:
            upload.maxRetries, // Mark as exhausted so auto-resume skips it
        lastError: errorMessage,
      );

      // Try to update message uploadStatus in Firestore to show upload failed.
      // Keep original content (local file path) so sender still sees preview.
      try {
        await _chatDb.updateMessageStatus(
          upload.chatId,
          upload.messageId,
          'failed',
        );
      } catch (e) {
        debugPrint(
          '[ChatMediaUpload] ⚠️ Could not update message status in Firestore: $e. '
          'Message will remain with local path.',
        );
        // Don't fail completely if this fails - upload already marked as failed in SQLite
      }

      return null;
    }

    // Mark as failed for retry on app resume (don't schedule delayed retry)
    final nextRetry = upload.retryCount + 1;

    debugPrint(
      '[ChatMediaUpload] ⚠️ Upload $uploadId: Retry #$nextRetry will occur on app resume. '
      'Error: $errorMessage',
    );

    // Mark as failed so it gets picked up by resumePendingUploads on app resume
    // Primary retry mechanism is lifecycle-based (app resume/restart), not time-based
    await ChatMediaUploadQueueDb.updateStatus(
      uploadId,
      'failed',
      retryCount: nextRetry,
      lastError: errorMessage,
    );

    // If this was the last retry, also update Firestore so the UI shows
    // 'failed' instead of a spinner. Without this, getPendingUploads would
    // never return this row again (retryCount >= maxRetries) and Firestore
    // would stay stuck at 'pending' forever.
    if (nextRetry >= upload.maxRetries) {
      try {
        await _chatDb.updateMessageStatus(
          upload.chatId,
          upload.messageId,
          'failed',
        );
      } catch (_) {}
    }

    return null;
  }

  /// Determine if an error is retryable
  bool _isRetryableError(Object error) {
    final msg = error.toString().toLowerCase();

    // Retryable: network/server issues
    if (msg.contains('socket') ||
        msg.contains('timeout') ||
        msg.contains('connection') ||
        msg.contains('refused') ||
        msg.contains('500') ||
        msg.contains('503') ||
        msg.contains('network')) {
      return true;
    }

    // Not retryable: file issues, auth issues, client errors
    if (msg.contains('file') ||
        msg.contains('permission') ||
        msg.contains('unauthorized') ||
        msg.contains('403') ||
        msg.contains('404')) {
      return false;
    }

    // Default to retryable for unknown errors
    return true;
  }

  /// Resume pending uploads (called on app startup)
  Future<void> resumePendingUploads(String userId) async {
    debugPrint('[ChatMediaUpload] 🔄 Resuming pending uploads for $userId');

    final pending = await ChatMediaUploadQueueDb.getPendingUploads(userId);
    debugPrint(
      '[ChatMediaUpload] Found ${pending.length} pending uploads to resume',
    );

    for (final upload in pending) {
      // Don't spam retries - add small delays between each
      await Future.delayed(const Duration(milliseconds: 500));
      unawaited(_uploadWithRetry(upload.id!));
    }
  }

  /// Get pending upload count for UI badge
  Future<int> getPendingCount(String userId) async {
    return ChatMediaUploadQueueDb.getPendingCount(userId);
  }

  /// Re-attempt a failed upload from the SQLite queue.
  /// Called from the UI when the user taps "retry" on a failed message.
  Future<void> retryUpload(String messageId) async {
    final upload = await ChatMediaUploadQueueDb.getByMessageId(messageId);
    if (upload == null || upload.id == null) {
      debugPrint(
        '[ChatMediaUpload] ⚠️ retryUpload: No queue entry for $messageId',
      );
      return;
    }

    // Reset retry count and status so it gets a fresh set of attempts
    await ChatMediaUploadQueueDb.updateStatus(
      upload.id!,
      'pending',
      retryCount: 0,
      lastError: '',
    );

    // Also reset Firestore uploadStatus back to pending so UI shows spinner
    try {
      await _chatDb.updateMessageStatus(
        upload.chatId,
        upload.messageId,
        'pending',
      );
    } catch (_) {}

    unawaited(_uploadWithRetry(upload.id!));
  }

  /// Listen to upload progress (for future UI indicators if needed)
  Stream<({String messageId, double progress})> uploadProgressStream =
      const Stream.empty();

  // ============================================================================
  // PRIVATE HELPERS
  // ============================================================================

  /// Update Firestore message with cloud URL (with retry)
  /// Throws exception if all retries fail
  Future<void> _updateMessageWithCloudUrl(
    String chatId,
    String messageId,
    String cloudUrl,
  ) async {
    // Retry up to 3 times with exponential backoff
    for (int attempt = 1; attempt <= 3; attempt++) {
      try {
        await _chatDb.updateMessageContent(chatId, messageId, cloudUrl);
        debugPrint(
          '[ChatMediaUpload] ✅ Updated message with cloud URL: $cloudUrl',
        );
        return; // Success
      } catch (e) {
        if (attempt < 3) {
          final delay = Duration(seconds: 1 << attempt); // 2s, 4s
          debugPrint(
            '[ChatMediaUpload] ⚠️ Failed to update message (attempt $attempt/3), '
            'retrying in ${delay.inSeconds}s: $e',
          );
          await Future.delayed(delay);
        } else {
          // All retries failed - rethrow so caller can handle
          debugPrint(
            '[ChatMediaUpload] 🔴 Failed to update message after 3 attempts: $messageId. '
            'Error: $e',
          );
          rethrow; // Let exception propagate to caller
        }
      }
    }
  }
}

/// Database service wrapper for chat operations
abstract class ChatQueueDatabaseService {
  Future<void> updateMessageContent(
    String chatId,
    String messageId,
    String cloudUrl, {
    String? uploadStatus,
  });

  /// Update only the uploadStatus metadata field (no content change).
  Future<void> updateMessageStatus(
    String chatId,
    String messageId,
    String status,
  );
}
