import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nexus_app_min_test/core/auth/auth_providers.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/services/chat_service.dart';
import 'package:nexus_app_min_test/core/widgets/disabled_account_gate.dart';
import 'package:nexus_app_min_test/core/providers/service_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:nexus_app_min_test/core/constants/app_constants.dart';
import 'package:nexus_app_min_test/features/subscription/presentation/screens/subscription_screen.dart';

final _userDocByIdProvider =
    StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
      return FirebaseFirestore.instance
          .collection('users')
          .doc(uid)
          .snapshots()
          .map((doc) => doc.exists ? doc.data() : null);
    });

String? _bestAvatarUrl(Map<String, dynamic>? u) {
  if (u == null) return null;

  // Common locations:
  // - profileUrl
  // - photos[0]
  // - nexus2.photos[0]
  final direct = (u['profileUrl'] ?? '').toString().trim();
  if (direct.isNotEmpty) return direct;

  final photos = u['photos'];
  if (photos is List && photos.isNotEmpty) {
    final v = (photos.first ?? '').toString().trim();
    if (v.isNotEmpty) return v;
  }

  final nexus2 = u['nexus2'];
  if (nexus2 is Map) {
    final n2photos = nexus2['photos'];
    if (n2photos is List && n2photos.isNotEmpty) {
      final v = (n2photos.first ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
    final n2url = (nexus2['profileUrl'] ?? '').toString().trim();
    if (n2url.isNotEmpty) return n2url;
  }

  return null;
}

// Audio recording duration constraints (in seconds)
const int _minAudioDuration = 45;
const int _maxAudioDuration = 60;

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

bool? _bestIsOnline(Map<String, dynamic>? u) {
  if (u == null) return null;

  // Try a few common patterns. If none exist, return null (no indicator).
  final direct = u['isOnline'];
  if (direct is bool) return direct;

  final online = u['online'];
  if (online is bool) return online;

  final presence = u['presence'];
  if (presence is Map) {
    final p = presence['isOnline'];
    if (p is bool) return p;
  }

  return null;
}

class _OnlineDot extends StatelessWidget {
  final bool isOnline;
  const _OnlineDot({required this.isOnline});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 10,
      height: 10,
      decoration: BoxDecoration(
        color: isOnline ? Colors.green : AppColors.textMuted,
        shape: BoxShape.circle,
        border: Border.all(color: AppColors.background, width: 2),
      ),
    );
  }
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
  late final AudioPlayer _player;
  late final AudioRecorder _recorder;

  bool _isRecording = false;
  String? _recordingPath;

  String? _playingMessageId;

  _UiMessage? _replyTo;
  bool _didMarkAsReadForOpen = false;
  // Messages are Firestore-backed via chatMessagesProvider.

  @override
  void initState() {
    super.initState();
    _player = AudioPlayer();
    _recorder = AudioRecorder();

    _player.playerStateStream.listen((_) {
      if (!mounted) return;
      setState(() {});
    });

    _player.processingStateStream.listen((state) {
      if (!mounted) return;
      if (state == ProcessingState.completed) {
        setState(() => _playingMessageId = null);
      }
    });
  }

  @override
  void dispose() {
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
      return 'Premium required: you can message up to 3 people for free. Upgrade to message more.';
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
          msg.toLowerCase().contains('chat with only one person') ||
          msg.toLowerCase().contains('message only one person');

      if (looksLikePremiumGate) {
        await _showPremiumRequiredDialog(msg);
      } else {
        _toast(msg);
      }
      return null;
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
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: AppColors.getBorder(context),
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
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
                const SizedBox(height: 8),
                ListTile(
                  leading: const Icon(Icons.reply),
                  title: const Text('Reply'),
                  subtitle: Text(_replySnippet(m)),
                  onTap: () {
                    Navigator.of(context).pop();
                    setState(() => _replyTo = m);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;

    await _ensureSignedInThen(() async {
      final authAsync = ref.read(authStateProvider);
      final me = authAsync.maybeWhen(
        data: (a) => a.user?.uid,
        orElse: () => null,
      );
      if (me == null) return;

      final convo = await ref.read(
        chatConversationProvider(widget.chatId).future,
      );
      final otherId = _resolveOtherId(convo, me);

      if (otherId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not determine the other user in this chat.'),
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

      if (sent == null) return;
      setState(() => _replyTo = null);
      _controller.clear();
      _scrollToBottomSoon();
    });
  }

  Future<void> _openAttachSheet() async {
    await _ensureSignedInThen(() async {
      if (!mounted) return;
      showModalBottomSheet(
        context: context,
        backgroundColor: AppColors.getSurface(context),
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
        ),
        builder: (_) {
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: AppColors.getBorder(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Text('Attach', style: AppTextStyles.titleLarge),
                      const Spacer(),
                      IconButton(
                        icon: const Icon(Icons.close),
                        onPressed: () => Navigator.of(context).pop(),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  _AttachTile(
                    icon: Icons.image_outlined,
                    title: 'Photo',
                    subtitle: 'Pick an image to send',
                    onTap: () async {
                      Navigator.of(context).pop();
                      await _pickAndSendImage();
                    },
                  ),
                  const SizedBox(height: 10),
                  _AttachTile(
                    icon: Icons.attach_file,
                    title: 'File',
                    subtitle: 'Attach a document (coming soon)',
                    onTap: () {
                      Navigator.of(context).pop();
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Files: add file_picker later.'),
                        ),
                      );
                    },
                  ),
                  const SizedBox(height: 10),
                  _AttachTile(
                    icon: Icons.mic_none,
                    title: 'Voice note',
                    subtitle:
                        _isRecording
                            ? 'Recording… tap mic to stop'
                            : 'Tap mic to start recording',
                    onTap: () {
                      Navigator.of(context).pop();
                      _toggleRecording();
                    },
                  ),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  Future<void> _pickAndSendImage() async {
    await _ensureSignedInThen(() async {
      final okPhotos = await _ensurePhotosPermission();
      if (!okPhotos) {
        _toast('Photo permission is required to attach images.');
        return;
      }

      final ok = await _ensurePhotoPermission();
      if (!ok) {
        _toast('Photo permission is required to attach images.');
        return;
      }

      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) {
        _toast('No photo selected.');
        return;
      }

      final authAsync = ref.read(authStateProvider);
      final me = authAsync.maybeWhen(
        data: (a) => a.user?.uid,
        orElse: () => null,
      );
      if (me == null) return;

      final convo = await ref.read(
        chatConversationProvider(widget.chatId).future,
      );
      final otherId = _resolveOtherId(convo, me);
      if (otherId.isEmpty) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Could not determine the other user in this chat.'),
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
      final media = ref.read(mediaServiceProvider);
      final imageUrl = await _runOp(
        () => media.uploadChatImage(
          chatId: widget.chatId,
          userId: me,
          imageFile: File(picked.path),
        ),
        failMessage: 'Could not upload photo. Please try again.',
      );
      if (imageUrl == null || imageUrl.trim().isEmpty) return;
      final sent = await _runOp(() async {
        await ref
            .read(chatNotifierProvider.notifier)
            .sendImage(
              chatId: widget.chatId,
              receiverId: otherId,
              imageUrl: imageUrl,
              metadata: metadata,
            );
        return true;
      }, failMessage: 'Photo failed to send. Please try again.');
      if (sent == null) return;

      if (!mounted) return;
      setState(() => _replyTo = null);
      _scrollToBottomSoon();
    });
  }

  Future<bool> _ensureMicPermission() async {
    final before = await Permission.microphone.status;
    debugPrint('[perm] mic before: $before');

    final requested = await Permission.microphone.request();
    debugPrint('[perm] mic requested: $requested');

    final after = await Permission.microphone.status;
    debugPrint('[perm] mic after: $after');

    return requested.isGranted;
  }

  Future<bool> _ensurePhotoPermission() async {
    final before = await Permission.photos.status;
    debugPrint('[perm] photos before: $before');

    final requested = await Permission.photos.request();
    debugPrint('[perm] photos requested: $requested');

    final after = await Permission.photos.status;
    debugPrint('[perm] photos after: $after');

    return requested.isGranted || requested.isLimited;
  }

  Future<bool> _ensurePhotosPermission() async {
    // iOS: Permission.photos; Android: permission_handler maps appropriately, but manifest still matters.
    final status = await Permission.photos.request();

    if (status.isGranted || status.isLimited) return true;

    if (status.isPermanentlyDenied) {
      _toast(
        'Photo permission is disabled. Please enable it in app Settings to attach images.',
      );
      // Don't automatically open app settings - let user decide if they want to go there
      // await openAppSettings();
      return false;
    }

    if (status.isRestricted) {
      _toast('Photo permission is restricted on this device.');
      return false;
    }

    _toast('Photo permission was denied.');
    return false;
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
        await _stopRecordingAndSend();
      } else {
        await _startRecording();
      }
    });
  }

  Future<void> _startRecording() async {
    final ok = await _ensureMicPermission();
    if (!ok) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Microphone permission is required to record voice notes.',
          ),
        ),
      );
      return;
    }

    final canRecord = await _recorder.hasPermission();
    if (!canRecord) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Microphone permission not granted.')),
      );
      return;
    }

    final path = await _nextRecordingPath();

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
    });

    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('Recording… tap the mic again to stop.')),
    );
  }

  Future<void> _stopRecordingAndSend() async {
    final stoppedPath = await _recorder.stop();

    setState(() {
      _isRecording = false;
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
    if (me == null) return;

    final convo = await ref.read(
      chatConversationProvider(widget.chatId).future,
    );
    final otherId = _resolveOtherId(convo, me);
    if (otherId.isEmpty) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Could not determine the other user in this chat.'),
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

    // Compute duration (seconds) safely without interrupting playback.
    int durationSeconds = 0;
    try {
      final tmp = AudioPlayer();
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
            'Recording too short. Minimum duration is $_minAudioDuration seconds. You recorded ${durationSeconds}s.',
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

    final media = ref.read(mediaServiceProvider);
    final audioUrl = await media.uploadChatAudio(
      chatId: widget.chatId,
      userId: me,
      filePath: path,
    );

    final sent = await _runOp(() async {
      await ref
          .read(chatNotifierProvider.notifier)
          .sendAudio(
            chatId: widget.chatId,
            receiverId: otherId,
            audioUrl: audioUrl,
            durationSeconds: durationSeconds,
            metadata: metadata,
          );
      return true;
    }, failMessage: 'Voice note failed to send. Please try again.');
    if (sent == null) return;

    if (!mounted) return;
    setState(() => _replyTo = null);
    _scrollToBottomSoon();
  }

  Future<void> _startAudioCall() async {
    await _ensureSignedInThen(() async {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Audio call (TODO). Needs WebRTC/signalling later.'),
        ),
      );
    });
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
      final p = msg.filePath!;
      if (p.startsWith('http://') || p.startsWith('https://')) {
        await _player.setUrl(p);
      } else {
        await _player.setFilePath(p);
      }
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
          titlePadding: const EdgeInsets.fromLTRB(24, 20, 20, 12),
          contentPadding: const EdgeInsets.fromLTRB(24, 0, 24, 16),
          actionsPadding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
          title: Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(
                  Icons.workspace_premium,
                  color: AppColors.primary,
                  size: 28,
                ),
              ),
              const SizedBox(width: 12),
              const Expanded(
                child: Text(
                  'Premium Required',
                  style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                ),
              ),
              IconButton(
                tooltip: 'Close',
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(message, style: const TextStyle(fontSize: 15, height: 1.4)),
              const SizedBox(height: 16),
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.05),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Premium includes:',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const _PremiumFeatureRow(
                      icon: Icons.chat_bubble_outline,
                      text: 'Unlimited messaging',
                    ),
                    const SizedBox(height: 6),
                    const _PremiumFeatureRow(
                      icon: Icons.favorite_outline,
                      text: 'View compatibility data',
                    ),
                    const SizedBox(height: 6),
                    const _PremiumFeatureRow(
                      icon: Icons.contact_page_outlined,
                      text: 'Access contact information',
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            Row(
              children: [
                Expanded(
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    style: TextButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    child: const Text('Maybe Later'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  flex: 2,
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
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'View Plans',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ),
              ],
            ),
          ],
        );
      },
    );
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

                final otherUserAsync = ref.watch(_userDocProvider(otherId));

                return otherUserAsync.when(
                  loading:
                      () => Row(
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
                                  'Chat',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  'Loading…',
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  error:
                      (_, __) => Row(
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
                                  'Chat',
                                  style: theme.textTheme.titleMedium?.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                Text(
                                  otherId,
                                  style: theme.textTheme.bodySmall?.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                  overflow: TextOverflow.ellipsis,
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                  data: (u) {
                    final name = _bestDisplayName(u);
                    final avatarUrl = _bestAvatarUrl(u);
                    final isOnline = _bestIsOnline(u);

                    return Row(
                      children: [
                        const SizedBox(width: 8),
                        InkWell(
                          onTap: () => _openOtherUserProfile(otherId),
                          borderRadius: BorderRadius.circular(14),
                          child: Stack(
                            clipBehavior: Clip.none,
                            children: [
                              _Avatar(label: name, imageUrl: avatarUrl),
                              if (isOnline != null)
                                Positioned(
                                  right: -2,
                                  bottom: -2,
                                  child: _OnlineDot(isOnline: isOnline),
                                ),
                            ],
                          ),
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
                              Text(
                                isOnline == true
                                    ? 'Online'
                                    : (isOnline == false
                                        ? 'Offline'
                                        : 'Tap to view profile'),
                                style: theme.textTheme.bodySmall?.copyWith(
                                  color: AppColors.getTextSecondary(context),
                                ),
                                overflow: TextOverflow.ellipsis,
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
          IconButton(
            tooltip: 'Audio call',
            icon: const Icon(Icons.call_outlined),
            onPressed: _startAudioCall,
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

                          if (m.type == MessageType.image) {
                            return _UiMessage.image(
                              id: m.id,
                              filePath: m.content,
                              isMe: isMe,
                              timeLabel: '$hh:$mm',
                              senderId: m.senderId,
                              replyToSnippet: replyToSnippet,
                              replyToWasMine: replyToWasMine,
                            );
                          }
                          if (m.type == MessageType.audio) {
                            return _UiMessage.audio(
                              id: m.id,
                              filePath: m.content,
                              isMe: isMe,
                              timeLabel: '$hh:$mm',
                              senderId: m.senderId,
                              replyToSnippet: replyToSnippet,
                              replyToWasMine: replyToWasMine,
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
                      padding: const EdgeInsets.fromLTRB(14, 12, 14, 12),
                      itemCount: uiMsgs.length,
                      itemBuilder: (context, index) {
                        final m = uiMsgs[index];
                        return _Bubble(
                          message: m,
                          isPlaying:
                              _playingMessageId == m.id && _player.playing,
                          isThisAudioSelected: _playingMessageId == m.id,
                          positionStream: _player.positionStream,
                          durationStream: _player.durationStream,
                          onAudioTap: () => _togglePlay(m),
                          onLongPress: () => _openMessageActions(m),
                        );
                      },
                    );
                  },
                );
              },
            ),
          ),
          _Composer(
            controller: _controller,
            hintText: 'Message',
            isRecording: _isRecording,
            onTextChanged: () => setState(() {}),
            onAttach: () async {
              await _openAttachSheet();
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
  final String? hintText;
  final VoidCallback onTextChanged;
  final VoidCallback onAttach;
  final VoidCallback onMic;
  final VoidCallback? onSend;

  final String? replySnippet;
  final bool? replyWasMine;
  final VoidCallback? onClearReply;

  const _Composer({
    required this.controller,
    required this.isRecording,
    this.hintText,
    required this.onTextChanged,
    required this.onAttach,
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
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        border: Border(top: BorderSide(color: AppColors.getBorder(context))),
      ),
      child: SafeArea(
        top: false,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (hasReply)
              Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 10),
                decoration: BoxDecoration(
                  color: AppColors.getBackground(context),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  children: [
                    Container(
                      width: 3,
                      height: 34,
                      decoration: BoxDecoration(
                        color: AppColors.primary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
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
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            replySnippet!,
                            style: AppTextStyles.bodyMedium,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      tooltip: 'Cancel reply',
                      icon: const Icon(Icons.close),
                      onPressed: onClearReply,
                    ),
                  ],
                ),
              ),
            Row(
              children: [
                IconButton(
                  tooltip: 'Attach',
                  icon: const Icon(Icons.add_circle_outline),
                  onPressed: onAttach,
                ),
                Expanded(
                  child: ConstrainedBox(
                    // Bigger so cursor never clips; expands up to 5 lines.
                    constraints: const BoxConstraints(
                      minHeight: 62,
                      maxHeight: 180,
                    ),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 18,
                        vertical: 16,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.getBackground(context),
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: controller,
                        onChanged: (_) => onTextChanged(),
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: InputDecoration(
                          hintText: hintText ?? 'Message',
                          border: InputBorder.none,
                          isDense: true,
                          contentPadding: EdgeInsets.zero,
                        ),
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: isRecording ? 'Stop recording' : 'Record voice note',
                  icon: Icon(
                    isRecording ? Icons.stop_circle_outlined : Icons.mic_none,
                  ),
                  onPressed: onMic,
                ),
                IconButton(
                  tooltip: 'Send',
                  icon: const Icon(Icons.send),
                  onPressed: onSend,
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _AttachTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _AttachTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: AppColors.getBackground(context),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.getBorder(context)),
          ),
          child: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.10),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(icon, color: AppColors.primary),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title, style: AppTextStyles.labelLarge),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right),
            ],
          ),
        ),
      ),
    );
  }
}

class _Bubble extends ConsumerWidget {
  final _UiMessage message;

  final bool isPlaying;
  final bool isThisAudioSelected;
  final Stream<Duration> positionStream;
  final Stream<Duration?> durationStream;
  final VoidCallback onAudioTap;
  final VoidCallback? onLongPress;

  const _Bubble({
    required this.message,
    required this.isPlaying,
    required this.isThisAudioSelected,
    required this.positionStream,
    required this.durationStream,
    required this.onAudioTap,
    this.onLongPress,
  });

  String _fmt(Duration d) {
    final m = d.inMinutes;
    final s = (d.inSeconds % 60).toString().padLeft(2, '0');
    return '$m:$s';
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final maxWidth = MediaQuery.of(context).size.width * 0.78;
    final isMe = message.isMe;

    final userDocAsync = ref.watch(_userDocByIdProvider(message.senderId));

    return GestureDetector(
      onLongPress: onLongPress,
      child: userDocAsync.maybeWhen(
        data: (userData) {
          final avatarUrl = _bestAvatarUrl(userData);

          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: Padding(
              padding: EdgeInsets.only(left: isMe ? 0 : 8, right: isMe ? 8 : 0),
              child: Row(
                mainAxisAlignment:
                    isMe ? MainAxisAlignment.end : MainAxisAlignment.start,
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  if (!isMe)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        backgroundColor: AppColors.primary.withOpacity(0.10),
                        child:
                            avatarUrl == null
                                ? const Icon(
                                  Icons.person,
                                  size: 14,
                                  color: AppColors.primary,
                                )
                                : null,
                      ),
                    ),
                  ConstrainedBox(
                    constraints: BoxConstraints(maxWidth: maxWidth),
                    child: Container(
                      margin: const EdgeInsets.only(bottom: 10),
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color:
                            isMe
                                ? AppColors.primary.withOpacity(0.14)
                                : AppColors.getSurface(context),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.getBorder(context)),
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
                            ),
                          ),
                          const SizedBox(height: 6),
                          Text(
                            message.timeLabel,
                            style: AppTextStyles.caption.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  if (isMe)
                    Padding(
                      padding: const EdgeInsets.only(left: 8),
                      child: CircleAvatar(
                        radius: 16,
                        backgroundImage:
                            avatarUrl != null ? NetworkImage(avatarUrl) : null,
                        backgroundColor: AppColors.primary.withOpacity(0.10),
                        child:
                            avatarUrl == null
                                ? const Icon(
                                  Icons.person,
                                  size: 14,
                                  color: AppColors.primary,
                                )
                                : null,
                      ),
                    ),
                ],
              ),
            ),
          );
        },
        orElse: () {
          return Align(
            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth),
              child: Container(
                margin: const EdgeInsets.only(bottom: 10),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color:
                      isMe
                          ? AppColors.primary.withOpacity(0.14)
                          : AppColors.getSurface(context),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppColors.getBorder(context)),
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
                      ),
                    ),
                    const SizedBox(height: 6),
                    Text(
                      message.timeLabel,
                      style: AppTextStyles.caption.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                    ),
                  ],
                ),
              ),
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

  const _MessageBody({
    required this.message,
    required this.isPlaying,
    required this.isThisAudioSelected,
    required this.positionStream,
    required this.durationStream,
    required this.onAudioTap,
    required this.fmt,
  });

  Widget _replyBlock(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.getBackground(context),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Row(
        children: [
          Container(
            width: 3,
            height: 34,
            decoration: BoxDecoration(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  (message.replyToWasMine ?? false) ? 'You' : 'Them',
                  style: AppTextStyles.caption.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.replyToSnippet!,
                  style: AppTextStyles.bodyMedium,
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
          final body = Text(
            message.text ?? '',
            style: AppTextStyles.bodyMedium,
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
          final Widget body;
          if (path == null || path.isEmpty) {
            body = Text('(missing image)', style: AppTextStyles.bodyMedium);
          } else {
            body = ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: Image.file(
                File(path),
                fit: BoxFit.cover,
                errorBuilder:
                    (_, __, ___) => Container(
                      height: 160,
                      alignment: Alignment.center,
                      color: AppColors.getBackground(context),
                      child: const Icon(Icons.broken_image_outlined),
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
          final Widget body;
          if (path == null || path.isEmpty) {
            body = Text('(missing audio)', style: AppTextStyles.bodyMedium);
          } else {
            body = Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
              decoration: BoxDecoration(
                color: AppColors.getBackground(context),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.getBorder(context)),
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
                    ),
                    onPressed: onAudioTap,
                  ),
                  const SizedBox(width: 6),
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
                                LinearProgressIndicator(value: clamped),
                                const SizedBox(height: 4),
                                Text(
                                  isThisAudioSelected
                                      ? '${fmt(pos)} / ${fmt(dur)}'
                                      : 'Voice note',
                                  style: AppTextStyles.caption.copyWith(
                                    color: AppColors.getTextSecondary(context),
                                  ),
                                ),
                              ],
                            );
                          },
                        );
                      },
                    ),
                  ),
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
      backgroundImage: hasUrl ? NetworkImage(u) : null,
      child:
          hasUrl
              ? null
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

  final String? replyToId;
  final String? replyToSnippet;
  final bool? replyToWasMine;

  const _UiMessage._({
    required this.id,
    required this.kind,
    required this.isMe,
    required this.timeLabel,
    required this.senderId,
    this.text,
    this.filePath,
    this.replyToId,
    this.replyToSnippet,
    this.replyToWasMine,
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
    );
  }

  factory _UiMessage.image({
    required String id,
    required String filePath,
    required bool isMe,
    required String timeLabel,
    required String senderId,
    String? replyToId,
    String? replyToSnippet,
    bool? replyToWasMine,
  }) {
    return _UiMessage._(
      id: id,
      kind: _MessageKind.image,
      isMe: isMe,
      timeLabel: timeLabel,
      senderId: senderId,
      filePath: filePath,
      replyToId: replyToId,
      replyToSnippet: replyToSnippet,
      replyToWasMine: replyToWasMine,
    );
  }

  factory _UiMessage.audio({
    required String id,
    required String filePath,
    required bool isMe,
    required String timeLabel,
    required String senderId,
    String? replyToId,
    String? replyToSnippet,
    bool? replyToWasMine,
  }) {
    return _UiMessage._(
      id: id,
      kind: _MessageKind.audio,
      isMe: isMe,
      timeLabel: timeLabel,
      senderId: senderId,
      filePath: filePath,
      replyToId: replyToId,
      replyToSnippet: replyToSnippet,
      replyToWasMine: replyToWasMine,
    );
  }
}

// ============================================================================
// PREMIUM FEATURE ROW WIDGET
// ============================================================================

class _PremiumFeatureRow extends StatelessWidget {
  final IconData icon;
  final String text;

  const _PremiumFeatureRow({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: AppColors.primary),
        const SizedBox(width: 8),
        Expanded(
          child: Text(text, style: const TextStyle(fontSize: 13, height: 1.2)),
        ),
      ],
    );
  }
}
