import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart';

import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/application/dating_onboarding_draft.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';

class DatingAudioQuestionScreen extends ConsumerStatefulWidget {
  final int questionNumber;

  const DatingAudioQuestionScreen({super.key, required this.questionNumber});

  @override
  ConsumerState<DatingAudioQuestionScreen> createState() =>
      _DatingAudioQuestionScreenState();
}

class _DatingAudioQuestionScreenState
    extends ConsumerState<DatingAudioQuestionScreen> {
  static const int _maxSeconds = 60;
  static const int _minSeconds = 45;

  final _recorder = AudioRecorder();
  final _player = AudioPlayer();

  Timer? _timer;
  int _elapsed = 0;
  int _recordedDuration = 0;

  bool _isRecording = false;
  bool _isPaused = false;
  bool _busy = false;
  bool _hasRecording = false; // Track if a recording has been made
  bool _isPlaying = false; // Track if recording is being played back
  int _playbackPosition = 0; // Track playback position in milliseconds

  String? _filePath;

  @override
  void initState() {
    super.initState();
    _loadExisting();

    // Listen to player state changes
    _player.playerStateStream.listen((state) {
      setState(() {
        _isPlaying = state.playing;
      });

      // Reset _isPlaying when playback completes
      if (state.processingState == ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
          _playbackPosition = 0;
        });
      }
    });

    // Listen to playback position changes
    _player.positionStream.listen((position) {
      setState(() {
        _playbackPosition = position.inMilliseconds;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    // Stop playback before disposing to prevent audio continuing after screen exit
    if (_isPlaying) {
      _player.stop();
    }
    _player.dispose();
    _recorder.dispose();
    super.dispose();
  }

  void _loadExisting() async {
    final d = ref.read(datingOnboardingDraftProvider);
    switch (widget.questionNumber) {
      case 1:
        _filePath = d.audio1Path;
        break;
      case 2:
        _filePath = d.audio2Path;
        break;
      case 3:
        _filePath = d.audio3Path;
        break;
    }

    // Check if file exists and load its duration
    if (_filePath != null) {
      final file = File(_filePath!);
      if (!await file.exists() || await file.length() == 0) {
        _filePath = null;
      } else {
        // File exists and has data, mark as having a recording
        setState(() => _hasRecording = true);

        // Load the actual duration from the audio file
        try {
          final tempPlayer = AudioPlayer();
          await tempPlayer.setFilePath(_filePath!);
          final duration = tempPlayer.duration;
          await tempPlayer.dispose();

          if (duration != null) {
            final durationSeconds = duration.inSeconds;
            debugPrint(
              '[AudioRecord] Loaded existing recording duration: ${durationSeconds}s',
            );
            setState(() => _recordedDuration = durationSeconds);
          }
        } catch (e) {
          debugPrint('[AudioRecord] Could not probe audio duration: $e');
          // If we can't get duration, assume it's valid since file exists
          setState(() => _recordedDuration = _minSeconds);
        }
      }
    }
  }

  String get _questionText {
    switch (widget.questionNumber) {
      case 1:
        return 'How would you describe your current relationship with God & why is this relationship important to you?';
      case 2:
        return 'What are your thoughts on the role of a husband and a wife in marriage?';
      case 3:
        return 'What are your favorite qualities or traits about yourself?';
      default:
        return '';
    }
  }

  String? get _helperText {
    if (widget.questionNumber == 1) {
      return '(Please answer both parts of this question)';
    }
    if (widget.questionNumber == 3) {
      return '(If you have a good sense of humour, this is also an opportunity to make a great impression on listeners by being creative with your response)';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // Strict timer: only enable Continue when timer reaches 45+ seconds
    final canNext =
        (_isRecording && _elapsed >= _minSeconds) ||
        (_recordedDuration >= _minSeconds && !_isRecording);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Audio Recordings',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DatingProfileProgressBar(
                  currentStep: 5 + widget.questionNumber,
                  totalSteps: 9,
                ),
                const SizedBox(height: 18),
                _StepIndicator(step: widget.questionNumber),
                const SizedBox(height: 18),
                Text(
                  _questionText,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleLarge.copyWith(height: 1.35),
                ),
                if (_helperText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _helperText!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                ],
                const SizedBox(height: 28),
                Text(
                  // Show playback position when playing, otherwise show recording elapsed time
                  _isPlaying
                      ? _formatTime(_playbackPosition ~/ 1000)
                      : _formatTime(_elapsed),
                  style: AppTextStyles.headlineLarge.copyWith(
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                _Waveform(
                  active: _isRecording && !_isPaused,
                  hasRecording: _hasRecording,
                  isPlaying: _isPlaying,
                ),
                const SizedBox(height: 44),

                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    _CircleIconButton(
                      icon: Icons.restart_alt_rounded,
                      label: 'Restart',
                      onTap: _busy ? null : _restart,
                    ),
                    const SizedBox(width: 20),
                    _RecordButton(
                      isRecording: _isRecording,
                      isPaused: _isPaused,
                      onTap: _busy ? null : _toggleRecord,
                    ),
                    const SizedBox(width: 20),
                    _PlayButton(
                      isPlaying: _isPlaying,
                      hasRecording: _hasRecording,
                      canPlayDuringRecording: false,
                      onTap: _hasRecording && !_busy ? _playRecording : null,
                    ),
                  ],
                ),

                const Spacer(),

                SizedBox(
                  width: double.infinity,
                  height: 54,
                  child: ElevatedButton(
                    onPressed:
                        canNext
                            ? () =>
                                (widget.questionNumber == 3
                                    ? _goSummary(context)
                                    : _goNext(context))
                            : null,
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
                const SizedBox(height: 18),
              ],
            ),
          ),
          if (_busy)
            Positioned.fill(
              child: Container(
                color: Colors.black.withOpacity(0.25),
                child: const Center(child: CircularProgressIndicator()),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _toggleRecord() async {
    if (_isRecording && !_isPaused) {
      // If recording is active, stop it
      await _stop();
      return;
    }
    if (_isRecording && _isPaused) {
      // If paused, resume
      await _resume();
      return;
    }

    // Start new recording
    await _start();
  }

  Future<void> _playRecording() async {
    if (_filePath == null) return;

    try {
      if (_isPlaying) {
        // If already playing, pause it
        await _player.pause();
      } else {
        // Otherwise, play the recording
        await _player.setFilePath(_filePath!);
        await _player.play();
      }
    } catch (e) {
      debugPrint('[AudioRecord] Error playing recording: $e');
      _toast('Failed to play recording: $e');
    }
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        _toast('Microphone permission required.');
        return;
      }

      // Delete old audio file if it exists before starting fresh recording
      if (_filePath != null) {
        try {
          final oldFile = File(_filePath!);
          if (await oldFile.exists()) {
            await oldFile.delete();
            debugPrint('[AudioRecord] Deleted old file: $_filePath');
          }
        } catch (e) {
          debugPrint('[AudioRecord] Error deleting old file: $e');
        }
      }

      // Clear previous recording (both path and URL) to force fresh upload
      ref
          .read(datingOnboardingDraftProvider.notifier)
          .clearSingleAudio(widget.questionNumber);

      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/dating_audio_q${widget.questionNumber}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      debugPrint('[AudioRecord] Starting recording to: $path');
      _elapsed = 0;
      _filePath = path;

      await _recorder.start(
        const RecordConfig(
          encoder: AudioEncoder.aacLc,
          bitRate: 128000,
          sampleRate: 44100,
          numChannels: 1,
        ),
        path: path,
      );

      // Verify recording actually started
      final isRecording = await _recorder.isRecording();
      debugPrint('[AudioRecord] Recorder started successfully: $isRecording');

      _isRecording = true;
      _isPaused = false;
      _startTimer();

      // Early guard: if simulator, warn once because iOS sims often produce empty audio.
      if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb) {
        debugPrint(
          '[AudioRecord] Running on iOS simulator? If mic is unavailable, recordings may stay 28 bytes.',
        );
      }
      setState(() {});
    } catch (e) {
      _toast('Failed to start recording: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _resume() async {
    try {
      await _recorder.resume();
      _startTimer();
      setState(() {
        _isPaused = false;
      });
    } catch (_) {}
  }

  Future<void> _stop() async {
    int finalSize = 0;
    try {
      debugPrint('[AudioRecord] Stopping recorder...');
      final path = await _recorder.stop();
      debugPrint('[AudioRecord] Recorder stopped, returned path: $path');

      // CRITICAL: Wait for iOS to flush audio buffer to disk
      await Future.delayed(const Duration(milliseconds: 500));

      // Check file size after giving iOS time to write
      if (path != null) {
        final file = File(path);
        if (await file.exists()) {
          finalSize = await file.length();
          debugPrint(
            '[AudioRecord] File size after recording: $finalSize bytes',
          );
        }
      }
    } catch (e) {
      debugPrint('[AudioRecord] Error stopping recorder: $e');
    }
    _timer?.cancel();

    // Save the recorded duration
    _recordedDuration = _elapsed;

    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    // Only save if minimum duration met and file is not tiny
    if (_recordedDuration >= _minSeconds && finalSize > 2048) {
      debugPrint('[AudioRecord] Recording valid. Setting _hasRecording = true');
      setState(() => _hasRecording = true);
      _saveDraftPath();
    } else {
      final reason =
          finalSize <= 2048
              ? 'No audio was captured (file too small). On iOS simulators the mic may be unavailable.'
              : 'Recording must be at least ${_minSeconds}s long';
      _toast(reason);
      await _restart();
    }
  }

  Future<void> _restart() async {
    HapticFeedback.mediumImpact();
    if (_isRecording) {
      await _stop();
    }

    if (_filePath != null) {
      try {
        final f = File(_filePath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    setState(() {
      _elapsed = 0;
      _recordedDuration = 0;
      _filePath = null;
      _hasRecording = false;
    });

    _saveDraftPath(clear: true);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_isRecording || _isPaused) return;

      setState(() => _elapsed++);

      // Check file size during recording every 5 seconds
      if (_elapsed % 5 == 0 && _filePath != null) {
        try {
          final file = File(_filePath!);
          if (await file.exists()) {
            final size = await file.length();
            debugPrint(
              '[AudioRecord] Recording in progress - file size: $size bytes at ${_elapsed}s',
            );

            // If file is still header-only after 15s, warn in logs.
            if (_elapsed >= 15 && size <= 64) {
              debugPrint(
                '[AudioRecord][WARN] Still 0-byte audio after 15s. Mic/input may be unavailable (common on iOS simulator).',
              );
            }
          }
        } catch (e) {
          debugPrint('[AudioRecord] Error checking file size: $e');
        }
      }

      if (_elapsed >= _maxSeconds) {
        await _stop();
      }
    });
  }

  void _saveDraftPath({bool clear = false}) {
    final notifier = ref.read(datingOnboardingDraftProvider.notifier);
    if (clear) {
      if (widget.questionNumber == 1) notifier.setAudio(a1: null);
      if (widget.questionNumber == 2) notifier.setAudio(a2: null);
      if (widget.questionNumber == 3) notifier.setAudio(a3: null);
      return;
    }

    if (_filePath == null) return;
    if (widget.questionNumber == 1) notifier.setAudio(a1: _filePath);
    if (widget.questionNumber == 2) notifier.setAudio(a2: _filePath);
    if (widget.questionNumber == 3) notifier.setAudio(a3: _filePath);
  }

  void _goNext(BuildContext context) async {
    if (_isRecording) await _stop();
    Navigator.of(
      context,
    ).pushNamed('/dating/setup/audio/q${widget.questionNumber + 1}');
  }

  void _goSummary(BuildContext context) async {
    if (_isRecording) await _stop();
    Navigator.of(context).pushNamed('/dating/setup/audio/summary');
  }

  void _toast(String msg) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
  }

  String _formatTime(int seconds) {
    final m = seconds ~/ 60;
    final s = seconds % 60;
    return '${m.toString().padLeft(2, '0')}:${s.toString().padLeft(2, '0')}';
  }
}

class _StepIndicator extends StatelessWidget {
  final int step;

  const _StepIndicator({required this.step});

  @override
  Widget build(BuildContext context) {
    return CircleAvatar(
      radius: 18,
      backgroundColor: AppColors.primary,
      child: Text(
        '$step',
        style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
      ),
    );
  }
}

class _Waveform extends StatefulWidget {
  final bool active;
  final bool hasRecording;
  final bool isPlaying;
  const _Waveform({
    required this.active,
    required this.hasRecording,
    required this.isPlaying,
  });

  @override
  State<_Waveform> createState() => _WaveformState();
}

class _WaveformState extends State<_Waveform>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 600),
    )..repeat(reverse: true);
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _c,
      builder: (_, __) {
        // Show animation during recording OR during playback
        final isAnimating = widget.active || widget.isPlaying;
        final t = isAnimating ? _c.value : 0.0;

        // Color logic:
        // - Primary (animated) when recording or playing back
        // - Red (static) when recording exists but not currently recording/playing
        // - Border (static) when idle with no recording
        final Color waveColor =
            widget.active || widget.isPlaying
                ? AppColors.primary
                : (widget.hasRecording
                    ? Colors.red.shade400
                    : AppColors.border);

        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(24, (i) {
            final amp = isAnimating ? (0.25 + (t * (i % 5) / 4)) : 0.15;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: 18 + (amp * 42),
              decoration: BoxDecoration(
                color: waveColor,
                borderRadius: BorderRadius.circular(8),
              ),
            );
          }),
        );
      },
    );
  }
}

class _RecordButton extends StatelessWidget {
  final bool isRecording;
  final bool isPaused;
  final VoidCallback? onTap;

  const _RecordButton({
    required this.isRecording,
    required this.isPaused,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;

    if (isRecording) {
      // During recording: show stop icon (stop is the primary action)
      icon = Icons.stop_circle_rounded;
    } else if (isPaused) {
      // If paused (shouldn't happen in current flow): show resume icon
      icon = Icons.play_arrow_rounded;
    } else {
      // Initial state or after recording: show record icon (mic)
      icon = Icons.mic_rounded;
    }

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        width: 86,
        height: 86,
        decoration: BoxDecoration(
          color: AppColors.primary.withOpacity(0.12),
          shape: BoxShape.circle,
        ),
        child: Center(
          child: Container(
            width: 64,
            height: 64,
            decoration: const BoxDecoration(
              color: AppColors.primary,
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: Colors.white, size: 28),
          ),
        ),
      ),
    );
  }
}

class _PlayButton extends StatelessWidget {
  final bool isPlaying;
  final bool hasRecording;
  final bool canPlayDuringRecording;
  final VoidCallback? onTap;

  const _PlayButton({
    required this.isPlaying,
    required this.hasRecording,
    required this.canPlayDuringRecording,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final icon = isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded;
    final enabled = onTap != null;

    return Opacity(
      opacity: enabled ? 1.0 : 0.5,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(999),
        child: Container(
          width: 86,
          height: 86,
          decoration: BoxDecoration(
            color: AppColors.primary.withOpacity(enabled ? 0.12 : 0.05),
            shape: BoxShape.circle,
          ),
          child: Center(
            child: Container(
              width: 64,
              height: 64,
              decoration: BoxDecoration(
                color:
                    enabled
                        ? AppColors.primary
                        : AppColors.primary.withOpacity(0.4),
                shape: BoxShape.circle,
              ),
              child: Icon(icon, color: Colors.white, size: 28),
            ),
          ),
        ),
      ),
    );
  }
}

class _CircleIconButton extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback? onTap;

  const _CircleIconButton({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final enabled = onTap != null;
    return SizedBox(
      height: 86,
      child: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(999),
            child: Container(
              width: 48,
              height: 48,
              decoration: BoxDecoration(
                color:
                    enabled
                        ? AppColors.surface
                        : AppColors.surface.withOpacity(0.6),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.border),
              ),
              child: Icon(
                icon,
                size: 22,
                color: enabled ? AppColors.textPrimary : AppColors.textMuted,
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
          const SizedBox(height: 2),
        ],
      ),
    );
  }
}
