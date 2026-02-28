import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const String lastUpdated = 'January 12, 2026';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Terms of Service',
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _buildHeader(context, 'NEXUS TERMS OF SERVICE'),
              const SizedBox(height: 8),
              _buildSubtleText(context, 'Last updated: $lastUpdated'),
              const SizedBox(height: 24),
              _buildBodyText(
                context,
                'These Terms of Service ("Terms") govern your use of the Nexus mobile application and related services (collectively, "Nexus", "we", "us", or "our"). By accessing or using Nexus, you agree to these Terms. If you do not agree, do not use Nexus.',
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                '1) WHO NEXUS IS FOR',
                'Nexus is a personal and marital growth ecosystem that seeks to help single, married, divorced, or widowed individuals build Kingdom marriages and families, they way God intended.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '2) ACCOUNT AND ACCESS',
                'You may use Nexus as a guest (where available) or by creating an account. You are responsible for:',
                bullets: [
                  'Providing accurate information (where required)',
                  'Keeping your login credentials confidential',
                  'All activity under your account',
                ],
                footer:
                    'We may suspend or terminate access if we believe your account is being used in a way that violates these Terms or harms the community.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '3) COMMUNITY STANDARDS AND SAFETY',
                'You agree not to:',
                bullets: [
                  'Harass, threaten, shame, stalk, or intimidate others',
                  'Share hateful, discriminatory, sexually exploitative, or violent content',
                  'Share private information (yours or others\') without consent',
                  'Impersonate others or misrepresent your identity',
                  'Use Nexus to solicit money, scams, or illegal activity',
                ],
                footer:
                    'We may remove content or restrict accounts to protect users and the community.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '4) CONTENT IS NOT PROFESSIONAL ADVICE',
                'Nexus may provide educational content related to relationships, communication, marriage, faith, and emotional wellbeing. Nexus does NOT provide medical, mental health, psychiatric, legal, or financial advice. If you need professional support, please consult a qualified professional or local emergency services.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '5) ASSESSMENTS, AND JOURNEYS',
                'Assessment Results and Recommended Journeys are informational tools designed to help guide your experience. They may not be accurate for every person and should not be treated as definitive diagnosis, judgment, or label. You are responsible for your choices and actions.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '6) SUBSCRIPTIONS, FEES, AND PAYMENTS',
                'Some features may require payment (e.g., subscriptions or paid Programs). Pricing and features may change over time. If you purchase a subscription:',
                bullets: [
                  'Payments are handled by the platform provider (e.g., Apple/Google) unless otherwise stated',
                  'Subscriptions renew automatically unless canceled through your device\'s subscription settings',
                  'Refunds follow the platform provider\'s refund policies, unless required by local law',
                ],
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '7) USER CONTENT AND LICENSE',
                'If you submit content (text, images, audio, profile data, feedback) ("User Content"), you own your User Content. You grant Nexus a limited license to host, store, display, and process your User Content to operate and improve Nexus, provide features, keep the community safe, and comply with legal obligations.\n\nYou are responsible for ensuring you have rights to submit any User Content you upload.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '8) INTELLECTUAL PROPERTY',
                'Nexus and our Programs, designs, graphics, branding, and original content are owned by us or our licensors and are protected by intellectual property laws. You may not copy, modify, distribute, or reverse engineer Nexus except where legally permitted.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '9) PROHIBITED USES',
                'You may not:',
                bullets: [
                  'Attempt to bypass security or access restricted parts of the app',
                  'Scrape or harvest user data',
                  'Use bots or automated tools to interact with Nexus',
                  'Interfere with service availability or performance',
                ],
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '10) TERMINATION',
                'You may stop using Nexus at any time. We may suspend or terminate your access if:',
                bullets: [
                  'You violate these Terms',
                  'We must do so to comply with law',
                  'Your use risks harm to Nexus or other users',
                ],
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '11) DISCLAIMERS',
                'Nexus is provided "as is" and "as available." We do not guarantee uninterrupted service, error-free operation, or that content will meet your expectations.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '12) LIMITATION OF LIABILITY',
                'To the maximum extent allowed by law, Nexus is not liable for indirect, incidental, special, consequential, or punitive damages, or loss of data, revenue, or goodwill. Our total liability for claims related to Nexus is limited to the amount you paid to Nexus in the 12 months before the claim (or zero if you used Nexus without paying), to the extent permitted by law.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '13) CHANGES TO THESE TERMS',
                'We may update these Terms occasionally. We will update the "Last updated" date. Continued use after an update means you accept the updated Terms.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '14) CONTACT',
                'If you have questions about these Terms, contact us at:\n\ncontact@nexus4singles.com',
              ),
              const SizedBox(height: 40),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _buildHeader(BuildContext context, String text) {
    return Text(
      text,
      style: AppTextStyles.titleLarge.copyWith(
        fontWeight: FontWeight.w800,
        color: AppColors.getTextPrimary(context),
      ),
    );
  }

  static Widget _buildSubtleText(BuildContext context, String text) {
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.getTextSecondary(context),
      ),
    );
  }

  static Widget _buildBodyText(BuildContext context, String text) {
    return Text(
      text,
      style: AppTextStyles.bodyMedium.copyWith(
        color: AppColors.getTextPrimary(context),
        height: 1.6,
      ),
    );
  }

  static Widget _buildSection(
    BuildContext context,
    String title,
    String content, {
    List<String>? bullets,
    String? footer,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          title,
          style: AppTextStyles.titleMedium.copyWith(
            fontWeight: FontWeight.w700,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        _buildBodyText(context, content),
        if (bullets != null && bullets.isNotEmpty) ...[
          const SizedBox(height: 12),
          ..._buildBulletList(context, bullets),
        ],
        if (footer != null) ...[
          const SizedBox(height: 12),
          _buildBodyText(context, footer),
        ],
      ],
    );
  }

  static List<Widget> _buildBulletList(
    BuildContext context,
    List<String> items,
  ) {
    return items.map((item) {
      return Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 4),
              child: Text(
                '•',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            Expanded(child: _buildBodyText(context, item)),
          ],
        ),
      );
    }).toList();
  }
}
