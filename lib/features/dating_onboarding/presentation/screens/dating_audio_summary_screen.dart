import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/application/dating_onboarding_draft.dart';
import 'package:nexus_app_min_test/core/storage/do_spaces_storage_service.dart';
import 'package:nexus_app_min_test/core/storage/providers/media_storage_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:firebase_auth/firebase_auth.dart';

class DatingAudioSummaryScreen extends ConsumerStatefulWidget {
  const DatingAudioSummaryScreen({super.key});

  @override
  ConsumerState<DatingAudioSummaryScreen> createState() =>
      _DatingAudioSummaryScreenState();
}

class _DatingAudioSummaryScreenState
    extends ConsumerState<DatingAudioSummaryScreen> {
  final _player = AudioPlayer();
  bool _isUploading = false;
  bool _uploadError = false;

  // Track which audio is currently playing (1, 2, 3, or null)
  int? _playingIndex;
  bool _isPlaying = false;
  int? _loadingIndex; // Track which audio is currently loading

  @override
  void initState() {
    super.initState();
    // Listen to player state changes
    _player.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
        // Clear loading indicator when audio actually starts playing
        if (state.playing && _loadingIndex != null) {
          _loadingIndex = null;
        }
      });
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _playingIndex = null;
          _loadingIndex = null;
        });
      }
    });
    _uploadAudios();
  }

  Future<void> _uploadAudios() async {
    if (_isUploading) return;

    setState(() => _isUploading = true);

    try {
      final draft = ref.read(datingOnboardingDraftProvider);
      final a1 = draft.audio1Path;
      final a2 = draft.audio2Path;
      final a3 = draft.audio3Path;

      debugPrint('[AudioSummary] Upload check: a1=$a1, a2=$a2, a3=$a3');
      debugPrint(
        '[AudioSummary] URLs: audio1Url=${draft.audio1Url}, audio2Url=${draft.audio2Url}, audio3Url=${draft.audio3Url}',
      );

      // Check if existing URLs are valid before skipping
      if (draft.audio1Url != null &&
          draft.audio2Url != null &&
          draft.audio3Url != null) {
        debugPrint('[AudioSummary] Checking existing URLs for validity...');
        final url1Valid = await _isUrlValid(draft.audio1Url!);
        final url2Valid = await _isUrlValid(draft.audio2Url!);
        final url3Valid = await _isUrlValid(draft.audio3Url!);

        if (url1Valid && url2Valid && url3Valid) {
          debugPrint('[AudioSummary] All URLs valid, skipping upload');
          setState(() => _isUploading = false);
          return;
        }

        debugPrint(
          '[AudioSummary] One or more URLs invalid, clearing and reuploading',
        );
        ref.read(datingOnboardingDraftProvider.notifier).clearAudios();
      }

      if (a1 == null || a2 == null || a3 == null) {
        throw Exception('One or more audio files are missing');
      }

      // Validate files exist before uploading
      final file1 = File(a1);
      final file2 = File(a2);
      final file3 = File(a3);

      debugPrint(
        '[AudioSummary] File 1 exists: ${await file1.exists()}, size: ${await file1.length()}',
      );
      debugPrint(
        '[AudioSummary] File 2 exists: ${await file2.exists()}, size: ${await file2.length()}',
      );
      debugPrint(
        '[AudioSummary] File 3 exists: ${await file3.exists()}, size: ${await file3.length()}',
      );

      if (!await file1.exists() ||
          !await file2.exists() ||
          !await file3.exists()) {
        throw Exception('One or more audio files do not exist on disk');
      }

      debugPrint('[AudioSummary] Uploading audio files...');
      final storage = ref.read(mediaStorageProvider) as DoSpacesStorageService;

      debugPrint('[AudioSummary] Uploading audio 1: $a1');
      final url1 = await storage.uploadFile(localPath: a1);
      debugPrint('[AudioSummary] Audio 1 uploaded: $url1');

      debugPrint('[AudioSummary] Uploading audio 2: $a2');
      final url2 = await storage.uploadFile(localPath: a2);
      debugPrint('[AudioSummary] Audio 2 uploaded: $url2');

      debugPrint('[AudioSummary] Uploading audio 3: $a3');
      final url3 = await storage.uploadFile(localPath: a3);
      debugPrint('[AudioSummary] Audio 3 uploaded: $url3');

      ref
          .read(datingOnboardingDraftProvider.notifier)
          .updateAudioUrls(audio1Url: url1, audio2Url: url2, audio3Url: url3);

      // Persist audio URLs to Firestore under users/{uid}.dating.audioPrompts
      try {
        final ready = ref.read(firebaseReadyProvider);
        final fs = ref.read(firestoreInstanceProvider);
        final uid = FirebaseAuth.instance.currentUser?.uid;

        debugPrint(
          '[AudioSummary] 🔍 Firebase ready: $ready, Firestore: ${fs != null}, UID: $uid',
        );
        debugPrint(
          '[AudioSummary] 🔍 Audio URLs to save: [$url1, $url2, $url3]',
        );

        if (ready && fs != null && uid != null) {
          final payload = {
            'dating': {
              'audioPrompts': [url1, url2, url3],
            },
          };
          debugPrint('[AudioSummary] 🔍 Firestore payload: $payload');

          await fs
              .collection('users')
              .doc(uid)
              .set(payload, SetOptions(merge: true));
          debugPrint('[AudioSummary] ✅ Saved audio URLs to Firestore for $uid');
        } else {
          debugPrint(
            '[AudioSummary] ❌ Skipped Firestore save - ready: $ready, fs: ${fs != null}, uid: $uid',
          );
        }
      } catch (e, stackTrace) {
        debugPrint('[AudioSummary] ❌ Firestore save failed: $e');
        debugPrint('[AudioSummary] Stack trace: $stackTrace');
      }

      setState(() => _isUploading = false);
    } catch (e) {
      debugPrint('Audio upload error: $e');
      setState(() {
        _isUploading = false;
        _uploadError = true;
      });
    }
  }

  @override
  void dispose() {
    // Stop playback before disposing to prevent audio continuing after screen exit
    try {
      _player.stop();
    } catch (_) {}
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(datingOnboardingDraftProvider);

    if (_isUploading) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Uploading Recordings...', style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_uploadError) {
      return Scaffold(
        backgroundColor: AppColors.getBackground(context),
        appBar: AppBar(backgroundColor: AppColors.background, elevation: 0),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.error_outline, size: 64, color: AppColors.primary),
                const SizedBox(height: 16),
                Text('Upload Failed', style: AppTextStyles.headlineMedium),
                const SizedBox(height: 8),
                Text(
                  'Unable to upload recordings. Please check your connection and try again.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () {
                    setState(() => _uploadError = false);
                    _uploadAudios();
                  },
                  child: const Text('Retry'),
                ),
              ],
            ),
          ),
        ),
      );
    }

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Audio Recordings', style: AppTextStyles.titleLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DatingProfileProgressBar(currentStep: 8, totalSteps: 9),
            const SizedBox(height: 18),
            Text('Your Responses', style: AppTextStyles.titleLarge),
            const SizedBox(height: 16),
            _Row(
              n: 1,
              q: 'How would you describe your current relationship with God & why is this relationship important to you?',
              url: draft.audio1Url,
              index: 1,
              isPlaying: _playingIndex == 1 && _isPlaying,
              isPaused: _playingIndex == 1 && !_isPlaying,
              isLoading: _loadingIndex == 1,
              onPlay: () => _play(draft.audio1Url, 1),
            ),
            const SizedBox(height: 14),
            _Row(
              n: 2,
              q: 'What are your thoughts on the role of a husband and a wife in marriage?',
              url: draft.audio2Url,
              index: 2,
              isPlaying: _playingIndex == 2 && _isPlaying,
              isPaused: _playingIndex == 2 && !_isPlaying,
              isLoading: _loadingIndex == 2,
              onPlay: () => _play(draft.audio2Url, 2),
            ),
            const SizedBox(height: 14),
            _Row(
              n: 3,
              q: 'What are your favorite qualities or traits about yourself?',
              url: draft.audio3Url,
              index: 3,
              isPlaying: _playingIndex == 3 && _isPlaying,
              isPaused: _playingIndex == 3 && !_isPlaying,
              isLoading: _loadingIndex == 3,
              onPlay: () => _play(draft.audio3Url, 3),
            ),
            const Spacer(),
            SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed: () {
                        Navigator.of(
                          context,
                        ).pushNamed('/dating/setup/contact-info');
                      },
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        elevation: 0,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(18),
                        ),
                      ),
                      child: Text(
                        'Continue',
                        style: AppTextStyles.labelLarge.copyWith(
                          color: Colors.white,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _play(String? url, int index) async {
    if (url == null) {
      _showSnackBar('Recording not available');
      return;
    }

    try {
      debugPrint('[AudioSummary] Playing URL: $url for index: $index');

      // If already playing this track, pause it
      if (_playingIndex == index && _isPlaying) {
        await _player.pause();
        setState(() => _isPlaying = false);
        return;
      }

      // If paused but same track, resume
      if (_playingIndex == index && !_isPlaying) {
        await _player.play();
        // Loading state will be cleared by playerStateStream listener
        return;
      }

      // New track or different track: stop current and load new one
      if (_playingIndex != index && _playingIndex != null) {
        await _player.stop();
        setState(() {
          _playingIndex = null;
          _isPlaying = false;
          _loadingIndex = null; // Clear loading from previous track
        });
      }

      // Show loading indicator
      setState(() => _loadingIndex = index);

      try {
        // Load and play new track
        await _player.setUrl(url);
        await _player.play();
        // Loading state will be cleared by playerStateStream listener when audio actually starts
        setState(() {
          _playingIndex = index;
        });
      } catch (playError) {
        debugPrint('Error loading/playing audio: $playError');
        setState(() => _loadingIndex = null);
        _showSnackBar('Unable to play recording');
      }
    } catch (e) {
      debugPrint('Play error: $e');
      setState(() => _loadingIndex = null);
      _showSnackBar('Unable to play recording');
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  /// Check if a URL is valid (accessible and has reasonable file size)
  Future<bool> _isUrlValid(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      final statusCode = response.statusCode;
      final contentLength =
          int.tryParse(response.headers['content-length'] ?? '0') ?? 0;

      debugPrint(
        '[AudioSummary] URL check: $url -> status=$statusCode, size=$contentLength',
      );

      // Valid if 200 OK and file is larger than 10KB (reasonable audio minimum)
      return statusCode == 200 && contentLength > 10240;
    } catch (e) {
      debugPrint('[AudioSummary] URL validation failed: $e');
      return false;
    }
  }
}

class _Row extends StatelessWidget {
  final int n;
  final String q;
  final String? url;
  final int index;
  final bool isPlaying;
  final bool isPaused;
  final bool isLoading;
  final VoidCallback onPlay;

  const _Row({
    required this.n,
    required this.q,
    required this.url,
    required this.index,
    required this.isPlaying,
    required this.isPaused,
    required this.isLoading,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final ok = url != null;
    final playing = isPlaying || isPaused;
    final playIcon = isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;
    final playText = isPlaying ? 'Pause' : (isPaused ? 'Resume' : 'Play');
    final displayText =
        isLoading
            ? 'Loading...'
            : (ok ? (playing ? playText : 'Play Recording') : 'Uploading...');

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          CircleAvatar(
            radius: 14,
            backgroundColor: AppColors.primary.withOpacity(0.12),
            child: Text('$n', style: AppTextStyles.labelLarge),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(q, style: AppTextStyles.bodyMedium),
                const SizedBox(height: 10),
                InkWell(
                  onTap: ok ? onPlay : null,
                  borderRadius: BorderRadius.circular(999),
                  child: Container(
                    height: 44,
                    padding: const EdgeInsets.symmetric(horizontal: 14),
                    decoration: BoxDecoration(
                      color:
                          ok
                              ? AppColors.primary.withOpacity(0.10)
                              : AppColors.border,
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        if (isLoading)
                          SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              valueColor: AlwaysStoppedAnimation<Color>(
                                AppColors.primary,
                              ),
                            ),
                          )
                        else
                          Icon(
                            playIcon,
                            color: ok ? AppColors.primary : AppColors.textMuted,
                          ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            displayText,
                            style: AppTextStyles.bodyMedium.copyWith(
                              color:
                                  ok ? AppColors.primary : AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        if (!isLoading)
                          Icon(
                            Icons.graphic_eq_rounded,
                            color: ok ? AppColors.primary : AppColors.textMuted,
                          ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
