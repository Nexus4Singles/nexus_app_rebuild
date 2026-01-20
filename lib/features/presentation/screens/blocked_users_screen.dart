import 'package:flutter/material.dart';

class BlockedUsersScreen extends StatelessWidget {
  const BlockedUsersScreen({super.key});

  @override
  Widget build(BuildContext context) {
    // Placeholder list until hooked to real data
    // NOTE: Blocked users data model is intentionally disabled for now.
    // final blockedUsers = ref.watch(blockedUsersProvider); // (future)
    // For now, show a static empty state.
    final blocked = const <String>[];
    return Scaffold(
      appBar: AppBar(title: const Text('Blocked Users')),
      body:
          blocked.isEmpty
              ? const Center(child: Text('You have not blocked anyone.'))
              : ListView.separated(
                padding: const EdgeInsets.all(16),
                itemBuilder: (_, i) {
                  final name = blocked[i];
                  return ListTile(
                    leading: const CircleAvatar(child: Icon(Icons.person)),
                    title: Text(name),
                    trailing: TextButton(
                      onPressed: () {},
                      child: const Text('Unblock'),
                    ),
                  );
                },
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemCount: blocked.length,
              ),
    );
  }
}
