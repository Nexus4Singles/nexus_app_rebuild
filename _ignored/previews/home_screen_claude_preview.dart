import 'package:flutter/material.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

/// Claude Home UI Preview (no providers / backend)
class HomeScreenClaudePreview extends StatefulWidget {
  const HomeScreenClaudePreview({super.key});

  @override
  State<HomeScreenClaudePreview> createState() => _HomeScreenClaudePreviewState();
}

class _HomeScreenClaudePreviewState extends State<HomeScreenClaudePreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;
  late Animation<Offset> _slideUp;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 800),
      vsync: this,
    );

    _fadeIn = Tween<double>(begin: 0.0, end: 1.0).animate(
      CurvedAnimation(parent: _animController, curve: Curves.easeOut),
    );

    _slideUp = Tween<Offset>(
      begin: const Offset(0, 0.1),
      end: Offset.zero,
    ).animate(CurvedAnimation(parent: _animController, curve: Curves.easeOut));

    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  String _getGreeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning';
    if (hour < 17) return 'Good afternoon';
    return 'Good evening';
  }

  @override
  Widget build(BuildContext context) {
    final userName = "Ayomide";
    final streakDays = 3;
    final featuredJourney = "Singles Journey";

    final t = Theme.of(context).textTheme;

    return SafeArea(
      child: FadeTransition(
        opacity: _fadeIn,
        child: SlideTransition(
          position: _slideUp,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("${_getGreeting()}, $userName", style: t.headlineLarge),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  "Ready to grow today?",
                  style: t.bodyMedium?.copyWith(color: AppColors.textSecondary),
                ),
                const SizedBox(height: AppSpacing.xl),

                _InfoCard(
                  title: "Your Streak",
                  subtitle: "Keep going — you're building consistency.",
                  trailing: "🔥 $streakDays",
                ),
                const SizedBox(height: AppSpacing.md),

                _InfoCard(
                  title: "Featured Journey",
                  subtitle: featuredJourney,
                  trailing: "Start",
                ),
                const SizedBox(height: AppSpacing.md),

                _InfoCard(
                  title: "Community",
                  subtitle: "New stories waiting for you",
                  trailing: "View",
                ),
                const SizedBox(height: AppSpacing.xl),

                ElevatedButton(
                  onPressed: () {},
                  child: const Text("Continue"),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final String title;
  final String subtitle;
  final String trailing;

  const _InfoCard({
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Card(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: t.titleMedium),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    subtitle,
                    style: t.bodySmall?.copyWith(color: AppColors.textSecondary),
                  ),
                ],
              ),
            ),
            const SizedBox(width: AppSpacing.md),
            Text(
              trailing,
              style: t.labelLarge?.copyWith(
                color: AppColors.primary,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
