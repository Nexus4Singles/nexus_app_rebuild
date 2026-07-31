import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart' as ja;
import 'package:nexus_app_v2/core/auth/auth_providers.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/services/chat_service.dart';
import 'package:nexus_app_v2/core/widgets/disabled_account_gate.dart';
import 'package:nexus_app_v2/core/providers/service_providers.dart';
import 'package:nexus_app_v2/core/moderation/moderation_providers.dart';
import 'package:nexus_app_v2/core/moderation/moderation_models.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:nexus_app_v2/core/constants/app_constants.dart';
import 'package:nexus_app_v2/features/subscription/presentation/screens/subscription_screen.dart';
import 'package:nexus_app_v2/features/subscription/application/subscription_provider.dart';
import 'package:nexus_app_v2/core/widgets/cached_image.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:nexus_app_v2/core/providers/chat_media_upload_provider.dart';
import 'package:http/http.dart' as http;
import 'chat_thread_decline_utils.dart';

final _userDocByIdProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? doc.data() : null);
    });

/// Fast username fetch (one-time, no loading state) for chat thread header
final _userDisplayNameByIdProvider = FutureProvider.family<String?, String>((
  ref,
  uid,
) async {
  try {
    final doc =
        await FirebaseFirestore.instance.collection('users').doc(uid).get();
    if (!doc.exists) return null;
    final data = doc.data();
    final candidates = [
      data?['username'],
      data?['displayName'],
      data?['name'],
      data?['fullName'],
    ];
    for (final c in candidates) {
      final v = (c ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    return null;
  } catch (_) {
    return null;
  }
});

String? _bestAvatarUrl(Map<String, dynamic>? u) {
  if (u == null) return null;

  // Common locations:
  // - profileUrl
  // - photos[0..n] (iterate to find first valid)
  // - nexus2.photos[0..n] (iterate to find first valid)
  final direct = (u['profileUrl'] ?? '').toString().trim();
  if (direct.isNotEmpty) return direct;

  // FIXED: Iterate through all photos to find first valid (non-empty) one
  // This handles cases where photos are deleted from Firestore
  final photos = u['photos'];
  if (photos is List && photos.isNotEmpty) {
    for (final photo in photos) {
      final v = (photo ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
  }

  final nexus2 = u['nexus2'];
  if (nexus2 is Map) {
    // FIXED: Iterate through nexus2 photos as well
    final n2photos = nexus2['photos'];
    if (n2photos is List && n2photos.isNotEmpty) {
      for (final photo in n2photos) {
        final v = (photo ?? '').toString().trim();
        if (v.isNotEmpty) return v;
      }
    }
    final n2url = (nexus2['profileUrl'] ?? '').toString().trim();
    if (n2url.isNotEmpty) return n2url;
  }

  return null;
}

// Audio recording duration constraints (in seconds)
const int _minAudioDuration = 1; // Minimum 1 second
const int _maxAudioDuration = 600; // Maximum 10 minutes for chat voice notes

enum _MessageKind { text, image, audio }

class _ThreadEmptyStateCard extends StatelessWidget {
  final String name;
  const _ThreadEmptyStateCard({required this.name});

  @override
  Widget build(BuildContext context) {
    final n = name.trim().isEmpty ? 'them' : name.trim();
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            height: 44,
            width: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(
              Icons.chat_bubble_outline_rounded,
              color: AppColors.primary.withOpacity(0.85),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            "Send $n a thoughtful message",
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          Text(
            'Be kind, specific, and start the conversation.',
            textAlign: TextAlign.center,
            style: Theme.of(context).textTheme.bodySmall?.copyWith(
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ],
      ),
    );
  }
}

class _ThreadErrorStateCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String? errorText;

  const _ThreadErrorStateCard({
    required this.title,
    required this.subtitle,
    this.errorText,
  });

  String _compact(String? s) {
    final v = (s ?? '').trim();
    if (v.isEmpty) return '';
    return v.length > 220 ? '${v.substring(0, 220)}…' : v;
  }

  @override
  Widget build(BuildContext context) {
    final details = _compact(errorText);

    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Container(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 16),
          decoration: BoxDecoration(
            color: AppColors.getSurface(context),
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: AppColors.getBorder(context)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 54,
                height: 54,
                decoration: BoxDecoration(
                  color: Colors.orange.withOpacity(0.14),
                  borderRadius: BorderRadius.circular(18),
                ),
                child: const Icon(Icons.wifi_off, color: Colors.orange),
              ),
              const SizedBox(height: 12),
              Text(
                title,
                style: AppTextStyles.titleLarge,
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 6),
              Text(
                subtitle,
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
                textAlign: TextAlign.center,
              ),
              if (details.isNotEmpty) ...[
                const SizedBox(height: 10),
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppColors.getBackground(context),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: AppColors.getBorder(context)),
                  ),
                  child: Text(
                    details,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

final _chatOtherUserIdProvider = FutureProvider.family<String?, String>((
  ref,
  chatId,
) async {
  final authAsync = ref.watch(authStateProvider);
  final me = authAsync.maybeWhen(data: (a) => a.user?.uid, orElse: () => null);
  if (me == null) return null;

  final convo = await ref.watch(chatConversationProvider(chatId).future);
  return convo?.getOtherParticipantId(me);
});

final _userDocProvider = StreamProvider.family<Map<String, dynamic>?, String>((
  ref,
  uid,
) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(uid)
      .snapshots()
      .map((d) => d.data());
});

/// Provider for user's last active status (real-time)
final _userLastActiveProvider = StreamProvider.family<String, String>((
  ref,
  userId,
) {
  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
        final data = doc.data();
        final lastActiveAt = data?['lastActiveAt'] as Timestamp?;
        if (lastActiveAt == null) {
          return 'Offline';
        }
        final dateTime = lastActiveAt.toDate();
        return ChatService.formatLastActive(dateTime);
      });
});

String _bestDisplayName(Map<String, dynamic>? u) {
  if (u == null) return 'Chat';
  final candidates = [
    u['username'],
    u['displayName'],
    u['name'],
    u['fullName'],
  ];
  for (final c in candidates) {
    final v = (c ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }
  return 'Chat';
}

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatThreadScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
  String _resolveOtherId(dynamic convo, String me) {
    final myId = me.trim();
    if (myId.isEmpty) return '';

    // 1) Prefer convo participant ids (supports multiple model shapes).
    try {
      final ids = <String>[];

      // ChatConversation in your "good" ChatService uses participantIds.
      final dynamic p1 = (convo == null) ? null : (convo.participantIds);
      if (p1 is List) {
        for (final v in p1) {
          final s = v.toString().trim();
          if (s.isNotEmpty) ids.add(s);
        }
      }

      // Your older chat_models.dart uses "participants".
      final dynamic p2 = (convo == null) ? null : (convo.participants);
      if (ids.isEmpty && p2 is List) {
        for (final v in p2) {
          final s = v.toString().trim();
          if (s.isNotEmpty) ids.add(s);
        }
      }

      // Some implementations expose a helper.
      if (ids.isEmpty && convo != null) {
        final dynamic other = convo.getOtherParticipantId(myId);
        if (other is String && other.trim().isNotEmpty) return other.trim();
      }

      // Derive from ids list.
      if (ids.isNotEmpty) {
        for (final id in ids) {
          if (id != myId) return id;
        }
      }
    } catch (_) {
      // fall through
    }

    // 2) Fallback: parse chatId like "<uidA>_<uidB>"
    final parts = widget.chatId.split('_').map((s) => s.trim()).toList();
    if (parts.length >= 2) {
      // deterministic chatId is two uids joined by underscore
      if (parts[0] == myId) return parts[1];
      if (parts[1] == myId) return parts[0];
    }

    return '';
  }

  final _controller = TextEditingController();
  final _scroll = ScrollController();

  final _picker = ImagePicker();
  late final ja.AudioPlayer _player;
  late final AudioRecorder _recorder;

  bool _isRecording = false;
  String? _recordingPath;
  Timer? _recordingTimer;
  Duration _recordingDuration = Duration.zero;
  double _recordingDragOffset = 0; // Track horizontal drag for slide-to-cancel

  String? _playingMessageId;

  _UiMessage? _replyTo;
  bool _didMarkAsReadForOpen = false;
  // Messages are Firestore-backed via chatMessagesProvider.

  // Audio cache directory for voice notes - persistent across app restarts
  Directory? _audioCacheDir;

  /// Get or create the audio cache directory for chat voice notes
  Future<Directory> _getAudioCacheDir() async {
    if (_audioCacheDir != null) return _audioCacheDir!;
    final appDir = await getApplicationSupportDirectory();
    _audioCacheDir = Directory('${appDir.path}/chat_audio_cache');
    if (!await _audioCacheDir!.exists()) {
      await _audioCacheDir!.create(recursive: true);
    }
    return _audioCacheDir!;
  }

  /// Generate a stable cache file path for a URL (survives app restarts)
  Future<File> _cacheFileForUrl(String url) async {
    final dir = await _getAudioCacheDir();
    // Use hash of URL as filename to avoid path issues
    final hash = url.hashCode.toUnsigned(32).toRadixString(16);
    final ext = url.contains('.m4a') ? '.m4a' : '.mp3';
    return File('${dir.path}/$hash$ext');
  }

  /// Get audio source with disk caching for network URLs
  /// Downloads once and replays from local cache on subsequent plays
  Future<ja.AudioSource> _audioSourceForPath(String path) async {
    // Local file path - use directly
    if (!path.startsWith('http://') && !path.startsWith('https://')) {
      return ja.AudioSource.file(path);
    }

    // Network URL - use disk caching
    final cacheFile = await _cacheFileForUrl(path);

    // Ensure cache directory exists right before use (OS may have purged it)
    final cacheDir = cacheFile.parent;
    if (!cacheDir.existsSync()) {
      cacheDir.createSync(recursive: true);
    }

    // Check if already cached (both platforms)
    if (await cacheFile.exists() && await cacheFile.length() > 2048) {
      debugPrint('[ChatAudio] Playing from cache: ${cacheFile.path}');
      return ja.AudioSource.file(cacheFile.path);
    }

    // Download and cache the audio file (both platforms)
    // Avoids LockCachingAudioSource which can throw unhandled PathNotFoundException
    // when the OS purges the cache dir between .part file creation and rename.
    try {
      debugPrint('[ChatAudio] Downloading to cache: $path');
      final response = await http
          .get(Uri.parse(path))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode >= 200 &&
          response.statusCode < 300 &&
          response.bodyBytes.length > 2048) {
        // Re-ensure directory exists right before write (OS may purge mid-download)
        if (!cacheDir.existsSync()) {
          cacheDir.createSync(recursive: true);
        }
        await cacheFile.writeAsBytes(response.bodyBytes);
        debugPrint('[ChatAudio] ✅ Cached ${response.bodyBytes.length} bytes');
        return ja.AudioSource.file(cacheFile.path);
      }

      debugPrint(
        '[ChatAudio] ⚠️ Download failed (${response.statusCode}), '
        'falling back to streaming',
      );
    } catch (e) {
      debugPrint('[ChatAudio] ⚠️ Cache download error: $e, streaming instead');
    }

    // Fallback: stream directly from URL
    return ja.AudioSource.uri(Uri.parse(path));
  }

  @override
  void initState() {
    super.initState();
    _player = ja.AudioPlayer();
    _recorder = AudioRecorder();

    // Keep the send button in sync with the text field on ALL Android input
    // methods (IME suggestions, swipe/glide typing, voice input, etc.).
    // The TextField.onChanged callback is not always called by Android IMEs
    // when text is committed via suggestion bar or predictive input, so this
    // listener acts as a reliable fallback to trigger a rebuild.
    _controller.addListener(_onControllerChanged);

    _player.playerStateStream.listen((_) {
      if (!mounted) return;
      setState(() {});
    });

    _player.processingStateStream.listen((state) {
      if (!mounted) return;
      if (state == ja.ProcessingState.completed) {
        setState(() => _playingMessageId = null);
      }
    });
  }

  void _onControllerChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _controller.removeListener(_onControllerChanged);
    _controller.dispose();
    _scroll.dispose();
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  bool get _canSendText => _controller.text.trim().isNotEmpty;

  Future<void> _ensureSignedInThen(Future<void> Function() onAllowed) async {
    // Chat thread does not do guest/dating-profile gating.
    // Auth is assumed by navigation (guests shouldn't reach chat).
    await onAllowed();
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      _scroll.animateTo(
        0,
        duration: const Duration(milliseconds: 250),
        curve: Curves.easeOut,
      );
    });
  }

  /// Generate status text for message delivery and interaction states
  String _getMessageStatusText(_UiMessage msg) {
    // Declined takes priority - show decline reason or fallback to "Declined"
    if (msg.isDeclined) {
      final reason = msg.declineReason?.trim() ?? '';
      if (reason.isNotEmpty) {
        return 'Declined: $reason';
      } else {
        return 'Declined';
      }
    }

    // For received messages, just show the time
    if (!msg.isMe) {
      return msg.timeLabel;
    }

    // For sent messages, show delivery/read status
    if (msg.isRead && msg.readAt != null) {
      final rt = TimeOfDay.fromDateTime(msg.readAt!);
      final rhh = rt.hour.toString().padLeft(2, '0');
      final rmm = rt.minute.toString().padLeft(2, '0');
      return 'Read at $rhh:$rmm';
    }

    // Default: just show time
    return msg.timeLabel;
  }

  /// Get visual read status indicator for sent messages
  /// Returns: ✓ (sent), ✓✓ (delivered), ✓✓ (read, blue)
  Widget _getMessageReadStatusIcon(_UiMessage msg, BuildContext context) {
    if (!msg.isMe) {
      return const SizedBox.shrink();
    }

    // Read (blue double checkmark)
    if (msg.isRead) {
      return Text(
        '✓✓',
        style: TextStyle(
          color: AppColors.primary,
          fontSize: 10,
          fontWeight: FontWeight.bold,
        ),
      );
    }

    // Sent/Delivered (grey double checkmark)
    return Text(
      '✓✓',
      style: TextStyle(
        color: AppColors.getTextSecondary(context),
        fontSize: 10,
      ),
    );
  }

  /// Show decline reason bottom sheet with templated options
  Future<void> _showDeclineReasonBottomSheet(
    BuildContext context,
    _UiMessage message,
  ) async {
    if (!mounted) return;

    const declineReasons = [
      'Looking for different connections',
      'Not a good fit for me right now',
      'Already chatting with someone',
    ];

    await showModalBottomSheet<String>(
      context: context,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.getBorder(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Let them know why',
                      style: AppTextStyles.titleMedium.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'They\'ll get a friendly notification',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: AppColors.getBorder(context).withOpacity(0.2),
              ),
              ...declineReasons.map((reason) {
                return ListTile(
                  contentPadding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 12,
                  ),
                  title: Text(reason),
                  onTap: () {
                    Navigator.of(context).pop(reason);
                    _handleDeclineMessage(message, reason);
                  },
                );
              }).toList(),
            ],
          ),
        );
      },
    );
  }

  /// Handle message decline - update Firestore and send notification
  Future<void> _handleDeclineMessage(_UiMessage message, String reason) async {
    if (!mounted) return;

    try {
      final authAsync = ref.read(authStateProvider);
      final me = authAsync.maybeWhen(
        data: (a) => a.user?.uid,
        orElse: () => null,
      );
      if (me == null) return;

      // Update the message in Firestore to mark as declined
      await FirebaseFirestore.instance
          .collection('nexus2_chats')
          .doc(widget.chatId)
          .collection('messages')
          .doc(message.id)
          .update({
            'isDeclined': true,
            'declineReason': reason,
            'declinedAt': FieldValue.serverTimestamp(),
          });

      // Get decliner info for notification
      final declinerName = await _getUserDisplayName(me);

      // Trigger cloud function to send friendly push notification
      // Must be stored under users/{userId}/notifications/ for the FCM trigger to work
      await FirebaseFirestore.instance
          .collection('users')
          .doc(message.senderId)
          .collection('notifications')
          .add({
            'type': 'message_declined',
            'title': 'Interest Update',
            'body': buildDeclineNotificationBody(declinerName, reason),
            'senderName': declinerName,
            'declineReason': reason,
            'timestamp': FieldValue.serverTimestamp(),
            'read': false,
          });

      if (!mounted) return;
      _toast(buildDeclineStatusText(reason));
    } catch (e) {
      if (!mounted) return;
      _toast('Failed to send response');
      debugPrint('[ChatThread] Decline error: $e');
    }
  }

  /// Get display name for a user
  Future<String> _getUserDisplayName(String uid) async {
    try {
      final doc =
          await FirebaseFirestore.instance.collection('users').doc(uid).get();
      if (!doc.exists) return 'Someone';

      final data = doc.data();
      final candidates = [
        data?['username'],
        data?['displayName'],
        data?['name'],
        data?['fullName'],
      ];
      for (final c in candidates) {
        final v = (c ?? '').toString().trim();
        if (v.isNotEmpty) return v;
      }
      return 'Someone';
    } catch (_) {
      return 'Someone';
    }
  }

  void _toast(String msg) {
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _sanitizeChatError(Object e) {
    // Prefer user-friendly messages and strip noisy prefixes.
    final raw = e.toString().trim();

    // Strip common exception prefixes shown to users.
    // e.g. "ChatException: Premium required..." -> "Premium required..."
    final cleaned =
        raw
            .replaceFirst(RegExp(r'^ChatException:\s*'), '')
            .replaceFirst(RegExp(r'^Exception:\s*'), '')
            .replaceFirst(RegExp(r'^StateError:\s*'), '')
            .replaceFirst(RegExp(r'^Failed to send message:\s*'), '')
            .trim();

    // If this looks like a Firestore permission error, show a friendly gating message.
    // (This prevents users seeing cloud_firestore internals.)
    final lower = cleaned.toLowerCase();
    if (lower.contains('permission-denied') ||
        lower.contains('permission_denied') ||
        lower.contains('permission denied') ||
        lower.contains('[cloud_firestore/permission-denied]') ||
        lower.contains('cloud_firestore/permission-denied') ||
        lower.contains('permissiondenied')) {
      return 'Premium required: free users can message 1 person. Upgrade to message more.';
    }

    return cleaned.isEmpty
        ? 'Something went wrong. Please try again.'
        : cleaned;
  }

  Future<T?> _runOp<T>(
    Future<T?> Function() op, {
    String failMessage = 'Something went wrong. Please try again.',
  }) async {
    try {
      final result = await op();
      if (result == null) _toast(failMessage);
      return result;
    } catch (e) {
      final msg = _sanitizeChatError(e);

      final looksLikePremiumGate =
          msg.toLowerCase().contains('premium required') ||
          msg.toLowerCase().contains('upgrade') ||
          msg.toLowerCase().contains('subscribe') ||
          msg.toLowerCase().contains('can only chat with');

      if (looksLikePremiumGate) {
        await _showPremiumRequiredDialog(msg);
      } else {
        _toast(msg);
      }
      return null;
    }
  }

  /// Read-only pre-check: can the current user send in this chat?
  /// Returns `true` if allowed. Shows the premium dialog and returns
  /// `false` if the free-tier limit blocks the send.
  /// Does NOT write anything — safe to call before image picker / recording.
  Future<bool> _checkFreeTierOrShowDialog() async {
    final authAsync = ref.read(authStateProvider);
    final me = authAsync.maybeWhen(
      data: (a) => a.user?.uid,
      orElse: () => null,
    );
    if (me == null) return true; // let downstream handle sign-in

    try {
      final convo = await ref.read(
        chatConversationProvider(widget.chatId).future,
      );
      final otherId = _resolveOtherId(convo, me);
      if (otherId.isEmpty) return true; // let downstream handle error

      await ref
          .read(chatNotifierProvider.notifier)
          .checkCanSendToReceiver(otherId);
      return true;
    } catch (e) {
      final msg = _sanitizeChatError(e);
      final looksLikePremiumGate =
          msg.toLowerCase().contains('premium required') ||
          msg.toLowerCase().contains('upgrade') ||
          msg.toLowerCase().contains('subscribe') ||
          msg.toLowerCase().contains('can only chat with');

      if (looksLikePremiumGate) {
        if (mounted) await _showPremiumRequiredDialog(msg);
      } else {
        if (mounted) _toast(msg);
      }
      return false;
    }
  }

  String _replySnippet(_UiMessage m) {
    switch (m.kind) {
      case _MessageKind.text:
        final t = (m.text ?? '').trim();
        if (t.isEmpty) return 'Message';
        return t.length > 80 ? '${t.substring(0, 80)}…' : t;
      case _MessageKind.image:
        return 'Photo';
      case _MessageKind.audio:
        return 'Voice note';
    }
  }

  Future<void> _openMessageActions(_UiMessage m) async {
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.getSurface(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) {
        return SafeArea(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Column(
                  children: [
                    Container(
                      width: 44,
                      height: 5,
                      decoration: BoxDecoration(
                        color: AppColors.getBorder(context),
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Text('Message', style: AppTextStyles.titleLarge),
                        const Spacer(),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () => Navigator.of(context).pop(),
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    // Message preview bubble
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            m.isMe
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.getBorder(context).withOpacity(0.1),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: AppColors.getBorder(context).withOpacity(0.2),
                          width: 1,
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          if (m.isMe)
                            Text(
                              'You',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.primary,
                              ),
                            )
                          else
                            Text(
                              'Sender',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w600,
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                          const SizedBox(height: 6),
                          if (m.kind == _MessageKind.text)
                            Text(
                              _replySnippet(m),
                              style: const TextStyle(fontSize: 14),
                              maxLines: 3,
                              overflow: TextOverflow.ellipsis,
                            )
                          else if (m.kind == _MessageKind.image)
                            Row(
                              children: [
                                const Icon(Icons.image, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Photo message',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.getTextMuted(context),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            )
                          else if (m.kind == _MessageKind.audio)
                            Row(
                              children: [
                                const Icon(Icons.mic, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Voice note',
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: AppColors.getTextMuted(context),
                                    fontStyle: FontStyle.italic,
                                  ),
                                ),
                              ],
                            ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
              Divider(
                height: 1,
                color: AppColors.getBorder(context).withOpacity(0.2),
              ),
              ListTile(
                contentPadding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                leading: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: const Icon(
                    Icons.reply,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                title: const Text(
                  'Reply',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                onTap: () {
                  Navigator.of(context).pop();
                  setState(() => _replyTo = m);
                },
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await _ensureSignedInThen(() async {
      try {
        final authAsync = ref.read(authStateProvider);
        final me = authAsync.maybeWhen(
          data: (a) => a.user?.uid,
          orElse: () => null,
        );
        if (me == null) {
          debugPrint('[ChatThread] Current user is null when trying to send');
          if (!mounted) return;
          _toast('You need to be signed in to send messages.');
          return;
        }

        debugPrint(
          '[ChatThread] Sending message as user: $me to chat: ${widget.chatId}',
        );

        final convo = await ref.read(
          chatConversationProvider(widget.chatId).future,
        );
        final otherId = _resolveOtherId(convo, me);

        if (otherId.isEmpty) {
          debugPrint(
            '[ChatThread] ERROR: Could not determine other user. '
            'chatId=${widget.chatId}, currentUser=$me, convo=$convo',
          );

          // Show error alert instead of silent failure
          if (!mounted) {
            debugPrint(
              '[ChatThread] Widget not mounted, cannot show error dialog',
            );
            return;
          }

          await showDialog<void>(
            context: context,
            builder:
                (ctx) => AlertDialog(
                  title: const Text('Chat Error'),
                  content: const Text(
                    'This conversation is no longer valid for this account. '
                    'This can happen if you log in with a different account on the same device. '
                    'Please return to the chat list and try again.',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () {
                        Navigator.of(ctx).pop();
                        // Try to go back to chat list
                        if (mounted) Navigator.of(context).pop();
                      },
                      child: const Text('OK'),
                    ),
                  ],
                ),
          );
          return;
        }

        // Check if you have blocked this user
        final blockedUsers = ref.read(blockedUsersProvider(me));
        final amBlocked = blockedUsers.maybeWhen(
          data: (set) => set.contains(otherId),
          orElse: () => false,
        );

        if (amBlocked) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: const Text(
                'You have blocked this user. Unblock them to send messages.',
              ),
              duration: const Duration(seconds: 3),
            ),
          );
          return;
        }

        final reply = _replyTo;
        final metadata =
            reply == null
                ? null
                : <String, dynamic>{
                  'replyToId': reply.id,
                  'replyToSnippet': _replySnippet(reply),
                  'replyToWasMine': reply.isMe,
                };

        // Optimistic UI: clear text + reply immediately so user feels instant send
        _controller.clear();
        setState(() => _replyTo = null);

        final sent = await _runOp(() async {
          await ref
              .read(chatNotifierProvider.notifier)
              .sendMessage(
                chatId: widget.chatId,

                receiverId: otherId,

                content: text,

                metadata: metadata,
              );

          return true;
        }, failMessage: 'Message failed to send. Please try again.');

        if (sent == null) {
          // Restore text on failure so user can retry
          if (mounted) {
            _controller.text = text;
            _controller.selection = TextSelection.fromPosition(
              TextPosition(offset: text.length),
            );
            setState(() {}); // Re-enable send button
          }
          return;
        }
        _scrollToBottomSoon();
      } catch (e) {
        debugPrint('[ChatThread] _sendText unhandled error: $e');
        if (!mounted) return;
        final msg = _sanitizeChatError(e);
        final looksLikePremiumGate =
            msg.toLowerCase().contains('premium required') ||
            msg.toLowerCase().contains('upgrade') ||
            msg.toLowerCase().contains('subscribe') ||
            msg.toLowerCase().contains('can only chat with');

        if (looksLikePremiumGate) {
          await _showPremiumRequiredDialog(msg);
        } else {
          _toast(msg);
        }
      }
    });
  }

  Future<void> _pickAndSendImage() async {
    await _ensureSignedInThen(() async {
      try {
        // Pre-check free-tier eligibility BEFORE opening the picker
        // so users don't waste time choosing a photo they can't send.
        if (!await _checkFreeTierOrShowDialog()) return;

        // image_picker handles permissions internally, so we call it directly
        final picked = await _picker.pickImage(
          source: ImageSource.gallery,
          imageQuality: 85,
        );

        if (picked == null) {
          // User cancelled or permission denied by image_picker
          if (!mounted) return;
          _toast(
            'No photo selected. Please enable photo library access in Settings.',
          );
          return;
        }

        final authAsync = ref.read(authStateProvider);
        final me = authAsync.maybeWhen(
          data: (a) => a.user?.uid,
          orElse: () => null,
        );
        if (me == null) {
          debugPrint(
            '[ChatThread] Current user is null when trying to send image',
          );
          if (!mounted) return;
          _toast('You need to be signed in to send photos.');
          return;
        }

        final convo = await ref.read(
          chatConversationProvider(widget.chatId).future,
        );
        final otherId = _resolveOtherId(convo, me);
        if (otherId.isEmpty) {
          debugPrint(
            '[ChatThread] Could not determine other user for image send. '
            'chatId=${widget.chatId}, currentUser=$me',
          );
          if (!mounted) return;
          _toast(
            'Could not determine the other user in this chat. Please go back and try again.',
          );
          return;
        }

        final reply = _replyTo;
        final metadata =
            reply == null
                ? null
                : <String, dynamic>{
                  'replyToId': reply.id,
                  'replyToSnippet': _replySnippet(reply),
                  'replyToWasMine': reply.isMe,
                };

        // For now, store image locally without cloud upload
        // In production, this would upload to cloud storage
        final imagePath = picked.path;

        final sent = await _runOp(() async {
          await ref
              .read(chatNotifierProvider.notifier)
              .sendImage(
                chatId: widget.chatId,
                receiverId: otherId,
                imageUrl: imagePath, // Store local path instead of cloud URL
                metadata: metadata,
              );
          return true;
        }, failMessage: 'Photo failed to send. Please try again.');
        if (sent == null) return;

        if (!mounted) return;
        setState(() => _replyTo = null);
        _scrollToBottomSoon();
      } catch (e) {
        debugPrint('[ChatThread] _pickAndSendImage unhandled error: $e');
        if (!mounted) return;
        final msg = _sanitizeChatError(e);
        final looksLikePremiumGate =
            msg.toLowerCase().contains('premium required') ||
            msg.toLowerCase().contains('upgrade') ||
            msg.toLowerCase().contains('subscribe') ||
            msg.toLowerCase().contains('can only chat with');

        if (looksLikePremiumGate) {
          await _showPremiumRequiredDialog(msg);
        } else {
          _toast(msg);
        }
      }
    });
  }

  Future<String> _nextRecordingPath() async {
    final dir = await getTemporaryDirectory();
    final folder = Directory('${dir.path}/nexus_voice_notes');
    if (!folder.existsSync()) folder.createSync(recursive: true);

    final filename = 'vn_${DateTime.now().millisecondsSinceEpoch}.m4a';
    return '${folder.path}/$filename';
  }

  Future<void> _toggleRecording() async {
    await _ensureSignedInThen(() async {
      if (_isRecording) {
        // Already recording — stop and attempt send (enforcement still
        // happens at send time, but the user already invested effort).
        await _stopRecordingAndSend();
      } else {
        // Pre-check free-tier eligibility BEFORE starting the recording
        // so users don't record a voice note they can't send.
        if (!await _checkFreeTierOrShowDialog()) return;
        await _startRecording();
      }
    });
  }

  Future<void> _startRecording() async {
    // Request permission using the record package, which handles it properly
    final isGranted = await _recorder.hasPermission();

    if (!isGranted) {
      // If not granted, try to request it
      final requestGranted = await Permission.microphone.request();

      if (requestGranted.isPermanentlyDenied) {
        if (!mounted) return;
        _toast(
          'Microphone permission is permanently disabled. Please enable it in app Settings.',
        );
        return;
      }

      if (!requestGranted.isGranted) {
        if (!mounted) return;
        _toast('Microphone permission is required to record voice notes.');
        return;
      }
    }

    final path = await _nextRecordingPath();

    try {
      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
        ),
        path: path,
      );

      setState(() {
        _isRecording = true;
        _recordingPath = path;
        _recordingDuration = Duration.zero;
      });

      // Start timer to update recording duration
      _recordingTimer?.cancel();
      _recordingTimer = Timer.periodic(const Duration(milliseconds: 100), (_) {
        if (mounted) {
          setState(() {
            _recordingDuration = Duration(
              milliseconds: _recordingDuration.inMilliseconds + 100,
            );
          });
        }
      });

      // No SnackBar messages - let the UI speak for itself
    } catch (e) {
      if (!mounted) return;
      _toast('Failed to start recording: $e');
      setState(() {
        _isRecording = false;
      });
    }
  }

  Future<void> _cancelRecording() async {
    // Cancel the timer
    _recordingTimer?.cancel();
    _recordingTimer = null;

    // Stop recording but don't send
    await _recorder.stop();

    // Delete the file
    if (_recordingPath != null) {
      try {
        final file = File(_recordingPath!);
        if (file.existsSync()) {
          file.deleteSync();
        }
      } catch (_) {
        // Silent fail
      }
    }

    setState(() {
      _isRecording = false;
      _recordingPath = null;
      _recordingDuration = Duration.zero;
      _recordingDragOffset = 0;
    });
  }

  void _updateRecordingDrag(double delta) {
    setState(() {
      _recordingDragOffset += delta;
    });
  }

  void _resetRecordingDrag() {
    setState(() {
      _recordingDragOffset = 0;
    });
  }

  Future<void> _stopRecordingAndSend() async {
    // Cancel the timer
    _recordingTimer?.cancel();
    _recordingTimer = null;

    final stoppedPath = await _recorder.stop();

    setState(() {
      _isRecording = false;
      _recordingDuration = Duration.zero;
    });

    final path = stoppedPath ?? _recordingPath;
    _recordingPath = null;

    if (path == null || path.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not save recording. Try again.')),
      );
      return;
    }

    final file = File(path);
    if (!file.existsSync()) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recording file not found. Try again.')),
      );
      return;
    }

    final authAsync = ref.read(authStateProvider);
    final me = authAsync.maybeWhen(
      data: (a) => a.user?.uid,
      orElse: () => null,
    );
    if (me == null) {
      debugPrint(
        '[ChatThread] Current user is null when trying to send voice note',
      );
      if (!mounted) return;
      _toast('You need to be signed in to send voice notes.');
      return;
    }

    try {
      final convo = await ref.read(
        chatConversationProvider(widget.chatId).future,
      );
      final otherId = _resolveOtherId(convo, me);
      if (otherId.isEmpty) {
        debugPrint(
          '[ChatThread] Could not determine other user for voice send. '
          'chatId=${widget.chatId}, currentUser=$me',
        );
        if (!mounted) return;
        _toast(
          'Could not determine the other user in this chat. Please go back and try again.',
        );
        return;
      }

      final reply = _replyTo;
      final metadata =
          reply == null
              ? null
              : <String, dynamic>{
                'replyToId': reply.id,
                'replyToSnippet': _replySnippet(reply),
                'replyToWasMine': reply.isMe,
              };

      // Compute duration (seconds) safely without interrupting playback.
      int durationSeconds = 0;
      try {
        final tmp = ja.AudioPlayer();
        await tmp.setFilePath(path);
        durationSeconds = tmp.duration?.inSeconds ?? 0;
        await tmp.dispose();
      } catch (_) {
        durationSeconds = 0;
      }

      // Validate duration meets minimum requirement
      if (durationSeconds < _minAudioDuration) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recording too short. Please record at least $_minAudioDuration second. You recorded ${durationSeconds}s.',
            ),
          ),
        );
        return;
      }

      // Validate duration doesn't exceed maximum
      if (durationSeconds > _maxAudioDuration) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Recording too long. Maximum duration is $_maxAudioDuration seconds. You recorded ${durationSeconds}s.',
            ),
          ),
        );
        return;
      }

      // Store audio as local file path - no cloud upload
      final sent = await _runOp(() async {
        await ref
            .read(chatNotifierProvider.notifier)
            .sendAudio(
              chatId: widget.chatId,
              receiverId: otherId,
              audioUrl: path, // Store local path directly
              durationSeconds: durationSeconds,
              metadata: metadata,
            );
        return true;
      }, failMessage: 'Voice note failed to send. Please try again.');
      if (sent == null) return;

      if (!mounted) return;
      setState(() => _replyTo = null);
      _scrollToBottomSoon();
    } catch (e) {
      debugPrint('[ChatThread] _stopRecordingAndSend unhandled error: $e');
      if (!mounted) return;
      final msg = _sanitizeChatError(e);
      final looksLikePremiumGate =
          msg.toLowerCase().contains('premium required') ||
          msg.toLowerCase().contains('upgrade') ||
          msg.toLowerCase().contains('subscribe') ||
          msg.toLowerCase().contains('can only chat with');

      if (looksLikePremiumGate) {
        await _showPremiumRequiredDialog(msg);
      } else {
        _toast(msg);
      }
    }
  }

  Future<void> _togglePlay(_UiMessage msg) async {
    if (msg.kind != _MessageKind.audio || msg.filePath == null) return;

    if (_playingMessageId == msg.id) {
      if (_player.playing) {
        await _player.pause();
      } else {
        await _player.play();
      }
      setState(() {});
      return;
    }

    try {
      await _player.stop();
      final path = msg.filePath!;

      // Use cached audio source for both network URLs and local files
      final audioSource = await _audioSourceForPath(path);
      await _player.setAudioSource(audioSource);

      setState(() => _playingMessageId = msg.id);
      await _player.play();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Could not play audio: $e')));
      setState(() => _playingMessageId = null);
    }
  }

  void _openOtherUserProfile(String otherUserId) {
    final id = otherUserId.trim();
    if (id.isEmpty) return;
    Navigator.of(context).pushNamed(AppNavRoutes.profileView(id));
  }

  Future<void> _showPremiumRequiredDialog(String message) async {
    if (!mounted) return;

    await showDialog<void>(
      context: context,
      barrierDismissible: true,
      builder: (ctx) {
        return AlertDialog(
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(20),
          ),
          titlePadding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
          contentPadding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: AppColors.primary,
                  size: 24,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Subscription Required',
                  style: AppTextStyles.titleMedium.copyWith(
                    fontWeight: FontWeight.w700,
                    color: AppColors.getTextPrimary(context),
                  ),
                ),
              ),
              SizedBox(
                width: 32,
                height: 32,
                child: IconButton(
                  tooltip: 'Close',
                  padding: EdgeInsets.zero,
                  icon: Icon(
                    Icons.close,
                    color: AppColors.getTextSecondary(context),
                    size: 20,
                  ),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ),
            ],
          ),
          content: Text(
            'You can only chat with 3 users on the free version of Nexus. Kindly subscribe to chat with more users.',
            textAlign: TextAlign.center,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.getTextPrimary(context),
              height: 1.5,
            ),
          ),
          actions: [
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(ctx).pop();
                  // Navigate to subscription screen
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const SubscriptionScreen(),
                    ),
                  );
                },
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                child: Text(
                  'Subscribe',
                  style: AppTextStyles.buttonMedium.copyWith(
                    color: Colors.white,
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  Future<void> _showReportSheetChat({
    required BuildContext context,
    required WidgetRef ref,
    required String reporterKey,
    required String reportedUid,
  }) async {
    ReportReason reason = ReportReason.harassment;
    final notesController = TextEditingController();
    bool isSubmitting = false;

    try {
      await showModalBottomSheet<void>(
        context: context,
        backgroundColor: Colors.transparent,
        isScrollControlled: true,
        builder: (sheetContext) {
          final bottomInset = MediaQuery.of(sheetContext).viewInsets.bottom;
          final theme = Theme.of(sheetContext);
          final colors = theme.colorScheme;

          return StatefulBuilder(
            builder: (ctx, setState) {
              return Padding(
                padding: EdgeInsets.only(bottom: bottomInset),
                child: Container(
                  padding: const EdgeInsets.fromLTRB(16, 16, 16, 18),
                  decoration: BoxDecoration(
                    color: colors.surface,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: colors.outline),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Expanded(
                            child: Text(
                              'Report User',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.w800,
                              ),
                            ),
                          ),
                          InkWell(
                            onTap:
                                isSubmitting
                                    ? null
                                    : () => Navigator.of(sheetContext).pop(),
                            borderRadius: BorderRadius.circular(999),
                            child: Container(
                              height: 36,
                              width: 36,
                              alignment: Alignment.center,
                              decoration: BoxDecoration(
                                color: colors.surfaceVariant,
                                borderRadius: BorderRadius.circular(999),
                                border: Border.all(color: colors.outline),
                              ),
                              child: Icon(
                                Icons.close_rounded,
                                size: 18,
                                color: colors.onSurface,
                              ),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Reason',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 12),
                        decoration: BoxDecoration(
                          color: colors.surfaceVariant,
                          borderRadius: BorderRadius.circular(12),
                          border: Border.all(color: colors.outline),
                        ),
                        child: DropdownButtonHideUnderline(
                          child: DropdownButton<ReportReason>(
                            value: reason,
                            isExpanded: true,
                            items:
                                ReportReason.values
                                    .map(
                                      (r) => DropdownMenuItem(
                                        value: r,
                                        child: Text(r.label),
                                      ),
                                    )
                                    .toList(),
                            onChanged:
                                isSubmitting
                                    ? null
                                    : (v) {
                                      if (v == null) return;
                                      setState(() => reason = v);
                                    },
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Notes (optional)',
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      TextField(
                        controller: notesController,
                        maxLines: 4,
                        enabled: !isSubmitting,
                        style: theme.textTheme.bodyMedium,
                        decoration: InputDecoration(
                          hintText: 'Add more details (optional)',
                          filled: true,
                          fillColor: colors.surfaceVariant,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.outline),
                          ),
                          enabledBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.outline),
                          ),
                          focusedBorder: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                            borderSide: BorderSide(color: colors.primary),
                          ),
                        ),
                      ),
                      const SizedBox(height: 14),
                      SizedBox(
                        width: double.infinity,
                        child: ElevatedButton(
                          onPressed:
                              isSubmitting
                                  ? null
                                  : () async {
                                    setState(() => isSubmitting = true);
                                    try {
                                      print(
                                        'DEBUG: Starting report submission...',
                                      );
                                      await submitLocalReport(
                                        ref: ref,
                                        reporterKey: reporterKey,
                                        reportedUid: reportedUid,
                                        reason: reason,
                                        notes: notesController.text,
                                      );
                                      print(
                                        'DEBUG: Report submitted successfully',
                                      );
                                      if (sheetContext.mounted) {
                                        Navigator.of(sheetContext).pop();
                                      }
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          const SnackBar(
                                            content: Text(
                                              'Report submitted successfully',
                                            ),
                                          ),
                                        );
                                      }
                                    } catch (e) {
                                      print(
                                        'DEBUG: Report submission error: $e',
                                      );
                                      if (context.mounted) {
                                        ScaffoldMessenger.of(
                                          context,
                                        ).showSnackBar(
                                          SnackBar(
                                            content: Text('Report failed: $e'),
                                          ),
                                        );
                                      }
                                      if (sheetContext.mounted && mounted) {
                                        setState(() => isSubmitting = false);
                                      }
                                    }
                                  },
                          child:
                              isSubmitting
                                  ? const SizedBox(
                                    height: 20,
                                    width: 20,
                                    child: CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                  : const Text('Submit Report'),
                        ),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Reports are reviewed. Please avoid sharing sensitive personal information.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          color: colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
      );
    } finally {
      notesController.dispose();
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        title: Consumer(
          builder: (context, ref, _) {
            final otherIdAsync = ref.watch(
              _chatOtherUserIdProvider(widget.chatId),
            );

            return otherIdAsync.when(
              loading:
                  () => Row(
                    children: [
                      const SizedBox(width: 8),
                      _Avatar(label: '…'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Chat',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
              error:
                  (_, __) => Row(
                    children: [
                      const SizedBox(width: 8),
                      _Avatar(label: '?'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Chat',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
              data: (otherId) {
                if (otherId == null || otherId.trim().isEmpty) {
                  return Row(
                    children: [
                      const SizedBox(width: 8),
                      _Avatar(label: '?'),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          'Chat',
                          style: theme.textTheme.titleMedium?.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  );
                }

                // Get fast username first (no loading state)
                // Then subscribe to stream for real-time avatar/data
                final displayNameAsync = ref.watch(
                  _userDisplayNameByIdProvider(otherId),
                );
                final otherUserAsync = ref.watch(_userDocProvider(otherId));

                final initialDisplayName = displayNameAsync.maybeWhen(
                  data: (n) => n,
                  orElse: () => null,
                );

                return otherUserAsync.when(
                  loading: () {
                    final displayName = initialDisplayName ?? 'Chat';
                    return Row(
                      children: [
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _openOtherUserProfile(otherId),
                          borderRadius: BorderRadius.circular(14),
                          child: _Avatar(label: '…'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  error: (_, __) {
                    final displayName = initialDisplayName ?? 'Chat';
                    return Row(
                      children: [
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _openOtherUserProfile(otherId),
                          borderRadius: BorderRadius.circular(14),
                          child: _Avatar(label: '?'),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                displayName,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                  data: (u) {
                    final name = _bestDisplayName(u);
                    final avatarUrl = _bestAvatarUrl(u);
                    final lastActiveAsync = ref.watch(
                      _userLastActiveProvider(otherId),
                    );

                    return Row(
                      children: [
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _openOtherUserProfile(otherId),
                          borderRadius: BorderRadius.circular(14),
                          child: _Avatar(label: name, imageUrl: avatarUrl),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                name,
                                style: theme.textTheme.titleMedium?.copyWith(
                                  fontWeight: FontWeight.w800,
                                ),
                                overflow: TextOverflow.ellipsis,
                              ),
                              lastActiveAsync.maybeWhen(
                                data: (lastActive) {
                                  return Text(
                                    lastActive,
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.getTextSecondary(
                                        context,
                                      ),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                                orElse: () {
                                  return Text(
                                    'Tap to view profile',
                                    style: theme.textTheme.bodySmall?.copyWith(
                                      color: AppColors.getTextSecondary(
                                        context,
                                      ),
                                    ),
                                    overflow: TextOverflow.ellipsis,
                                  );
                                },
                              ),
                            ],
                          ),
                        ),
                      ],
                    );
                  },
                );
              },
            );
          },
        ),
        actions: [
          Consumer(
            builder: (context, ref, _) {
              final otherIdAsync = ref.watch(
                _chatOtherUserIdProvider(widget.chatId),
              );

              return otherIdAsync.maybeWhen(
                data: (otherId) {
                  if (otherId == null || otherId.trim().isEmpty) {
                    return const SizedBox.shrink();
                  }
                  return PopupMenuButton<String>(
                    icon: const Icon(Icons.more_vert_rounded),
                    onSelected: (v) async {
                      final authAsync = ref.read(authStateProvider);
                      final me = authAsync.maybeWhen(
                        data: (a) => a.user?.uid,
                        orElse: () => null,
                      );
                      final viewerKey = (me ?? 'guest').trim();

                      if (v == 'block') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) {
                            return Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Block User?',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'Are you sure you want to block this user?\n\nThey will be hidden from you and you won\'t be able to start a chat with them.',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(ctx).pop(true),
                                        child: const Text('Block'),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );

                        if (ok == true) {
                          await ref
                              .read(blockedUsersProvider(viewerKey).notifier)
                              .block(otherId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User blocked')),
                            );
                          }
                        }
                      } else if (v == 'unblock') {
                        final ok = await showDialog<bool>(
                          context: context,
                          builder: (ctx) {
                            return Dialog(
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Padding(
                                    padding: const EdgeInsets.all(16),
                                    child: Column(
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        const Text(
                                          'Unblock User?',
                                          style: TextStyle(
                                            fontSize: 20,
                                            fontWeight: FontWeight.bold,
                                          ),
                                        ),
                                        const SizedBox(height: 16),
                                        const Text(
                                          'They will be visible to you again.',
                                          style: TextStyle(fontSize: 16),
                                        ),
                                      ],
                                    ),
                                  ),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.end,
                                    children: [
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(ctx).pop(false),
                                        child: const Text('Cancel'),
                                      ),
                                      const SizedBox(width: 8),
                                      TextButton(
                                        onPressed:
                                            () => Navigator.of(ctx).pop(true),
                                        child: const Text('Unblock'),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                  ),
                                ],
                              ),
                            );
                          },
                        );

                        if (ok == true) {
                          await ref
                              .read(blockedUsersProvider(viewerKey).notifier)
                              .unblock(otherId);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(content: Text('User unblocked')),
                            );
                          }
                        }
                      } else if (v == 'report') {
                        await _showReportSheetChat(
                          context: context,
                          ref: ref,
                          reporterKey: viewerKey,
                          reportedUid: otherId,
                        );
                      }
                    },
                    itemBuilder: (context) {
                      final authAsync = ref.watch(authStateProvider);
                      final me = authAsync.maybeWhen(
                        data: (a) => a.user?.uid,
                        orElse: () => null,
                      );
                      final viewerKey = (me ?? 'guest').trim();

                      final isBlocked = ref.watch(
                        isBlockedProvider((
                          viewerKey: viewerKey,
                          targetUid: otherId,
                        )),
                      );

                      return [
                        PopupMenuItem(
                          value: isBlocked ? 'unblock' : 'block',
                          child: Text(
                            isBlocked ? 'Unblock User' : 'Block User',
                          ),
                        ),
                        const PopupMenuItem(
                          value: 'report',
                          child: Text('Report User'),
                        ),
                      ];
                    },
                  );
                },
                orElse: () => const SizedBox.shrink(),
              );
            },
          ),
          const SizedBox(width: 4),
        ],
      ),
      body: Column(
        children: [
          Expanded(
            child: Builder(
              builder: (context) {
                final authAsync = ref.watch(authStateProvider);
                final me = authAsync.maybeWhen(
                  data: (a) => a.user?.uid,
                  orElse: () => null,
                );

                final messagesAsync = ref.watch(
                  chatMessagesProvider(widget.chatId),
                );

                return messagesAsync.when(
                  loading:
                      () => const Center(child: CircularProgressIndicator()),
                  error: (e, __) {
                    final err = e.toString();
                    final isDenied = err.contains('permission-denied');
                    return _ThreadErrorStateCard(
                      title: 'Could not load messages.',
                      subtitle:
                          isDenied
                              ? 'We could not open this chat yet. If this is a new chat, try again in a moment.'
                              : 'Please try again.',
                      errorText: err,
                    );
                  },
                  data: (msgs) {
                    if (msgs.isEmpty) {
                      return Center(
                        child: Padding(
                          padding: const EdgeInsets.symmetric(horizontal: 18),
                          child: Consumer(
                            builder: (context, ref, _) {
                              final otherIdAsync = ref.watch(
                                _chatOtherUserIdProvider(widget.chatId),
                              );

                              return otherIdAsync.when(
                                loading:
                                    () => const _ThreadEmptyStateCard(
                                      name: 'them',
                                    ),
                                error:
                                    (_, __) => const _ThreadEmptyStateCard(
                                      name: 'them',
                                    ),
                                data: (otherId) {
                                  final uid = (otherId ?? '').trim();
                                  if (uid.isEmpty) {
                                    return const _ThreadEmptyStateCard(
                                      name: 'them',
                                    );
                                  }

                                  final otherDocAsync = ref.watch(
                                    _userDocByIdProvider(uid),
                                  );

                                  return otherDocAsync.maybeWhen(
                                    data: (map) {
                                      final u =
                                          (map?['username'] ?? '')
                                              .toString()
                                              .trim();
                                      final dn =
                                          (map?['displayName'] ?? '')
                                              .toString()
                                              .trim();
                                      final n =
                                          (map?['name'] ?? '')
                                              .toString()
                                              .trim();
                                      final name =
                                          u.isNotEmpty
                                              ? u
                                              : (dn.isNotEmpty ? dn : n);
                                      return _ThreadEmptyStateCard(name: name);
                                    },
                                    orElse:
                                        () => const _ThreadEmptyStateCard(
                                          name: 'them',
                                        ),
                                  );
                                },
                              );
                            },
                          ),
                        ),
                      );
                    }

                    final mine = me ?? '';
                    final uiMsgs =
                        msgs.map((m) {
                          final isMe = m.senderId == mine;
                          final t = TimeOfDay.fromDateTime(m.sentAt);
                          final hh = t.hour.toString().padLeft(2, '0');
                          final mm = t.minute.toString().padLeft(2, '0');

                          final replyToSnippet =
                              (m.metadata is Map)
                                  ? (m.metadata?['replyToSnippet']?.toString())
                                  : null;
                          final replyToWasMine =
                              (m.metadata is Map)
                                  ? (m.metadata?['replyToWasMine'] == true)
                                  : null;
                          final uploadStatus =
                              (m.metadata is Map)
                                  ? (m.metadata?['uploadStatus']?.toString() ??
                                      'uploaded')
                                  : 'uploaded';

                          if (m.type == MessageType.image) {
                            return _UiMessage.image(
                              id: m.id,
                              filePath: m.content,
                              isMe: isMe,
                              timeLabel: '$hh:$mm',
                              senderId: m.senderId,
                              uploadStatus: uploadStatus,
                              replyToSnippet: replyToSnippet,
                              replyToWasMine: replyToWasMine,
                              isRead: m.isRead,
                              readAt: m.readAt,
                              isDeclined: m.isDeclined,
                              declineReason: m.declineReason,
                            );
                          }
                          if (m.type == MessageType.audio) {
                            return _UiMessage.audio(
                              id: m.id,
                              filePath: m.content,
                              isMe: isMe,
                              timeLabel: '$hh:$mm',
                              senderId: m.senderId,
                              uploadStatus: uploadStatus,
                              replyToSnippet: replyToSnippet,
                              replyToWasMine: replyToWasMine,
                              isRead: m.isRead,
                              readAt: m.readAt,
                              isDeclined: m.isDeclined,
                              declineReason: m.declineReason,
                            );
                          }
                          return _UiMessage.text(
                            id: m.id,
                            text: m.content,
                            isMe: isMe,
                            timeLabel: '$hh:$mm',
                            senderId: m.senderId,
                            replyToSnippet: replyToSnippet,
                            replyToWasMine: replyToWasMine,
                            isRead: m.isRead,
                            readAt: m.readAt,
                            isDeclined: m.isDeclined,
                            declineReason: m.declineReason,
                          );
                        }).toList();

                    if (mine.isNotEmpty && !_didMarkAsReadForOpen) {
                      _didMarkAsReadForOpen = true;
                      WidgetsBinding.instance.addPostFrameCallback((_) {
                        ref
                            .read(chatNotifierProvider.notifier)
                            .markAsRead(widget.chatId);
                      });
                    }

                    return ListView.builder(
                      controller: _scroll,
                      reverse: true,
                      padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                      itemCount: uiMsgs.length,
                      itemBuilder: (context, index) {
                        final m = uiMsgs[index];
                        return _Bubble(
                          chatId: widget.chatId,
                          message: m,
                          isPlaying:
                              _playingMessageId == m.id && _player.playing,
                          isThisAudioSelected: _playingMessageId == m.id,
                          positionStream: _player.positionStream,
                          durationStream: _player.durationStream,
                          onAudioTap: () => _togglePlay(m),
                          onLongPress: () => _openMessageActions(m),
                          onDeclineTap:
                              (ctx, msg) =>
                                  _showDeclineReasonBottomSheet(ctx, msg),
                          getStatusText: _getMessageStatusText,
                          getReadStatusIcon: _getMessageReadStatusIcon,
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          // Block status indicator
          Consumer(
            builder: (context, ref, _) {
              final authAsync = ref.watch(authStateProvider);
              final me = authAsync.maybeWhen(
                data: (a) => a.user?.uid,
                orElse: () => null,
              );

              if (me == null) return const SizedBox.shrink();

              final convoAsync = ref.watch(
                chatConversationProvider(widget.chatId),
              );

              return convoAsync.maybeWhen(
                data: (convo) {
                  final otherId = _resolveOtherId(convo, me);
                  if (otherId.isEmpty) return const SizedBox.shrink();

                  final blockedUsers = ref.watch(blockedUsersProvider(me));
                  final amBlocked = blockedUsers.maybeWhen(
                    data: (set) => set.contains(otherId),
                    orElse: () => false,
                  );

                  if (amBlocked) {
                    return Container(
                      padding: const EdgeInsets.all(12),
                      color: Colors.red.shade100,
                      child: Row(
                        children: [
                          Icon(
                            Icons.block,
                            color: Colors.red.shade700,
                            size: 20,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'You have blocked this user. They cannot send you messages.',
                              style: TextStyle(
                                color: Colors.red.shade700,
                                fontSize: 14,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }

                  return const SizedBox.shrink();
                },
                orElse: () => const SizedBox.shrink(),
              );
            },
          ),
          _Composer(
            controller: _controller,
            hintText: 'Message',
            isRecording: _isRecording,
            recordingDuration: _recordingDuration,
            recordingDragOffset: _recordingDragOffset,
            onCancelRecording: _cancelRecording,
            onRecordingDragUpdate: _updateRecordingDrag,
            onRecordingDragEnd: _resetRecordingDrag,
            onTextChanged: () => setState(() {}),
            onPhoto: () async {
              await _pickAndSendImage();
            },
            onMic: () async {
              await _toggleRecording();
            },
            onSend:
                _canSendText
                    ? () async {
                      await _sendText();
                    }
                    : null,
            replySnippet: _replyTo == null ? null : _replySnippet(_replyTo!),
            replyWasMine: _replyTo?.isMe,
            onClearReply: () => setState(() => _replyTo = null),
          ),
        ],
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller;
  final bool isRecording;
  final Duration recordingDuration;
  final double recordingDragOffset;
  final VoidCallback onCancelRecording;
  final Function(double) onRecordingDragUpdate;
  final VoidCallback onRecordingDragEnd;
  final String? hintText;
  final VoidCallback onTextChanged;
  final VoidCallback onPhoto;
  final VoidCallback onMic;
  final VoidCallback? onSend;

  final String? replySnippet;
  final bool? replyWasMine;
  final VoidCallback? onClearReply;

  const _Composer({
    required this.controller,
    required this.isRecording,
    required this.recordingDuration,
    required this.recordingDragOffset,
    required this.onCancelRecording,
    required this.onRecordingDragUpdate,
    required this.onRecordingDragEnd,
    this.hintText,
    required this.onTextChanged,
    required this.onPhoto,
    required this.onMic,
    required this.onSend,
    this.replySnippet,
    this.replyWasMine,
    this.onClearReply,
  });

  @override
  Widget build(BuildContext context) {
    final hasReply = (replySnippet ?? '').trim().isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        border: Border(
          top: BorderSide(color: AppColors.getBorder(context), width: 0.8),
        ),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasReply)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
                decoration: BoxDecoration(
                  color: AppColors.getBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getBorder(context),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 2.5,
                      height: 28,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (replyWasMine ?? false)
                                ? 'Replying to you'
                                : 'Replying',
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.getTextSecondary(context),
                              fontSize: 11,
                            ),
                          ),
                          const SizedBox(height: 1),
                          Text(
                            replySnippet!,
                            style: AppTextStyles.bodySmall,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(width: 4),
                    GestureDetector(
                      onTap: onClearReply,
                      child: Icon(
                        Icons.close_rounded,
                        size: 18,
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                if (!isRecording) ...[
                  IconButton(
                    tooltip: 'Attach photo',
                    icon: const Icon(Icons.image_outlined),
                    onPressed: onPhoto,
                    iconSize: 22,
                    visualDensity: VisualDensity.compact,
                  ),
                ] else ...[
                  const SizedBox(width: 4),
                ],
                Expanded(
                  child:
                      isRecording
                          ? GestureDetector(
                            onHorizontalDragUpdate: (details) {
                              onRecordingDragUpdate(details.delta.dx);

                              // If slid more than 100px to the left, cancel
                              if (recordingDragOffset < -100) {
                                onCancelRecording();
                              }
                            },
                            onHorizontalDragEnd: (_) {
                              onRecordingDragEnd();
                            },
                            child: AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              height: 68,
                              decoration: BoxDecoration(
                                color:
                                    recordingDragOffset < -50
                                        ? Colors.red.withOpacity(0.1)
                                        : AppColors.getBackground(context),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color:
                                      recordingDragOffset < -50
                                          ? Colors.red
                                          : AppColors.primary,
                                  width: 1.5,
                                ),
                              ),
                              child: Row(
                                children: [
                                  const SizedBox(width: 12),
                                  // Animated recording indicator
                                  _AnimatedRecordingDot(),
                                  const SizedBox(width: 10),
                                  // Duration
                                  Text(
                                    '${recordingDuration.inMinutes}:${(recordingDuration.inSeconds % 60).toString().padLeft(2, '0')}',
                                    style: AppTextStyles.bodyMedium.copyWith(
                                      color:
                                          recordingDragOffset < -50
                                              ? Colors.red
                                              : AppColors.primary,
                                      fontWeight: FontWeight.w700,
                                    ),
                                  ),
                                  const Spacer(),
                                  // Slide to cancel instruction
                                  Padding(
                                    padding: const EdgeInsets.only(right: 12),
                                    child: AnimatedOpacity(
                                      opacity:
                                          recordingDragOffset < -50 ? 0.3 : 1.0,
                                      duration: const Duration(
                                        milliseconds: 200,
                                      ),
                                      child: Text(
                                        recordingDragOffset < -50
                                            ? 'Release to cancel'
                                            : 'Slide to cancel',
                                        style: AppTextStyles.caption.copyWith(
                                          color:
                                              recordingDragOffset < -50
                                                  ? Colors.red
                                                  : AppColors.getTextSecondary(
                                                    context,
                                                  ),
                                          fontSize: 11,
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          )
                          : ConstrainedBox(
                            constraints: const BoxConstraints(
                              minHeight: 68,
                              maxHeight: 180,
                            ),
                            child: Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.getBackground(context),
                                borderRadius: BorderRadius.circular(20),
                                border: Border.all(
                                  color: AppColors.getBorder(
                                    context,
                                  ).withOpacity(0.3),
                                  width: 0.5,
                                ),
                              ),
                              child: TextField(
                                controller: controller,
                                onChanged: (_) => onTextChanged(),
                                minLines: 1,
                                maxLines: 4,
                                keyboardType: TextInputType.multiline,
                                textInputAction: TextInputAction.newline,
                                textCapitalization:
                                    TextCapitalization.sentences,
                                decoration: InputDecoration(
                                  hintText: hintText ?? 'Message',
                                  border: InputBorder.none,
                                  isDense: false,
                                  contentPadding: const EdgeInsets.symmetric(
                                    vertical: 2,
                                  ),
                                  hintStyle: AppTextStyles.bodyMedium.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ),
                            ),
                          ),
                ),
                const SizedBox(width: 2),
                IconButton(
                  tooltip: isRecording ? 'Stop recording' : 'Record voice note',
                  icon: Icon(
                    isRecording ? Icons.stop_circle_outlined : Icons.mic_none,
                    size: 22,
                  ),
                  onPressed: onMic,
                  visualDensity: VisualDensity.compact,
                ),
                IconButton(
                  tooltip: 'Send',
                  icon: const Icon(Icons.send),
                  onPressed: onSend,
                  visualDensity: VisualDensity.compact,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// Network image with error handling for avatars (cached)
class _NetworkAvatarImage extends StatelessWidget {
  final String imageUrl;

  const _NetworkAvatarImage(this.imageUrl);

  @override
  Widget build(BuildContext context) {
    return CachedAvatarImage(imageUrl: imageUrl, size: 32);
  }
}

/// Animated recording indicator dot
class _AnimatedRecordingDot extends StatefulWidget {
  const _AnimatedRecordingDot();

  @override
  State<_AnimatedRecordingDot> createState() => _AnimatedRecordingDotState();
}

class _AnimatedRecordingDotState extends State<_AnimatedRecordingDot>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;
  late Animation<double> _scaleAnimation;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(
      begin: 0.7,
      end: 1.2,
    ).animate(CurvedAnimation(parent: _controller, curve: Curves.easeInOut));
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return ScaleTransition(
      scale: _scaleAnimation,
      child: Container(
        width: 10,
        height: 10,
        decoration: BoxDecoration(
          color: AppColors.primary,
          shape: BoxShape.circle,
        ),
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  final String chatId;
  final _UiMessage message;

  final bool isPlaying;
  final bool isThisAudioSelected;
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;
  final VoidCallback onAudioTap;
  final VoidCallback? onLongPress;
  final Function(BuildContext, _UiMessage) onDeclineTap;
  final String Function(_UiMessage) getStatusText;
  final Widget Function(_UiMessage, BuildContext) getReadStatusIcon;

  const _Bubble({
    required this.chatId,
    required this.message,
    required this.isPlaying,
    required this.isThisAudioSelected,
    required this.positionStream,
    required this.durationStream,
    required this.onAudioTap,
    this.onLongPress,
    required this.onDeclineTap,
    required this.getStatusText,
    required this.getReadStatusIcon,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isCompactScreen = screenWidth < 400; // Phone in portrait
    final maxWidth =
        isCompactScreen
            ? screenWidth *
                0.82 // More width on thin screens
            : screenWidth * 0.68; // Less width on wider screens
    final isMe = message.isMe;

    // Mark received unread messages as read when displayed
    if (!isMe && !message.isRead) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        try {
          final chatService = ChatService();
          chatService.markMessageAsRead(chatId, message.id);
        } catch (e) {
          debugPrint('Error marking message as read: $e');
        }
      });
    }

    // Build retry callback for failed media uploads (sender only)
    final VoidCallback? retryCallback;
    if (isMe && message.uploadStatus == 'failed') {
      retryCallback = () {
        ref.read(chatMediaUploadServiceProvider).retryUpload(message.id);
      };
    } else {
      retryCallback = null;
    }

    final userDocAsync = ref.watch(_userDocByIdProvider(message.senderId));
    final subscriptionAsync = ref.watch(subscriptionStatusProvider);
    final showDeclineOption =
        !isMe &&
        !message.isDeclined &&
        subscriptionAsync.maybeWhen(
          data: (status) => !(status.isActive && !status.isExpired),
          orElse: () => true,
        );

    return GestureDetector(
      onLongPress: onLongPress,
      child: userDocAsync.maybeWhen(
        data: (userData) {
          final avatarUrl = _bestAvatarUrl(userData);
          final avatar = CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withOpacity(0.10),
            child:
                avatarUrl != null
                    ? _NetworkAvatarImage(avatarUrl)
                    : const Icon(
                      Icons.person,
                      size: 16,
                      color: AppColors.primary,
                    ),
          );

          return Padding(
            padding:
                isMe
                    ? const EdgeInsets.fromLTRB(
                      8,
                      2,
                      4,
                      2,
                    ) // Sender: minimal left padding
                    : const EdgeInsets.fromLTRB(
                      4,
                      2,
                      8,
                      2,
                    ), // Receiver: minimal right padding
            child: Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[avatar, const SizedBox(width: 8)],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    decoration: BoxDecoration(
                      color:
                          isMe
                              ? AppColors.getSentMessageBackground(context)
                              : AppColors.getSurface(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.getBorder(context),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _MessageBody(
                            message: message,
                            isPlaying: isPlaying,
                            isThisAudioSelected: isThisAudioSelected,
                            positionStream: positionStream,
                            durationStream: durationStream,
                            onAudioTap: onAudioTap,
                            fmt: _fmt,
                            isMe: isMe,
                            onRetry: retryCallback,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            // Polite decline option for non-premium users
                            if (showDeclineOption)
                              Flexible(
                                child: GestureDetector(
                                  onTap: () => onDeclineTap(context, message),
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(
                                      vertical: 2,
                                      horizontal: 6,
                                    ),
                                    constraints: const BoxConstraints(
                                      minHeight: 22,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.getBackground(context),
                                      borderRadius: BorderRadius.circular(8),
                                      border: Border.all(
                                        color: AppColors.getBorder(context),
                                        width: 0.5,
                                      ),
                                    ),
                                    child: FittedBox(
                                      fit: BoxFit.scaleDown,
                                      child: Text(
                                        buildDeclineButtonLabel(),
                                        style: AppTextStyles.caption.copyWith(
                                          color: AppColors.getTextSecondary(
                                            context,
                                          ),
                                          fontSize: 8,
                                        ),
                                        textAlign: TextAlign.center,
                                        maxLines: 1,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            const SizedBox(width: 6),
                            // Status indicator with icon and text
                            Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 2,
                                children: [
                                  getReadStatusIcon(message, context),
                                  Text(
                                    getStatusText(message),
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.getTextOnPrimary(
                                        context,
                                      ),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (isMe) ...[const SizedBox(width: 8), avatar],
              ],
            ),
          );
        },
        orElse: () {
          final avatar = CircleAvatar(
            radius: 18,
            backgroundColor: AppColors.primary.withOpacity(0.10),
            child: const Icon(Icons.person, size: 16, color: AppColors.primary),
          );

          return Padding(
            padding:
                isMe
                    ? const EdgeInsets.fromLTRB(8, 2, 4, 2)
                    : const EdgeInsets.fromLTRB(4, 2, 8, 2),
            child: Row(
              mainAxisAlignment:
                  isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMe) ...[avatar, const SizedBox(width: 8)],
                Flexible(
                  child: Container(
                    padding: const EdgeInsets.fromLTRB(12, 8, 12, 8),
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    decoration: BoxDecoration(
                      color:
                          isMe
                              ? AppColors.getSentMessageBackground(context)
                              : AppColors.getSurface(context),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: AppColors.getBorder(context),
                        width: 0.8,
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        Align(
                          alignment: Alignment.centerLeft,
                          child: _MessageBody(
                            message: message,
                            isPlaying: isPlaying,
                            isThisAudioSelected: isThisAudioSelected,
                            positionStream: positionStream,
                            durationStream: durationStream,
                            onAudioTap: onAudioTap,
                            fmt: _fmt,
                            isMe: isMe,
                            onRetry: retryCallback,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            const SizedBox(width: 1),
                            Padding(
                              padding: const EdgeInsets.only(right: 2),
                              child: Row(
                                mainAxisSize: MainAxisSize.min,
                                spacing: 2,
                                children: [
                                  getReadStatusIcon(message, context),
                                  Text(
                                    getStatusText(message),
                                    style: AppTextStyles.caption.copyWith(
                                      color: AppColors.getTextOnPrimary(
                                        context,
                                      ),
                                      fontSize: 10,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
                if (isMe) ...[const SizedBox(width: 8), avatar],
              ],
            ),
          );
        },
      ),
    );
  }
}

class _MessageBody extends StatelessWidget {
  final _UiMessage message;
  final bool isPlaying;
  final bool isThisAudioSelected;
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;
  final VoidCallback onAudioTap;
  final String Function(Duration) fmt;
  final bool isMe;
  final VoidCallback? onRetry;

  const _MessageBody({
    required this.message,
    required this.isPlaying,
    required this.isThisAudioSelected,
    required this.positionStream,
    required this.durationStream,
    required this.onAudioTap,
    required this.fmt,
    required this.isMe,
    this.onRetry,
  });

  Widget _replyBlock(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 6),
      padding: const EdgeInsets.fromLTRB(8, 6, 8, 6),
      decoration: BoxDecoration(
        color: AppColors.getBackground(context),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          Container(
            width: 2.5,
            height: 28,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (message.replyToWasMine ?? false) ? 'You' : 'Them',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.getTextSecondary(context),
                    fontSize: 10,
                  ),
                ),
                const SizedBox(height: 1),
                Text(
                  message.replyToSnippet!,
                  style: AppTextStyles.bodySmall,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final hasReply = (message.replyToSnippet ?? '').trim().isNotEmpty;

    switch (message.kind) {
      case _MessageKind.text:
        {
          final textColor =
              isMe
                  ? AppColors.getTextOnPrimary(context)
                  : AppColors.getTextPrimary(context);
          final body = Text(
            message.text ?? '',
            style: AppTextStyles.bodyMedium.copyWith(color: textColor),
          );
          if (!hasReply) return body;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_replyBlock(context), body],
          );
        }

      case _MessageKind.image:
        {
          final path = message.filePath;
          final uploadStatus = message.uploadStatus;
          final Widget body;

          if (path == null || path.isEmpty) {
            body = Container(
              height: 140,
              width: 140,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: AppColors.getBackground(context),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(Icons.image_outlined, size: 40),
            );
          } else if (uploadStatus == 'failed') {
            if (isMe && onRetry != null) {
              // Sender: dimmed preview + retry overlay
              body = GestureDetector(
                onTap: onRetry,
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: _buildChatImage(
                        path,
                        fit: BoxFit.cover,
                        opacity: 0.35,
                        context: context,
                      ),
                    ),
                    Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(9),
                          decoration: const BoxDecoration(
                            color: Colors.black54,
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.refresh,
                            color: Colors.white,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 5),
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 6,
                            vertical: 2,
                          ),
                          decoration: BoxDecoration(
                            color: Colors.black54,
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            'Tap to retry',
                            style: AppTextStyles.caption.copyWith(
                              color: Colors.white,
                              fontSize: 10,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              );
            } else {
              // Receiver: graceful "photo unavailable" placeholder
              body = Container(
                height: 140,
                width: 140,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.getBackground(context),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.image_not_supported_outlined,
                      size: 32,
                      color: AppColors.getTextSecondary(context),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Photo unavailable',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.getTextSecondary(context),
                        fontSize: 10,
                      ),
                    ),
                  ],
                ),
              );
            }
          } else if (uploadStatus == 'pending') {
            // Still uploading - show loading state with local preview if available
            body = Stack(
              alignment: Alignment.center,
              children: [
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque: false,
                        barrierColor: Colors.black87,
                        barrierDismissible: true,
                        pageBuilder:
                            (_, __, ___) =>
                                _FullScreenImageViewer(filePath: path),
                        transitionsBuilder: (_, anim, __, child) {
                          return FadeTransition(opacity: anim, child: child);
                        },
                      ),
                    );
                  },
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(12),
                    child: _buildChatImage(
                      path,
                      fit: BoxFit.cover,
                      opacity: 0.6,
                      context: context,
                    ),
                  ),
                ),
                Container(
                  height: 40,
                  width: 40,
                  decoration: BoxDecoration(
                    color: Colors.black.withOpacity(0.5),
                    shape: BoxShape.circle,
                  ),
                  child: const CircularProgressIndicator(
                    strokeWidth: 2,
                    valueColor: AlwaysStoppedAnimation(Colors.white),
                  ),
                ),
              ],
            );
          } else {
            // Uploaded - show full image
            body = GestureDetector(
              onTap: () {
                Navigator.of(context).push(
                  PageRouteBuilder(
                    opaque: false,
                    barrierColor: Colors.black87,
                    barrierDismissible: true,
                    pageBuilder:
                        (_, __, ___) => _FullScreenImageViewer(filePath: path),
                    transitionsBuilder: (_, anim, __, child) {
                      return FadeTransition(opacity: anim, child: child);
                    },
                  ),
                );
              },
              child: ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: _buildChatImage(
                  path,
                  fit: BoxFit.cover,
                  context: context,
                ),
              ),
            );
          }

          if (!hasReply) return body;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_replyBlock(context), body],
          );
        }

      case _MessageKind.audio:
        {
          final path = message.filePath;
          final uploadStatus = message.uploadStatus;
          final Widget body;

          if (path == null || path.isEmpty) {
            body = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.getBackground(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.getBorder(context),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.mic_outlined, size: 18),
                  const SizedBox(width: 6),
                  Text('Voice note', style: AppTextStyles.bodySmall),
                ],
              ),
            );
          } else if (uploadStatus == 'failed') {
            if (isMe && onRetry != null) {
              // Sender: error + retry button
              body = GestureDetector(
                onTap: onRetry,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 8,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.getBackground(context),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: AppColors.getBorder(context),
                      width: 0.8,
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.error_outline,
                        size: 18,
                        color: Colors.red.shade400,
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'Failed',
                        style: AppTextStyles.caption.copyWith(
                          color: AppColors.getTextSecondary(context),
                          fontSize: 11,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Icon(Icons.refresh, size: 16, color: AppColors.primary),
                    ],
                  ),
                ),
              );
            } else {
              // Receiver: graceful fallback
              body = Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.getBackground(context),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.getBorder(context),
                    width: 0.8,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.mic_off_outlined,
                      size: 18,
                      color: AppColors.getTextSecondary(context),
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Unavailable',
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.getTextSecondary(context),
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              );
            }
          } else if (uploadStatus == 'pending') {
            // Uploading - show loading state
            body = Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 6),
              decoration: BoxDecoration(
                color: AppColors.getBackground(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.getBorder(context),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const SizedBox(
                    width: 16,
                    height: 16,
                    child: CircularProgressIndicator(strokeWidth: 1.5),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    'Uploading...',
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.getTextSecondary(context),
                      fontSize: 11,
                    ),
                  ),
                ],
              ),
            );
          } else {
            // Uploaded - show full audio player
            body = Container(
              padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              decoration: BoxDecoration(
                color: AppColors.getBackground(context),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.getBorder(context),
                  width: 0.8,
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    icon: Icon(
                      isPlaying
                          ? Icons.pause_circle_outline
                          : Icons.play_circle_outline,
                      size: 20,
                    ),
                    onPressed: onAudioTap,
                    padding: EdgeInsets.zero,
                  ),
                  Expanded(
                    child: StreamBuilder<Duration?>(
                      stream: durationStream,
                      builder: (context, snapDur) {
                        final dur =
                            isThisAudioSelected
                                ? (snapDur.data ?? Duration.zero)
                                : Duration.zero;

                        return StreamBuilder<Duration>(
                          stream: positionStream,
                          builder: (context, snapPos) {
                            final pos =
                                isThisAudioSelected
                                    ? (snapPos.data ?? Duration.zero)
                                    : Duration.zero;

                            final safeDur =
                                dur.inMilliseconds <= 0
                                    ? const Duration(seconds: 1)
                                    : dur;

                            final value =
                                pos.inMilliseconds / safeDur.inMilliseconds;
                            final clamped =
                                value.isFinite ? value.clamp(0.0, 1.0) : 0.0;

                            return Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                LinearProgressIndicator(
                                  value: clamped,
                                  minHeight: 2,
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  isThisAudioSelected
                                      ? '${fmt(pos)} / ${fmt(dur)}'
                                      : 'Voice note',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                    fontSize: 10,
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 4),
                ],
              ),
            );
          }

          if (!hasReply) return body;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_replyBlock(context), body],
          );
        }
    }
  }
}

class _Avatar extends StatelessWidget {
  final String label;
  final String? imageUrl;

  const _Avatar({required this.label, this.imageUrl});

  String _initials(String s) {
    final parts =
        s.trim().split(RegExp(r'\s+')).where((p) => p.isNotEmpty).toList();
    if (parts.isEmpty) return '?';
    if (parts.length == 1) {
      final w = parts.first;
      return w.isEmpty ? '?' : w.substring(0, 1).toUpperCase();
    }
    final a = parts[0].substring(0, 1).toUpperCase();
    final b = parts[1].substring(0, 1).toUpperCase();
    return '$a$b';
  }

  bool _looksLikeUrl(String? v) {
    final u = (v ?? '').trim().toLowerCase();
    return u.startsWith('http://') || u.startsWith('https://');
  }

  @override
  Widget build(BuildContext context) {
    final u = (imageUrl ?? '').trim();
    final hasUrl = _looksLikeUrl(u);

    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.getSurface(context),
      child:
          hasUrl
              ? _NetworkAvatarImage(u)
              : Text(
                _initials(label),
                style: const TextStyle(fontWeight: FontWeight.w800),
              ),
    );
  }
}

class _UiMessage {
  final String id;
  final _MessageKind kind;
  final bool isMe;
  final String timeLabel;
  final String senderId;

  final String? text;
  final String? filePath;
  final String uploadStatus; // 'pending', 'uploaded', 'failed'

  final String? replyToId;
  final String? replyToSnippet;
  final bool? replyToWasMine;

  final bool isRead;
  final DateTime? readAt;
  final bool isDeclined;
  final String? declineReason;

  const _UiMessage._({
    required this.id,
    required this.kind,
    required this.isMe,
    required this.timeLabel,
    required this.senderId,
    this.text,
    this.filePath,
    this.uploadStatus = 'uploaded',
    this.replyToId,
    this.replyToSnippet,
    this.replyToWasMine,
    this.isRead = false,
    this.readAt,
    this.isDeclined = false,
    this.declineReason,
  });

  factory _UiMessage.text({
    required String id,
    required String text,
    required bool isMe,
    required String timeLabel,
    required String senderId,
    String? replyToId,
    String? replyToSnippet,
    bool? replyToWasMine,
    bool isRead = false,
    DateTime? readAt,
    bool isDeclined = false,
    String? declineReason,
  }) {
    return _UiMessage._(
      id: id,
      kind: _MessageKind.text,
      isMe: isMe,
      timeLabel: timeLabel,
      senderId: senderId,
      text: text,
      replyToId: replyToId,
      replyToSnippet: replyToSnippet,
      replyToWasMine: replyToWasMine,
      isRead: isRead,
      readAt: readAt,
      isDeclined: isDeclined,
      declineReason: declineReason,
    );
  }

  factory _UiMessage.image({
    required String id,
    required String filePath,
    required bool isMe,
    required String timeLabel,
    required String senderId,
    String uploadStatus = 'uploaded',
    String? replyToId,
    String? replyToSnippet,
    bool? replyToWasMine,
    bool isRead = false,
    DateTime? readAt,
    bool isDeclined = false,
    String? declineReason,
  }) {
    return _UiMessage._(
      id: id,
      kind: _MessageKind.image,
      isMe: isMe,
      timeLabel: timeLabel,
      senderId: senderId,
      filePath: filePath,
      uploadStatus: uploadStatus,
      replyToId: replyToId,
      replyToSnippet: replyToSnippet,
      replyToWasMine: replyToWasMine,
      isRead: isRead,
      readAt: readAt,
      isDeclined: isDeclined,
      declineReason: declineReason,
    );
  }

  factory _UiMessage.audio({
    required String id,
    required String filePath,
    required bool isMe,
    required String timeLabel,
    required String senderId,
    String uploadStatus = 'uploaded',
    String? replyToId,
    String? replyToSnippet,
    bool? replyToWasMine,
    bool isRead = false,
    DateTime? readAt,
    bool isDeclined = false,
    String? declineReason,
  }) {
    return _UiMessage._(
      id: id,
      kind: _MessageKind.audio,
      isMe: isMe,
      timeLabel: timeLabel,
      senderId: senderId,
      filePath: filePath,
      uploadStatus: uploadStatus,
      replyToId: replyToId,
      replyToSnippet: replyToSnippet,
      replyToWasMine: replyToWasMine,
      isRead: isRead,
      readAt: readAt,
      isDeclined: isDeclined,
      declineReason: declineReason,
    );
  }
}

// ============================================================================
/// Helper to detect if a path is a network URL.
bool _isNetworkUrl(String path) =>
    path.startsWith('http://') || path.startsWith('https://');

/// Build a chat image widget that handles both local file paths and cloud URLs.
/// After upload, Firestore stores a DO Spaces URL (e.g. https://ams3.digital...)
/// so receivers (and the sender on later sessions) need CachedNetworkImage.
Widget _buildChatImage(
  String path, {
  BoxFit fit = BoxFit.cover,
  double opacity = 1.0,
  required BuildContext context,
}) {
  final errorWidget = Container(
    height: 160,
    width: 160,
    alignment: Alignment.center,
    color: AppColors.getBackground(context),
    child: const Icon(Icons.image_outlined, size: 44),
  );

  if (_isNetworkUrl(path)) {
    // Cloud URL — use CachedNetworkImage (works for receiver + sender on restart)
    return Opacity(
      opacity: opacity,
      child: CachedNetworkImage(
        imageUrl: path,
        fit: fit,
        memCacheWidth: 800,
        placeholder:
            (_, __) => Container(
              height: 160,
              width: 160,
              alignment: Alignment.center,
              color: AppColors.getBackground(context),
              child: const SizedBox(
                width: 24,
                height: 24,
                child: CircularProgressIndicator(strokeWidth: 2),
              ),
            ),
        errorWidget: (_, __, ___) => errorWidget,
      ),
    );
  }

  // Local file path — sender's device still has the file locally
  return Image.file(
    File(path),
    fit: fit,
    opacity: AlwaysStoppedAnimation(opacity),
    errorBuilder: (_, __, ___) => errorWidget,
  );
}

/// Full-screen image viewer with pinch-to-zoom and swipe-to-dismiss
class _FullScreenImageViewer extends StatelessWidget {
  final String filePath;

  const _FullScreenImageViewer({required this.filePath});

  @override
  Widget build(BuildContext context) {
    final Widget imageWidget;
    if (_isNetworkUrl(filePath)) {
      imageWidget = CachedNetworkImage(
        imageUrl: filePath,
        fit: BoxFit.contain,
        placeholder:
            (_, __) => const Center(
              child: CircularProgressIndicator(color: Colors.white54),
            ),
        errorWidget:
            (_, __, ___) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64,
              ),
            ),
      );
    } else {
      imageWidget = Image.file(
        File(filePath),
        fit: BoxFit.contain,
        errorBuilder:
            (_, __, ___) => const Center(
              child: Icon(
                Icons.broken_image_outlined,
                color: Colors.white54,
                size: 64,
              ),
            ),
      );
    }

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: GestureDetector(
        onTap: () => Navigator.of(context).pop(),
        child: Stack(
          children: [
            // Zoomable image
            Center(
              child: InteractiveViewer(
                minScale: 0.5,
                maxScale: 4.0,
                child: Hero(tag: filePath, child: imageWidget),
              ),
            ),
            // Close button
            Positioned(
              top: MediaQuery.of(context).padding.top + 12,
              right: 16,
              child: GestureDetector(
                onTap: () => Navigator.of(context).pop(),
                child: Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.close, color: Colors.white, size: 24),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
