import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'dart:async';
import '../../../../core/theme/theme.dart';

/// AudioTeachingCard — Interactive audio playback widget for teaching content
///
/// This widget provides a complete audio player experience with:
/// - Streaming playback from Digital Ocean Spaces URLs
/// - Play/pause controls with animated state indicators
/// - Scrubbing progress bar for seeking
/// - Skip forward/backward buttons (±10 seconds)
/// - Fallback to text if audio unavailable
/// - Proper resource cleanup (memory leak prevention)
/// - Accessibility labels for screen readers
class AudioTeachingCard extends StatefulWidget {
  final String audioUrl;
  final String cardTitle;
  final String cardText; // Fallback text if audio fails
  final VoidCallback? onCompleted;
  final bool autoPlay;

  const AudioTeachingCard({
    super.key,
    required this.audioUrl,
    required this.cardTitle,
    required this.cardText,
    this.onCompleted,
    this.autoPlay = true,
  });

  @override
  State<AudioTeachingCard> createState() => _AudioTeachingCardState();
}

class _AudioTeachingCardState extends State<AudioTeachingCard>
    with TickerProviderStateMixin {
  late final AudioPlayer _audioPlayer;
  late final AnimationController _pulseAnimationController;
  late final Animation<double> _scaleAnimation;

  bool _isAudioReady = false;
  bool _showFallbackText = false;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _initializeAudioPlayer();
    _initializePulseAnimation();
  }

  void _initializeAudioPlayer() {
    _audioPlayer = AudioPlayer();

    // Listen to player state changes
    _audioPlayer.playerStateStream.listen((state) {
      if (!mounted) return;

      // Handle completion
      if (state.processingState == ProcessingState.completed) {
        Future.delayed(const Duration(milliseconds: 1500), () {
          if (mounted) {
            widget.onCompleted?.call();
          }
        });
      }

      setState(() {});
    });

    // Listen for errors
    _audioPlayer.playbackEventStream.listen(
      (_) {},
      onError: (error) {
        if (mounted) {
          setState(() {
            _showFallbackText = true;
            _loadError = 'Unable to load audio. Showing text instead.';
          });
        }
      },
    );

    // Load audio from URL
    _loadAudioFromUrl();
  }

  Future<void> _loadAudioFromUrl() async {
    try {
      // Set URL with timeout to handle slow networks
      await _audioPlayer
          .setAudioSource(
            AudioSource.uri(Uri.parse(widget.audioUrl)),
            preload: true,
          )
          .timeout(
            const Duration(seconds: 30),
            onTimeout: () => throw TimeoutException('Audio load timeout'),
          );

      if (!mounted) return;

      setState(() {
        _isAudioReady = true;
      });

      // Auto-play if enabled
      if (widget.autoPlay) {
        await _audioPlayer.play();
      }
    } on TimeoutException {
      if (mounted) {
        setState(() {
          _showFallbackText = true;
          _loadError = 'Connection timeout. Showing text instead.';
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _showFallbackText = true;
          _loadError = 'Unable to load audio: ${e.toString().split(':').first}';
        });
      }
    }
  }

  void _initializePulseAnimation() {
    _pulseAnimationController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);

    _scaleAnimation = Tween<double>(begin: 0.95, end: 1.05).animate(
      CurvedAnimation(parent: _pulseAnimationController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    // Critical: prevent memory leaks by disposing audio player
    _audioPlayer.dispose();
    _pulseAnimationController.dispose();
    super.dispose();
  }

  void _skipBackward() {
    final pos = _audioPlayer.position;
    final newPos = pos - const Duration(seconds: 10);
    _audioPlayer.seek(
      newPos.isNegative ? Duration.zero : newPos,
    );
  }

  void _skipForward() {
    final duration = _audioPlayer.duration ?? Duration.zero;
    final pos = _audioPlayer.position;
    final newPos = pos + const Duration(seconds: 10);
    _audioPlayer.seek(
      newPos > duration ? duration : newPos,
    );
  }

  void _togglePlayPause() {
    if (_audioPlayer.playing) {
      _audioPlayer.pause();
    } else {
      _audioPlayer.play();
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    // If audio failed to load, show text fallback
    if (_showFallbackText) {
      return _buildTextFallback(isDark);
    }

    // Show loading state while audio is loading
    if (!_isAudioReady) {
      return _buildLoadingState(isDark);
    }

    // Audio is ready — show player
    return _buildPlayerUI(isDark);
  }

  Widget _buildLoadingState(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            widget.cardTitle,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 24),
          Center(
            child: Column(
              children: [
                SizedBox(
                  width: 60,
                  height: 60,
                  child: CircularProgressIndicator(
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppColors.primary,
                    ),
                  ),
                ),
                const SizedBox(height: 16),
                Text(
                  'Loading audio lesson...',
                  style: AppTextStyles.bodySmall.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTextFallback(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.orange.withOpacity(0.1),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: Colors.orange.withOpacity(0.3)),
            ),
            child: Row(
              children: [
                Icon(
                  Icons.info_outline,
                  size: 16,
                  color: Colors.orange,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _loadError ?? 'Audio unavailable',
                    style: AppTextStyles.caption.copyWith(
                      color: Colors.orange,
                    ),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          Text(
            widget.cardTitle,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            widget.cardText,
            style: AppTextStyles.bodySmall.copyWith(
              height: 1.6,
              letterSpacing: 0.15,
              fontWeight: FontWeight.w500,
              color: AppColors.getTextPrimary(context),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPlayerUI(bool isDark) {
    return Padding(
      padding: const EdgeInsets.all(8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Title
          Text(
            widget.cardTitle,
            style: AppTextStyles.bodySmall.copyWith(
              fontWeight: FontWeight.w700,
              height: 1.25,
              letterSpacing: 0.15,
            ),
          ),
          const SizedBox(height: 20),

          // Animated pulse visualizer
          Center(
            child: ScaleTransition(
              scale: _scaleAnimation,
              child: Container(
                width: 100,
                height: 100,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.primary.withOpacity(0.3),
                      AppColors.primary.withOpacity(0.1),
                    ],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.2),
                      blurRadius: 16,
                      spreadRadius: 4,
                    ),
                  ],
                ),
                child: Center(
                  child: Container(
                    width: 60,
                    height: 60,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primary,
                    ),
                    child: Icon(
                      _audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                      color: Colors.white,
                      size: 28,
                    ),
                  ),
                ),
              ),
            ),
          ),

          const SizedBox(height: 24),

          // Progress bar
          StreamBuilder<Duration?>(
            stream: _audioPlayer.durationStream,
            builder: (context, durationSnapshot) {
              final duration = durationSnapshot.data ?? Duration.zero;

              return StreamBuilder<Duration>(
                stream: _audioPlayer.positionStream,
                builder: (context, positionSnapshot) {
                  final position = positionSnapshot.data ?? Duration.zero;

                  return Column(
                    children: [
                      // Seekable progress bar
                      SliderTheme(
                        data: SliderThemeData(
                          trackHeight: 5,
                          thumbShape: RoundSliderThumbShape(
                            enabledThumbRadius: 7,
                          ),
                          overlayShape: RoundSliderOverlayShape(
                            overlayRadius: 12,
                          ),
                        ),
                        child: Slider(
                          value: position.inMilliseconds.toDouble(),
                          max: duration.inMilliseconds.toDouble(),
                          onChanged: (value) {
                            _audioPlayer
                                .seek(Duration(milliseconds: value.toInt()));
                          },
                          activeColor: AppColors.primary,
                          inactiveColor: AppColors.primary.withOpacity(0.2),
                        ),
                      ),

                      // Time labels
                      Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 8),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Text(
                              _formatDuration(position),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                            Text(
                              _formatDuration(duration),
                              style: AppTextStyles.caption.copyWith(
                                color: AppColors.getTextSecondary(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  );
                },
              );
            },
          ),

          const SizedBox(height: 20),

          // Play/Pause button
          Center(
            child: GestureDetector(
              onTap: _togglePlayPause,
              child: Container(
                width: 56,
                height: 56,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: AppColors.primary,
                  boxShadow: [
                    BoxShadow(
                      color: AppColors.primary.withOpacity(0.3),
                      blurRadius: 12,
                      offset: const Offset(0, 4),
                    ),
                  ],
                ),
                child: Icon(
                  _audioPlayer.playing ? Icons.pause : Icons.play_arrow,
                  color: Colors.white,
                  size: 24,
                ),
              ),
            ),
          ),

          const SizedBox(height: 20),

          // Skip backward/forward buttons
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Replay 10s
              OutlinedButton.icon(
                onPressed: _skipBackward,
                icon: const Icon(Icons.replay_10),
                label: const Text('Replay 10s'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
              const SizedBox(width: 12),

              // Skip 10s
              OutlinedButton.icon(
                onPressed: _skipForward,
                icon: const Icon(Icons.forward_10),
                label: const Text('Skip 10s'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  side: BorderSide(color: AppColors.primary),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // Transcript toggle
          Center(
            child: TextButton(
              onPressed: () {
                _showTranscriptBottomSheet();
              },
              child: Text(
                '📄 Read transcript',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showTranscriptBottomSheet() {
    showModalBottomSheet(
      context: context,
      useRootNavigator: true,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (context) {
        return DraggableScrollableSheet(
          expand: false,
          initialChildSize: 0.6,
          minChildSize: 0.4,
          maxChildSize: 0.9,
          builder: (context, scrollController) {
            return SingleChildScrollView(
              controller: scrollController,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: AppColors.primary.withOpacity(0.3),
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Text(
                      'Transcript',
                      style: AppTextStyles.titleSmall.copyWith(
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 12),
                    Text(
                      widget.cardText,
                      style: AppTextStyles.bodySmall.copyWith(
                        height: 1.8,
                        color: AppColors.getTextPrimary(context),
                      ),
                    ),
                    const SizedBox(height: 32),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  String _formatDuration(Duration duration) {
    final minutes = duration.inMinutes;
    final seconds = duration.inSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }
}
