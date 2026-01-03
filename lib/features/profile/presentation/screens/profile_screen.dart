import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/auth/auth_controller.dart';
import 'package:nexus_app_min_test/core/auth/auth_providers.dart';
import 'package:nexus_app_min_test/core/theme/app_colors.dart';
import 'package:nexus_app_min_test/core/theme/app_text_styles.dart';
import 'package:nexus_app_min_test/core/widgets/guest_guard.dart';

class ProfileScreen extends ConsumerWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final authAsync = ref.watch(authStateProvider);

    final user = authAsync.maybeWhen(data: (a) => a.user, orElse: () => null);

    final isSignedIn = user != null;
    final displayName = isSignedIn ? (user.email ?? 'User') : 'Guest User';

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        elevation: 0,
        title: Text('Profile', style: AppTextStyles.headlineLarge),
        actions: [
          IconButton(
            onPressed: () => Navigator.of(context).pushNamed('/settings'),
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
          _ProfileHeader(
            title: displayName,
            subtitle: isSignedIn ? 'Signed in' : 'Guest mode',
          ),
          const SizedBox(height: 16),
          const _ProfileStatRow(),
          const SizedBox(height: 20),
          Text('Your Account', style: AppTextStyles.titleLarge),
          const SizedBox(height: 12),
          _ProfileTile(
            icon: Icons.edit_outlined,
            title: 'Edit Profile',
            subtitle: isSignedIn ? 'Coming soon' : 'Requires account',
            onTap: () {
              GuestGuard.requireSignedIn(
                context,
                ref,
                title: 'Create an account to edit your profile',
                message:
                    'You\'re currently in guest mode. Create an account to edit your profile and settings.',
                primaryText: 'Create an account',
                onCreateAccount:
                    () => Navigator.of(context).pushNamed('/signup'),
                onAllowed: () async {
                  _showComingSoon(context, 'Edit Profile');
                },
              );
            },
          ),
          const SizedBox(height: 10),
          _ProfileTile(
            icon: Icons.lock_outline,
            title: 'Privacy',
            subtitle: isSignedIn ? 'Coming soon' : 'Requires account',
            onTap: () {
              GuestGuard.requireSignedIn(
                context,
                ref,
                title: 'Create an account to access privacy settings',
                message:
                    'You\'re currently in guest mode. Create an account to manage privacy settings.',
                primaryText: 'Create an account',
                onCreateAccount:
                    () => Navigator.of(context).pushNamed('/signup'),
                onAllowed: () async {
                  _showComingSoon(context, 'Privacy');
                },
              );
            },
          ),
          const SizedBox(height: 10),
          _ProfileTile(
            icon: Icons.support_agent,
            title: 'Help & Support',
            subtitle: 'Contact support',
            onTap: () => Navigator.of(context).pushNamed('/contact-support'),
          ),
          const SizedBox(height: 24),
          if (!isSignedIn)
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: () => Navigator.of(context).pushNamed('/signup'),
                child: const Text('Create an account'),
              ),
            ),
          if (isSignedIn) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton(
                onPressed: () async {
                  await ref.read(authControllerProvider).signOut();
                },
                child: const Text('Sign out'),
              ),
            ),
          ],
          const SizedBox(height: 24),
        ],
      ),
    );
  }

  static void _showComingSoon(BuildContext context, String title) {
    showDialog(
      context: context,
      builder:
          (_) => AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(18),
            ),
            title: Text(title, style: AppTextStyles.headlineSmall),
            content: Text(
              'This is coming soon. We are rebuilding feature-by-feature.',
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
  final String title;
  final String subtitle;

  const _ProfileHeader({required this.title, required this.subtitle});

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
                Text(title, style: AppTextStyles.headlineSmall),
                const SizedBox(height: 4),
                Text(subtitle, style: AppTextStyles.caption),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ProfileStatRow extends StatelessWidget {
  const _ProfileStatRow();

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
