import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';

class CompleteDatingProfilePlaceholderScreen extends StatelessWidget {
  const CompleteDatingProfilePlaceholderScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Complete Profile', style: AppTextStyles.headlineLarge),
      ),
      body: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Dating Profile Required', style: AppTextStyles.titleLarge),
            const SizedBox(height: 10),
            Text(
              'Minimum fields required to use Search/Chats:',
              style: AppTextStyles.bodyMedium,
            ),
            const SizedBox(height: 12),
            const _Bullet('Name (non-empty)'),
            const _Bullet('Age (18+)'),
            const _Bullet('Gender'),
            const _Bullet('At least 1 photo'),
            const SizedBox(height: 24),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.surface,
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: AppColors.border),
              ),
              child: Text(
                'Profile builder will be implemented next.\n\nMedia uploads will use DigitalOcean Spaces.',
                style: AppTextStyles.bodyMedium,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Bullet extends StatelessWidget {
  final String text;
  const _Bullet(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [const Text('•  '), Expanded(child: Text(text))],
      ),
    );
  }
}
