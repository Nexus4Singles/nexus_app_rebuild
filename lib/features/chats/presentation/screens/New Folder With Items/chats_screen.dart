import 'package:flutter/material.dart';

// IMPORTANT:
// This file previously contained a Safe Mode Chats UI.
// To prevent inconsistent navigation while migrating to Firebase,
// it now delegates to the real Firestore-backed ChatsScreen.

import 'package:nexus_app_min_test/features/presentation/screens/chats_screen.dart'
    as real;

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return const real.ChatsScreen();
  }
}
