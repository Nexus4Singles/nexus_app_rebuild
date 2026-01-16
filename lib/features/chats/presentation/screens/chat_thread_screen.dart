import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nexus_app_min_test/core/auth/auth_providers.dart';
import 'package:nexus_app_min_test/core/dating/dating_profile_gate.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/services/chat_service.dart';
import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';
import 'package:nexus_app_min_test/core/widgets/disabled_account_gate.dart';
import 'package:nexus_app_min_test/core/providers/service_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';

enum _MessageKind { text, image, audio }

class ChatThreadScreen extends ConsumerStatefulWidget {
  final String chatId;

  const ChatThreadScreen({super.key, required this.chatId});

  @override
  ConsumerState<ChatThreadScreen> createState() => _ChatThreadScreenState();
}

class _ChatThreadScreenState extends ConsumerState<ChatThreadScreen> {
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
    final authAsync = ref.read(authStateProvider);
    final isSignedIn = authAsync.maybeWhen(
      data: (a) => a.isSignedIn,
      orElse: () => false,
    );
    if (!isSignedIn) {
      GuestGuard.requireSignedIn(
        context,
        ref,
        title: 'Create an account to chat',
        message:
            'You\'re currently in guest mode. Create an account to send messages, voice notes, and photos.',
        primaryText: 'Create an account',
        onCreateAccount: () => Navigator.of(context).pushNamed('/signup'),
        onAllowed: () async {},
      );
      return;
    }

    await DatingProfileGate.requireCompleteProfile(
      context,
      ref,
      onAllowed: onAllowed,
    );
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
      backgroundColor: AppColors.surface,
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
                    color: AppColors.border,
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
      final otherId = convo?.getOtherParticipantId(me) ?? '';

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

      await ref
          .read(chatNotifierProvider.notifier)
          .sendMessage(
            chatId: widget.chatId,
            receiverId: otherId,
            content: text,
            metadata: metadata,
          );

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
        backgroundColor: AppColors.surface,
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
                      color: AppColors.border,
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
      final picked = await _picker.pickImage(
        source: ImageSource.gallery,
        imageQuality: 85,
      );
      if (picked == null) return;

      final authAsync = ref.read(authStateProvider);
      final me = authAsync.maybeWhen(
        data: (a) => a.user?.uid,
        orElse: () => null,
      );
      if (me == null) return;

      final convo = await ref.read(
        chatConversationProvider(widget.chatId).future,
      );
      final otherId = convo?.getOtherParticipantId(me) ?? '';
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
      final imageUrl = await media.uploadChatImage(
        chatId: widget.chatId,
        userId: me,
        imageFile: File(picked.path),
      );

      await ref
          .read(chatNotifierProvider.notifier)
          .sendImage(
            chatId: widget.chatId,
            receiverId: otherId,
            imageUrl: imageUrl, // dev: local path; prod: upload -> URL later
            metadata: metadata,
          );

      if (!mounted) return;
      setState(() => _replyTo = null);
      _scrollToBottomSoon();
    });
  }

  Future<bool> _ensureMicPermission() async {
    final status = await Permission.microphone.request();
    return status.isGranted;
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
    final otherId = convo?.getOtherParticipantId(me) ?? '';
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

    final media = ref.read(mediaServiceProvider);
    final audioUrl = await media.uploadChatAudio(
      chatId: widget.chatId,
      userId: me,
      filePath: path,
    );

    await ref
        .read(chatNotifierProvider.notifier)
        .sendAudio(
          chatId: widget.chatId,
          receiverId: otherId,
          audioUrl: audioUrl, // dev: local path; prod: upload -> URL later
          durationSeconds: durationSeconds, // TODO: compute duration later
          metadata: metadata,
        );

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

  void _openOtherUserProfile() {
    Navigator.of(context).pushNamed('/profile');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        title: Row(
          children: [
            const SizedBox(width: 8),
            InkWell(
              onTap: _openOtherUserProfile,
              borderRadius: BorderRadius.circular(14),
              child: _Avatar(label: widget.chatId),
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
                    widget.chatId,
                    style: theme.textTheme.bodySmall?.copyWith(
                      color: AppColors.textMuted,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ],
              ),
            ),
          ],
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
                  error:
                      (_, __) => Center(
                        child: Text(
                          'Unable to load messages right now.',
                          style: AppTextStyles.bodyMedium.copyWith(
                            color: AppColors.textMuted,
                          ),
                        ),
                      ),
                  data: (msgs) {
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

                          // Map Firestore message -> existing UI message type.
                          if (m.type == MessageType.image) {
                            return _UiMessage.image(
                              id: m.id,
                              filePath: m.content, // can be url
                              isMe: isMe,
                              timeLabel: '$hh:$mm',
                              replyToSnippet: replyToSnippet,
                              replyToWasMine: replyToWasMine,
                            );
                          }
                          if (m.type == MessageType.audio) {
                            return _UiMessage.audio(
                              id: m.id,
                              filePath: m.content, // can be url
                              isMe: isMe,
                              timeLabel: '$hh:$mm',
                              replyToSnippet: replyToSnippet,
                              replyToWasMine: replyToWasMine,
                            );
                          }
                          return _UiMessage.text(
                            id: m.id,
                            text: m.content,
                            isMe: isMe,
                            timeLabel: '$hh:$mm',
                            replyToSnippet: replyToSnippet,
                            replyToWasMine: replyToWasMine,
                          );
                        }).toList();

                    // Mark as read once per screen open (avoid firing on every rebuild).
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
            isRecording: _isRecording,
            onTextChanged: () => setState(() {}),
            onAttach: _openAttachSheet,
            onMic: _toggleRecording,
            onSend: _canSendText ? _sendText : null,
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
        color: AppColors.surface,
        border: Border(top: BorderSide(color: AppColors.border)),
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
                  color: AppColors.background,
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
                              color: AppColors.textMuted,
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
                        color: AppColors.background,
                        borderRadius: BorderRadius.circular(24),
                      ),
                      child: TextField(
                        controller: controller,
                        onChanged: (_) => onTextChanged(),
                        minLines: 1,
                        maxLines: 5,
                        keyboardType: TextInputType.multiline,
                        textInputAction: TextInputAction.newline,
                        decoration: const InputDecoration(
                          hintText: 'Message…',
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
            color: AppColors.background,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: AppColors.border),
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
                        color: AppColors.textMuted,
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

class _Bubble extends StatelessWidget {
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
  Widget build(BuildContext context) {
    final maxWidth = MediaQuery.of(context).size.width * 0.78;
    final isMe = message.isMe;

    return GestureDetector(
      onLongPress: onLongPress,
      child: Align(
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
                      : AppColors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: AppColors.border),
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
                    color: AppColors.textMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
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

  Widget _replyBlock() {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(10, 8, 10, 8),
      decoration: BoxDecoration(
        color: AppColors.background,
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
                    color: AppColors.textMuted,
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
            children: [_replyBlock(), body],
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
                      color: AppColors.background,
                      child: const Icon(Icons.broken_image_outlined),
                    ),
              ),
            );
          }
          if (!hasReply) return body;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [_replyBlock(), body],
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
                color: AppColors.background,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
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
                                    color: AppColors.textMuted,
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
            children: [_replyBlock(), body],
          );
        }
    }
  }
}

class _Avatar extends StatelessWidget {
  final String label;
  const _Avatar({required this.label});

  @override
  Widget build(BuildContext context) {
    final initials = label.isEmpty ? 'C' : label.substring(0, 1).toUpperCase();
    return Container(
      width: 38,
      height: 38,
      decoration: BoxDecoration(
        color: AppColors.primary.withOpacity(0.12),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: AppColors.border),
      ),
      alignment: Alignment.center,
      child: Text(
        initials,
        style: AppTextStyles.labelLarge.copyWith(color: AppColors.primary),
      ),
    );
  }
}

class _UiMessage {
  final String id;
  final _MessageKind kind;
  final bool isMe;
  final String timeLabel;

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
    String? replyToId,
    String? replyToSnippet,
    bool? replyToWasMine,
  }) {
    return _UiMessage._(
      id: id,
      kind: _MessageKind.text,
      isMe: isMe,
      timeLabel: timeLabel,
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
    String? replyToId,
    String? replyToSnippet,
    bool? replyToWasMine,
  }) {
    return _UiMessage._(
      id: id,
      kind: _MessageKind.image,
      isMe: isMe,
      timeLabel: timeLabel,
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
    String? replyToId,
    String? replyToSnippet,
    bool? replyToWasMine,
  }) {
    return _UiMessage._(
      id: id,
      kind: _MessageKind.audio,
      isMe: isMe,
      timeLabel: timeLabel,
      filePath: filePath,
      replyToId: replyToId,
      replyToSnippet: replyToSnippet,
      replyToWasMine: replyToWasMine,
    );
  }
}
