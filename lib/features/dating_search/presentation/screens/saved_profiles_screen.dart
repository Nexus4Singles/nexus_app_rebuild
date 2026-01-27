import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nexus_app_min_test/core/theme/theme.dart';
import 'package:nexus_app_min_test/core/providers/auth_provider.dart';
import 'package:nexus_app_min_test/core/providers/service_providers.dart';
import 'package:nexus_app_min_test/core/constants/app_constants.dart';
import 'package:nexus_app_min_test/features/dating_search/application/saved_profiles_provider.dart';
import 'package:nexus_app_min_test/features/dating_search/domain/dating_profile.dart';
import 'package:nexus_app_min_test/features/profile/presentation/screens/profile_screen.dart';

/// Provider for fetching saved profile details
final savedProfileDetailsProvider = FutureProvider<List<DatingProfile>>((
  ref,
) async {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return [];

  final savedProfileIds = ref.watch(savedProfilesProvider).valueOrNull ?? {};
  if (savedProfileIds.isEmpty) return [];

  final firestore = FirebaseFirestore.instance;
  final profiles = <DatingProfile>[];

  for (final profileId in savedProfileIds) {
    try {
      final doc = await firestore.collection('users').doc(profileId).get();
      if (doc.exists) {
        final data = doc.data();
        if (data != null) {
          try {
            final profile = DatingProfile.fromFirestore(doc.id, data);
            // Validate profile has minimum required data
            if (profile.name.trim().isNotEmpty && profile.age > 0) {
              profiles.add(profile);
            }
          } catch (parseError) {
            // Skip profiles with corrupted/deleted critical fields
            // ignore: avoid_print
            print(
              '[SavedProfiles] Skipping profileId=$profileId due to parse error: $parseError',
            );
            continue;
          }
        }
      } else {
        // Profile deleted - remove from saved list automatically
        ref.read(savedProfilesNotifierProvider).removeSaved(profileId);
      }
    } catch (e) {
      // Skip profiles that can't be loaded (network/permission errors)
      // ignore: avoid_print
      print(
        '[SavedProfiles] Skipping profileId=$profileId due to fetch error: $e',
      );
      continue;
    }
  }

  return profiles;
});

class SavedProfilesScreen extends ConsumerWidget {
  const SavedProfilesScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final profilesAsync = ref.watch(savedProfileDetailsProvider);

    return Scaffold(
      backgroundColor: AppColors.getBackground(context),
      appBar: AppBar(
        backgroundColor: AppColors.getBackground(context),
        surfaceTintColor: AppColors.getBackground(context),
        elevation: 0,
        titleSpacing: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_ios_new_rounded),
          onPressed: () => Navigator.pop(context),
        ),
        title: Text(
          'Saved Profiles',
          style: AppTextStyles.headlineLarge.copyWith(
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: profilesAsync.when(
        data: (profiles) {
          if (profiles.isEmpty) {
            return _EmptyState();
          }

          return ListView.builder(
            padding: const EdgeInsets.all(16),
            itemCount: profiles.length,
            itemBuilder: (context, index) {
              return _SavedProfileCard(profile: profiles[index]);
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error:
            (error, stack) => Center(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(Icons.error_outline, size: 64, color: AppColors.error),
                  const SizedBox(height: 16),
                  Text(
                    'Failed to load saved profiles',
                    style: AppTextStyles.titleMedium,
                  ),
                  const SizedBox(height: 8),
                  Text(
                    error.toString(),
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
                    ),
                    textAlign: TextAlign.center,
                  ),
                ],
              ),
            ),
      ),
    );
  }
}

class _SavedProfileCard extends ConsumerWidget {
  final DatingProfile profile;

  const _SavedProfileCard({required this.profile});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final photo = profile.photos.isNotEmpty ? profile.photos.first : null;
    final subtitle = [
      if (profile.displayLocation.trim().isNotEmpty) profile.displayLocation,
      if ((profile.profession ?? '').trim().isNotEmpty)
        profile.profession!.trim(),
    ].join(' • ');

    final displayName =
        profile.name.trim().isNotEmpty ? profile.name.trim() : 'User';
    final isSaved = ref.watch(isProfileSavedProvider(profile.uid));
    final currentUserId = ref.watch(currentUserIdProvider);

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: AppColors.getSurface(context),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.getBorder(context)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.03),
              blurRadius: 8,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Column(
          children: [
            // Profile info row
            InkWell(
              borderRadius: BorderRadius.circular(14),
              onTap: () {
                Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => ProfileScreen(userId: profile.uid),
                  ),
                );
              },
              child: Row(
                children: [
                  // Profile photo
                  ClipRRect(
                    borderRadius: BorderRadius.circular(14),
                    child: Container(
                      width: 64,
                      height: 64,
                      color: AppColors.primary.withOpacity(0.1),
                      child:
                          photo == null
                              ? Icon(
                                Icons.person,
                                size: 32,
                                color: AppColors.primary,
                              )
                              : Image.network(
                                photo,
                                fit: BoxFit.cover,
                                errorBuilder:
                                    (_, __, ___) => Icon(
                                      Icons.person,
                                      size: 32,
                                      color: AppColors.primary,
                                    ),
                              ),
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Profile info
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '$displayName, ${profile.age}',
                          style: AppTextStyles.titleMedium,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 4),
                        if (subtitle.trim().isNotEmpty)
                          Text(
                            subtitle,
                            style: AppTextStyles.bodySmall.copyWith(
                              color: AppColors.getTextSecondary(context),
                            ),
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                          ),
                      ],
                    ),
                  ),
                  const SizedBox(width: 12),

                  // Unsave button
                  InkWell(
                    borderRadius: BorderRadius.circular(12),
                    onTap: () async {
                      await ref
                          .read(savedProfilesNotifierProvider)
                          .unsave(profile.uid);
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: const Text('Removed from saved profiles'),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.textSecondary,
                            duration: const Duration(seconds: 2),
                          ),
                        );
                      }
                    },
                    child: Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color:
                            isSaved
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.background,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(
                          color: isSaved ? AppColors.primary : AppColors.border,
                        ),
                      ),
                      child: Icon(
                        isSaved ? Icons.bookmark : Icons.bookmark_border,
                        color:
                            isSaved ? AppColors.primary : AppColors.textMuted,
                        size: 22,
                      ),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 12),

            // Chat button
            if (currentUserId != null && currentUserId != profile.uid)
              SizedBox(
                width: double.infinity,
                child: ElevatedButton.icon(
                  onPressed: () async {
                    try {
                      // This will automatically enforce the 3 free chats limit
                      final chatId = await ref.read(
                        getOrCreateChatProvider(profile.uid).future,
                      );
                      if (context.mounted) {
                        Navigator.of(
                          context,
                        ).pushNamed(AppNavRoutes.chat(chatId));
                      }
                    } catch (e) {
                      if (context.mounted) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text(e.toString()),
                            behavior: SnackBarBehavior.floating,
                            backgroundColor: AppColors.error,
                            duration: const Duration(seconds: 3),
                          ),
                        );
                      }
                    }
                  },
                  icon: const Icon(Icons.chat_bubble_outline, size: 20),
                  label: Text('Chat with $displayName'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    elevation: 0,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Container(
              width: 100,
              height: 100,
              decoration: BoxDecoration(
                color: AppColors.getSurface(context),
                shape: BoxShape.circle,
                border: Border.all(color: AppColors.getBorder(context)),
              ),
              child: Icon(
                Icons.bookmark_outline,
                size: 48,
                color: AppColors.getTextSecondary(context),
              ),
            ),
            const SizedBox(height: 24),
            Text(
              'No Saved Profiles',
              style: AppTextStyles.titleLarge.copyWith(
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Profiles you bookmark will appear here for easy access later.',
              style: AppTextStyles.bodyMedium.copyWith(
                color: AppColors.getTextSecondary(context),
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 24),
            OutlinedButton.icon(
              onPressed: () => Navigator.pop(context),
              icon: const Icon(Icons.search),
              label: const Text('Browse Profiles'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
