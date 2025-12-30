import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Settings', style: AppTextStyles.headlineLarge),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: const [
          _SettingsItem(
            title: 'Account',
            subtitle: 'Edit profile, preferences',
            icon: Icons.person_outline,
          ),
          SizedBox(height: 10),
          _SettingsItem(
            title: 'Notifications',
            subtitle: 'Reminders, updates',
            icon: Icons.notifications_outlined,
          ),
          SizedBox(height: 10),
          _SettingsItem(
            title: 'Privacy',
            subtitle: 'Blocked users, data',
            icon: Icons.lock_outline,
          ),
          SizedBox(height: 10),
          _SettingsItem(
            title: 'Help & Support',
            subtitle: 'Contact support',
            icon: Icons.support_agent,
          ),
          SizedBox(height: 10),
          _SettingsItem(
            title: 'About',
            subtitle: 'App version',
            icon: Icons.info_outline,
          ),
        ],
      ),
    );
  }
}

class _SettingsItem extends StatelessWidget {
  final String title;
  final String subtitle;
  final IconData icon;

  const _SettingsItem({
    required this.title,
    required this.subtitle,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Icon(icon, color: AppColors.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: AppTextStyles.labelLarge),
                const SizedBox(height: 2),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
          Icon(Icons.chevron_right, color: AppColors.textMuted),
        ],
      ),
    );
  }
}
