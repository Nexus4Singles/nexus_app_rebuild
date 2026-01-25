import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';
import 'package:path_provider/path_provider.dart';
import 'package:record/record.dart';

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
  int _recordedDuration = 0; // Track completed recording duration

  bool _isRecording = false;
  bool _isPaused = false;
  bool _busy = false;

  String? _filePath;

  @override
  void initState() {
    super.initState();
    _loadExisting();
  }

  @override
  void dispose() {
    _timer?.cancel();
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
            padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
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
                  _formatTime(_elapsed),
                  style: AppTextStyles.headlineLarge.copyWith(
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: 24),
                _Waveform(active: _isRecording && !_isPaused),
                const SizedBox(height: 44),

                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    _CircleIconButton(
                      icon: Icons.restart_alt_rounded,
                      label: 'Restart',
                      onTap: _busy ? null : _restart,
                    ),
                    _RecordButton(
                      isRecording: _isRecording,
                      isPaused: _isPaused,
                      onTap: _busy ? null : _toggleRecord,
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
      await _pause();
      return;
    }
    if (_isRecording && _isPaused) {
      await _resume();
      return;
    }

    await _start();
  }

  Future<void> _start() async {
    setState(() => _busy = true);
    try {
      final ok = await _recorder.hasPermission();
      if (!ok) {
        _toast('Microphone permission required.');
        return;
      }

      final dir = await getApplicationDocumentsDirectory();
      final path =
          '${dir.path}/dating_audio_q${widget.questionNumber}_${DateTime.now().millisecondsSinceEpoch}.m4a';

      _elapsed = 0;
      _filePath = path;

      await _recorder.start(
        const RecordConfig(encoder: AudioEncoder.aacLc),
        path: path,
      );

      _isRecording = true;
      _isPaused = false;
      _startTimer();
      setState(() {});
    } catch (e) {
      _toast('Failed to start recording: $e');
    } finally {
      setState(() => _busy = false);
    }
  }

  Future<void> _pause() async {
    try {
      await _recorder.pause();
      _timer?.cancel();
      setState(() {
        _isPaused = true;
      });
    } catch (_) {}
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
    try {
      await _recorder.stop();
    } catch (_) {}
    _timer?.cancel();

    // Save the recorded duration
    _recordedDuration = _elapsed;

    setState(() {
      _isRecording = false;
      _isPaused = false;
    });

    // Only save if minimum duration met
    if (_recordedDuration >= _minSeconds) {
      _saveDraftPath();
    } else {
      _toast('Recording must be at least ${_minSeconds}s long');
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
    });

    _saveDraftPath(clear: true);
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (_) async {
      if (!_isRecording || _isPaused) return;

      setState(() => _elapsed++);
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
  const _Waveform({required this.active});

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
        final t = widget.active ? _c.value : 0.0;
        return Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: List.generate(24, (i) {
            final amp = widget.active ? (0.25 + (t * (i % 5) / 4)) : 0.15;
            return Container(
              margin: const EdgeInsets.symmetric(horizontal: 2),
              width: 4,
              height: 18 + (amp * 42),
              decoration: BoxDecoration(
                color: widget.active ? AppColors.primary : AppColors.border,
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
    final icon =
        isRecording
            ? (isPaused ? Icons.mic_rounded : Icons.pause_rounded)
            : Icons.mic_rounded;

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
    return Column(
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
      ],
    );
  }
}
