import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_v2/features/admin_review/application/coach_application_providers.dart';
import 'coach_review_detail_screen.dart';

class CoachReviewQueueScreen extends ConsumerWidget {
  const CoachReviewQueueScreen({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final applicationsAsync = ref.watch(pendingCoachApplicationsProvider);

    return applicationsAsync.when(
      data: (applications) {
        if (applications.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.inbox, size: 64, color: Colors.grey[400]),
                const SizedBox(height: 16),
                Text(
                  'No pending applications',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(color: Colors.grey[600]),
                ),
              ],
            ),
          );
        }

        return ListView.builder(
          itemCount: applications.length,
          itemBuilder: (context, index) {
            final app = applications[index];
            return _CoachApplicationListTile(application: app);
          },
        );
      },
      loading: () => const Center(child: CircularProgressIndicator()),
      error:
          (error, stack) =>
              Center(child: Text('Error loading applications: $error')),
    );
  }
}

class _CoachApplicationListTile extends ConsumerWidget {
  final CoachApplicationReviewItem application;

  const _CoachApplicationListTile({Key? key, required this.application})
    : super(key: key);

  void _showDeleteConfirmation(BuildContext context, WidgetRef ref) {
    showDialog(
      context: context,
      builder:
          (dialogContext) => AlertDialog(
            title: const Text('Delete Application'),
            content: Text(
              'Delete ${application.fullName}\'s coach application? This cannot be undone.',
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.pop(dialogContext),
                child: const Text('Cancel'),
              ),
              FilledButton(
                style: FilledButton.styleFrom(backgroundColor: Colors.red),
                onPressed: () async {
                  Navigator.pop(dialogContext);
                  try {
                    await ref.read(
                      deleteCoachApplicationProvider(
                        application.applicationId,
                      ).future,
                    );
                    if (context.mounted) {
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(
                          content: Text('Application deleted'),
                          duration: Duration(seconds: 2),
                        ),
                      );
                    }
                  } catch (e) {
                    if (context.mounted) {
                      ScaffoldMessenger.of(
                        context,
                      ).showSnackBar(SnackBar(content: Text('Error: $e')));
                    }
                  }
                },
                child: const Text('Delete'),
              ),
            ],
          ),
    );
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return ListTile(
      leading: CircleAvatar(
        radius: 28,
        backgroundColor: Colors.grey[300],
        backgroundImage:
            (application.profilePhotoUrl != null &&
                    application.profilePhotoUrl!.isNotEmpty)
                ? NetworkImage(application.profilePhotoUrl!)
                : null,
        child:
            (application.profilePhotoUrl == null ||
                    application.profilePhotoUrl!.isEmpty)
                ? const Icon(Icons.person, size: 28)
                : null,
      ),
      title: Text(application.fullName),
      subtitle: Text(
        '${application.yearsOfExperience} years exp. • ${application.gender}',
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
      ),
      trailing: Wrap(
        spacing: 8,
        children: [
          IconButton(
            icon: Icon(Icons.delete_outline, color: Colors.red[600]),
            onPressed: () => _showDeleteConfirmation(context, ref),
            tooltip: 'Delete application',
          ),
          const Icon(Icons.chevron_right),
        ],
      ),
      onTap: () {
        Navigator.of(context).push(
          MaterialPageRoute(
            builder:
                (_) => CoachReviewDetailScreen(
                  applicationId: application.applicationId,
                ),
          ),
        );
      },
    );
  }
}
