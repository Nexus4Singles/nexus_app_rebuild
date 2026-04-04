import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../../features/auth/presentation/screens/email_verification_screen.dart';

/// EmailVerificationGate ensures that users with unverified emails cannot
/// access the app until they verify their email address.
///
/// This gate is placed between Bootstrap and the app to enforce email verification,
/// preventing users from bypassing it by restarting the app.
class EmailVerificationGate extends StatefulWidget {
  final Widget child;

  const EmailVerificationGate({super.key, required this.child});

  @override
  State<EmailVerificationGate> createState() => _EmailVerificationGateState();
}

class _EmailVerificationGateState extends State<EmailVerificationGate> {
  late Stream<User?> _authStream;

  @override
  void initState() {
    super.initState();
    // Use idTokenChanges() instead of authStateChanges() because email verification
    // status changes are reflected in ID token updates, not just auth state changes.
    // authStateChanges() only emits on sign in/out, but idTokenChanges() emits when
    // the user's email verification status changes (token is refreshed).
    _authStream = FirebaseAuth.instance.idTokenChanges();
  }

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<User?>(
      stream: _authStream,
      builder: (context, snapshot) {
        // Still loading auth state
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Material(
            child: Center(child: CircularProgressIndicator()),
          );
        }

        final user = snapshot.data;

        // No user signed in - show app (which will show login screen if needed)
        if (user == null) {
          return widget.child;
        }

        // Anonymous user - show app
        if (user.isAnonymous) {
          return widget.child;
        }

        // Email not verified - force email verification screen
        if (!user.emailVerified) {
          // ignore: avoid_print
          final userEmail = user.email;
          if (userEmail == null || userEmail.isEmpty) {
            // Edge case: User exists but email is null/empty - shouldn't happen
            // but handle gracefully by signing out
            print(
              '[EmailVerificationGate] ERROR: User ${user.uid} has no email; signing out',
            );
            FirebaseAuth.instance.signOut();
            return widget.child;
          }
          print(
            '[EmailVerificationGate] User ${user.uid} not verified ($userEmail); showing verification screen',
          );
          return EmailVerificationScreen(email: userEmail);
        }

        // Email verified - show app
        return widget.child;
      },
    );
  }
}
