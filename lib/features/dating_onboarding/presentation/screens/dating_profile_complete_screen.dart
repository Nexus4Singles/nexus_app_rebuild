import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/theme/theme.dart';

class DatingProfileCompleteScreen extends ConsumerStatefulWidget {
  const DatingProfileCompleteScreen({super.key});

  @override
  ConsumerState<DatingProfileCompleteScreen> createState() =>
      _DatingProfileCompleteScreenState();
}

class _DatingProfileCompleteScreenState
    extends ConsumerState<DatingProfileCompleteScreen> {
  @override
  void initState() {
    super.initState();
    // Immediately route to compatibility quiz after a brief celebration
    WidgetsBinding.instance.addPostFrameCallback((_) {
      Future.delayed(const Duration(milliseconds: 1500), () {
        if (mounted) {
          Navigator.of(context).pushReplacementNamed('/compatibility-quiz');
        }
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
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
                'Great! Your dating profile is complete. '
                'Before you can view other users in the pool, please take a short compatibility quiz. '
                'This helps Nexus recommend better matches and improves the quality of the community.\n\n'
                'Redirecting to compatibility quiz...',
                style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
              ),
            ),
            const Spacer(),
            Center(
              child: CircularProgressIndicator(
                color: AppColors.primary,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
