import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

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
          'Privacy Policy',
          style: AppTextStyles.headlineLarge.copyWith(
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
              _buildHeader(context, 'NEXUS PRIVACY POLICY'),
              const SizedBox(height: 8),
              _buildSubtleText(context, 'Last updated: $lastUpdated'),
              const SizedBox(height: 24),
              _buildBodyText(
                context,
                'This Privacy Policy explains how Nexus ("we", "us", "our") collects, uses, shares, and protects information when you use the Nexus mobile application ("Nexus").',
              ),
              const SizedBox(height: 24),
              _buildSection(
                context,
                '1) WHAT WE COLLECT',
                '',
                subsections: [
                  _SubsectionData('A) Information you provide', [
                    'Account details (e.g., email, username) if you create an account',
                    'Profile details you choose to share (e.g., photos, bio, preferences)',
                    'Support messages, feedback, or survey responses',
                    'Any content you submit (text, audio, images) where the feature exists',
                  ]),
                  _SubsectionData('B) Information collected automatically', [
                    'Device and app information (device type, OS version, app version)',
                    'Basic usage analytics (screens viewed, feature usage)',
                    'Approximate location inferred from IP (for security/anti-abuse, not precise GPS unless you grant permission)',
                  ]),
                  _SubsectionData(
                    'C) Sensitive topics and personal reflections',
                    [
                      'Nexus may include relationship and wellbeing prompts. We treat this content as private. You control what you submit. Please avoid submitting highly sensitive personal information you are not comfortable storing.',
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '2) HOW WE USE INFORMATION',
                'We use information to:',
                bullets: [
                  'Provide and operate Nexus features (Programs, personalization, account functions)',
                  'Improve and test product experience (analytics, troubleshooting)',
                  'Keep the community safe (fraud prevention, abuse detection, enforcement)',
                  'Communicate with you (support responses, service announcements)',
                  'Process payments/subscriptions (through platform providers, where applicable)',
                  'Comply with legal obligations',
                ],
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '3) HOW WE SHARE INFORMATION',
                'We do not sell your personal information.\n\nWe may share information:',
                bullets: [
                  'With service providers who help operate Nexus (hosting, analytics, customer support), under contractual protections',
                  'With payment processors/platform providers for subscription management',
                  'For safety, security, and legal reasons (e.g., to respond to valid legal requests; to protect users from harm; to investigate abuse)',
                  'In connection with a business transfer (e.g., merger, acquisition), where permitted by law',
                ],
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '4) DATA RETENTION',
                'We keep information as long as needed to operate Nexus and for legitimate business purposes (e.g., security, legal compliance). If you request deletion (when supported), some data may remain in backups for a limited period, or be retained where legally required.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '5) YOUR CONTROLS AND RIGHTS',
                'Depending on your location, you may have rights to:',
                bullets: [
                  'Access, correct, or delete certain information',
                  'Object to or restrict processing in some cases',
                  'Withdraw consent (where processing is based on consent)',
                ],
                footer:
                    'You can also control certain privacy options inside Nexus (where available). For requests, contact:\n\nnexusgodlydating@gmail.com',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '6) SECURITY',
                'We use reasonable safeguards to protect your information. However, no system is 100% secure. Please use a strong password and keep your device secure.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '7) CHILDREN',
                'Nexus is not intended for children. Do not use Nexus if you are under the minimum age required in your country.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '8) THIRD-PARTY LINKS',
                'Nexus may include links to third-party services. Their privacy practices are governed by their own policies.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '9) CHANGES TO THIS POLICY',
                'We may update this Privacy Policy from time to time. We will update the "Last updated" date. Continued use after updates means you accept the updated policy.',
              ),
              const SizedBox(height: 20),
              _buildSection(
                context,
                '10) CONTACT',
                'Questions or requests:\n\nnexusgodlydating@gmail.com',
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
    List<_SubsectionData>? subsections,
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
        if (content.isNotEmpty) ...[
          _buildBodyText(context, content),
          const SizedBox(height: 12),
        ],
        if (subsections != null && subsections.isNotEmpty) ...[
          ..._buildSubsections(context, subsections),
        ],
        if (bullets != null && bullets.isNotEmpty) ...[
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

  static List<Widget> _buildSubsections(
    BuildContext context,
    List<_SubsectionData> subsections,
  ) {
    return subsections.expand((subsection) {
      return [
        Text(
          subsection.title,
          style: AppTextStyles.bodyMedium.copyWith(
            fontWeight: FontWeight.w600,
            color: AppColors.getTextPrimary(context),
          ),
        ),
        const SizedBox(height: 8),
        ..._buildBulletList(context, subsection.items),
        const SizedBox(height: 12),
      ];
    }).toList();
  }
}

class _SubsectionData {
  final String title;
  final List<String> items;

  _SubsectionData(this.title, this.items);
}
