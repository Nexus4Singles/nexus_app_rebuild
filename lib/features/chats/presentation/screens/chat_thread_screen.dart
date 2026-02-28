import 'dart:io';
import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:image_picker/image_picker.dart';
import 'package:just_audio/just_audio.dart';
import 'package:nexus_app_v2/core/auth/auth_providers.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/services/chat_service.dart';
import 'package:nexus_app_v2/core/providers/service_providers.dart';
import 'package:path_provider/path_provider.dart';
import 'package:permission_handler/permission_handler.dart';
import 'package:record/record.dart';
import 'package:nexus_app_v2/core/constants/app_constants.dart';
import 'package:nexus_app_v2/core/widgets/cached_image.dart';
import 'package:nexus_app_v2/core/services/media_service.dart';

final _userDocByIdProvider = StreamProvider.family<Map<String, dynamic>?, String>((ref, uid) {
  return FirebaseFirestore.instance.collection('users').doc(uid).snapshots().map((doc) => doc.exists ? doc.data() : null);
});

String? _bestAvatarUrl(Map<String, dynamic>? u) {
  if (u == null) return null;
  final photos = u['photos'];
  if (photos is List && photos.isNotEmpty) {
    for (final photo in photos) {
      final v = (photo ?? '').toString().trim();
      if (v.isNotEmpty) return v;
    }
  }
  return (u['profileUrl'] ?? '').toString().trim().isEmpty ? null : u['profileUrl'];
}

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
  final _recorder = AudioRecorder();
  late final MediaService _mediaService;

  bool _isRecording = false;
  Duration _recordingDuration = Duration.zero;
  Timer? _recordingTimer;
  String? _playingMessageId;
  bool _isPlaying = false;
  bool _didMarkAsReadForOpen = false;

  @override
  void initState() {
    super.initState();
    _mediaService = ref.read(mediaServiceProvider);
    _mediaService.onPlayerStateChanged.listen((state) {
      if (mounted) {
        setState(() {
          _isPlaying = state.playing;
          if (state.processingState == ProcessingState.completed) _playingMessageId = null;
        });
      }
    });
  }

  @override
  void deactivate() {
    _mediaService.stopAudio();
    super.deactivate();
  }

  @override
  void dispose() {
    _controller.dispose();
    _scroll.dispose();
    _recorder.dispose();
    _recordingTimer?.cancel();
    super.dispose();
  }

  Future<void> _togglePlay(_UiMessage msg) async {
    if (msg.kind != _MessageKind.audio || msg.filePath == null) return;
    if (_playingMessageId == msg.id) {
      _isPlaying ? await _mediaService.pauseAudio() : await _mediaService.resumeAudio();
      return;
    }
    await _mediaService.stopAudio();
    setState(() { _playingMessageId = msg.id; _isPlaying = true; });
    await _mediaService.playAudio(msg.filePath!);
  }

  void _scrollToBottomSoon() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scroll.hasClients) _scroll.animateTo(0, duration: const Duration(milliseconds: 250), curve: Curves.easeOut);
    });
  }

  Future<void> _sendText() async {
    final text = _controller.text.trim();
    if (text.isEmpty) return;
    final me = ref.read(authStateProvider).valueOrNull?.user?.uid;
    if (me == null) return;
    final convo = await ref.read(chatConversationProvider(widget.chatId).future);
    final otherId = convo?.getOtherParticipantId(me) ?? '';
    if (otherId.isEmpty) return;

    await ref.read(chatNotifierProvider.notifier).sendMessage(chatId: widget.chatId, receiverId: otherId, content: text);
    _controller.clear();
    _scrollToBottomSoon();
  }

  @override
  Widget build(BuildContext context) {
    final authAsync = ref.watch(authStateProvider);
    final me = authAsync.maybeWhen(data: (a) => a.user?.uid, orElse: () => null);
    final messagesAsync = ref.watch(chatMessagesProvider(widget.chatId));

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(title: const Text('Chat'), backgroundColor: AppColors.getBackground(context), elevation: 0),
      body: Column(
        children: [
          Expanded(
            child: messagesAsync.when(
              loading: () => const Center(child: CircularProgressIndicator()),
              error: (e, __) => Center(child: Text('Error: $e')),
              data: (msgs) {
                final uiMsgs = msgs.map((m) {
                  final isMe = m.senderId == me;
                  if (m.type == MessageType.image) return _UiMessage.image(id: m.id, filePath: m.content, isMe: isMe, senderId: m.senderId);
                  if (m.type == MessageType.audio) return _UiMessage.audio(id: m.id, filePath: m.content, isMe: isMe, senderId: m.senderId);
                  return _UiMessage.text(id: m.id, text: m.content, isMe: isMe, senderId: m.senderId);
                }).toList();

                if (me != null && !_didMarkAsReadForOpen) {
                  _didMarkAsReadForOpen = true;
                  WidgetsBinding.instance.addPostFrameCallback((_) {
                    ref.read(chatNotifierProvider.notifier).markAsRead(widget.chatId);
                  });
                }

                return ListView.builder(
                  controller: _scroll, reverse: true, padding: const EdgeInsets.all(14),
                  itemCount: uiMsgs.length,
                  itemBuilder: (context, index) {
                    final m = uiMsgs[index];
                    return _Bubble(
                      message: m, isPlaying: _playingMessageId == m.id && _isPlaying,
                      isThisAudioSelected: _playingMessageId == m.id,
                      positionStream: _mediaService.onPositionChanged,
                      durationStream: _mediaService.onDurationChanged,
                      onAudioTap: () => _togglePlay(m),
                    );
                  },
                );
              },
            ),
          ),
          _Composer(controller: _controller, isRecording: _isRecording, recordingDuration: _recordingDuration, onTextChanged: () => setState((){}), onSend: _sendText),
        ],
      ),
    );
  }
}

class _Bubble extends StatelessWidget {
  final _UiMessage message; final bool isPlaying; final bool isThisAudioSelected;
  final Stream<Duration> positionStream; final Stream<Duration?> durationStream; final VoidCallback onAudioTap;
  const _Bubble({required this.message, required this.isPlaying, required this.isThisAudioSelected, required this.positionStream, required this.durationStream, required this.onAudioTap});

  @override
  Widget build(BuildContext context) {
    final isMe = message.isMe;
    return Align(
      alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMe ? AppColors.getSentMessageBackground(context) : AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppColors.getBorder(context)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMe) Consumer(builder: (context, ref, _) {
              final userAsync = ref.watch(_userDocByIdProvider(message.senderId));
              return userAsync.maybeWhen(
                data: (u) => Row(mainAxisSize: MainAxisSize.min, children: [CircleAvatar(radius: 12, backgroundImage: _bestAvatarUrl(u) != null ? NetworkImage(_bestAvatarUrl(u)!) : null, child: _bestAvatarUrl(u) == null ? const Icon(Icons.person, size: 12) : null), const SizedBox(width: 8)]),
                orElse: () => const SizedBox.shrink(),
              );
            }),
            message.kind == _MessageKind.audio 
              ? Row(mainAxisSize: MainAxisSize.min, children: [IconButton(icon: Icon(isPlaying ? Icons.pause : Icons.play_arrow), onPressed: onAudioTap), const Text('Voice Note')])
              : message.kind == _MessageKind.image 
                ? ConstrainedBox(constraints: const BoxConstraints(maxWidth: 200, maxHeight: 200), child: ClipRRect(borderRadius: BorderRadius.circular(12), child: CachedImage(message.filePath!, fit: BoxFit.cover)))
                : Text(message.text ?? '', style: TextStyle(color: isMe ? Colors.white : Colors.black)),
          ],
        ),
      ),
    );
  }
}

class _Composer extends StatelessWidget {
  final TextEditingController controller; final bool isRecording; final Duration recordingDuration; final VoidCallback onTextChanged; final VoidCallback onSend;
  const _Composer({required this.controller, required this.isRecording, required this.recordingDuration, required this.onTextChanged, required this.onSend});
  @override
  Widget build(BuildContext context) => Container(padding: const EdgeInsets.all(12), child: Row(children: [Expanded(child: TextField(controller: controller, onChanged: (_) => onTextChanged())), IconButton(icon: const Icon(Icons.send), onPressed: onSend)]));
}

class _UiMessage {
  final String id; final _MessageKind kind; final bool isMe; final String senderId; final String? text; final String? filePath;
  const _UiMessage({required this.id, required this.kind, required this.isMe, required this.senderId, this.text, this.filePath});
  factory _UiMessage.text({required String id, required String text, required bool isMe, required String senderId}) => _UiMessage(id: id, kind: _MessageKind.text, isMe: isMe, senderId: senderId, text: text);
  factory _UiMessage.image({required String id, required String filePath, required bool isMe, required String senderId}) => _UiMessage(id: id, kind: _MessageKind.image, isMe: isMe, senderId: senderId, filePath: filePath);
  factory _UiMessage.audio({required String id, required String filePath, required bool isMe, required String senderId}) => _UiMessage(id: id, kind: _MessageKind.audio, isMe: isMe, senderId: senderId, filePath: filePath);
}
