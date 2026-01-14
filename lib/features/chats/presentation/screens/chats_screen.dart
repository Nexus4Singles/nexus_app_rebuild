import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/widgets/disabled_account_gate.dart';

class ChatsScreen extends StatelessWidget {
  const ChatsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DisabledAccountGate(
      child: Scaffold(
        appBar: AppBar(title: const Text('Chats')),
        body: const Center(child: Text('Chats Screen')),
      ),
    );
  }
}
