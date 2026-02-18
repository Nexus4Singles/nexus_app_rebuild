import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class ContactScreen extends StatelessWidget {
  const ContactScreen({super.key});

  static const String contactEmail = 'contact@nexus4singles.com';

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Contact')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Contact Us',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.w900),
            ),
            const SizedBox(height: 10),
            const Text(
              'For questions, feedback, or support requests, email us at:',
            ),
            const SizedBox(height: 12),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(14),
                child: Row(
                  children: [
                    const Icon(Icons.email_outlined),
                    const SizedBox(width: 10),
                    const Expanded(
                      child: SelectableText(
                        contactEmail,
                        style: TextStyle(fontWeight: FontWeight.w800),
                      ),
                    ),
                    IconButton(
                      tooltip: 'Copy',
                      onPressed: () async {
                        await Clipboard.setData(
                          const ClipboardData(text: contactEmail),
                        );
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(content: Text('Email copied')),
                          );
                        }
                      },
                      icon: const Icon(Icons.copy),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 10),
            Text(
              'We always reply within 1 hour of reaching out to us',
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}
