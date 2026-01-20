import 'package:flutter/material.dart';

class HelpCenterScreen extends StatelessWidget {
  const HelpCenterScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Help Center')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
        children: [
          const _SectionTitle('Quick actions'),
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.support_agent),
            title: const Text('Contact Support'),
            subtitle: const Text('Get help from the Nexus team'),
            trailing: const Icon(Icons.chevron_right),
            onTap: () => Navigator.of(context).pushNamed('/contact-support'),
          ),
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
            a: 'Nexus is a faith-aligned relationship growth platform. It combines practical learning, reflection, and guided activities to help you build healthier communication, boundaries, and emotional habits. Some versions may include dating and community features.',
          ),
          const _FaqItem(
            q: 'Do I need an account to use Nexus?',
            a: 'You can explore some parts as a guest (where available). Creating an account helps you save progress, personalize recommendations, and access additional features.',
          ),
          const _FaqItem(
            q: 'How do assessments work?',
            a: 'Assessments are short check-ins designed to highlight patterns and growth areas. Results are informational—not a diagnosis—and are used to recommend relevant Programs or activities.',
          ),
          const _FaqItem(
            q: 'What are “Programs” or “Activities”?',
            a: 'Programs are guided learning journeys broken into sessions/activities. They include small practical steps like reflection prompts, communication scripts, boundary exercises, and habits you can practice consistently.',
          ),
          const _FaqItem(
            q: 'Can I use Nexus if I’m married, single, divorced, or widowed?',
            a: 'Yes. Nexus supports multiple relationship journeys. Your experience may be tailored based on your selected relationship status to keep recommendations relevant and respectful.',
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
          const _SectionTitle('Still need help?'),
          FilledButton.icon(
            onPressed:
                () => Navigator.of(context).pushNamed('/contact-support'),
            icon: const Icon(Icons.support_agent),
            label: const Text('Contact Support'),
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
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Nexus helps people build healthier relationships through practical, faith-aligned guidance.\n\n'
                  'Inside Nexus you’ll find:\n'
                  '• Short assessments to reflect on patterns\n'
                  '• Guided Programs made up of small activities\n'
                  '• Tools for communication, boundaries, healing, and growth\n\n'
                  'Nexus is designed to be supportive and respectful across different life seasons—single, married, divorced, or widowed.\n\n'
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
