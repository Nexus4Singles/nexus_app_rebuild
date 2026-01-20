import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_app_min_test/app_shell.dart';

class BootstrapGate extends StatelessWidget {
  const BootstrapGate({super.key});

  Future<void> _enforceGuestIfNeeded() async {
    final prefs = await SharedPreferences.getInstance();
    final forceGuest = prefs.getBool('force_guest') ?? false;
    if (!forceGuest) return;

    final u = FirebaseAuth.instance.currentUser;
    if (u != null) {
      await FirebaseAuth.instance.signOut();
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<void>(
      future: _enforceGuestIfNeeded(),
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Material(
            child: Center(child: CircularProgressIndicator()),
          );
        }
        return const AppShell();
      },
    );
  }
}
