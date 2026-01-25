import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  static const String lastUpdated = 'January 12, 2026';

  @override
  Widget build(BuildContext context) {
    final text = buildPrivacyText(lastUpdated);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
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
          child: Text(
            text,
            style: AppTextStyles.bodyMedium.copyWith(
              color: AppColors.textPrimary,
              height: 1.6,
            ),
          ),
        ),
      ),
    );
  }
}

String buildPrivacyText(String lastUpdated) {
  return '''
NEXUS PRIVACY POLICY
Last updated: $lastUpdated

This Privacy Policy explains how Nexus (“we”, “us”, “our”) collects, uses, shares, and protects information when you use the Nexus mobile application (“Nexus”).

1) WHAT WE COLLECT
A) Information you provide
- Account details (e.g., email, username) if you create an account
- Profile details you choose to share (e.g., photos, bio, preferences)
- Support messages, feedback, or survey responses
- Any content you submit (text, audio, images) where the feature exists

B) Information collected automatically
- Device and app information (device type, OS version, app version)
- Basic usage analytics (screens viewed, feature usage)
- Approximate location inferred from IP (for security/anti-abuse, not precise GPS unless you grant permission)

C) Sensitive topics and personal reflections
Nexus may include relationship and wellbeing prompts. We treat this content as private. You control what you submit. Please avoid submitting highly sensitive personal information you are not comfortable storing.

2) HOW WE USE INFORMATION
We use information to:
- Provide and operate Nexus features (Programs, personalization, account functions)
- Improve and test product experience (analytics, troubleshooting)
- Keep the community safe (fraud prevention, abuse detection, enforcement)
- Communicate with you (support responses, service announcements)
- Process payments/subscriptions (through platform providers, where applicable)
- Comply with legal obligations

3) HOW WE SHARE INFORMATION
We do not sell your personal information.

We may share information:
- With service providers who help operate Nexus (hosting, analytics, customer support), under contractual protections
- With payment processors/platform providers for subscription management
- For safety, security, and legal reasons (e.g., to respond to valid legal requests; to protect users from harm; to investigate abuse)
- In connection with a business transfer (e.g., merger, acquisition), where permitted by law

4) DATA RETENTION
We keep information as long as needed to operate Nexus and for legitimate business purposes (e.g., security, legal compliance).
If you request deletion (when supported), some data may remain in backups for a limited period, or be retained where legally required.

5) YOUR CONTROLS AND RIGHTS
Depending on your location, you may have rights to:
- Access, correct, or delete certain information
- Object to or restrict processing in some cases
- Withdraw consent (where processing is based on consent)

You can also control certain privacy options inside Nexus (where available). For requests, contact:
nexusgodlydating@gmail.com

6) SECURITY
We use reasonable safeguards to protect your information. However, no system is 100% secure. Please use a strong password and keep your device secure.

7) CHILDREN
Nexus is not intended for children. Do not use Nexus if you are under the minimum age required in your country.

8) THIRD-PARTY LINKS
Nexus may include links to third-party services. Their privacy practices are governed by their own policies.

9) CHANGES TO THIS POLICY
We may update this Privacy Policy from time to time. We will update the “Last updated” date. Continued use after updates means you accept the updated policy.

10) CONTACT
Questions or requests:
nexusgodlydating@gmail.com
''';
}
