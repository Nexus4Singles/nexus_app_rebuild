import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

class ForgotPasswordStubScreen extends StatefulWidget {
  const ForgotPasswordStubScreen({super.key});

  @override
  State<ForgotPasswordStubScreen> createState() =>
      _ForgotPasswordStubScreenState();
}

class _ForgotPasswordStubScreenState extends State<ForgotPasswordStubScreen> {
  final _emailCtrl = TextEditingController();
  bool _loading = false;
  String? _message;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendReset() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty) {
      setState(() => _error = 'Please enter your email.');
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _message = null;
    });

    try {
      await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
      setState(() => _message = 'Password reset email sent. Check your inbox.');
    } on FirebaseAuthException catch (e) {
      setState(() => _error = e.message ?? 'Failed to send reset email.');
    } catch (_) {
      setState(() => _error = 'Failed to send reset email.');
    } finally {
      setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(title: const Text('Reset password')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            TextField(
              controller: _emailCtrl,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: 'Email'),
            ),
            const SizedBox(height: 16),
            if (_error != null) ...[
              Text(
                _error!,
                style: theme.textTheme.bodyMedium?.copyWith(color: Colors.red),
              ),
              const SizedBox(height: 12),
            ],
            if (_message != null) ...[
              Text(_message!, style: theme.textTheme.bodyMedium),
              const SizedBox(height: 12),
            ],
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: _loading ? null : _sendReset,
                child:
                    _loading
                        ? const SizedBox(
                          height: 18,
                          width: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                        : const Text('Send reset email'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
