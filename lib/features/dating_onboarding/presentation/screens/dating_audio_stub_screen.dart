import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';

class DatingAudioStubScreen extends StatelessWidget {
  const DatingAudioStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text('Dating Profile', style: AppTextStyles.titleLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 6 of 8', style: AppTextStyles.caption),
            const SizedBox(height: 8),
            Text('Audio Responses', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Instructions\n\n'
                'Please record genuine responses to the questions you see on the subsequent screens. These three (3) questions are centered around your christian faith, marriage beliefs & personality. \n'
                'Each response has a limit of 60 seconds and you will not be able to change \n'
                'your responses after your profile is completed. Your responses don´t need to \n'
                'be perfect, they just need to be audible & authentic. \n'
                'Remember that people value authenticity and most people can tell when a response feels rehearsed or scripted, so we recommend reflecting deeply on each question & responding from your heart, to avoid wondering why you’re not getting matches, despite saying impressive things in your responses. \n'
                'It is also obvious that any user who records gibberish or submits empty recordings will not be taken seriously by other users,  and such profiles will         be deleted.\n\n'
                'Happy Recording!',
                style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
              ),
            ),

            const SizedBox(height: 18),

            Text(
              'You will answer 3 short questions (60 seconds max each).',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.textMuted,
              ),
            ),

            const Spacer(),

            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/dating/setup/audio/q1');
                },
                child: const Text('Start Recording'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
