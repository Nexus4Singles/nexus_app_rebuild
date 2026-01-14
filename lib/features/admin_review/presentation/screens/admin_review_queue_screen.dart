import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/user/is_admin_provider.dart';
import '../../application/admin_review_providers.dart';
import 'admin_review_detail_screen.dart';

class AdminReviewQueueScreen extends ConsumerWidget {
  const AdminReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref.watch(isAdminProvider);
    if (!isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access required')));
    }

    final pendingAsync = ref.watch(pendingReviewUsersProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Pending Profile Reviews')),
      body: pendingAsync.when(
        data: (items) {
          if (items.isEmpty) {
            return const Center(child: Text('No pending profiles.'));
          }
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final it = items[i];
              final photo = it.photoUrls.isNotEmpty ? it.photoUrls.first : null;
              final audioCount = it.audioUrls.length;

              return ListTile(
                leading:
                    photo == null
                        ? const CircleAvatar(child: Icon(Icons.person))
                        : ClipRRect(
                          borderRadius: BorderRadius.circular(8),
                          child: Image.network(
                            photo,
                            width: 48,
                            height: 48,
                            fit: BoxFit.cover,
                          ),
                        ),
                title: Text(it.name),
                subtitle: Text(
                  [
                    if (it.gender != null && it.gender!.isNotEmpty) it.gender!,
                    if (it.relationshipStatus != null &&
                        it.relationshipStatus!.isNotEmpty)
                      it.relationshipStatus!,
                    '🎤 $audioCount',
                  ].join(' • '),
                ),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => AdminReviewDetailScreen(userId: it.uid),
                    ),
                  );
                },
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Failed: $e')),
      ),
    );
  }
}
