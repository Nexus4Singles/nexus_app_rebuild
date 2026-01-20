import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';

class DatingQualitiesStubScreen extends StatelessWidget {
  const DatingQualitiesStubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Desired Qualities', style: AppTextStyles.titleLarge),
      ),
      body: const Center(child: Text('Desired Qualities (next step)')),
    );
  }
}
