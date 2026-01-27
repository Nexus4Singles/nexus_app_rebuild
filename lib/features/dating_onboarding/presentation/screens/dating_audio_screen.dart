import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';

class DatingAudioScreen extends StatelessWidget {
  const DatingAudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Audio Recordings',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 18),
            Text('Instructions', style: AppTextStyles.headlineMedium),
            const SizedBox(height: 12),

            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppColors.getBorder(context)),
              ),
              child: Text.rich(
                TextSpan(
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                  children: [
                    const TextSpan(
                      text:
                          'Please record genuine responses to the questions you see on the subsequent screens. These three (3) questions are centered around your ',
                    ),
                    TextSpan(
                      text: 'Christian Faith, Marriage Beliefs & Personality',
                      style: AppTextStyles.bodyMedium.copyWith(
                        height: 1.45,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(
                      text: '. \n\nEach recording has a minimum duration of ',
                    ),
                    TextSpan(
                      text: '45 seconds',
                      style: AppTextStyles.bodyMedium.copyWith(
                        height: 1.45,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(text: ' and a maximum of '),
                    TextSpan(
                      text: '60 seconds',
                      style: AppTextStyles.bodyMedium.copyWith(
                        height: 1.45,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(
                      text:
                          'and you will not be able to change your responses after \n'
                          'your profile is completed. \nYour responses don´t need to be perfect, \n'
                          'they just need to be audible & authentic. \n\n',
                    ),
                    TextSpan(
                      text:
                          'Remember that people value authenticity and most people can tell when a response feels rehearsed or scripted, so we recommend reflecting deeply on each question & responding from your heart.',
                      style: AppTextStyles.bodyMedium.copyWith(
                        height: 1.45,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const TextSpan(
                      text:
                          ' \n\n'
                          'Lastly, any user who records gibberish or submits empty recordings will not be verified and such profiles will be deleted.\n\n'
                          'Happy Recording!',
                    ),
                  ],
                ),
              ),
            ),

            const SizedBox(height: 18),

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
                        ).pushNamed('/dating/setup/audio/q1');
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
                        'Start Recording',
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
}
