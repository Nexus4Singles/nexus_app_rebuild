import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/application/dating_onboarding_draft.dart';
import 'package:nexus_app_min_test/core/storage/do_spaces_storage_service.dart';
import 'package:nexus_app_min_test/core/storage/providers/media_storage_provider.dart';

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

  @override
  void initState() {
    super.initState();
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

      // Skip if already uploaded
      if (draft.audio1Url != null &&
          draft.audio2Url != null &&
          draft.audio3Url != null) {
        setState(() => _isUploading = false);
        return;
      }

      if (a1 == null || a2 == null || a3 == null) {
        throw Exception('One or more audio files are missing');
      }

      final storage = ref.read(mediaStorageProvider) as DoSpacesStorageService;
      final url1 = await storage.uploadFile(localPath: a1);
      final url2 = await storage.uploadFile(localPath: a2);
      final url3 = await storage.uploadFile(localPath: a3);

      ref
          .read(datingOnboardingDraftProvider.notifier)
          .updateAudioUrls(audio1Url: url1, audio2Url: url2, audio3Url: url3);

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
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(datingOnboardingDraftProvider);

    if (_isUploading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        body: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const CircularProgressIndicator(),
              const SizedBox(height: 16),
              Text('Uploading recordings...', style: AppTextStyles.bodyMedium),
            ],
          ),
        ),
      );
    }

    if (_uploadError) {
      return Scaffold(
        backgroundColor: AppColors.background,
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
                    color: AppColors.textSecondary,
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
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
              onPlay: () => _play(draft.audio1Url),
            ),
            const SizedBox(height: 14),
            _Row(
              n: 2,
              q: 'What are your thoughts on the role of a husband and a wife in marriage?',
              url: draft.audio2Url,
              onPlay: () => _play(draft.audio2Url),
            ),
            const SizedBox(height: 14),
            _Row(
              n: 3,
              q: 'What are your favorite qualities or traits about yourself?',
              url: draft.audio3Url,
              onPlay: () => _play(draft.audio3Url),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/dating/setup/contact-info');
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
                  style: AppTextStyles.labelLarge.copyWith(color: Colors.white),
                ),
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 54,
              child: OutlinedButton(
                onPressed: _showReRecordConfirmation,
                style: OutlinedButton.styleFrom(
                  foregroundColor: AppColors.primary,
                  elevation: 0,
                  side: BorderSide(color: AppColors.primary, width: 1.5),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                ),
                child: Text(
                  'Clear & Re-record',
                  style: AppTextStyles.labelLarge.copyWith(
                    color: AppColors.primary,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _play(String? url) async {
    if (url == null) {
      _showSnackBar('Recording not available');
      return;
    }

    try {
      debugPrint('[AudioSummary] Playing URL: $url');
      try {
        await _player.stop();
      } catch (_) {}

      await _player.setUrl(url);
      await _player.play();
    } catch (e) {
      debugPrint('Play error: $e');
      _showSnackBar('Unable to play recording');
    }
  }

  void _showSnackBar(String msg) {
    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  void _showReRecordConfirmation() {
    showDialog(
      context: context,
      builder: (BuildContext dialogContext) {
        return AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(
            'Clear Recordings?',
            style: AppTextStyles.titleMedium,
          ),
          content: Text(
            'This will delete all your current recordings and start over.',
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textSecondary,
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(dialogContext),
              child: Text(
                'Cancel',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);
                _clearAndReRecord();
              },
              child: Text(
                'Clear & Re-record',
                style: AppTextStyles.labelLarge.copyWith(
                  color: AppColors.primary,
                ),
              ),
            ),
          ],
        );
      },
    );
  }

  void _clearAndReRecord() {
    ref.read(datingOnboardingDraftProvider.notifier).clearAudios();
    Navigator.of(context).pushReplacementNamed('/dating/setup/audio/q1');
  }
}

class _Row extends StatelessWidget {
  final int n;
  final String q;
  final String? url;
  final VoidCallback onPlay;

  const _Row({
    required this.n,
    required this.q,
    required this.url,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final ok = url != null;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppColors.border),
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
                        Icon(
                          Icons.play_arrow_rounded,
                          color: ok ? AppColors.primary : AppColors.textMuted,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            ok ? 'Play Recording' : 'Uploading...',
                            style: AppTextStyles.bodyMedium.copyWith(
                              color:
                                  ok ? AppColors.primary : AppColors.textMuted,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
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
