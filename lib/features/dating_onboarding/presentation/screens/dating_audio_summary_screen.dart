import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:just_audio/just_audio.dart';

import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/application/dating_onboarding_draft.dart';

class DatingAudioSummaryScreen extends ConsumerStatefulWidget {
  const DatingAudioSummaryScreen({super.key});

  @override
  ConsumerState<DatingAudioSummaryScreen> createState() =>
      _DatingAudioSummaryScreenState();
}

class _DatingAudioSummaryScreenState
    extends ConsumerState<DatingAudioSummaryScreen> {
  final _player = AudioPlayer();

  @override
  void dispose() {
    _player.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final draft = ref.watch(datingOnboardingDraftProvider);

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
            Text('Your Responses', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 16),

            _Row(
              n: 1,
              q: 'How would you describe your current relationship with God & why is this relationship important to you?',
              path: draft.audio1Path,
              onPlay: () => _play(draft.audio1Path),
            ),
            const SizedBox(height: 14),
            _Row(
              n: 2,
              q: 'What are your thoughts on the role of a husband and a wife in marriage?',
              path: draft.audio2Path,
              onPlay: () => _play(draft.audio2Path),
            ),
            const SizedBox(height: 14),
            _Row(
              n: 3,
              q: 'What are your favorite qualities or traits about yourself?',
              path: draft.audio3Path,
              onPlay: () => _play(draft.audio3Path),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  // next step will be contact info
                  Navigator.of(context).pushNamed('/dating/setup/contact-info');
                },
                child: const Text('Complete Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _play(String? path) async {
    if (path == null) return;
    if (!File(path).existsSync()) return;
    await _player.setFilePath(path);
    await _player.play();
  }
}

class _Row extends StatelessWidget {
  final int n;
  final String q;
  final String? path;
  final VoidCallback onPlay;

  const _Row({
    required this.n,
    required this.q,
    required this.path,
    required this.onPlay,
  });

  @override
  Widget build(BuildContext context) {
    final ok = path != null && File(path!).existsSync();

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
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
                            ok ? 'Play recording' : 'Missing recording',
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
