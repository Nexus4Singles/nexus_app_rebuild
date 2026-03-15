import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'dart:convert';
import 'package:firebase_auth/firebase_auth.dart';

/// Admin panel for manually verifying users
/// Add this to your admin dashboard
class AdminUserVerificationPanel extends StatefulWidget {
  const AdminUserVerificationPanel({Key? key}) : super(key: key);

  @override
  State<AdminUserVerificationPanel> createState() =>
      _AdminUserVerificationPanelState();
}

class _AdminUserVerificationPanelState
    extends State<AdminUserVerificationPanel> {
  final _emailController = TextEditingController();
  final _statusController = TextEditingController(text: 'verified');
  bool _isLoading = false;
  String? _message;
  bool _isSuccess = false;

  @override
  void dispose() {
    _emailController.dispose();
    _statusController.dispose();
    super.dispose();
  }

  Future<void> _verifyUser() async {
    final email = _emailController.text.trim();
    final status = _statusController.text.trim();

    if (email.isEmpty) {
      setState(() => _message = 'Email is required');
      return;
    }

    setState(() => _isLoading = true);

    try {
      final idToken = await FirebaseAuth.instance.currentUser?.getIdToken();
      if (idToken == null) {
        throw Exception('Not authenticated');
      }

      final response = await http
          .post(
            Uri.parse(
              'https://us-central1-nexus-visibility-app.cloudfunctions.net/verifyUserProfile',
            ),
            headers: {
              'Authorization': 'Bearer $idToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({'email': email, 'verificationStatus': status}),
          )
          .timeout(const Duration(seconds: 30));

      final responseData = jsonDecode(response.body);

      if (response.statusCode == 200 && responseData['success'] == true) {
        setState(() {
          _message =
              '✅ ${responseData['userName']} verified with status: $status';
          _isSuccess = true;
        });
        _emailController.clear();
      } else {
        setState(() {
          _message = '❌ Error: ${responseData['error'] ?? 'Unknown error'}';
          _isSuccess = false;
        });
      }
    } catch (e) {
      setState(() {
        _message = '❌ Error: ${e.toString()}';
        _isSuccess = false;
      });
    } finally {
      setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '🔐 Admin: Verify User',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _emailController,
              decoration: InputDecoration(
                labelText: 'User Email',
                hintText: 'arc.prosperchukwuka@gmail.com',
                border: const OutlineInputBorder(),
                enabled: !_isLoading,
              ),
            ),
            const SizedBox(height: 12),
            DropdownButtonFormField<String>(
              value: _statusController.text,
              decoration: const InputDecoration(
                labelText: 'Verification Status',
                border: OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(value: 'verified', child: Text('✅ Verified')),
                DropdownMenuItem(value: 'pending', child: Text('⏳ Pending')),
                DropdownMenuItem(value: 'rejected', child: Text('❌ Rejected')),
              ],
              onChanged:
                  _isLoading
                      ? null
                      : (value) {
                        if (value != null) {
                          _statusController.text = value;
                        }
                      },
            ),
            const SizedBox(height: 16),
            ElevatedButton.icon(
              onPressed: _isLoading ? null : _verifyUser,
              icon:
                  _isLoading
                      ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                      : const Icon(Icons.verified_user),
              label: Text(_isLoading ? 'Verifying...' : 'Verify User'),
            ),
            if (_message != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: _isSuccess ? Colors.green.shade50 : Colors.red.shade50,
                  border: Border.all(
                    color: _isSuccess ? Colors.green : Colors.red,
                  ),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  _message!,
                  style: TextStyle(
                    color:
                        _isSuccess
                            ? Colors.green.shade800
                            : Colors.red.shade800,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
