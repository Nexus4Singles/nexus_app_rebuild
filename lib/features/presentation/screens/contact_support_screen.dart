import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';

class ContactSupportScreen extends StatefulWidget {
  const ContactSupportScreen({super.key});

  @override
  State<ContactSupportScreen> createState() => _ContactSupportScreenState();
}

class _ContactSupportScreenState extends State<ContactSupportScreen> {
  final _formKey = GlobalKey<FormState>();
  String _category = 'Account Issue';
  final _subject = TextEditingController();
  final _message = TextEditingController();

  @override
  void dispose() {
    _subject.dispose();
    _message.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const categories = [
      'Account Issue',
      'Login / Password',
      'Billing / Subscription',
      'Bug Report',
      'Feature Request',
      'Profile Help',
      'Safety Concern',
      'Other',
    ];

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Contact Support',
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Form(
        key: _formKey,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
          children: [
            Text(
              'Tell us what happened and we\'ll help you out.',
              style: AppTextStyles.bodyLarge.copyWith(
                color: AppColors.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 12),

            DropdownButtonFormField<String>(
              value: _category,
              items:
                  categories
                      .map((c) => DropdownMenuItem(value: c, child: Text(c)))
                      .toList(),
              onChanged: (v) => setState(() => _category = v ?? _category),
              decoration: const InputDecoration(
                labelText: 'Category',
                border: OutlineInputBorder(),
              ),
            ),

            const SizedBox(height: 12),
            TextFormField(
              controller: _subject,
              decoration: const InputDecoration(
                labelText: 'Subject',
                hintText: 'e.g., “App freezes after completing a session”',
                border: OutlineInputBorder(),
              ),
              validator:
                  (v) =>
                      (v == null || v.trim().isEmpty)
                          ? 'Subject is required'
                          : null,
            ),

            const SizedBox(height: 12),
            TextFormField(
              controller: _message,
              minLines: 5,
              maxLines: 10,
              decoration: const InputDecoration(
                labelText: 'Message',
                hintText:
                    'Include steps to reproduce, what you expected, and what happened.\n'
                    'For safety concerns, include usernames + screenshots if possible.',
                border: OutlineInputBorder(),
              ),
              validator: (v) {
                final t = (v ?? '').trim();
                if (t.isEmpty) return 'Message is required';
                if (t.length < 25) {
                  return 'Please add a bit more detail (min 25 characters)';
                }
                return null;
              },
            ),

            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: _submit,
              icon: const Icon(Icons.send),
              label: const Text('Send'),
            ),

            const SizedBox(height: 10),
            const Text(
              'For now, messages are queued locally (stub). Later we’ll wire this to email or Firestore tickets.\n'
              'Support email: nexusgodlydating@gmail.com',
              style: TextStyle(fontSize: 12),
            ),
          ],
        ),
      ),
    );
  }

  void _submit() {
    if (!_formKey.currentState!.validate()) return;

    // Stub: In the future, send to Firestore or an email endpoint.
    final payload = {
      'category': _category,
      'subject': _subject.text.trim(),
      'message': _message.text.trim(),
      'createdAt': DateTime.now().toIso8601String(),
    };

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Sent (stub): ${payload['category']}')),
    );

    Navigator.of(context).pop();
  }
}
