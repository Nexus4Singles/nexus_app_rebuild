import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String lastUpdated = 'June 22, 2026';
  static const String effectiveDate = 'June 22, 2026';

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final horizontalPadding =
        width < 420
            ? 16.0
            : width < 720
            ? 20.0
            : 24.0;
    final verticalPadding = width < 420 ? 16.0 : 20.0;
    final maxContentWidth = width > 900 ? 820.0 : double.infinity;
    final sectionSpacing =
        width < 420
            ? 20.0
            : width < 720
            ? 24.0
            : 28.0;
    final headingSize =
        width < 420
            ? 18.0
            : width < 720
            ? 20.0
            : 22.0;

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Privacy Policy',
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
                  _buildHeader(context, 'NEXUS PRIVACY POLICY'),
                  SizedBox(height: sectionSpacing * 0.15),
                  _buildSubtleText(
                    context,
                    'Last updated: $lastUpdated | Effective: $effectiveDate',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildBodyText(
                    context,
                    'This Privacy Policy explains how Nexus ("Nexus", "we", "us", "our", "Company") collects, uses, shares, retains, and protects personal information when you use the Nexus mobile application and related services (collectively, the "Service"). We are committed to being transparent about our data practices and respecting your privacy rights.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '1. DATA CONTROLLER & CONTACT INFORMATION',
                    '''Nexus is the data controller for personal information collected through the Service. Questions about this Privacy Policy or our privacy practices should be directed to:

Email: contact@nexus4christians.com

We typically respond to privacy inquiries within 30 days.''',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '2. WHAT WE COLLECT',
                    'We collect the following types of information:',
                    subsections: [
                      _SubsectionData('A. Information You Provide Directly', [
                        'Account registration data (email, username, password, phone number)',
                        'Profile information (name, photo, date of birth, bio, relationship status, interests, preferences)',
                        'Faith-based and relationship content you choose to share',
                        'Support messages, feedback, survey responses, and user-generated content',
                        'Payment and transaction information (processed through third-party payment providers)',
                        'Communication preferences and notification settings',
                      ]),
                      _SubsectionData('B. Information Collected Automatically', [
                        'Device information (model, manufacturer, operating system, OS version, app version)',
                        'Usage data (features accessed, screens viewed, time spent on app, interaction patterns)',
                        'Connection information (IP address, device identifiers, wireless network data)',
                        'Approximate location inferred from IP address (for security and content delivery)',
                        'App performance and crash data',
                        'Mobile device information including unique device identifiers',
                      ]),
                      _SubsectionData('C. Information from Third Parties', [
                        'Analytics providers (usage patterns and performance metrics)',
                        'Platform providers (Apple, Google - subscription and transaction data)',
                        'Business partners and service providers',
                      ]),
                      _SubsectionData('D. Sensitive Personal Data', [
                        'We may collect sensitive information including religious beliefs, relationship history, and wellbeing data through optional assessments and reflections. You control whether to submit this information. We treat all sensitive data with heightened protection.',
                      ]),
                    ],
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '3. LAWFUL BASIS FOR PROCESSING (GDPR)',
                    'We process your personal information based on the following lawful bases:',
                    bullets: [
                      'Contract: To fulfill our agreement with you and provide the Service',
                      'Consent: Where you have explicitly consented to specific processing (e.g., marketing communications)',
                      'Legitimate Interests: To operate, improve, and secure our Service; prevent fraud and abuse; conduct analytics; and improve user experience',
                      'Legal Obligation: To comply with applicable laws and regulations',
                      'Vital Interests: To protect the safety and wellbeing of users',
                    ],
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '4. HOW WE USE INFORMATION',
                    'We use your information for the following purposes:',
                    bullets: [
                      'Provide and operate Service features (programs, assessments, personalization, account management)',
                      'Communicate with you (support responses, service updates, announcements, newsletters with your consent)',
                      'Improve and enhance the Service (analytics, troubleshooting, feature development, testing)',
                      'Keep the community safe (fraud detection, abuse prevention, account security, enforcement of policies)',
                      'Process payments and manage subscriptions through platform providers',
                      'Comply with legal obligations and respond to lawful requests from authorities',
                      'Create aggregated, de-identified data for research and reporting',
                      'Personalize your experience and provide tailored recommendations',
                    ],
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '5. AUTOMATED DECISION-MAKING & PROFILING',
                    '''Nexus uses automated decision-making to personalize your experience, including:

• Assessment result analysis and journey recommendations
• Content personalization based on preferences and behavior
• Safety measures to detect and prevent fraudulent activity

You have the right to request human review of automated decisions that significantly affect you. Reach out to us at contact@nexus4christians.com with details of the decision.''',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '6. HOW WE SHARE INFORMATION',
                    'We do not sell your personal information to third parties for their direct marketing.',
                    bullets: [
                      'Service Providers: We share information with vendors under Data Processing Agreements (email providers, cloud hosting providers, analytics services, customer support platforms) - all bound by strict confidentiality',
                      'Payment Processors: Payment and subscription information is shared with Apple, Google, and RevenueCat for transaction processing only',
                      'Safety & Legal: We may disclose information to comply with legal obligations, respond to lawful requests from authorities, protect user safety, or prevent fraud',
                      'Business Transfers: In the event of merger, acquisition, bankruptcy, or asset sale, your information may be transferred as part of that transaction',
                      'Aggregated Data: We may share anonymized, aggregated insights for research, analytics, and reporting',
                      'With Your Consent: We may share information with third parties when you explicitly consent',
                    ],
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '7. INTERNATIONAL DATA TRANSFERS',
                    'If you are located outside the United States, your data will be transferred to and processed in the United States. We employ Standard Contractual Clauses (SCCs) for lawful data transfers from EEA/UK. By using Nexus, you consent to such transfers. If you do not consent, do not use the Service.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '8. DATA RETENTION & DELETION',
                    'We retain information for as long as necessary to:',
                    bullets: [
                      'Provide the Service and fulfill your account needs',
                      'Comply with legal obligations and tax requirements',
                      'Enforce agreements and resolve disputes',
                      'Prevent fraud and maintain security',
                      'Support legitimate business purposes',
                    ],
                    footer:
                        'Backup copies may persist for 30-90 days after deletion. Certain data may be retained longer where required by law. Upon request, we will delete or anonymize your data where legally permitted (right to erasure). Some data may remain for legal compliance or security purposes.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '9. YOUR PRIVACY RIGHTS & CONTROLS',
                    'Depending on your location (especially under GDPR, CCPA, and similar laws), you may have the following rights:',
                    bullets: [
                      'Right to Access: Request a copy of your personal data',
                      'Right to Rectification: Correct inaccurate or incomplete information',
                      'Right to Erasure: Request deletion of your data (subject to legal limitations)',
                      'Right to Data Portability: Receive your data in a portable, machine-readable format',
                      'Right to Object: Object to processing based on legitimate interests',
                      'Right to Restrict Processing: Limit how we use your information',
                      'Right to Withdraw Consent: Withdraw consent for marketing or optional processing',
                      'Right to Lodge a Complaint: File a complaint with your local data protection authority',
                      'Right to Opt-Out: Opt out of marketing communications anytime',
                    ],
                    footer:
                        'To exercise these rights, email contact@nexus4christians.com with your request and proof of identity. We will respond within 30 days. You may also adjust privacy settings directly in the app.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '10. COOKIES & TRACKING TECHNOLOGIES',
                    '''The Service may use cookies, pixels, and similar tracking technologies to:

• Maintain your session and preferences
• Analyze usage patterns and improve features
• Deliver personalized content
• Prevent fraud

You can control cookie preferences through your device settings or opt-out of analytics (where applicable). Some features may not function without cookies.''',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '11. THIRD-PARTY SERVICES & LINKS',
                    'Nexus may include links to or integrate with third-party services (e.g., social media, analytics providers). We are not responsible for their privacy practices. We recommend reviewing their privacy policies separately. If you link your account to third-party services, they may collect data per their own policies.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '12. SECURITY MEASURES',
                    '''We implement reasonable technical, administrative, and physical security measures including:

• Encryption in transit (TLS/SSL) and at rest
• Secure authentication and password protocols
• Access controls and employee training
• Regular security assessments

However, no security system is 100% secure. Please use a strong password, enable two-factor authentication where available, and keep your device secure. You are responsible for maintaining account security.''',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '13. CHILDREN & MINORS',
                    'Nexus is intended for adults only. We do not knowingly collect information from individuals under the applicable age of digital consent in their jurisdiction (typically 13-16 years). If we learn we have collected data from a minor without proper consent, we will delete it promptly. If you believe a minor\'s data has been collected, reach out on contact@nexus4christians.com.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '14. CALIFORNIA PRIVACY RIGHTS (CCPA/CPRA)',
                    'If you are a California resident, you have additional rights under CCPA/CPRA:',
                    bullets: [
                      'Right to Know: What personal information is collected, used, and shared',
                      'Right to Delete: Request deletion of personal data we have collected',
                      'Right to Opt-Out: Opt out of the sale or sharing of personal information',
                      'Right to Correct: Correct inaccurate personal information',
                      'Right to Non-Discrimination: No discrimination for exercising your rights',
                    ],
                    footer:
                        'To submit a CCPA request, email contact@nexus4christians.com. We will verify your identity and respond within 45 days.',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '15. EUROPEAN PRIVACY RIGHTS (GDPR)',
                    'If you are in the EEA or UK, you have rights under GDPR including those listed in Section 9. You have the right to lodge a complaint with your local data protection authority. To contact the Information Commissioner\'s Office (UK): www.ico.org.uk/make-a-complaint',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '16. SUB-PROCESSORS & SERVICE PROVIDERS',
                    '''We work with the following categories of service providers:

• Cloud Hosting: Firebase/Google Cloud
• Analytics: Firebase Analytics, Mixpanel
• Payment Processing: Apple, Google, RevenueCat
• Customer Support: Intercom, Zendesk
• Email Services: SendGrid, Mailgun

For a current list of specific sub-processors and their data processing locations, email contact@nexus4christians.com.''',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '17. CHANGES TO THIS POLICY',
                    '''We may update this Privacy Policy to reflect changes in our practices, technology, legal requirements, or other factors. We will notify you of material changes by:

• Updating the "Last updated" date
• Posting the revised policy in the app
• Sending you a notification (for significant changes)

Your continued use of Nexus after updates constitutes acceptance of the revised policy. We encourage you to review this policy periodically.''',
                  ),
                  SizedBox(height: sectionSpacing),
                  _buildSection(
                    context,
                    '18. PRIVACY INQUIRY & CONTACT',
                    '''For privacy-related questions, concerns, or to exercise your rights:

Email: contact@nexus4christians.com

We aim to respond within 30 days. For unresolved concerns, you may contact your local data protection authority.''',
                  ),
                  SizedBox(height: sectionSpacing * 1.2),
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
    List<_SubsectionData>? subsections,
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
        const SizedBox(height: 16),
        if (content.isNotEmpty) ...[
          _buildBodyText(context, content),
          const SizedBox(height: 16),
        ],
        if (subsections != null && subsections.isNotEmpty) ...[
          ..._buildSubsections(context, subsections),
        ],
        if (bullets != null && bullets.isNotEmpty) ...[
          ..._buildBulletList(context, bullets),
        ],
        if (footer != null) ...[
          const SizedBox(height: 16),
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
              padding: const EdgeInsets.only(right: 16, top: 2),
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

  static List<Widget> _buildSubsections(
    BuildContext context,
    List<_SubsectionData> subsections,
  ) {
    return subsections.expand((subsection) {
      return [
        Text(
          subsection.title,
          style: AppTextStyles.bodySmall.copyWith(
            fontWeight: FontWeight.w700,
            fontSize: 14,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 12),
        ..._buildBulletList(context, subsection.items),
        const SizedBox(height: 20),
      ];
    }).toList();
  }
}

class _SubsectionData {
  final String title;
  final List<String> items;

  _SubsectionData(this.title, this.items);
}
