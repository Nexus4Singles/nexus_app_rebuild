import 'package:flutter/material.dart';
import 'package:nexus_app_min_test/core/theme/theme.dart';

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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
        titleSpacing: 0,
        title: Text(
          'Blocked Users',
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body:
          blocked.isEmpty
              ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Container(
                      width: 80,
                      height: 80,
                      decoration: BoxDecoration(
                        color: AppColors.surfaceLight,
                        borderRadius: BorderRadius.circular(20),
                      ),
                      child: Icon(
                        Icons.block,
                        size: 40,
                        color: AppColors.textMuted,
                      ),
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'You have not blocked anyone.',
                      style: AppTextStyles.titleLarge.copyWith(
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              )
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
