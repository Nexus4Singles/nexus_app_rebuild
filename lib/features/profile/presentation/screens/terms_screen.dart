import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const String lastUpdated = 'June 22, 2026';
  static const String effectiveDate = 'June 22, 2026';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding = width < 420 ? 16.0 : width < 720 ? 20.0 : 24.0;
    final verticalPadding = width < 420 ? 16.0 : 20.0;
    final maxContentWidth = width > 900 ? 820.0 : double.infinity;
    final headingSize = width < 420 ? 18.0 : width < 720 ? 20.0 : 22.0;
    final sectionSpacing = width < 420 ? 20.0 : width < 720 ? 24.0 : 28.0;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Terms of Service',
          style: AppTextStyles.headlineSmall.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: headingSize,
          ),
        ),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: EdgeInsets.symmetric(
            horizontal: horizontalPadding,
            vertical: verticalPadding,
          ),
          child: Center(
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxContentWidth),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildHeader(context, 'NEXUS TERMS OF SERVICE'),
                  SizedBox(height: sectionSpacing * 0.15),
                  _buildSubtleText(
                    context,
                    'Last updated: $lastUpdated | Effective: $effectiveDate',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildBodyText(
                    context,
                    'These Terms of Service ("Terms", "Agreement") constitute a legally binding agreement between you ("User", "you") and Nexus ("Company", "we", "us", "our"). By downloading, accessing, or using the Nexus mobile application and services (the "Service"), you acknowledge that you have read, understood, and agree to be bound by these Terms. If you do not agree, you must not use the Service.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '1. ELIGIBILITY & AGE RESTRICTIONS',
                    'By using Nexus, you represent and warrant that:',
                    bullets: [
                      'You are at least the minimum age of digital consent in your jurisdiction (typically 18+, or the age of majority)',
                      'You have the legal authority to enter into this Agreement',
                      'You will comply with all applicable laws and regulations',
                      'You have not been prohibited from using online services due to legal restrictions',
                      'You are not a resident of a jurisdiction where Nexus services are restricted by law',
                    ],
                    footer: 'Nexus is intended for adults only. We do not knowingly serve minors. Use by minors without proper parental/legal guardian consent is prohibited.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '2. SERVICE DESCRIPTION',
                    'Nexus is a personal and relational growth platform designed to help individuals and couples build healthy relationships and marriages grounded in Christian values. The Service includes:',
                    bullets: [
                      'Relationship and marriage programs, assessments, and journeys',
                      'Faith-based content and resources',
                      'Communication tools and couple features',
                      'Community features (where enabled)',
                      'Premium subscription content and programs',
                    ],
                    footer: 'Nexus reserves the right to modify, suspend, or discontinue any feature with reasonable notice. We are not responsible for third-party content or services.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '3. ACCOUNT REGISTRATION & SECURITY',
                    'To use certain features of Nexus, you must create an account. You agree to:',
                    bullets: [
                      'Provide accurate, truthful, and current information during registration',
                      'Maintain the confidentiality of your password and account credentials',
                      'Accept full responsibility for all activity under your account',
                      'Immediately notify us of unauthorized access or account breach',
                      'Update account information to keep it accurate and current',
                      'Not share your account with others or allow unauthorized use',
                    ],
                    footer: 'Nexus may suspend or terminate accounts that violate these terms, engage in harmful behavior, or appear fraudulent. Multiple account creation to circumvent restrictions is prohibited.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '4. USER CONDUCT & COMMUNITY STANDARDS',
                    'You agree not to use Nexus for any unlawful purpose or in violation of these Terms. Prohibited conduct includes:',
                    bullets: [
                      'Harassment, bullying, threats, intimidation, or abuse of any user or employee',
                      'Hate speech, discrimination, or content promoting violence based on protected characteristics',
                      'Sexual harassment, exploitation, or non-consensual intimate imagery',
                      'Stalking, doxxing, or sharing private information without consent',
                      'Impersonation, misrepresentation, or deception',
                      'Scams, fraud, or solicitation of money for illegal purposes',
                      'Attempted unauthorized access or hacking of the Service',
                      'Spamming, flooding, or disruption of the Service',
                      'Copyright infringement or intellectual property violations',
                      'Marketing, advertising, or promotion without authorization',
                    ],
                    footer: 'We reserve the right to investigate violations, remove content, restrict features, or terminate accounts. We may report illegal activity to law enforcement.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '5. CONTENT RESPONSIBILITY & DISCLAIMERS',
                    'Nexus provides informational and educational content related to relationships, marriage, communication, and faith. Important disclaimers:',
                    bullets: [
                      'Nexus does NOT provide medical, psychiatric, mental health, legal, or financial advice',
                      'Assessment results are informational only and not diagnostic or definitive judgments',
                      'Recommended journeys and programs are guides, not professional treatment',
                      'All content is for educational purposes and general information',
                      'Users should consult qualified professionals for medical, legal, or mental health concerns',
                      'In emergencies, contact local emergency services or crisis helplines immediately',
                    ],
                    footer: 'You are solely responsible for decisions made based on Nexus content. Nexus makes no guarantees regarding results or outcomes from using the Service.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '6. USER-GENERATED CONTENT & LICENSE GRANT',
                    'If you submit content to Nexus (text, images, audio, videos, assessments, profile data, feedback, or comments) ("User Content"), you:',
                    bullets: [
                      'Represent that you own or have rights to the User Content',
                      'Grant Nexus a worldwide, royalty-free, perpetual license to use, reproduce, display, and modify User Content to operate and improve the Service',
                      'Grant Nexus the right to use User Content for analytics, research, and quality improvement',
                      'Waive moral rights to the extent permitted by law',
                      'Warrant that User Content does not violate third-party rights or these Terms',
                      'Acknowledge that User Content may be visible to other users in the Service',
                    ],
                    footer: 'Nexus is not obligated to publish, monitor, or respond to User Content. You may delete certain User Content through account settings, though backups may persist.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '7. INTELLECTUAL PROPERTY RIGHTS',
                    'Nexus and all of its content, features, functionality, designs, graphics, text, video, music, and code (the "Materials") are owned by Nexus or our licensors and are protected by international copyright, trademark, and other intellectual property laws. You may not:',
                    bullets: [
                      'Copy, modify, distribute, or transmit the Materials without authorization',
                      'Create derivative works based on Nexus',
                      'Reverse engineer, decompile, disassemble, or attempt to derive source code',
                      'Use Nexus Materials for commercial purposes',
                      'Remove copyright, trademark, or proprietary notices',
                      'Scrape, crawl, or automated harvest data or content',
                    ],
                    footer: 'All rights not expressly granted are reserved. Limited license is granted solely for personal, non-commercial use.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '8. SUBSCRIPTIONS, PAYMENTS & REFUNDS',
                    'If you purchase premium features or subscriptions:',
                    bullets: [
                      'Pricing is displayed before purchase and may change with notice',
                      'Payments are processed by Apple (iOS), Google (Android), or third-party providers',
                      'Subscriptions auto-renew unless you cancel through your device settings',
                      'Cancellation takes effect at the end of your current billing period',
                      'Refunds follow the respective app store or payment processor policies',
                      'Some refunds may be subject to our 14-day refund window where legally permitted',
                      'Nexus is not responsible for third-party payment processor errors or disputes',
                    ],
                    footer: 'You are responsible for monitoring your billing. All sales are final except where legally required to offer refunds. No refunds for suspensions due to Terms violations.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '9. LIMITATION OF LIABILITY & DISCLAIMERS',
                    'To the maximum extent permitted by applicable law:',
                    bullets: [
                      'Nexus is provided "AS IS" and "AS AVAILABLE" without warranties of any kind',
                      'We do not guarantee uninterrupted service, error-free operation, or security',
                      'We disclaim all implied warranties, including merchantability and fitness for a particular purpose',
                      'Nexus is not liable for indirect, incidental, special, consequential, or punitive damages',
                      'Nexus is not liable for loss of data, revenue, profits, goodwill, or other intangible losses',
                      'Our total liability is limited to the amount you paid in the 12 months before the claim (or zero if unpaid)',
                      'Some jurisdictions limit liability disclaimers; these terms apply to the fullest extent permitted',
                    ],
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '10. INDEMNIFICATION',
                    '''You agree to indemnify, defend, and hold harmless Nexus, our officers, directors, employees, and agents from any claims, damages, losses, liabilities, and expenses (including attorney's fees) arising from:

• Your use of the Service
• Your violation of these Terms
• Your User Content
• Your violation of any law or third-party rights
• Any dispute with another user''',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '11. TERMINATION & ACCOUNT SUSPENSION',
                    'Either you or Nexus may terminate this Agreement:',
                    bullets: [
                      'You may stop using Nexus and delete your account at any time',
                      'Nexus may suspend your account immediately for Terms violations',
                      'Nexus may terminate access if you violate these Terms or harm the community',
                      'Nexus may terminate for legal compliance or to protect users',
                      'Nexus may terminate for inactivity or non-use (notice will be provided)',
                      'Upon termination, your license to use Nexus ends; we may delete your data',
                      'Sections surviving termination: Intellectual Property, Limitation of Liability, Indemnification, Governing Law',
                    ],
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '12. THIRD-PARTY SERVICES & LINKS',
                    '''Nexus may contain links to or integrate with third-party services, platforms, and websites. Nexus does not endorse or assume responsibility for:

• Third-party content or services
• Their privacy practices or terms of use
• Transaction disputes or data breaches

You use third-party services at your own risk and per their terms. We are not liable for third-party conduct.''',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '13. CHANGES TO TERMS & SERVICE',
                    '''Nexus may update these Terms at any time. Material changes will be communicated via:

• In-app notification
• Email notification to your registered address
• Posted notice in the Service

Your continued use after changes means you accept updated Terms. If you do not accept changes, stop using the Service.''',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '14. GOVERNING LAW & DISPUTE RESOLUTION',
                    '''These Terms are governed by the laws of the United States and applicable state law, without regard to conflicts of law principles. Any disputes will be resolved:

• First through good-faith negotiation
• Then through binding arbitration (not class action)
• In the state/jurisdiction where Nexus is incorporated

You waive your right to jury trial and class action participation.''',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '15. SEVERABILITY & WAIVERS',
                    'If any provision of these Terms is found invalid or unenforceable, that provision will be modified to the minimum extent necessary, and other provisions remain in effect. No waiver of any provision constitutes waiver of any other provision. Our failure to enforce a right does not constitute waiver of that right.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '16. ENTIRE AGREEMENT',
                    'These Terms, together with our Privacy Policy and any other policies referenced, constitute the entire agreement between you and Nexus regarding the Service and supersede all prior negotiations, understandings, and agreements.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '17. CONTACT FOR TERMS QUESTIONS',
                    '''If you have questions about these Terms or need to report violations:

Email: contact@nexus4christians.com
Email (Conduct Issues): contact@nexus4christians.com

We aim to respond to inquiries within 30 days.''',
                  ),
                  SizedBox(height: sectionSpacing * 1.4),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  static double _responsiveScale(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    if (width > 720) return 1.0;
    if (width > 420) return 0.98;
    return 0.96;
  }

  static Widget _buildHeader(BuildContext context, String text) {
    final scale = _responsiveScale(context);
    return Text(
      text,
      style: AppTextStyles.titleSmall.copyWith(
        fontWeight: FontWeight.w800,
        fontSize: 22 * scale,
        color: AppColors.getTextPrimary(context),
        letterSpacing: 0.5,
      ),
    );
  }

  static Widget _buildSubtleText(BuildContext context, String text) {
    final scale = _responsiveScale(context);
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.getTextSecondary(context),
        fontSize: 12 * scale,
        fontWeight: FontWeight.w500,
      ),
    );
  }

  static Widget _buildBodyText(BuildContext context, String text) {
    final scale = _responsiveScale(context);
    return Text(
      text,
      style: AppTextStyles.bodySmall.copyWith(
        color: AppColors.getTextPrimary(context),
        height: 1.65,
        fontSize: 14 * scale,
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
          style: AppTextStyles.titleSmall.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 16,
            color: AppColors.getTextPrimary(context),
            letterSpacing: 0.3,
          ),
        ),
        const SizedBox(height: 14),
        _buildBodyText(context, content),
        if (bullets != null && bullets.isNotEmpty) ...[
          const SizedBox(height: 14),
          ..._buildBulletList(context, bullets),
        ],
        if (footer != null) ...[
          const SizedBox(height: 14),
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
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.only(right: 12, top: 2),
              child: Text(
                '•',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
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
