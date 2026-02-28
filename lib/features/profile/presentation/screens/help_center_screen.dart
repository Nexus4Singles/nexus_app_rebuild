import 'package:flutter/material.dart';
import 'package:nexus_app_v2/core/router/safe_nav.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => navigateBackToHome(context),
        ),
        title: Text(
          'Help Center',
          style: AppTextStyles.headlineMedium.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const _SectionTitle('Quick Actions'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.info_outline),
            title: const Text('About Nexus'),
            subtitle: const Text('What Nexus is and how it helps'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showAbout(context),
          ),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.shield_outlined),
            title: const Text('Safety & community guidelines'),
            subtitle: const Text('How to stay safe and report issues'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => _showSafetySheet(context),
          ),

          const SizedBox(height: 16),
          const _SectionTitle('FAQs'),
          const _FaqItem(
            q: 'What is Nexus?',
            a: 'Nexus is a personal and marital growth ecosystem that seeks to help single, married, divorced, or widowed individuals build Kingdom marriages and families, the way God intended.',
          ),
          const _FaqItem(
            q: 'Do I need an account to use Nexus?',
            a: 'You can explore some parts as a guest (read weekly stories). Creating an account helps you save progress, take personalize assesments and journey recommendations, and access additional features.',
          ),
          const _FaqItem(
            q: 'How do Assessments work?',
            a: 'Assessments are short and practical questions designed to highlight patterns and growth areas. Results are informational—not a diagnosis—and are used to recommend relevant Journeys you could take to resolve growth areas identified',
          ),
          const _FaqItem(
            q: 'What are "Journeys" or “Activities”?',
            a: 'Journeys are guided learning programs broken into activities. They include small practical steps like reflection prompts, communication scripts, boundary exercises, and habits you can practice consistently.',
          ),
          const _FaqItem(
            q: 'Can I use Nexus if I’m married?',
            a: 'Yes. Nexus supports multiple relationship journeys. Whether you\'re single, divorced, widowed, or married, your experience is tailored to your selected marital status.',
          ),
          const _FaqItem(
            q: 'How do I report bad behavior or safety concerns?',
            a: 'Use Contact Support and select “Safety Concern.” Include screenshots, usernames, and what happened. We take safety seriously and may restrict accounts that violate our standards.',
          ),
          const _FaqItem(
            q: 'I found a bug—what should I include in a report?',
            a: 'Describe what you expected vs what happened, your device model, OS version, and the steps to reproduce. If possible, attach a screenshot.',
          ),

          const SizedBox(height: 16),
          const Text(
            'Still need help?',
            style: TextStyle(fontWeight: FontWeight.w600, fontSize: 16),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: () => Navigator.of(context).pushNamed('/contact'),
            child: const Text('Contact Support'),
          ),
        ],
      ),
    );
  }

  static Future<void> _showAbout(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 5,
                    decoration: BoxDecoration(
                      color: Theme.of(ctx).colorScheme.outlineVariant,
                      borderRadius: BorderRadius.circular(999),
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                const Text(
                  'About Nexus',
                  style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Family is the smallest unit that shapes society and we are on a mission to raise Godly families through kingdom relationships and marriages. We have created Nexus as a personal and marital growth ecosystem that seeks to help single, married, divorced, or widowed individuals build kingdom marriages and families, the way God intended.\n\n'
                  'Inside Nexus you’ll find:\n'
                  '• A Purposeful Dating section for singles, divorced or widowed individuals seeking relationships leading to marriage.\n'
                  '• Practical Assessments to reflect on patterns\n'
                  '• Guided Journeys made up of small activities to enhance your knowledge and provide you with clarity on how to strengthen your relationships or marriage, using biblical principles.\n'
                  '• Beautiful weekly stories that uncover powerful lessons for navigating relationships and marriage.\n'
                  '• Expert guidance from professional Marriage Counsellors and Family Therapists (Coming Soon).\n\n'
                  'Nexus is designed to be supportive and respectful across different life seasons—',
                ),
                RichText(
                  text: const TextSpan(
                    children: [
                      TextSpan(text: 'single, married, divorced, or widowed'),
                      TextSpan(text: '.\n\n'),
                    ],
                    style: TextStyle(
                      fontWeight: FontWeight.w900,
                      color: Colors.black87,
                    ),
                  ),
                ),
                const Text(
                  ''
                  'Important: Nexus is educational and is not medical, mental health, or legal advice. If you need professional or emergency support, please contact a qualified provider or local emergency services.',
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  static Future<void> _showSafetySheet(BuildContext context) async {
    await showModalBottomSheet<void>(
      context: context,
      builder: (ctx) {
        return SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  width: 44,
                  height: 5,
                  decoration: BoxDecoration(
                    color: Theme.of(ctx).colorScheme.outlineVariant,
                    borderRadius: BorderRadius.circular(999),
                  ),
                ),
                const SizedBox(height: 12),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    'Safety tips',
                    style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
                  ),
                ),
                const SizedBox(height: 8),
                const Text(
                  '• Don’t share sensitive personal info (address, passwords, financial details).\n'
                  '• If someone pressures you, asks for money, or threatens you—stop engaging and report.\n'
                  '• Meet in public places if meeting anyone offline.\n'
                  '• Use Contact Support → “Safety Concern” to report issues.',
                ),
                const SizedBox(height: 12),
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton(
                    onPressed: () => Navigator.of(ctx).pop(),
                    child: const Text('Close'),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String text;
  const _SectionTitle(this.text);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        text,
        style: Theme.of(
          context,
        ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.w900),
      ),
    );
  }
}

class _FaqItem extends StatefulWidget {
  final String q;
  final String a;
  const _FaqItem({required this.q, required this.a});

  @override
  State<_FaqItem> createState() => _FaqItemState();
}

class _FaqItemState extends State<_FaqItem> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 10),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => setState(() => _open = !_open),
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(
                      widget.q,
                      style: const TextStyle(fontWeight: FontWeight.w800),
                    ),
                  ),
                  Icon(_open ? Icons.expand_less : Icons.expand_more),
                ],
              ),
              if (_open) ...[const SizedBox(height: 8), Text(widget.a)],
            ],
          ),
        ),
      ),
    );
  }
}
