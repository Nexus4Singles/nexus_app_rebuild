import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/safe_imports.dart';

class GenericRouteStubScreen extends StatelessWidget {
  final String title;
  const GenericRouteStubScreen({super.key, required this.title});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text(title, style: AppTextStyles.headlineLarge),
      ),
      body: Center(
        child: Text('Stub: $title', style: AppTextStyles.bodyMedium),
      ),
    );
  }
}
