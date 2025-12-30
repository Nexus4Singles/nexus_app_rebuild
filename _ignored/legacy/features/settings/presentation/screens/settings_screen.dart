import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';
import '../../../../core/providers/auth_provider.dart';
import '../../../../core/providers/user_provider.dart';
import '../../../../core/providers/theme_provider.dart';

/// Premium Settings Screen with modern card-based UI
class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen>
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
    final currentUser = ref.watch(currentUserProvider).valueOrNull;
    final isPremium = currentUser?.isPremium ?? false;

    return Scaffold(
      backgroundColor: AppColors.background,
      body: FadeTransition(
        opacity: _fadeIn,
        child: CustomScrollView(
          physics: const BouncingScrollPhysics(),
          slivers: [
            // Premium App Bar
            SliverAppBar(
              expandedHeight: 140,
              floating: false,
              pinned: true,
              backgroundColor: AppColors.primary,
              leading: IconButton(
                onPressed: () => context.pop(),
                icon: const Icon(Icons.arrow_back, color: Colors.white),
              ),
              flexibleSpace: FlexibleSpaceBar(
                background: Container(
                  decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                  child: SafeArea(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 50, 20, 20),
                      child: Row(
                        children: [
                          Container(
                            width: 56,
                            height: 56,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.white, width: 2),
                              image: currentUser?.profileUrl != null
                                  ? DecorationImage(
                                      image: NetworkImage(currentUser!.profileUrl!),
                                      fit: BoxFit.cover,
                                    )
                                  : null,
                            ),
                            child: currentUser?.profileUrl == null
                                ? const Icon(Icons.person, color: Colors.white, size: 28)
                                : null,
                          ),
                          const SizedBox(width: 16),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  currentUser?.displayName ?? 'User',
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    if (isPremium) ...[
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                        decoration: BoxDecoration(
                                          gradient: const LinearGradient(
                                            colors: [Color(0xFFFFD700), Color(0xFFFFA500)],
                                          ),
                                          borderRadius: BorderRadius.circular(10),
                                        ),
                                        child: const Row(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            Icon(Icons.star, size: 12, color: Colors.white),
                                            SizedBox(width: 4),
                                            Text('PRO', style: TextStyle(fontSize: 10, fontWeight: FontWeight.bold, color: Colors.white)),
                                          ],
                                        ),
                                      ),
                                      const SizedBox(width: 8),
                                    ],
                                    Text(
                                      currentUser?.email ?? '',
                                      style: TextStyle(fontSize: 13, color: Colors.white.withOpacity(0.8)),
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ),

            // Settings Content
            SliverPadding(
              padding: const EdgeInsets.all(20),
              sliver: SliverList(
                delegate: SliverChildListDelegate([
                  _buildSection(
                    title: 'Profile',
                    icon: Icons.person_outline,
                    children: [
                      _SettingsTile(icon: Icons.edit_outlined, title: 'Edit Profile', subtitle: 'Update photos and information', onTap: () => context.push('/edit-profile')),
                      _SettingsTile(icon: Icons.badge_outlined, title: 'Username', subtitle: '@${currentUser?.username ?? 'not set'}', onTap: () => _showUsernameSheet(context, currentUser?.username)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'Subscription',
                    icon: Icons.diamond_outlined,
                    accentColor: const Color(0xFFFFD700),
                    children: [
                      _SettingsTile(
                        icon: isPremium ? Icons.star : Icons.star_outline,
                        iconColor: isPremium ? const Color(0xFFFFD700) : null,
                        title: isPremium ? 'Premium Active' : 'Upgrade to Premium',
                        subtitle: isPremium ? 'Manage your subscription' : 'Unlock all features',
                        trailing: !isPremium ? _buildUpgradeBadge() : null,
                        onTap: () => context.push('/subscription'),
                      ),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'Notifications',
                    icon: Icons.notifications_outlined,
                    children: [
                      _SettingsTile(icon: Icons.notifications_active_outlined, title: 'Push Notifications', trailing: _buildSwitch(true, (v) {})),
                      _SettingsTile(icon: Icons.chat_bubble_outline, title: 'Message Alerts', trailing: _buildSwitch(true, (v) {})),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildAppearanceSection(),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'Privacy & Safety',
                    icon: Icons.shield_outlined,
                    children: [
                      _SettingsTile(icon: Icons.block, title: 'Blocked Users', subtitle: 'Manage blocked accounts', onTap: () => context.push('/blocked-users')),
                      _SettingsTile(icon: Icons.visibility_outlined, title: 'Profile Visibility', subtitle: 'Everyone', onTap: () => _showVisibilitySheet(context)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'Account',
                    icon: Icons.manage_accounts_outlined,
                    children: [
                      _SettingsTile(icon: Icons.lock_outline, title: 'Change Password', onTap: () => _showPasswordSheet(context)),
                      _SettingsTile(icon: Icons.swap_horiz, title: 'Relationship Status', subtitle: _getStatusLabel(currentUser?.nexus2?.relationshipStatus), onTap: () => _showStatusSheet(context)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'Support',
                    icon: Icons.help_outline,
                    children: [
                      _SettingsTile(icon: Icons.quiz_outlined, title: 'Help Center', onTap: () => context.push('/help')),
                      _SettingsTile(icon: Icons.support_agent, title: 'Contact Support', onTap: () => context.push('/contact-support')),
                      _SettingsTile(icon: Icons.feedback_outlined, title: 'Send Feedback', onTap: () => _showFeedbackSheet(context)),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'Legal',
                    icon: Icons.gavel_outlined,
                    children: [
                      _SettingsTile(icon: Icons.description_outlined, title: 'Terms of Service', onTap: () => context.push('/terms')),
                      _SettingsTile(icon: Icons.privacy_tip_outlined, title: 'Privacy Policy', onTap: () => context.push('/privacy')),
                    ],
                  ),
                  const SizedBox(height: 20),
                  _buildSection(
                    title: 'Account Actions',
                    icon: Icons.warning_amber_outlined,
                    accentColor: AppColors.error,
                    children: [
                      _SettingsTile(icon: Icons.logout, iconColor: AppColors.warning, title: 'Log Out', titleColor: AppColors.warning, onTap: () => _showLogoutDialog(context)),
                      _SettingsTile(icon: Icons.delete_forever_outlined, iconColor: AppColors.error, title: 'Delete Account', titleColor: AppColors.error, onTap: () => _showDeleteDialog(context)),
                    ],
                  ),
                  const SizedBox(height: 32),
                  _buildAppVersion(),
                  const SizedBox(height: 40),
                ]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSection({required String title, required IconData icon, required List<Widget> children, Color? accentColor}) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.only(left: 4, bottom: 12),
          child: Row(
            children: [
              Icon(icon, size: 18, color: accentColor ?? AppColors.primary),
              const SizedBox(width: 8),
              Text(title, style: TextStyle(fontSize: 14, fontWeight: FontWeight.w700, color: accentColor ?? AppColors.primary, letterSpacing: 0.3)),
            ],
          ),
        ),
        Container(
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(16),
            boxShadow: [BoxShadow(color: Colors.black.withOpacity(0.04), blurRadius: 12, offset: const Offset(0, 4))],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(16),
            child: Column(
              children: children.asMap().entries.map((entry) {
                final isLast = entry.key == children.length - 1;
                return Column(children: [entry.value, if (!isLast) Divider(height: 1, indent: 56, color: AppColors.border.withOpacity(0.5))]);
              }).toList(),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildSwitch(bool value, ValueChanged<bool> onChanged) => Switch(value: value, onChanged: onChanged, activeColor: AppColors.primary, activeTrackColor: AppColors.primarySoft);
  Widget _buildUpgradeBadge() => Container(padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6), decoration: BoxDecoration(gradient: AppColors.primaryGradient, borderRadius: BorderRadius.circular(16)), child: const Text('UPGRADE', style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: Colors.white)));
  Widget _buildAppVersion() => Center(child: Column(children: [Container(width: 48, height: 48, decoration: BoxDecoration(color: AppColors.primarySoft, borderRadius: BorderRadius.circular(12)), child: Icon(Icons.favorite, color: AppColors.primary, size: 24)), const SizedBox(height: 12), Text('Nexus', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700, color: AppColors.textPrimary)), const SizedBox(height: 4), Text('Version 2.0.0', style: TextStyle(fontSize: 13, color: AppColors.textMuted))]));

  Widget _buildAppearanceSection() {
    final isDarkMode = ref.watch(isDarkModeProvider);
    
    return _buildSection(
      title: 'Appearance',
      icon: Icons.palette_outlined,
      children: [
        _SettingsTile(
          icon: isDarkMode ? Icons.dark_mode : Icons.light_mode,
          title: 'Dark Mode',
          subtitle: isDarkMode ? 'Currently enabled' : 'Currently disabled',
          trailing: Switch(
            value: isDarkMode,
            onChanged: (value) {
              HapticFeedback.lightImpact();
              ref.read(themeModeProvider.notifier).toggleTheme();
            },
            activeColor: AppColors.primary,
            activeTrackColor: AppColors.primarySoft,
          ),
        ),
      ],
    );
  }
  String _getStatusLabel(dynamic status) {
    final s = status?.toString() ?? '';
    if (s.contains('single_never')) return 'Single (Never Married)';
    if (s.contains('divorced') || s.contains('widowed')) return 'Divorced / Widowed';
    if (s.contains('married')) return 'Married';
    return 'Not set';
  }

  void _showUsernameSheet(BuildContext context, String? current) {
    final controller = TextEditingController(text: current);
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => _BottomSheet(title: 'Change Username', child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(controller: controller, autofocus: true, decoration: _inputDecoration('username', prefixText: '@')), const SizedBox(height: 24), _SheetButtons(onSave: () => Navigator.pop(ctx))])));
  }

  void _showPasswordSheet(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => _BottomSheet(title: 'Change Password', child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(obscureText: true, decoration: _inputDecoration('Current Password')), const SizedBox(height: 12), TextField(obscureText: true, decoration: _inputDecoration('New Password')), const SizedBox(height: 12), TextField(obscureText: true, decoration: _inputDecoration('Confirm Password')), const SizedBox(height: 24), _SheetButtons(saveLabel: 'Update', onSave: () => Navigator.pop(ctx))])));
  }

  void _showVisibilitySheet(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => _BottomSheet(title: 'Profile Visibility', child: Column(mainAxisSize: MainAxisSize.min, children: [_OptionTile(icon: Icons.public, title: 'Everyone', subtitle: 'Visible to all users', isSelected: true, onTap: () => Navigator.pop(ctx)), _OptionTile(icon: Icons.visibility_off, title: 'Hidden', subtitle: 'Hidden from search', onTap: () => Navigator.pop(ctx))])));
  }

  void _showStatusSheet(BuildContext context) {
    showModalBottomSheet(context: context, backgroundColor: Colors.transparent, builder: (ctx) => _BottomSheet(title: 'Relationship Status', child: Column(mainAxisSize: MainAxisSize.min, children: [_OptionTile(icon: Icons.person, title: 'Single (Never Married)', subtitle: 'Access dating features', onTap: () => Navigator.pop(ctx)), _OptionTile(icon: Icons.person_outline, title: 'Divorced / Widowed', subtitle: 'Dating + co-parenting content', onTap: () => Navigator.pop(ctx)), _OptionTile(icon: Icons.favorite, title: 'Married', subtitle: 'Marriage enrichment content', onTap: () => Navigator.pop(ctx))])));
  }

  void _showFeedbackSheet(BuildContext context) {
    showModalBottomSheet(context: context, isScrollControlled: true, backgroundColor: Colors.transparent, builder: (ctx) => _BottomSheet(title: 'Send Feedback', child: Column(mainAxisSize: MainAxisSize.min, children: [TextField(maxLines: 4, decoration: _inputDecoration('Tell us what you think...')), const SizedBox(height: 24), _SheetButtons(saveLabel: 'Send', onSave: () { Navigator.pop(ctx); ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: const Text('Thank you!'), backgroundColor: AppColors.success, behavior: SnackBarBehavior.floating)); })])));
  }

  void _showLogoutDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: const Text('Log Out'), content: const Text('Are you sure you want to log out?'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: Text('Cancel', style: TextStyle(color: AppColors.textSecondary))), ElevatedButton(onPressed: () async { Navigator.pop(ctx); await ref.read(authServiceProvider).signOut(); if (context.mounted) context.go('/login'); }, style: ElevatedButton.styleFrom(backgroundColor: AppColors.warning, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Log Out', style: TextStyle(color: Colors.white)))]));
  }

  void _showDeleteDialog(BuildContext context) {
    showDialog(context: context, builder: (ctx) => AlertDialog(shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)), title: Row(children: [Icon(Icons.warning_amber, color: AppColors.error), const SizedBox(width: 8), const Text('Delete Account')]), content: const Text('This cannot be undone. All data will be permanently deleted.'), actions: [TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')), ElevatedButton(onPressed: () => Navigator.pop(ctx), style: ElevatedButton.styleFrom(backgroundColor: AppColors.error, shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Delete', style: TextStyle(color: Colors.white)))]));
  }

  InputDecoration _inputDecoration(String hint, {String? prefixText}) => InputDecoration(hintText: hint, prefixText: prefixText, filled: true, fillColor: AppColors.surfaceLight, border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none), focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide(color: AppColors.primary, width: 2)));
}

class _SettingsTile extends StatelessWidget {
  final IconData icon;
  final Color? iconColor;
  final String title;
  final Color? titleColor;
  final String? subtitle;
  final Widget? trailing;
  final VoidCallback? onTap;

  const _SettingsTile({required this.icon, this.iconColor, required this.title, this.titleColor, this.subtitle, this.trailing, this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(width: 36, height: 36, decoration: BoxDecoration(color: (iconColor ?? AppColors.textSecondary).withOpacity(0.1), borderRadius: BorderRadius.circular(10)), child: Icon(icon, size: 18, color: iconColor ?? AppColors.textSecondary)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: titleColor ?? AppColors.textPrimary)), if (subtitle != null) ...[const SizedBox(height: 2), Text(subtitle!, style: TextStyle(fontSize: 12, color: AppColors.textMuted))]])),
              if (trailing != null) trailing! else if (onTap != null) Icon(Icons.chevron_right, color: AppColors.textMuted, size: 20),
            ],
          ),
        ),
      ),
    );
  }
}

class _BottomSheet extends StatelessWidget {
  final String title;
  final Widget child;
  const _BottomSheet({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(24))),
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(mainAxisSize: MainAxisSize.min, crossAxisAlignment: CrossAxisAlignment.start, children: [
          Center(child: Container(width: 40, height: 4, decoration: BoxDecoration(color: AppColors.border, borderRadius: BorderRadius.circular(2)))),
          const SizedBox(height: 24),
          Text(title, style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w700)),
          const SizedBox(height: 20),
          child,
          SizedBox(height: MediaQuery.of(context).padding.bottom + 8),
        ]),
      ),
    );
  }
}

class _SheetButtons extends StatelessWidget {
  final String saveLabel;
  final VoidCallback onSave;
  const _SheetButtons({this.saveLabel = 'Save', required this.onSave});

  @override
  Widget build(BuildContext context) {
    return Row(children: [
      Expanded(child: OutlinedButton(onPressed: () => Navigator.pop(context), style: OutlinedButton.styleFrom(padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: const Text('Cancel'))),
      const SizedBox(width: 12),
      Expanded(child: ElevatedButton(onPressed: onSave, style: ElevatedButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))), child: Text(saveLabel, style: const TextStyle(color: Colors.white)))),
    ]);
  }
}

class _OptionTile extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;
  final bool isSelected;
  final VoidCallback onTap;
  const _OptionTile({required this.icon, required this.title, required this.subtitle, this.isSelected = false, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 12),
          child: Row(children: [
            Container(width: 44, height: 44, decoration: BoxDecoration(color: isSelected ? AppColors.primarySoft : AppColors.surfaceLight, borderRadius: BorderRadius.circular(12)), child: Icon(icon, color: isSelected ? AppColors.primary : AppColors.textSecondary)),
            const SizedBox(width: 14),
            Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [Text(title, style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600, color: AppColors.textPrimary)), Text(subtitle, style: TextStyle(fontSize: 12, color: AppColors.textMuted))])),
            if (isSelected) Icon(Icons.check_circle, color: AppColors.primary),
          ]),
        ),
      ),
    );
  }
}
