import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/constants/app_constants.dart';
import '../../../../core/services/config_loader_service.dart';
import '../../../../core/theme/theme.dart';
import '../../../../core/session/effective_relationship_status_provider.dart';
import '../../../../core/widgets/guest_guard.dart';

import 'journey_session_screen.dart';

class JourneyDetailScreen extends ConsumerWidget {
  final String journeyId;
  const JourneyDetailScreen({super.key, required this.journeyId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final status =
        ref.watch(effectiveRelationshipStatusProvider) ??
        RelationshipStatus.singleNeverMarried;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text('Challenge'),
        backgroundColor: AppColors.background,
        surfaceTintColor: AppColors.background,
        elevation: 0,
      ),
      body: FutureBuilder(
        future: ConfigLoaderService().getJourneyCatalogForStatus(status),
        builder: (context, snapshot) {
          if (snapshot.connectionState != ConnectionState.done) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError || !snapshot.hasData) {
            return const Center(child: Text('Unable to load challenge'));
          }

          final catalog = snapshot.data!;
          final resolvedId = Uri.decodeComponent(journeyId).trim();
            debugPrint("DETAIL resolvedId=$resolvedId products=${catalog.products.length} first=${catalog.products.isNotEmpty ? catalog.products.first.productId : 'none'} audience=${catalog.audience}");
            final product = catalog.findProduct(resolvedId);

          if (product == null) {
            return const Center(child: Text('Challenge not found'));
          }

          final title = product.title;
          final subtitle = product.subtitle;
          final description = product.description;
          final sessions = product.sessions;
          final sessionCount = sessions.length;

          return ListView(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 28),
            children: [
              Text(
                title,
                style: AppTextStyles.titleLarge.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 6),
              if (subtitle.trim().isNotEmpty)
                Text(
                  subtitle,
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.textMuted,
                    height: 1.35,
                  ),
                ),
              const SizedBox(height: 12),
              if (description.trim().isNotEmpty)
                Text(
                  description,
                  style: AppTextStyles.bodyMedium.copyWith(height: 1.45),
                ),

              const SizedBox(height: 18),

              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.06),
                  borderRadius: BorderRadius.circular(18),
                  border: Border.all(
                    color: AppColors.primary.withOpacity(0.18),
                  ),
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.lock_open_outlined,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'Session 1 is free. Sessions 2+ unlock after purchase.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.textMuted,
                          height: 1.3,
                        ),
                      ),
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 18),

              Text(
                'Sessions',
                style: AppTextStyles.titleMedium.copyWith(
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 10),

              if (sessionCount == 0)
                const Text('No sessions configured yet.')
              else
                ...List.generate(sessionCount, (i) {
                  final sessionNumber = i + 1;
                  final isUnlocked = sessionNumber == 1; // Rule for now

                  return Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: _SessionTile(
                      sessionNumber: sessionNumber,
                      title: sessions[i].title,
                      subtitle: sessions[i].subtitle,
                      isUnlocked: isUnlocked,
                      onTap: () {
                        if (isUnlocked) {
                          Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder:
                                  (_) => JourneySessionScreen(
                                    journeyId: journeyId,
                                    sessionNumber: sessionNumber,
                                  ),
                            ),
                          );
                          return;
                        }

                        // Locked session: enforce account (guest) first.
                        GuestGuard.requireSignedIn(
                          context,
                          ref,
                          title: 'Create an account to continue',
                          message:
                              'You’re currently in guest mode. Create an account to unlock all sessions and track progress.',
                          primaryText: 'Create an account',
                          onCreateAccount:
                              () => Navigator.of(context).pushNamed('/signup'),
                          onAllowed: () async {
                            // TODO: purchase flow placeholder
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text(
                                  'Locked — purchase flow coming soon',
                                ),
                              ),
                            );
                          },
                        );
                      },
                    ),
                  );
                }),

              const SizedBox(height: 6),
            ],
          );
        },
      ),
    );
  }
}

class _SessionTile extends StatelessWidget {
  final int sessionNumber;
  final String title;
  final String subtitle;
  final bool isUnlocked;
  final VoidCallback onTap;

  const _SessionTile({
    required this.sessionNumber,
    required this.title,
    required this.subtitle,
    required this.isUnlocked,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final badgeColor = isUnlocked ? AppColors.success : AppColors.textMuted;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(18),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppColors.surface,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Row(
          children: [
            Container(
              width: 44,
              height: 44,
              decoration: BoxDecoration(
                color: badgeColor.withOpacity(0.12),
                borderRadius: BorderRadius.circular(14),
              ),
              child: Icon(
                isUnlocked ? Icons.play_circle_outline : Icons.lock_outline,
                color: badgeColor,
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Session $sessionNumber',
                    style: AppTextStyles.labelLarge.copyWith(
                      color: AppColors.textMuted,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    title,
                    style: AppTextStyles.bodyLarge.copyWith(
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  if (subtitle.trim().isNotEmpty) ...[
                    const SizedBox(height: 4),
                    Text(
                      subtitle,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.textMuted,
                        height: 1.3,
                      ),
                    ),
                  ],
                ],
              ),
            ),
            const SizedBox(width: 10),
            Icon(
              Icons.chevron_right,
              color: AppColors.textMuted.withOpacity(0.8),
            ),
          ],
        ),
      ),
    );
  }
}
