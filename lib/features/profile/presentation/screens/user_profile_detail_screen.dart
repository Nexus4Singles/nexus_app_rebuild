import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/core/providers/auth_status_provider.dart';
import 'package:nexus_app_v2/core/providers/service_providers.dart';

class UserProfileDetailScreen extends ConsumerStatefulWidget {
  final String name;

  const UserProfileDetailScreen({super.key, required this.name});

  @override
  ConsumerState<UserProfileDetailScreen> createState() =>
      _UserProfileDetailScreenState();
}

class _UserProfileDetailScreenState
    extends ConsumerState<UserProfileDetailScreen> {
  @override
  void deactivate() {
    // Stop audio playback when navigating away from screen
    final media = ref.read(mediaServiceProvider);
    try {
      media.stopAudio();
    } catch (_) {}
    super.deactivate();
  }

  @override
  Widget build(BuildContext context) {
    final isLoggedIn = ref.watch(isLoggedInProvider);
    final media = ref.read(mediaServiceProvider);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        title: Text('Profile', style: AppTextStyles.headlineMedium),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.getBorder(context)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      color: AppColors.primary.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(22),
                    ),
                    child: Icon(
                      Icons.person,
                      color: AppColors.primary,
                      size: 34,
                    ),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(widget.name, style: AppTextStyles.headlineSmall),
                        const SizedBox(height: 4),
                        Text(
                          'Safe Mode profile view',
                          style: AppTextStyles.caption,
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),
            Text('About', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            Text(
              'This is a placeholder profile detail flow.\n\nLater: wire to real user profiles + matching via backend.',
              style: AppTextStyles.bodyMedium,
            ),

            const SizedBox(height: 20),
            Text('Audio', style: AppTextStyles.titleLarge),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.getBorder(context)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Dev test: audio playback via MediaService (audioplayers).',
                    style: AppTextStyles.bodyMedium,
                  ),
                  const SizedBox(height: 12),
                  Row(
                    children: [
                      Expanded(
                        child: ElevatedButton(
                          onPressed: () async {
                            if (!isLoggedIn) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: const Text(
                                    'Please sign in to play audio.',
                                  ),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                              return;
                            }
                            // Temporary sample URL for profile audio playback.
                            const testUrl =
                                'https://www.soundhelix.com/examples/mp3/SoundHelix-Song-1.mp3';
                            try {
                              await media.playAudioFromUrl(testUrl);
                            } catch (e) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Audio failed: $e'),
                                  backgroundColor: AppColors.primary,
                                ),
                              );
                            }
                          },
                          style: ElevatedButton.styleFrom(
                            backgroundColor: AppColors.primary,
                            foregroundColor: Colors.white,
                            padding: const EdgeInsets.symmetric(vertical: 12),
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(14),
                            ),
                          ),
                          child: const Text('Play test audio'),
                        ),
                      ),
                      const SizedBox(width: 12),
                      ElevatedButton(
                        onPressed: () async {
                          try {
                            await media.stopAudio();
                          } catch (_) {}
                        },
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppColors.getSurface(context),
                          foregroundColor: AppColors.textPrimary,
                          side: BorderSide(color: AppColors.getBorder(context)),
                          padding: const EdgeInsets.symmetric(
                            vertical: 12,
                            horizontal: 14,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                        child: const Text('Stop'),
                      ),
                    ],
                  ),
                ],
              ),
            ),

            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: () => Navigator.pop(context),
                child: const Text(
                  'Back to Search',
                  style: TextStyle(fontWeight: FontWeight.w800),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
