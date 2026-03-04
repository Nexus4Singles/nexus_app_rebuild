import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_app_v2/core/constants/app_constants.dart';
import 'package:nexus_app_v2/core/providers/relationship_status_provider.dart';
import 'package:nexus_app_v2/core/providers/user_provider.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import 'package:nexus_app_v2/core/theme/app_colors.dart';
import 'package:nexus_app_v2/core/theme/app_text_styles.dart';
import 'package:nexus_app_v2/core/user/current_user_doc_provider.dart';
import 'package:nexus_app_v2/core/session/effective_relationship_status_provider.dart';
import 'package:nexus_app_v2/features/dating_search/presentation/screens/dating_preferences_setup_screen.dart';

class RelationshipStatusEditor extends ConsumerWidget {
  final String currentStatus;
  final VoidCallback? onStatusChanged;
  final String? customSubtitle;

  const RelationshipStatusEditor({
    required this.currentStatus,
    this.onStatusChanged,
    this.customSubtitle,
    Key? key,
  }) : super(key: key);

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final cardColor = Theme.of(context).colorScheme.surface;
    final borderColor = Theme.of(context).dividerColor;

    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () {
          showRelationshipStatusDialog(
            context,
            ref,
            currentStatus,
            onSuccess: onStatusChanged ?? () {},
          );
        },
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          curve: Curves.easeOut,
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: [
              BoxShadow(
                blurRadius: 16,
                offset: const Offset(0, 6),
                color: Theme.of(context).shadowColor.withOpacity(0.05),
              ),
            ],
          ),
          child: Row(
            children: [
              Container(
                height: 46,
                width: 46,
                decoration: BoxDecoration(
                  color: Theme.of(context).colorScheme.surface,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: Theme.of(context).dividerColor),
                ),
                child: Icon(
                  Icons.favorite_border_rounded,
                  color: Theme.of(context).colorScheme.primary,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Switch Marital Status',
                      style: AppTextStyles.titleSmall,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      customSubtitle ?? _getStatusLabel(currentStatus),
                      style: AppTextStyles.bodySmall.copyWith(
                        color: AppColors.getTextSecondary(context),
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: AppColors.getTextSecondary(context),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

String _getStatusLabel(String status) {
  switch (status.toLowerCase()) {
    case 'single':
    case 'single_never_married':
    case 'never married':
    case 'never_married':
      return 'Never Married';
    case 'divorced':
      return 'Divorced';
    case 'widowed':
      return 'Widowed';
    case 'married':
      return 'Married';
    default:
      return status;
  }
}

/// Dialog for editing relationship status
void showRelationshipStatusDialog(
  BuildContext context,
  WidgetRef ref,
  String currentStatus, {
  required VoidCallback onSuccess,
}) {
  // Cache all colors BEFORE showing the dialog - they don't change during the dialog lifecycle
  final surfaceColor = AppColors.getSurface(context);
  final borderColor = AppColors.getBorder(context);
  final textSecondaryColor = AppColors.getTextSecondary(context);

  final updater = ref.read(relationshipStatusUpdaterProvider);
  // Normalize currentStatus to canonical value
  String normalizeStatus(String status) {
    final s = status.toLowerCase();
    if (s.contains('never') || s.contains('single')) return 'never_married';
    if (s.contains('married')) return 'married';
    if (s.contains('divorc')) return 'divorced';
    if (s.contains('widow')) return 'widowed';
    return 'never_married'; // fallback
  }

  String selectedStatus = normalizeStatus(currentStatus);
  bool isLoading = false;

  final statusOptions = ['never_married', 'married', 'divorced', 'widowed'];

  showDialog(
    context: context,
    builder:
        (dialogContext) => StatefulBuilder(
          builder: (sbContext, setState) {
            final statusChanged =
                selectedStatus.toLowerCase() !=
                normalizeStatus(currentStatus).toLowerCase();

            return Dialog(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Header with title and close button
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Expanded(
                          child: Text(
                            'Switch Marital Status',
                            style: AppTextStyles.headlineSmall,
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed:
                              isLoading
                                  ? null
                                  : () => Navigator.pop(dialogContext),
                          tooltip: 'Close',
                          iconSize: 24,
                        ),
                      ],
                    ),
                  ),
                  // Divider
                  Divider(height: 1, thickness: 1),
                  // Content
                  Flexible(
                    child: SingleChildScrollView(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Select your current relationship status:',
                              style: AppTextStyles.bodyMedium.copyWith(
                                color: textSecondaryColor,
                              ),
                            ),
                            const SizedBox(height: 16),
                            ...statusOptions.map((status) {
                              final displayLabel = _getStatusLabel(status);
                              final isSelected =
                                  selectedStatus.toLowerCase() ==
                                  status.toLowerCase();
                              return Padding(
                                padding: const EdgeInsets.only(bottom: 8),
                                child: Material(
                                  color: Colors.transparent,
                                  child: InkWell(
                                    onTap:
                                        isLoading
                                            ? null
                                            : () => setState(
                                              () => selectedStatus = status,
                                            ),
                                    borderRadius: BorderRadius.circular(12),
                                    child: Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            isSelected
                                                ? AppColors.primary.withOpacity(
                                                  0.1,
                                                )
                                                : surfaceColor,
                                        borderRadius: BorderRadius.circular(12),
                                        border: Border.all(
                                          color:
                                              isSelected
                                                  ? AppColors.primary
                                                  : borderColor.withOpacity(
                                                    0.3,
                                                  ),
                                          width: isSelected ? 2 : 1,
                                        ),
                                      ),
                                      child: Row(
                                        children: [
                                          Radio<String>(
                                            value: status,
                                            groupValue: selectedStatus,
                                            onChanged:
                                                isLoading
                                                    ? null
                                                    : (value) {
                                                      if (value != null) {
                                                        setState(
                                                          () =>
                                                              selectedStatus =
                                                                  value,
                                                        );
                                                      }
                                                    },
                                            activeColor: AppColors.primary,
                                          ),
                                          const SizedBox(width: 8),
                                          Expanded(
                                            child: Text(
                                              displayLabel,
                                              style: AppTextStyles.bodyMedium,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                  ),
                                ),
                              );
                            }).toList(),
                            // Info message only shows when status is different
                            if (statusChanged) ...[
                              const SizedBox(height: 16),
                              Container(
                                padding: const EdgeInsets.all(12),
                                decoration: BoxDecoration(
                                  color: AppColors.primary.withOpacity(0.08),
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(
                                    color: AppColors.primary.withOpacity(0.2),
                                  ),
                                ),
                                child: Row(
                                  children: [
                                    Icon(
                                      Icons.info_outline,
                                      color: AppColors.primary,
                                      size: 16,
                                    ),
                                    const SizedBox(width: 8),
                                    Expanded(
                                      child: Text(
                                        _getStatusChangeMessage(
                                          currentStatus,
                                          selectedStatus,
                                        ),
                                        style: AppTextStyles.bodySmall.copyWith(
                                          color: textSecondaryColor,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ],
                        ),
                      ),
                    ),
                  ),
                  // Divider before actions
                  Divider(height: 1, thickness: 1),
                  // Action buttons - only show Update when status changed
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        // Update button - only visible when status changed
                        if (statusChanged)
                          Expanded(
                            child: ElevatedButton(
                              onPressed:
                                  isLoading
                                      ? null
                                      : () async {
                                        // ignore: avoid_print
                                        print(
                                          '[RelationshipStatusDialog] UPDATE button pressed',
                                        );
                                        setState(() => isLoading = true);
                                        try {
                                          final userAsync = ref.read(
                                            currentUserProvider,
                                          );
                                          final user = userAsync.maybeWhen(
                                            data: (u) => u,
                                            orElse: () => null,
                                          );

                                          if (user == null) {
                                            if (sbContext.mounted) {
                                              ScaffoldMessenger.of(
                                                sbContext,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: const Text(
                                                    'User not found',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.primary,
                                                ),
                                              );
                                            }
                                            return;
                                          }

                                          // Check if transitioning FROM married to eligible status
                                          final oldStatus =
                                              currentStatus.toLowerCase();
                                          final newStatus =
                                              selectedStatus.toLowerCase();
                                          // ignore: avoid_print
                                          print(
                                            '[RelationshipStatusDialog] Status change: $oldStatus → $newStatus',
                                          );
                                          final isReactivatingDating =
                                              oldStatus == 'married' &&
                                              [
                                                'single',
                                                'divorced',
                                                'widowed',
                                                'never_married',
                                              ].contains(newStatus);

                                          // ignore: avoid_print
                                          print(
                                            '[RelationshipStatusDialog] BEFORE UPDATE: auth state ready for update',
                                          );

                                          // ignore: avoid_print
                                          print(
                                            '[RelationshipStatusDialog] Calling updateRelationshipStatus...',
                                          );
                                          await updater
                                              .updateRelationshipStatus(
                                                user.uid,
                                                newStatus,
                                                oldStatus: oldStatus,
                                              );
                                          // ignore: avoid_print
                                          print(
                                            '[RelationshipStatusDialog] updateRelationshipStatus completed!',
                                          );

                                          if (sbContext.mounted) {
                                            // Clear the "preferences setup after status change" flag
                                            // so that if user reactivates dating, it will show setup again
                                            final prefs =
                                                await SharedPreferences.getInstance();
                                            await prefs.remove(
                                              'preferences_setup_after_status_change',
                                            );
                                            // ignore: avoid_print
                                            print(
                                              '[RelationshipStatusDialog] ✓ Cleared preferences setup flag for new status',
                                            );

                                            // Close dialog - Firestore listeners automatically handle UI updates
                                            Navigator.pop(dialogContext);
                                            // ignore: avoid_print
                                            print(
                                              '[RelationshipStatusDialog] Dialog popped!',
                                            );
                                          }

                                          // If switching FROM married to eligible status, ask about reactivating dating profile
                                          if (isReactivatingDating) {
                                            _showReactivateDatingProfileDialog(
                                              context,
                                              ref,
                                              user.uid,
                                              updater,
                                              selectedStatus,
                                              onSuccess,
                                            );
                                          } else {
                                            // Show success message for non-dating transitions
                                            // Use context (outer) instead of sbContext to avoid deactivated widget
                                            if (context.mounted) {
                                              ScaffoldMessenger.of(
                                                context,
                                              ).showSnackBar(
                                                SnackBar(
                                                  content: Text(
                                                    'Relationship status updated to $selectedStatus ✓',
                                                  ),
                                                  backgroundColor:
                                                      AppColors.primary,
                                                ),
                                              );
                                            }

                                            onSuccess();
                                          }
                                        } catch (e) {
                                          setState(() => isLoading = false);
                                          if (context.mounted) {
                                            ScaffoldMessenger.of(
                                              context,
                                            ).showSnackBar(
                                              SnackBar(
                                                content: Text(
                                                  'Error: ${e.toString()}',
                                                ),
                                                backgroundColor:
                                                    AppColors.error,
                                              ),
                                            );
                                          }
                                        }
                                      },
                              child:
                                  isLoading
                                      ? SizedBox(
                                        width: 20,
                                        height: 20,
                                        child: CircularProgressIndicator(
                                          valueColor:
                                              AlwaysStoppedAnimation<Color>(
                                                AppColors.textOnPrimary,
                                              ),
                                          strokeWidth: 2,
                                        ),
                                      )
                                      : const Text('Update'),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          },
        ),
  );
}

String _getStatusChangeMessage(String oldStatus, String newStatus) {
  final oldLower = oldStatus.toLowerCase();
  final newLower = newStatus.toLowerCase();

  if (newLower == 'married') {
    return 'Switching to married will archive your dating profile. You can reactivate it anytime.';
  } else if (oldLower == 'married' && newLower != 'married') {
    return 'You can now create or rejoin the dating section.';
  }

  return 'Your profile settings will be updated.';
}

/// Show dialog asking user if they want to reactivate their dating profile
void _showReactivateDatingProfileDialog(
  BuildContext context,
  WidgetRef ref,
  String uid,
  RelationshipStatusUpdater updater,
  String newStatus,
  VoidCallback onSuccess,
) {
  showDialog(
    context: context,
    builder:
        (dialogContext) => AlertDialog(
          title: Text(
            'Reactivate Dating Profile?',
            style: AppTextStyles.headlineSmall,
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'You previously had a dating profile. Would you like to reactivate it now?',
                style: AppTextStyles.bodyMedium.copyWith(
                  color: AppColors.getTextSecondary(dialogContext),
                ),
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: AppColors.primary.withOpacity(0.08),
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: AppColors.primary.withOpacity(0.2)),
                ),
                child: Row(
                  children: [
                    Icon(
                      Icons.info_outline,
                      color: AppColors.primary,
                      size: 16,
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        'Your profile data has been kept safe. You can reactivate it anytime.',
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(dialogContext),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(dialogContext);

                // User chose NOT to reactivate - show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Relationship status updated to $newStatus ✓',
                    ),
                    backgroundColor: AppColors.primary,
                  ),
                );

                onSuccess();
              },
              child: Text(
                'Keep as Basic Profile',
                style: TextStyle(
                  color: AppColors.getTextSecondary(dialogContext),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: () async {
                Navigator.pop(dialogContext);

                try {
                  // Reactivate the dating profile
                  final userRef = FirebaseFirestore.instance
                      .collection('users')
                      .doc(uid);
                  final datingProfileRef = userRef
                      .collection('dating')
                      .doc('profile');

                  await datingProfileRef.set({
                    'isActive': true,
                  }, SetOptions(merge: true));

                  // Invalidate providers after pop to be safe
                  try {
                    ref.invalidate(currentUserProvider);
                    ref.invalidate(effectiveRelationshipStatusProvider);
                  } catch (e) {
                    // Ignore errors if ref is already disposed
                  }

                  if (context.mounted) {
                    // Navigate to dating preferences setup screen instead of showing success
                    // This allows them to set up preferences for their new status
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder:
                            (_) => const DatingPreferencesSetupScreen(
                              isReactivatingAfterStatusChange: true,
                            ),
                      ),
                    );
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: Text('Error: ${e.toString()}'),
                        backgroundColor: AppColors.primary,
                      ),
                    );
                  }
                }
              },
              child: const Text('Reactivate Dating Profile'),
            ),
          ],
        ),
  );
}
