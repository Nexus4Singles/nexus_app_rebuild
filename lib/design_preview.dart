import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'core/theme/app_theme.dart';

class DesignPreviewApp extends StatelessWidget {
  const DesignPreviewApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      home: const _DesignPreviewHome(),
    );
  }
}

class _DesignPreviewHome extends StatelessWidget {
  const _DesignPreviewHome();

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Scaffold(
      appBar: AppBar(title: const Text('Nexus Design Preview')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Theme is wired up ✅', style: t.headlineLarge),
            const SizedBox(height: 8),
            Text(
              'This screen uses AppTheme.lightTheme + AppColors + Poppins.',
              style: t.bodyMedium,
            ),

            const SizedBox(height: 24),

            Text('Brand Colors', style: t.titleLarge),
            const SizedBox(height: 12),
            Wrap(
              spacing: 12,
              runSpacing: 12,
              children: const [
                _Swatch('Primary', AppColors.primary),
                _Swatch('Primary Light', AppColors.primaryLight),
                _Swatch('Secondary', AppColors.secondary),
                _Swatch('Gold', AppColors.gold),
                _Swatch('Success', AppColors.success),
                _Swatch('Warning', AppColors.warning),
                _Swatch('Error', AppColors.error),
              ],
            ),

            const SizedBox(height: 28),

            Text('Typography', style: t.titleLarge),
            const SizedBox(height: 12),
            Text('Display Large', style: t.displayLarge),
            const SizedBox(height: 6),
            Text('Headline Medium', style: t.headlineMedium),
            const SizedBox(height: 6),
            Text('Body Medium', style: t.bodyMedium),
            const SizedBox(height: 6),
            Text('Label Small', style: t.labelSmall),

            const SizedBox(height: 28),

            Text('Buttons', style: t.titleLarge),
            const SizedBox(height: 12),
            ElevatedButton(
              onPressed: () {},
              child: const Text('Primary Button'),
            ),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: () {},
              child: const Text('Outlined Button'),
            ),
            const SizedBox(height: 12),
            TextButton(onPressed: () {}, child: const Text('Text Button')),

            const SizedBox(height: 28),

            Text('Card', style: t.titleLarge),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Text(
                  'If this card has a subtle border + rounded corners, '
                  'your CardTheme is working.',
                  style: t.bodyMedium,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Swatch extends StatelessWidget {
  final String label;
  final Color color;

  const _Swatch(this.label, this.color);

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Container(
      width: 160,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.black12),
      ),
      child: Text(
        label,
        style: t.labelLarge?.copyWith(
          color: Colors.white,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }
}
