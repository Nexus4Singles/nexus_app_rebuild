import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';
import 'package:flutter/foundation.dart';

import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/features/dating_onboarding/application/dating_onboarding_draft.dart';
import 'package:nexus_app_v2/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';
import 'package:nexus_app_v2/core/router/safe_nav.dart';

class DatingAudioQuestionScreen extends ConsumerStatefulWidget {
  final int questionNumber;

  const DatingAudioQuestionScreen({super.key, required this.questionNumber});

  @override
  ConsumerState<DatingAudioQuestionScreen> createState() =>
      _DatingAudioQuestionScreenState();
}

class _DatingAudioQuestionScreenState
    extends ConsumerState<DatingAudioQuestionScreen> {
  static const int _maxSeconds = 90;
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

  // Stream subscriptions – cancelled in dispose() to prevent setState-after-dispose
  StreamSubscription<PlayerState>? _playerStateSub;
  StreamSubscription<Duration>? _positionSub;

  @override
  void initState() {
    super.initState();
    _loadExisting();

    // Listen to player state changes
    _playerStateSub = _player.playerStateStream.listen((state) {
      if (!mounted) return;
      setState(() {
        _isPlaying = state.playing;
      });

      // Reset _isPlaying when playback completes
      if (state.processingState == ProcessingState.completed) {
        if (!mounted) return;
        setState(() {
          _isPlaying = false;
          _playbackPosition = 0;
        });
      }
    });

    // Listen to playback position changes
    _positionSub = _player.positionStream.listen((position) {
      if (!mounted) return;
      setState(() {
        _playbackPosition = position.inMilliseconds;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _playerStateSub?.cancel();
    _positionSub?.cancel();
    try {
      _player.stop();
    } catch (_) {}
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

    // Just check if file exists - don't assume it meets 45s minimum
    if (_filePath != null) {
      final file = File(_filePath!);
      if (!await file.exists() || await file.length() == 0) {
        _filePath = null;
      } else {
        // File exists and has data, mark as having a recording
        if (mounted) setState(() => _hasRecording = true);
      }
    }
    // _recordedDuration stays 0 - user must record to enable Continue
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

    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    // Responsive spacing - tighter at top
    final topPadding = isSmallScreen ? 8.0 : 12.0;
    final progressSpacing = isSmallScreen ? 10.0 : 14.0;
    final questionSpacing = isSmallScreen ? 12.0 : 18.0;
    final timerSpacing = isSmallScreen ? 10.0 : 18.0;
    final buttonsSpacing = isSmallScreen ? 20.0 : 32.0;

    // Responsive font sizing
    final questionFontSize = isSmallScreen ? 15.0 : 16.0;
    final timerFontSize = isSmallScreen ? 28.0 : 32.0;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => navigateBackToHome(context),
        ),
        title: Text(
          'Audio Recordings',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.fromLTRB(20, topPadding, 20, 0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.center,
              children: [
                DatingProfileProgressBar(
                  currentStep: 5 + widget.questionNumber,
                  totalSteps: 9,
                ),
                SizedBox(height: progressSpacing),
                _StepIndicator(step: widget.questionNumber),
                SizedBox(height: progressSpacing),
                Text(
                  _questionText,
                  textAlign: TextAlign.center,
                  style: AppTextStyles.titleMedium.copyWith(
                    height: 1.35,
                    fontSize: questionFontSize,
                  ),
                ),
                if (_helperText != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    _helperText!,
                    textAlign: TextAlign.center,
                    style: AppTextStyles.caption.copyWith(
                      color: AppColors.getTextMuted(context),
                      fontSize: isSmallScreen ? 11.0 : 12.0,
                    ),
                  ),
                ],
                SizedBox(height: questionSpacing),
                Text(
                  // Show playback position when playing, otherwise show recording elapsed time
                  _isPlaying
                      ? _formatTime(_playbackPosition ~/ 1000)
                      : _formatTime(_elapsed),
                  style: AppTextStyles.headlineLarge.copyWith(
                    letterSpacing: 0.5,
                    fontSize: timerFontSize,
                  ),
                ),
                // Debug info: show actual recorded duration vs timer duration
                if (_hasRecording &&
                    !_isRecording &&
                    _recordedDuration != _elapsed)
                  Padding(
                    padding: const EdgeInsets.only(top: 8),
                    child: Text(
                      'Recorded duration: ${_formatTime(_recordedDuration)}',
                      style: AppTextStyles.labelSmall.copyWith(
                        color: AppColors.getTextMuted(context),
                        fontSize: isSmallScreen ? 9.0 : 10.0,
                      ),
                    ),
                  ),
                SizedBox(height: timerSpacing),
                _Waveform(
                  active: _isRecording && !_isPaused,
                  hasRecording: _hasRecording,
                  isPlaying: _isPlaying,
                ),
                SizedBox(height: buttonsSpacing),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.center,
                  children: [
                    // Left control (Restart)
                    _CircleIconButton(
                      icon: Icons.restart_alt_rounded,
                      label: 'Restart',
                      onTap: _busy ? null : _restart,
                    ),

                    // Even spacing so the central record button sits exactly
                    // in the horizontal center of the screen.
                    const SizedBox(width: 36),

                    // Central record control
                    _RecordButton(
                      isRecording: _isRecording,
                      isPaused: _isPaused,
                      canStop: _isRecording && _elapsed >= _minSeconds,
                      onTap: _busy || _hasRecording ? null : _toggleRecord,
                    ),

                    const SizedBox(width: 36),

                    // Right control (Play)
                    _PlayButton(
                      isPlaying: _isPlaying,
                      hasRecording: _hasRecording,
                      canPlayDuringRecording: false,
                      onTap: _hasRecording && !_busy ? _playRecording : null,
                    ),
                  ],
                ),

                // Extra bottom padding so content doesn't hide behind
                // the pinned Continue button.
                SizedBox(
                  height:
                      buttonsSpacing +
                      54 +
                      MediaQuery.of(context).padding.bottom +
                      (isSmallScreen ? 20 : 40),
                ),
              ],
            ),
          ),

          // Continue button pinned to the bottom edge (matching other onboarding screens)
          Positioned(
            left: 20,
            right: 20,
            bottom: MediaQuery.of(context).padding.bottom + 20,
            child: SizedBox(
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
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                ),
              ),
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
    if (_isRecording) {
      // Once minimum duration is met, tapping the button STOPS (finalizes)
      // the recording so the file is properly closed and playable.
      if (_elapsed >= _minSeconds) {
        await _stop();
        return;
      }
      // Before minimum: pause / resume as usual
      if (!_isPaused) {
        await _pause();
        return;
      }
      await _resume();
      return;
    }

    await _start();
  }

  Future<void> _playRecording() async {
    if (_filePath == null) return;

    try {
      // If currently playing, pause instead
      if (_isPlaying) {
        await _player.pause();
        return;
      }

      // Verify the file exists and is non-trivial before trying to play
      final file = File(_filePath!);
      if (!await file.exists()) {
        _toast('Recording file not found. Please record again.');
        setState(() => _hasRecording = false);
        return;
      }
      final fileSize = await file.length();
      if (fileSize <= 2048) {
        _toast(
          'Recording file is too small — may be corrupt. Please re-record.',
        );
        setState(() => _hasRecording = false);
        return;
      }

      // Fully reset player state before loading a new source.
      // Use stop() only – avoid chaining stop+seek+setFilePath+seek+play
      // which triggers "Cannot complete a future with itself" on the
      // internal AudioPlayerPlatform future.
      try {
        await _player.stop();
      } catch (_) {}

      // Use setFilePath (simplest API, avoids double-wrapping).
      // setFilePath internally seeks to zero, so no extra seek needed.
      await _player.setFilePath(_filePath!);
      if (!mounted) return;
      await _player.play();
    } catch (e) {
      String errorMsg = 'Failed to play recording';
      if (e.toString().contains('permission')) {
        errorMsg = 'Audio playback permission denied';
      } else if (e.toString().contains('FileSystemException')) {
        errorMsg = 'Recording file corrupted or unavailable';
      } else if (e.toString().contains('-11829') ||
          e.toString().contains('Cannot Open')) {
        // -11829 on iOS often means the audio session is not ready or the file
        // was produced by the Simulator (which has no real microphone).
        if (defaultTargetPlatform == TargetPlatform.iOS) {
          errorMsg =
              'Cannot play audio. If using iOS Simulator, please test on a physical device.';
        } else {
          errorMsg = 'Cannot open audio file. Please re-record.';
        }
        setState(() => _hasRecording = false);
      }
      _toast('$errorMsg: $e');
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
          }
        } catch (e) {}
      }

      // Clear previous recording (both path and URL) to force fresh upload
      ref
          .read(datingOnboardingDraftProvider.notifier)
          .clearSingleAudio(widget.questionNumber);

      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/dating_audio_q${widget.questionNumber}_${DateTime.now().millisecondsSinceEpoch}.m4a';

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

      // Verify recording actually started (just ensure it started, no need to check result extensively)
      await _recorder.isRecording();
      _isRecording = true;
      _isPaused = false;
      _startTimer();

      // Early guard: if simulator, warn once because iOS sims often produce empty audio.
      if (defaultTargetPlatform == TargetPlatform.iOS && !kIsWeb) {}
      if (mounted) setState(() {});
    } catch (e) {
      _toast('Failed to start recording: $e');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _pause() async {
    try {
      await _recorder.pause();
      _timer?.cancel();
      if (mounted) {
        setState(() {
          _isPaused = true;
        });
      }
    } catch (_) {}
  }

  Future<void> _resume() async {
    try {
      await _recorder.resume();
      _startTimer();
      if (mounted) {
        setState(() {
          _isPaused = false;
        });
      }
    } catch (_) {}
  }

  Future<void> _stop({bool validate = true}) async {
    int finalSize = 0;
    String? recordedPath;
    try {
      recordedPath = await _recorder.stop();
      // CRITICAL: Wait for iOS to flush audio buffer to disk
      await Future.delayed(const Duration(milliseconds: 500));

      // Check file size after giving iOS time to write
      if (recordedPath != null) {
        final file = File(recordedPath);
        if (await file.exists()) {
          finalSize = await file.length();
        }
      }
    } catch (e) {}
    _timer?.cancel();

    // Stop any playback when recording stops
    try {
      await _player.stop();
    } catch (_) {
      // Ignore if already stopped
    }

    // Get actual audio duration from timer (avoids creating a second AudioPlayer
    // which can conflict with iOS audio session and cause -11829 playback errors).
    // Clamp to _maxSeconds as a safety net against any timer edge-case drift.
    _recordedDuration = _elapsed.clamp(0, _maxSeconds);

    if (mounted) {
      setState(() {
        _isRecording = false;
        _isPaused = false;
        _isPlaying = false;
        _playbackPosition = 0;
      });
    }

    // Only save if minimum duration met and file is not tiny.
    // If `validate` is false (we're stopping because the user requested a restart),
    // skip validation and do not show any toast or re-enter restart flow.
    if (validate) {
      if (_recordedDuration >= _minSeconds && finalSize > 2048) {
        if (mounted) setState(() => _hasRecording = true);
        _saveDraftPath();
      } else {
        final reason =
            finalSize <= 2048
                ? 'No audio was captured (file too small). On iOS simulators the mic may be unavailable.'
                : 'Recording must be at least ${_minSeconds}s long (actual: ${_recordedDuration}s)';
        _toast(reason);
        await _restart();
      }
    } else {
      // When not validating (user-initiated restart), ensure we don't persist
      // any incomplete recording and silently return so `_restart` can clear state.
      // Do not call `_saveDraftPath` or show toasts here.
    }
  }

  Future<void> _restart() async {
    HapticFeedback.mediumImpact();
    if (_isRecording) {
      // Stop recording silently for a restart (don't validate or show messages)
      await _stop(validate: false);
    }

    // Stop playback when restarting
    try {
      await _player.stop();
    } catch (_) {
      // Ignore if already stopped
    }

    if (_filePath != null) {
      try {
        final f = File(_filePath!);
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }

    if (mounted) {
      setState(() {
        _elapsed = 0;
        _recordedDuration = 0;
        _filePath = null;
        _hasRecording = false;
        _isPlaying = false;
        _playbackPosition = 0;
      });
    }

    _saveDraftPath(clear: true);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!mounted) return;
      if (!_isRecording || _isPaused) return;

      // Guard: never increment past max (defensive against queued ticks)
      if (_elapsed >= _maxSeconds) return;
      _elapsed++;

      // Cap at maxSeconds and stop IMMEDIATELY (cancel timer first to
      // prevent any further ticks while _stop() is awaited).
      if (_elapsed >= _maxSeconds) {
        _elapsed = _maxSeconds;
        _timer?.cancel();
        if (mounted) setState(() {});
        await _stop();
        return;
      }

      if (mounted) setState(() {});
    });
  }

  void _saveDraftPath({bool clear = false}) {
    final notifier = ref.read(datingOnboardingDraftProvider.notifier);
    if (clear) {
      if (widget.questionNumber == 1) notifier.setAudio(a1: null, d1: null);
      if (widget.questionNumber == 2) notifier.setAudio(a2: null, d2: null);
      if (widget.questionNumber == 3) notifier.setAudio(a3: null, d3: null);
      return;
    }

    if (_filePath == null) return;
    final dur = _recordedDuration;
    if (widget.questionNumber == 1) notifier.setAudio(a1: _filePath, d1: dur);
    if (widget.questionNumber == 2) notifier.setAudio(a2: _filePath, d2: dur);
    if (widget.questionNumber == 3) notifier.setAudio(a3: _filePath, d3: dur);
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
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(msg), backgroundColor: AppColors.primary),
    );
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
        // Only animate during recording, not playback
        final isAnimating = widget.active;
        final t = isAnimating ? _c.value : 0.0;

        // Color logic:
        // - Primary (animated) when actively recording
        // - Primary (static) when playing back
        // - Red (static) when recording exists but idle
        // - Border (static) when idle with no recording
        final Color waveColor =
            widget.active
                ? AppColors.primary
                : widget.isPlaying
                ? AppColors.primary
                : (widget.hasRecording
                    ? Colors.red.shade400
                    : AppColors.getBorder(context));

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
  final bool canStop;
  final VoidCallback? onTap;

  const _RecordButton({
    required this.isRecording,
    required this.isPaused,
    this.canStop = false,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    IconData icon;

    if (isRecording) {
      if (canStop) {
        // 45-90s range: show stop icon so user can finalize the recording
        icon = Icons.stop_rounded;
      } else {
        // < 45s: show pause icon while recording, mic icon while paused
        icon = isPaused ? Icons.mic_rounded : Icons.pause_rounded;
      }
    } else {
      // Initial state or after recording is finalized
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
    return Padding(
      padding: const EdgeInsets.only(top: 18.0),
      child: Column(
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
                        ? AppColors.getSurface(context)
                        : AppColors.getSurface(context).withOpacity(0.6),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.getBorder(context)),
              ),
              child: Icon(
                icon,
                size: 22,
                color:
                    enabled
                        ? AppColors.getTextPrimary(context)
                        : AppColors.getTextMuted(context),
              ),
            ),
          ),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption.copyWith(fontSize: 12)),
        ],
      ),
    );
  }
}
