import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/router/safe_nav.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/features/dating_onboarding/presentation/widgets/dating_profile_progress_bar.dart';

class DatingAudioScreen extends StatelessWidget {
  const DatingAudioScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final screenHeight = MediaQuery.of(context).size.height;
    final isSmallScreen = screenHeight < 700;

    // Responsive spacing - significantly tighter at top
    final topPadding = isSmallScreen ? 8.0 : 12.0;
    final titleBottomSpacing = isSmallScreen ? 8.0 : 12.0;

    // Responsive font sizing
    final titleFontSize = isSmallScreen ? 14.0 : 16.0;
    final bodyFontSize = isSmallScreen ? 12.0 : 13.0;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => navigateBackToHome(context),
        ),
        title: Text(
          'Audio Recordings',
          style: AppTextStyles.titleLarge.copyWith(fontWeight: FontWeight.w700),
        ),
      ),
      body: Padding(
        padding: EdgeInsets.fromLTRB(20, topPadding, 20, 20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Instructions',
              style: AppTextStyles.titleMedium.copyWith(
                fontSize: titleFontSize,
                fontWeight: FontWeight.w700,
                height: 1.3,
              ),
            ),
            SizedBox(height: titleBottomSpacing),

            Expanded(
              child: SingleChildScrollView(
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.getSurface(context),
                    borderRadius: BorderRadius.circular(24),
                    border: Border.all(color: AppColors.getBorder(context)),
                  ),
                  child: Text.rich(
                    TextSpan(
                      style: AppTextStyles.bodySmall.copyWith(
                        height: 1.45,
                        fontSize: bodyFontSize,
                      ),
                      children: [
                        const TextSpan(
                          text:
                              'Please record genuine responses to the questions you see on the subsequent screens. These three (3) questions are centered around your ',
                        ),
                        TextSpan(
                          text:
                              'Christian Faith, Marriage Beliefs & Personality',
                          style: AppTextStyles.bodySmall.copyWith(
                            height: 1.45,
                            fontWeight: FontWeight.bold,
                            fontSize: bodyFontSize,
                          ),
                        ),
                        const TextSpan(
                          text:
                              '. \n\nEach recording has a minimum duration of ',
                        ),
                        TextSpan(
                          text: '45 seconds',
                          style: AppTextStyles.bodySmall.copyWith(
                            height: 1.45,
                            fontWeight: FontWeight.bold,
                            fontSize: bodyFontSize,
                          ),
                        ),
                        const TextSpan(text: ' and a maximum of '),
                        TextSpan(
                          text: '90 seconds',
                          style: AppTextStyles.bodySmall.copyWith(
                            height: 1.45,
                            fontWeight: FontWeight.bold,
                            fontSize: bodyFontSize,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' and you will not be able to change your responses after'
                              ' your profile is completed. \nYour responses don´t need to be perfect, \n'
                              'they just need to be audible & authentic. \n\n',
                        ),
                        TextSpan(
                          text:
                              'Remember that people value authenticity and most people can tell when a response feels rehearsed or scripted, so we recommend reflecting deeply on each question & responding from your heart.',
                          style: AppTextStyles.bodySmall.copyWith(
                            height: 1.45,
                            fontWeight: FontWeight.bold,
                            fontSize: bodyFontSize,
                          ),
                        ),
                        const TextSpan(
                          text:
                              ' \n\n'
                              'Lastly, any user who records gibberish, empty recordings or AI-generated recordings will not be approved by our Admin team and such profiles will be deleted.\n\n'
                              'Happy Recording!',
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            SafeArea(
              top: false,
              child: Column(
                children: [
                  const SizedBox(height: 12),
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
