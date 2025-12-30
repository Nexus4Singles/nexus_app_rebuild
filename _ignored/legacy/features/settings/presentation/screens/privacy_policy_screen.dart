import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Privacy Policy Screen - Premium Design
class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          // Premium App Bar
          SliverAppBar(
            expandedHeight: 120,
            floating: false,
            pinned: true,
            backgroundColor: AppColors.primary,
            leading: IconButton(
              onPressed: () => context.pop(),
              icon: Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(Icons.arrow_back, color: Colors.white, size: 20),
              ),
            ),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                decoration: BoxDecoration(gradient: AppColors.primaryGradient),
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.fromLTRB(60, 16, 20, 20),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Privacy Policy',
                          style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w800,
                            color: Colors.white,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Last updated: December 2025',
                          style: TextStyle(
                            fontSize: 14,
                            color: Colors.white.withOpacity(0.85),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),

          // Content
          SliverPadding(
            padding: const EdgeInsets.all(20),
            sliver: SliverList(
              delegate: SliverChildListDelegate([
                // Introduction
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primarySoft,
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.shield_outlined, color: AppColors.primary, size: 28),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Text(
                          'Your privacy matters to us. We are committed to protecting your personal information.',
                          style: TextStyle(
                            fontSize: 14,
                            color: AppColors.primary,
                            height: 1.4,
                            fontWeight: FontWeight.w500,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 28),

                _buildSection(
                  '1. Information We Collect',
                  'We collect information you provide directly, including:\n\n'
                  '• Account information (name, email, phone number)\n'
                  '• Profile information (photos, audio recordings, preferences)\n'
                  '• Church and denomination information\n'
                  '• Communication data (messages, interactions)\n'
                  '• Device and usage information',
                ),
                _buildSection(
                  '2. How We Use Your Information',
                  'Your information helps us:\n\n'
                  '• Create and manage your account\n'
                  '• Match you with compatible Christian singles\n'
                  '• Improve our services and user experience\n'
                  '• Send important notifications and updates\n'
                  '• Ensure safety and prevent fraud\n'
                  '• Comply with legal obligations',
                ),
                _buildSection(
                  '3. Information Sharing',
                  'We may share your information with:\n\n'
                  '• Other users (as part of your public profile)\n'
                  '• Service providers who help operate our platform\n'
                  '• Legal authorities when required by law\n\n'
                  'We never sell your personal information to third parties.',
                ),
                _buildSection(
                  '4. Profile Visibility',
                  'Your profile is visible to other Nexus users based on your preferences. You can control:\n\n'
                  '• Which photos are visible\n'
                  '• Profile visibility settings\n'
                  '• Who can contact you\n'
                  '• Blocking and reporting users',
                ),
                _buildSection(
                  '5. Data Security',
                  'We implement industry-standard security measures to protect your data:\n\n'
                  '• Encryption in transit and at rest\n'
                  '• Secure authentication systems\n'
                  '• Regular security audits\n'
                  '• Access controls and monitoring',
                ),
                _buildSection(
                  '6. Your Rights',
                  'You have the right to:\n\n'
                  '• Access your personal data\n'
                  '• Correct inaccurate information\n'
                  '• Delete your account and data\n'
                  '• Export your data\n'
                  '• Opt-out of certain communications',
                ),
                _buildSection(
                  '7. Data Retention',
                  'We retain your data for as long as your account is active or as needed to provide services. After account deletion, we may retain certain data for legal compliance and fraud prevention.',
                ),
                _buildSection(
                  '8. Cookies and Tracking',
                  'We use cookies and similar technologies to improve your experience, analyze usage, and serve relevant content. You can manage cookie preferences in your device settings.',
                ),
                _buildSection(
                  '9. Third-Party Services',
                  'Our app may contain links to third-party services. We are not responsible for their privacy practices. Please review their policies before providing personal information.',
                ),
                _buildSection(
                  '10. Children\'s Privacy',
                  'Nexus is not intended for users under 21 years old. We do not knowingly collect information from minors. If you believe we have collected data from a minor, please contact us.',
                ),
                _buildSection(
                  '11. International Users',
                  'Your data may be processed in countries other than your own. By using Nexus, you consent to the transfer of your data internationally.',
                ),
                _buildSection(
                  '12. Changes to This Policy',
                  'We may update this Privacy Policy periodically. We will notify you of significant changes through the app or via email.',
                ),
                _buildSection(
                  '13. Contact Us',
                  'For privacy-related questions or requests, contact us at:\n\n'
                  'Email: privacy@nexusapp.com\n'
                  'Address: Nexus, Privacy Team',
                ),
                const SizedBox(height: 40),
              ]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSection(String title, String content) {
    return Container(
      margin: const EdgeInsets.only(bottom: 24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w700,
              color: AppColors.textPrimary,
            ),
          ),
          const SizedBox(height: 10),
          Text(
            content,
            style: TextStyle(
              fontSize: 15,
              color: AppColors.textSecondary,
              height: 1.6,
            ),
          ),
        ],
      ),
    );
  }
}
