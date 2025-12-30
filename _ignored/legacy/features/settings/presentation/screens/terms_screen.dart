import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../../../../core/theme/app_colors.dart';

/// Terms of Service Screen - Premium Design
class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

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
                          'Terms of Service',
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
                _buildSection(
                  '1. Acceptance of Terms',
                  'By accessing or using the Nexus app, you agree to be bound by these Terms of Service. If you do not agree to these terms, please do not use the app.',
                ),
                _buildSection(
                  '2. Eligibility',
                  'You must be at least 21 years old to use Nexus. By using the app, you represent and warrant that you meet this age requirement and have the legal capacity to enter into this agreement.',
                ),
                _buildSection(
                  '3. Account Registration',
                  'To use Nexus, you must create an account with accurate and complete information. You are responsible for maintaining the confidentiality of your account credentials and for all activities under your account.',
                ),
                _buildSection(
                  '4. User Conduct',
                  'You agree to use Nexus in a manner consistent with Christian values and community guidelines. Prohibited conduct includes:\n\n• Harassment or bullying of other users\n• Posting false, misleading, or deceptive content\n• Sharing inappropriate or explicit content\n• Impersonating another person\n• Using the app for commercial purposes without authorization\n• Attempting to circumvent security measures',
                ),
                _buildSection(
                  '5. Content Guidelines',
                  'All content you share, including photos, audio recordings, and profile information, must be accurate and represent you authentically. We reserve the right to remove any content that violates our guidelines.',
                ),
                _buildSection(
                  '6. Privacy',
                  'Your privacy is important to us. Please review our Privacy Policy to understand how we collect, use, and protect your personal information.',
                ),
                _buildSection(
                  '7. Subscription and Payments',
                  'Some features of Nexus require a paid subscription. Subscription terms, pricing, and cancellation policies are provided in the app. All payments are processed securely through our payment providers.',
                ),
                _buildSection(
                  '8. Intellectual Property',
                  'Nexus and its original content, features, and functionality are owned by Nexus and are protected by copyright, trademark, and other intellectual property laws.',
                ),
                _buildSection(
                  '9. Disclaimer',
                  'Nexus is provided "as is" without warranties of any kind. We do not guarantee that you will find a match or that the service will be uninterrupted or error-free.',
                ),
                _buildSection(
                  '10. Limitation of Liability',
                  'Nexus shall not be liable for any indirect, incidental, special, consequential, or punitive damages arising from your use of the app.',
                ),
                _buildSection(
                  '11. Termination',
                  'We reserve the right to suspend or terminate your account at any time for violations of these terms or for any other reason at our sole discretion.',
                ),
                _buildSection(
                  '12. Changes to Terms',
                  'We may update these Terms of Service from time to time. Continued use of the app after changes constitutes acceptance of the updated terms.',
                ),
                _buildSection(
                  '13. Contact Us',
                  'If you have questions about these Terms of Service, please contact us at support@nexusapp.com.',
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
