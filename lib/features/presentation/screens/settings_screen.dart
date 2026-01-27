import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/theme/app_colors.dart';
import 'package:nexus_app_min_test/core/theme/app_text_styles.dart';
import 'package:nexus_app_min_test/core/theme/theme_provider.dart';
import 'package:nexus_app_min_test/core/user/is_admin_provider.dart';
import 'package:nexus_app_min_test/features/admin_review/presentation/screens/admin_review_queue_screen.dart';

class SettingsScreen extends ConsumerWidget {
  const SettingsScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final themeMode = ref.watch(themeModeProvider);
    final isDarkMode = themeMode == ThemeMode.dark;
    final isAdminAsync = ref.watch(isAdminProvider);
    final isAdmin = isAdminAsync.maybeWhen(data: (v) => v, orElse: () => false);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        elevation: 0,
        centerTitle: false,
        leading: IconButton(
          icon: Icon(
            Icons.arrow_back_ios_new,
            size: 20,
            color: AppColors.getTextPrimary(context),
          ),
          onPressed: () => Navigator.of(context).pop(),
        ),
        title: Text(
          'Settings',
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        children: [
          const SizedBox(height: 8),

          // Appearance Section
          _SectionHeader(title: 'Appearance'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
                iconColor: isDarkMode ? Color(0xFF8B5CF6) : Color(0xFFFBBF24),
                iconBgColor: isDarkMode ? Color(0xFF2A1F3A) : Color(0xFFFEF3C7),
                title: 'Dark Mode',
                subtitle: isDarkMode ? 'Enabled' : 'Disabled',
                trailing: Switch(
                  value: isDarkMode,
                  onChanged: (value) {
                    ref.read(themeModeProvider.notifier).toggleTheme();
                  },
                  activeColor: AppColors.primary,
                ),
                onTap: () {
                  ref.read(themeModeProvider.notifier).toggleTheme();
                },
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Admin Section (only visible to admins)
          if (isAdmin) ...[
            _SectionHeader(title: 'Admin'),
            const SizedBox(height: 12),
            _SettingsCard(
              children: [
                _SettingsTile(
                  icon: Icons.admin_panel_settings,
                  iconColor: Color(0xFFEF4444),
                  iconBgColor: Color(0xFFFEE2E2),
                  title: 'Review Queue',
                  subtitle: 'Review pending user profiles',
                  onTap: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const AdminReviewQueueScreen(),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 24),
          ],

          // Support Section
          _SectionHeader(title: 'Support'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.help_outline,
                iconColor: AppColors.primary,
                iconBgColor: AppColors.primarySoft,
                title: 'Help Center',
                subtitle: 'FAQs and quick actions',
                onTap: () => Navigator.of(context).pushNamed('/help'),
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.support_agent,
                iconColor: Color(0xFF10B981),
                iconBgColor: Color(0xFFD1FAE5),
                title: 'Contact Support',
                subtitle: 'Email us for support and feedback',
                onTap: () => Navigator.of(context).pushNamed('/contact'),
              ),
            ],
          ),

          const SizedBox(height: 24),

          // Legal Section
          _SectionHeader(title: 'Legal'),
          const SizedBox(height: 12),
          _SettingsCard(
            children: [
              _SettingsTile(
                icon: Icons.description_outlined,
                iconColor: Color(0xFF3B82F6),
                iconBgColor: Color(0xFFDBEAFE),
                title: 'Terms of Service',
                subtitle: 'Read our terms and conditions',
                onTap: () => Navigator.of(context).pushNamed('/terms'),
              ),
              _Divider(),
              _SettingsTile(
                icon: Icons.privacy_tip_outlined,
                iconColor: Color(0xFF8B5CF6),
                iconBgColor: Color(0xFFEDE9FE),
                title: 'Privacy Policy',
                subtitle: 'How we handle your data',
                onTap: () => Navigator.of(context).pushNamed('/privacy'),
              ),
            ],
          ),

          const SizedBox(height: 32),

          // Version
          Center(
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                borderRadius: BorderRadius.circular(20),
                border: Border.all(
                  color: AppColors.getBorder(context).withOpacity(0.3),
                ),
              ),
              child: Text(
                'Version 2.0.0',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                  fontWeight: FontWeight.w600,
                  letterSpacing: 0.5,
                ),
              ),
            ),
          ),

          const SizedBox(height: 32),
        ],
      ),
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================
class _SectionHeader extends StatelessWidget {
  final String title;

  const _SectionHeader({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 4, bottom: 4),
      child: Text(
        title.toUpperCase(),
        style: AppTextStyles.labelMedium.copyWith(
          color: AppColors.getTextSecondary(context),
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
      ),
    );
  }
}

// ============================================================================
// SETTINGS CARD (Container for multiple tiles)
// ============================================================================
class _SettingsCard extends StatelessWidget {
  final List<Widget> children;

  const _SettingsCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getBorder(context).withOpacity(0.5),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withOpacity(0.02),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: Column(children: children),
    );
  }
}

// ============================================================================
// SETTINGS TILE
// ============================================================================
class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final Color iconBgColor;
  final String title;
  final String subtitle;
  final VoidCallback onTap;
  final Widget? trailing;

  const _SettingsTile({
    required this.icon,
    required this.iconColor,
    required this.iconBgColor,
    required this.title,
    required this.subtitle,
    required this.onTap,
    this.trailing,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 16),
          child: Row(
            children: [
              // Icon Container
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: iconBgColor,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Icon(icon, size: 22, color: iconColor),
              ),

              const SizedBox(width: 16),

              // Text Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      title,
                      style: AppTextStyles.bodyLarge.copyWith(
                        fontWeight: FontWeight.w600,
                        height: 1.2,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.getTextSecondary(context),
                        height: 1.3,
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(width: 8),

              // Trailing (switch or chevron)
              trailing ??
                  Icon(
                    Icons.chevron_right,
                    color: AppColors.getTextSecondary(context),
                    size: 20,
                  ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// DIVIDER
// ============================================================================
class _Divider extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Container(
      height: 1,
      margin: const EdgeInsets.only(left: 76),
      color: AppColors.getBorder(context).withOpacity(0.3),
    );
  }
}
