import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:io';
import 'package:http/http.dart' as http;

import 'package:nexus_app_v2/core/router/safe_nav.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';
import 'package:nexus_app_v2/features/dating_onboarding/application/dating_onboarding_draft.dart';
import 'package:nexus_app_v2/core/storage/do_spaces_storage_service.dart';
import 'package:nexus_app_v2/core/storage/providers/media_storage_provider.dart';
import 'package:nexus_app_v2/core/services/media_service.dart';

// Provider for MediaService to ensure we use the same instance everywhere
final mediaServiceProvider = Provider((ref) => MediaService());

class DatingAudioSummaryScreen extends ConsumerStatefulWidget {
  const DatingAudioSummaryScreen({super.key});

  @override
  ConsumerState<DatingAudioSummaryScreen> createState() =>
      _DatingAudioSummaryScreenState();
}

class _DatingAudioSummaryScreenState
    extends ConsumerState<DatingAudioSummaryScreen> {
  late final MediaService _mediaService;
  bool _isUploading = false;
  bool _uploadError = false;
  String? _errorMessage;

  int? _playingIndex;
  bool _isPlaying = false;
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _mediaService = ref.read(mediaServiceProvider);

    // Listen to the central media service state
    _mediaService.onPlayerStateChanged.listen((state) {
      if (!mounted) return;

      // Clear loading when audio starts playing
      if (state.playing && _isLoading) {
        setState(() => _isLoading = false);
      }

      // Always sync _isPlaying with actual player state (is audio currently playing?)
      setState(() => _isPlaying = state.playing);

      // Reset when playback completes
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _playingIndex = null;
          _isPlaying = false;
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

      if (draft.audio1Url != null &&
          draft.audio2Url != null &&
          draft.audio3Url != null) {
        final url1Valid = await _isUrlValid(draft.audio1Url!);
        final url2Valid = await _isUrlValid(draft.audio2Url!);
        final url3Valid = await _isUrlValid(draft.audio3Url!);

        if (url1Valid && url2Valid && url3Valid) {
          setState(() => _isUploading = false);
          return;
        }
        ref.read(datingOnboardingDraftProvider.notifier).clearAudios();
      }

      if (a1 == null || a2 == null || a3 == null) {
        throw Exception('One or more audio files are missing');
      }

      final file1 = File(a1);
      final file2 = File(a2);
      final file3 = File(a3);

      if (!await file1.exists() ||
          !await file2.exists() ||
          !await file3.exists()) {
        throw Exception('One or more audio files do not exist on disk');
      }

      if (await file1.length() <= 2048 ||
          await file2.length() <= 2048 ||
          await file3.length() <= 2048) {
        _showSnackBar('No audio captured. Please retry on a physical device.');
        setState(() => _isUploading = false);
        return;
      }

      final storage = ref.read(mediaStorageProvider) as DoSpacesStorageService;

      final results = await Future.wait([
        storage.uploadFile(localPath: a1),
        storage.uploadFile(localPath: a2),
        storage.uploadFile(localPath: a3),
      ]);

      ref
          .read(datingOnboardingDraftProvider.notifier)
          .updateAudioUrls(
            audio1Url: results[0],
            audio2Url: results[1],
            audio3Url: results[2],
          );

      await Future.delayed(const Duration(milliseconds: 500));
      if (mounted) setState(() => _isUploading = false);
    } catch (e) {
      if (mounted) {
        setState(() {
          _isUploading = false;
          _uploadError = true;
          _errorMessage = e.toString();
        });
      }
    }
  }

  @override
  void dispose() {
    // Note: We don't dispose the central MediaService here,
    // we just stop playback if this screen is closed.
    _mediaService.stopAudio();
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
        appBar: AppBar(
          backgroundColor: AppColors.getBackground(context),
          elevation: 0,
        ),
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
                  'Unable to upload recordings. Please try again.',
                  textAlign: TextAlign.center,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                if (_errorMessage != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    'Details: ' + _errorMessage!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                  ),
                ],
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
          onPressed: () => navigateBackToHome(context),
        ),
        title: Text('Audio Recordings', style: AppTextStyles.titleLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const DatingProfileProgressBar(currentStep: 8, totalSteps: 9),
            const SizedBox(height: 18),
            Text('Your Responses', style: AppTextStyles.titleLarge),
            const SizedBox(height: 16),
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  children: [
                    _Row(
                      n: 1,
                      q: 'How would you describe your current relationship with God & why is this relationship important to you?',
                      url: draft.audio1Url,
                      index: 1,
                      isPlaying: _playingIndex == 1 && _isPlaying,
                      isPaused: _playingIndex == 1 && !_isPlaying,
                      isLoading: _playingIndex == 1 && _isLoading,
                      onPlay: () => _play(draft.audio1Path, draft.audio1Url, 1),
                    ),
                    const SizedBox(height: 14),
                    _Row(
                      n: 2,
                      q: 'What are your thoughts on the role of a husband and a wife in marriage?',
                      url: draft.audio2Url,
                      index: 2,
                      isPlaying: _playingIndex == 2 && _isPlaying,
                      isPaused: _playingIndex == 2 && !_isPlaying,
                      isLoading: _playingIndex == 2 && _isLoading,
                      onPlay: () => _play(draft.audio2Path, draft.audio2Url, 2),
                    ),
                    const SizedBox(height: 14),
                    _Row(
                      n: 3,
                      q: 'What are your favorite qualities or traits about yourself?',
                      url: draft.audio3Url,
                      index: 3,
                      isPlaying: _playingIndex == 3 && _isPlaying,
                      isPaused: _playingIndex == 3 && !_isPlaying,
                      isLoading: _playingIndex == 3 && _isLoading,
                      onPlay: () => _play(draft.audio3Path, draft.audio3Url, 3),
                    ),
                  ],
                ),
              ),
            ),
            SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    height: 54,
                    child: ElevatedButton(
                      onPressed:
                          () => Navigator.of(
                            context,
                          ).pushNamed('/dating/setup/contact-info'),
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

  Future<void> _play(String? localPath, String? url, int index) async {
    if (localPath == null && url == null) {
      _showSnackBar('Recording not available');
      return;
    }

    try {
      if (_playingIndex == index) {
        if (_isLoading) return;
        if (_isPlaying) {
          await _mediaService.pauseAudio();
          setState(() => _isPlaying = false);
        } else {
          await _mediaService.resumeAudio();
          setState(() => _isPlaying = true);
        }
        return;
      }

      if (_playingIndex != null) await _mediaService.stopAudio();

      setState(() {
        _playingIndex = index;
        _isPlaying = false;
        _isLoading = true;
      });

      bool loadedLocal = false;
      if (localPath != null) {
        final file = File(localPath);
        if (await file.exists() && await file.length() > 2048) {
          await _mediaService.playAudio(localPath);
          loadedLocal = true;
        }
      }
      if (!loadedLocal && url != null) {
        await _mediaService.playAudio(url);
      } else if (!loadedLocal) {
        throw Exception('Local file missing and no remote URL');
      }

      setState(() {
        _isLoading = false;
        _isPlaying = true;
      });
    } catch (e) {
      _showSnackBar('Unable to play recording: $e');
      setState(() {
        _playingIndex = null;
        _isPlaying = false;
        _isLoading = false;
      });
    }
  }

  void _showSnackBar(String msg) {
    if (mounted)
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
      );
  }

  Future<bool> _isUrlValid(String url) async {
    try {
      final response = await http.head(Uri.parse(url));
      return response.statusCode == 200 &&
          (int.tryParse(response.headers['content-length'] ?? '0') ?? 0) >
              10240;
    } catch (_) {
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
    this.isLoading = false,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final ok = url != null;
    final playing = isPlaying || isPaused || isLoading;
    final playIcon =
        isLoading
            ? Icons.hourglass_top_rounded
            : (isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded);
    final playText =
        isLoading
            ? 'Loading...'
            : (isPlaying ? 'Pause' : (isPaused ? 'Resume' : 'Play'));

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
            backgroundColor: AppColors.primary,
            child: Text(
              '$n',
              style: AppTextStyles.labelLarge.copyWith(
                color: AppColors.getTextOnPrimary(context),
              ),
            ),
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
                              : AppColors.getBorder(context),
                      borderRadius: BorderRadius.circular(999),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          playIcon,
                          color:
                              ok
                                  ? AppColors.primary
                                  : AppColors.getTextMuted(context),
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ok
                                ? (playing ? playText : 'Play Recording')
                                : 'Uploading...',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color:
                                  ok
                                      ? AppColors.primary
                                      : AppColors.getTextMuted(context),
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        Icon(
                          Icons.graphic_eq_rounded,
                          color:
                              ok
                                  ? AppColors.primary
                                  : AppColors.getTextMuted(context),
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
