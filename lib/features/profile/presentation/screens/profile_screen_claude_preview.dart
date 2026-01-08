import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/theme/app_spacing.dart';

class ProfileScreenClaudePreview extends StatefulWidget {
  const ProfileScreenClaudePreview({super.key});

  @override
  State<ProfileScreenClaudePreview> createState() =>
      _ProfileScreenClaudePreviewState();
}

class _ProfileScreenClaudePreviewState extends State<ProfileScreenClaudePreview>
    with SingleTickerProviderStateMixin {
  late AnimationController _animController;
  late Animation<double> _fadeIn;

  @override
  void initState() {
    super.initState();
    _animController = AnimationController(
      duration: const Duration(milliseconds: 600),
      vsync: this,
    );
    _fadeIn = CurvedAnimation(parent: _animController, curve: Curves.easeOut);
    _animController.forward();
  }

  @override
  void dispose() {
    _animController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // Mock user (replace later with providers)
    final name = "Ayomide";
    final status = "Singles";
    final streak = 3;

    final t = Theme.of(context).textTheme;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: SystemUiOverlayStyle.dark,
      child: SafeArea(
        child: FadeTransition(
          opacity: _fadeIn,
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(AppSpacing.lg),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text("Profile", style: t.headlineLarge),
                const SizedBox(height: AppSpacing.md),

                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(AppSpacing.lg),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 26,
                          backgroundColor: AppColors.primarySoft,
                          child: Text(
                            name.isNotEmpty ? name[0].toUpperCase() : "U",
                            style: t.titleLarge?.copyWith(
                              color: AppColors.primary,
                            ),
                          ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(name, style: t.titleLarge),
                              const SizedBox(height: AppSpacing.xs),
                              Text(
                                status,
                                style: t.bodySmall?.copyWith(
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        Text(
                          "🔥 $streak",
                          style: t.labelLarge?.copyWith(
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: AppSpacing.lg),
                Text("Settings", style: t.titleLarge),
                const SizedBox(height: AppSpacing.sm),

                _RowItem(title: "Edit Profile", icon: Icons.edit_outlined),
                _RowItem(
                  title: "Notifications",
                  icon: Icons.notifications_outlined,
                ),
                _RowItem(title: "Privacy & Safety", icon: Icons.lock_outline),
                _RowItem(title: "Help & Support", icon: Icons.help_outline),
                _RowItem(
                  title: "Log out",
                  icon: Icons.logout,
                  isDestructive: true,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _RowItem extends StatelessWidget {
  final String title;
  final IconData icon;
  final bool isDestructive;

  const _RowItem({
    required this.title,
    required this.icon,
    this.isDestructive = false,
  });

  @override
  Widget build(BuildContext context) {
    final t = Theme.of(context).textTheme;

    return Card(
      child: ListTile(
        leading: Icon(
          icon,
          color: isDestructive ? AppColors.error : AppColors.textPrimary,
        ),
        title: Text(
          title,
          style: t.bodyLarge?.copyWith(
            color: isDestructive ? AppColors.error : AppColors.textPrimary,
            fontWeight: FontWeight.w600,
          ),
        ),
        trailing: const Icon(Icons.chevron_right),
        onTap: () {},
      ),
    );
  }
}
