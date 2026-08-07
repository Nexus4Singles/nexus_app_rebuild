import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_v2/core/user/is_admin_provider.dart';
import 'package:nexus_app_v2/core/theme/theme.dart';
import 'package:nexus_app_v2/features/dating_search/application/waiting_list_provider.dart';
import '../../application/admin_review_providers.dart';
import '../../application/coach_application_providers.dart';
import 'admin_review_detail_screen.dart';
import 'coach_review_queue_screen.dart';

class AdminReviewQueueScreen extends ConsumerWidget {
  const AdminReviewQueueScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref
        .watch(isAdminProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);
    if (!isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access required')));
    }

    return DefaultTabController(
      length: 2,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Admin Reviews'),
          bottom: const TabBar(
            tabs: [
              Tab(text: 'Dating Profiles'),
              Tab(text: 'Coach Applications'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [_DatingProfilesTab(), CoachReviewQueueScreen()],
        ),
      ),
    );
  }
}

class _DatingProfilesTab extends ConsumerWidget {
  const _DatingProfilesTab();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final pendingAsync = ref.watch(pendingReviewUsersProvider);
    final waitingListStatsAsync = ref.watch(ukWaitingListStatsProvider);

    return Column(
      children: [
        // Gender stats card - always shown at the top
        waitingListStatsAsync.when(
          data: (stats) => _buildGenderStatsHeader(context, stats),
          loading:
              () => const Padding(
                padding: EdgeInsets.all(16),
                child: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
          error:
              (e, _) => Padding(
                padding: const EdgeInsets.all(16),
                child: Text('Failed to load stats: $e'),
              ),
        ),
        // Profiles list or empty state
        Expanded(
          child: pendingAsync.when(
            data: (items) {
              if (items.isEmpty) {
                return const Center(child: Text('No pending profiles.'));
              }
              return ListView.separated(
                itemCount: items.length,
                separatorBuilder: (_, __) => const Divider(height: 1),
                itemBuilder: (context, i) {
                  final it = items[i];
                  final photo =
                      it.photoUrls.isNotEmpty ? it.photoUrls.first : null;
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
                        if (it.gender != null && it.gender!.isNotEmpty)
                          it.gender!,
                        if (it.relationshipStatus != null &&
                            it.relationshipStatus!.isNotEmpty)
                          it.relationshipStatus!,
                        '🎤 $audioCount',
                      ].join(' • '),
                    ),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [const Icon(Icons.chevron_right_rounded)],
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder:
                              (_) => AdminReviewDetailScreen(userId: it.uid),
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
        ),
      ],
    );
  }

  Widget _buildGenderStatsHeader(
    BuildContext context,
    WaitingListStats? stats,
  ) {
    final maleCount = stats?.maleCount ?? 0;
    final femaleCount = stats?.femaleCount ?? 0;
    final totalCount = stats?.totalCount ?? 0;

    final malePercentage =
        totalCount > 0
            ? ((maleCount / totalCount) * 100).toStringAsFixed(1)
            : '0';
    final femalePercentage =
        totalCount > 0
            ? ((femaleCount / totalCount) * 100).toStringAsFixed(1)
            : '0';

    return Container(
      margin: const EdgeInsets.all(12),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.getBorder(context)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'UK Waiting List - Gender Distribution',
            style: AppTextStyles.labelLarge.copyWith(
              color: AppColors.getTextPrimary(context),
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          // Total and gender stats on same line
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                'Total: $totalCount',
                style: AppTextStyles.bodySmall.copyWith(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
              // Male and Female on same line
              Row(
                children: [
                  Text(
                    'Male: $maleCount ($malePercentage%)',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    'Female: $femaleCount ($femalePercentage%)',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextPrimary(context),
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ],
              ),
            ],
          ),
          if (femaleCount > maleCount * 2)
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: Colors.amber.withOpacity(0.1),
                  borderRadius: BorderRadius.circular(6),
                  border: Border.all(color: Colors.amber.withOpacity(0.3)),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      Icons.warning_rounded,
                      size: 14,
                      color: Colors.amber[700],
                    ),
                    const SizedBox(width: 6),
                    Text(
                      'Gender imbalance - prioritize males',
                      style: AppTextStyles.bodySmall.copyWith(
                        color: Colors.amber[700],
                      ),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
