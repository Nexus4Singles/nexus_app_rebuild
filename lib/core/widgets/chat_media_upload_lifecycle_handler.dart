import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexus_app_v2/core/providers/chat_media_upload_provider.dart';
import 'package:nexus_app_v2/core/storage/chat_media_upload_queue.dart';

/// Widget that handles app lifecycle and resumes pending uploads.
/// Wrap your main app with this widget to enable automatic upload resumption.
class ChatMediaUploadLifecycleHandler extends ConsumerStatefulWidget {
  final Widget child;

  const ChatMediaUploadLifecycleHandler({required this.child, Key? key})
    : super(key: key);

  @override
  ConsumerState<ChatMediaUploadLifecycleHandler> createState() =>
      _ChatMediaUploadLifecycleHandlerState();
}

class _ChatMediaUploadLifecycleHandlerState
    extends ConsumerState<ChatMediaUploadLifecycleHandler>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    // Resume uploads on app startup
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _resumeUploads();
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    switch (state) {
      case AppLifecycleState.resumed:
        // App came to foreground - resume uploads
        _resumeUploads();
        break;
      case AppLifecycleState.paused:
      case AppLifecycleState.detached:
      case AppLifecycleState.inactive:
        // App went to background or closed
        // Uploads will resume when app comes back to foreground
        break;
      case AppLifecycleState.hidden:
        // App hidden on some platforms
        break;
    }
  }

  void _resumeUploads() {
    final currentUser = FirebaseAuth.instance.currentUser;
    if (currentUser == null) return;

    // ✅ Crash recovery: Reset any uploads stuck in 'uploading' state back to 'pending'
    // This handles cases where app crashed during an upload attempt
    ChatMediaUploadQueueDb.resetUploadingToPending(currentUser.uid).ignore();

    // Clean old uploads (DB maintenance)
    ChatMediaUploadQueueDb.deleteExpiredFailed().ignore();

    final uploadService = ref.read(chatMediaUploadServiceProvider);
    uploadService.resumePendingUploads(currentUser.uid);
  }

  @override
  Widget build(BuildContext context) {
    return widget.child;
  }
}
