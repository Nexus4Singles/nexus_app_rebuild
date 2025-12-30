import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/app_colors.dart';
import 'package:nexus_app_min_test/core/theme/app_text_styles.dart';
import 'package:nexus_app_min_test/features/presentation/screens/settings_screen.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Profile', style: AppTextStyles.headlineLarge),
        actions: [
          IconButton(
            onPressed: () {
              Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => const SettingsScreen()),
              );
            },
            icon: const Icon(
              Icons.settings_outlined,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(width: 6),
        ],
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          _ProfileHeader(),
          const SizedBox(height: 16),
          _ProfileStatRow(),
          const SizedBox(height: 20),
          Text('Your Account', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          _ProfileTile(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: 'Coming soon',
            onTap: () => _showComingSoon(context, 'Edit Profile'),
          ),
          const SizedBox(height: 10),
          _ProfileTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: 'Coming soon',
            onTap: () => _showComingSoon(context, 'Privacy'),
          ),
          const SizedBox(height: 10),
          _ProfileTile(
            icon: Icons.support_agent,
            title: 'Help & Support',
            subtitle: 'Coming soon',
            onTap: () => _showComingSoon(context, 'Help & Support'),
          ),
          const SizedBox(height: 24),
          Text('Stabilization', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: AppColors.surface,
              borderRadius: BorderRadius.circular(18),
              border: Border.all(color: AppColors.border),
            ),
            child: Text(
              'Safe Mode Profile Screen ✅\n\nBackend stays OFF.\nFirebase will be reintroduced later with a controlled toolchain.',
              style: AppTextStyles.bodyMedium,
            ),
          ),
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  void _showComingSoon(BuildContext context, String title) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(title, style: AppTextStyles.headlineSmall),
            content: Text(
              'This is coming soon. We are stabilizing the app first.',
              style: AppTextStyles.bodyMedium,
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(
                  'OK',
                  style: TextStyle(
                    color: AppColors.primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
    );
  }
}

class _ProfileHeader extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppColors.border),
      ),
      child: Row(
        children: [
          Container(
            width: 64,
            height: 64,
            decoration: BoxDecoration(
              color: AppColors.primary.withOpacity(0.12),
              borderRadius: BorderRadius.circular(22),
            ),
            child: const Icon(Icons.person, color: AppColors.primary, size: 34),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Guest User', style: AppTextStyles.headlineSmall),
                const SizedBox(height: 4),
                Text('Stabilization mode', style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatRow extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: _StatCard(label: 'Streak', value: '0')),
        SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Sessions', value: '0')),
        SizedBox(width: 10),
        Expanded(child: _StatCard(label: 'Journeys', value: '0')),
      ],
    );
  }
}

class _StatCard extends StatelessWidget {
  final String label;
  final String value;

  const _StatCard({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppColors.surface,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        children: [
          Text(value, style: AppTextStyles.headlineSmall),
          const SizedBox(height: 4),
          Text(label, style: AppTextStyles.caption),
        ],
      ),
    );
  }
}

class _ProfileTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  const _ProfileTile({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
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
        ),
      ),
    );
  }
}
