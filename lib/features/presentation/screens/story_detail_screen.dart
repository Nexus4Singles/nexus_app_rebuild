import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';

class StoryDetailScreen extends StatelessWidget {
  final String title;

  const StoryDetailScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Story', style: AppTextStyles.headlineLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: AppTextStyles.headlineMedium),
            const SizedBox(height: 12),
            Text(
              'Safe Mode story detail screen.\n\nLater: this becomes real content loaded from Firestore.',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 24),
            Expanded(
              child: Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.surface,
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(color: AppColors.border),
                ),
                child: Text(
                  '“Marriage isn’t built on big moments.\nIt’s built on small choices repeated daily.”\n\n— Nexus (placeholder)',
                  style: AppTextStyles.bodyLarge,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
