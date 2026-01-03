import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';

class DatingProfileCompleteScreen extends StatelessWidget {
  const DatingProfileCompleteScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () => Navigator.popUntil(context, (r) => r.isFirst),
        ),
        title: Text('Dating Profile', style: AppTextStyles.titleLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.fromLTRB(18, 18, 18, 18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Step 8 of 8', style: AppTextStyles.caption),
            const SizedBox(height: 10),
            Text('Profile completed 🎉', style: AppTextStyles.headlineLarge),
            const SizedBox(height: 18),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'You have successfully created a profile on Nexus! \n'
                'In the mean time, please go to your profile to fill a short compatibility quiz .\n'
                'Kindly tell your Christian single friends about Nexus & follow us on social media to stay updated!',
                style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
              ),
            ),
            const Spacer(),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () {
                  Navigator.of(context).pushNamed('/compatibility-quiz');
                },
                child: const Text('Go to Profile'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
