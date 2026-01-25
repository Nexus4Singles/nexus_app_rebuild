import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';

class TermsScreen extends StatelessWidget {
  const TermsScreen({super.key});

  static const String lastUpdated = 'January 12, 2026';

  @override
  Widget build(BuildContext context) {
    final text = buildTermsText(lastUpdated);

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Terms of Service',
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

String buildTermsText(String lastUpdated) {
  return '''
NEXUS TERMS OF SERVICE
Last updated: $lastUpdated

These Terms of Service (“Terms”) govern your use of the Nexus mobile application and related services (collectively, “Nexus”, “we”, “us”, or “our”). By accessing or using Nexus, you agree to these Terms. If you do not agree, do not use Nexus.

1) WHO NEXUS IS FOR
Nexus is a relationship and personal growth platform that may include educational content, assessments, activities (“Programs”), and community or dating-related features. You must be at least the minimum age required in your country to use Nexus. You are responsible for ensuring your use is legal where you live.

2) ACCOUNT AND ACCESS
You may use Nexus as a guest (where available) or by creating an account. You are responsible for:
- Providing accurate information (where required)
- Keeping your login credentials confidential
- All activity under your account

We may suspend or terminate access if we believe your account is being used in a way that violates these Terms or harms the community.

3) COMMUNITY STANDARDS AND SAFETY
You agree not to:
- Harass, threaten, shame, stalk, or intimidate others
- Share hateful, discriminatory, sexually exploitative, or violent content
- Share private information (yours or others’) without consent
- Impersonate others or misrepresent your identity
- Use Nexus to solicit money, scams, or illegal activity

We may remove content or restrict accounts to protect users and the community.

4) CONTENT IS NOT PROFESSIONAL ADVICE
Nexus may provide educational content related to relationships, communication, marriage, faith, and emotional wellbeing. Nexus does NOT provide medical, mental health, psychiatric, legal, or financial advice. If you need professional support, please consult a qualified professional or local emergency services.

5) PROGRAMS, ASSESSMENTS, AND RECOMMENDATIONS
Assessments and recommendations are informational tools designed to help guide your experience. They may not be accurate for every person and should not be treated as definitive diagnosis, judgment, or label. You are responsible for your choices and actions.

6) SUBSCRIPTIONS, FEES, AND PAYMENTS
Some features may require payment (e.g., subscriptions or paid Programs). Pricing and features may change over time. If you purchase a subscription:
- Payments are handled by the platform provider (e.g., Apple/Google) unless otherwise stated
- Subscriptions renew automatically unless canceled through your device’s subscription settings
- Refunds follow the platform provider’s refund policies, unless required by local law

7) USER CONTENT AND LICENSE
If you submit content (text, images, audio, profile data, feedback) (“User Content”), you own your User Content. You grant Nexus a limited license to host, store, display, and process your User Content to operate and improve Nexus, provide features, keep the community safe, and comply with legal obligations.

You are responsible for ensuring you have rights to submit any User Content you upload.

8) INTELLECTUAL PROPERTY
Nexus and our Programs, designs, graphics, branding, and original content are owned by us or our licensors and are protected by intellectual property laws. You may not copy, modify, distribute, or reverse engineer Nexus except where legally permitted.

9) PROHIBITED USES
You may not:
- Attempt to bypass security or access restricted parts of the app
- Scrape or harvest user data
- Use bots or automated tools to interact with Nexus
- Interfere with service availability or performance

10) TERMINATION
You may stop using Nexus at any time. We may suspend or terminate your access if:
- You violate these Terms
- We must do so to comply with law
- Your use risks harm to Nexus or other users

11) DISCLAIMERS
Nexus is provided “as is” and “as available.” We do not guarantee uninterrupted service, error-free operation, or that content will meet your expectations.

12) LIMITATION OF LIABILITY
To the maximum extent allowed by law, Nexus is not liable for indirect, incidental, special, consequential, or punitive damages, or loss of data, revenue, or goodwill. Our total liability for claims related to Nexus is limited to the amount you paid to Nexus in the 12 months before the claim (or zero if you used Nexus without paying), to the extent permitted by law.

13) CHANGES TO THESE TERMS
We may update these Terms occasionally. We will update the “Last updated” date. Continued use after an update means you accept the updated Terms.

14) CONTACT
If you have questions about these Terms, contact us at:
nexusgodlydating@gmail.com
''';
}
