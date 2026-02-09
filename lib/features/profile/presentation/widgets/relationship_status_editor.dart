import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_v2/core/constants/app_constants.dart';
import 'package:nexus_app_v2/core/providers/relationship_status_provider.dart';
import 'package:nexus_app_v2/core/providers/user_provider.dart';
import 'package:nexus_app_v2/core/theme/app_colors.dart';
import 'package:nexus_app_v2/core/theme/app_text_styles.dart';
import 'package:nexus_app_v2/core/user/current_user_doc_provider.dart';
import 'package:nexus_app_v2/core/session/effective_relationship_status_provider.dart';

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
    return Container(
      decoration: BoxDecoration(
        color: AppColors.getSurface(context),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: AppColors.getBorder(context).withOpacity(0.3),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: Icon(
                    Icons.favorite_border_rounded,
                    color: AppColors.primary,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Relationship Status',
                        style: AppTextStyles.bodyLarge.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        customSubtitle ?? _getStatusLabel(currentStatus),
                        style: AppTextStyles.bodySmall.copyWith(
                          color: AppColors.getTextSecondary(context),
                        ),
                      ),
                    ],
                  ),
                ),
                Icon(
                  Icons.chevron_right,
                  color: AppColors.getTextSecondary(context),
                  size: 20,
                ),
              ],
            ),
          ),
        ],
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
  final updater = ref.read(relationshipStatusUpdaterProvider);
  String selectedStatus = currentStatus;
  bool isLoading = false;

  final statusOptions = [
    'never_married',
    'married',
    'divorced',
    'widowed',
  ];

  showDialog(
    context: context,
    builder: (dialogContext) => StatefulBuilder(
      builder: (context, setState) {
        return AlertDialog(
          title: Text(
            'Update Relationship Status',
            style: AppTextStyles.headlineSmall,
          ),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Select your current relationship status:',
                  style: AppTextStyles.bodyMedium.copyWith(
                    color: AppColors.getTextSecondary(context),
                  ),
                ),
                const SizedBox(height: 16),
                ...statusOptions.map((status) {
                  final displayLabel = _getStatusLabel(status);
                  final isSelected = selectedStatus.toLowerCase() ==
                      status.toLowerCase();
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Material(
                      color: Colors.transparent,
                      child: InkWell(
                        onTap: isLoading ? null : () => setState(() => selectedStatus = status),
                        borderRadius: BorderRadius.circular(12),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isSelected
                                ? AppColors.primary.withOpacity(0.1)
                                : AppColors.getSurface(context),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isSelected
                                  ? AppColors.primary
                                  : AppColors.getBorder(context).withOpacity(0.3),
                              width: isSelected ? 2 : 1,
                            ),
                          ),
                          child: Row(
                            children: [
                              Radio<String>(
                                value: status,
                                groupValue: selectedStatus,
                                onChanged: isLoading
                                    ? null
                                    : (value) {
                                        if (value != null) {
                                          setState(() => selectedStatus = value);
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
                if (selectedStatus.toLowerCase() != currentStatus.toLowerCase()) ...[
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
                              color: AppColors.getTextSecondary(context),
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
          actions: [
            TextButton(
              onPressed: isLoading ? null : () => Navigator.pop(context),
              child: Text(
                'Cancel',
                style: TextStyle(
                  color: AppColors.getTextSecondary(context),
                ),
              ),
            ),
            ElevatedButton(
              onPressed: selectedStatus.toLowerCase() ==
                      currentStatus.toLowerCase()
                  ? null
                  : isLoading
                      ? null
                      : () async {
                          setState(() => isLoading = true);
                          try {
                            final userAsync = ref.read(currentUserProvider);
                            final user = userAsync.maybeWhen(
                              data: (u) => u,
                              orElse: () => null,
                            );

                            if (user == null) {
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('User not found'),
                                  ),
                                );
                              }
                              return;
                            }

                            // Check if transitioning FROM married to eligible status
                            final oldStatus = currentStatus.toLowerCase();
                            final newStatus = selectedStatus.toLowerCase();
                            final isReactivatingDating = oldStatus == 'married' &&
                                ['single', 'divorced', 'widowed', 'never_married']
                                    .contains(newStatus);

                            await updater.updateRelationshipStatus(
                              user.uid,
                              newStatus,
                            );

                            if (context.mounted) {
                              // Invalidate the entire provider cascade to refresh:
                              // currentUserDocProvider -> effectiveRelationshipStatusProvider 
                              // -> journeyCatalogProvider & recommendedAssessmentTypeProvider
                              ref.invalidate(currentUserDocProvider);
                              ref.invalidate(currentUserProvider);

                              // If switching FROM married to eligible status, ask about reactivating dating profile
                              if (isReactivatingDating) {
                                Navigator.pop(context);
                                _showReactivateDatingProfileDialog(
                                  context,
                                  ref,
                                  user.uid,
                                  updater,
                                  selectedStatus,
                                  onSuccess,
                                );
                              } else {
                                Navigator.pop(context);

                                // Show success message for non-dating transitions
                                ScaffoldMessenger.of(context).showSnackBar(
                                  SnackBar(
                                    content: Text(
                                      'Relationship status updated to $selectedStatus ✓',
                                    ),
                                    backgroundColor: AppColors.primary,
                                  ),
                                );

                                onSuccess();
                              }
                            }
                          } catch (e) {
                            setState(() => isLoading = false);
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Error: ${e.toString()}'),
                                  backgroundColor: AppColors.error,
                                ),
                              );
                            }
                          }
                        },
              child: isLoading
                  ? SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        valueColor: AlwaysStoppedAnimation<Color>(
                          AppColors.textOnPrimary,
                        ),
                        strokeWidth: 2,
                      ),
                    )
                  : const Text('Update'),
            ),
          ],
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
    builder: (dialogContext) => AlertDialog(
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
              color: AppColors.getTextSecondary(context),
            ),
          ),
          const SizedBox(height: 12),
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
                    'Your profile data has been kept safe. You can reactivate it anytime.',
                    style: AppTextStyles.bodySmall.copyWith(
                      color: AppColors.getTextSecondary(context),
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
            Navigator.pop(context);

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
              color: AppColors.getTextSecondary(context),
            ),
          ),
        ),
        ElevatedButton(
          onPressed: () async {
            Navigator.pop(context);

            try {
              // Reactivate the dating profile
              final userRef = FirebaseFirestore.instance.collection('users').doc(uid);
              final datingProfileRef = userRef.collection('dating').doc('profile');

              await datingProfileRef.set(
                {'isActive': true},
                SetOptions(merge: true),
              );

              // Invalidate to refresh UI
              ref.invalidate(currentUserDocProvider);
              ref.invalidate(currentUserProvider);

              if (context.mounted) {
                // Show success message
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text(
                      'Dating profile reactivated! Your profile is now visible. ✓',
                    ),
                    backgroundColor: AppColors.primary,
                  ),
                );

                onSuccess();
              }
            } catch (e) {
              if (context.mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  SnackBar(
                    content: Text('Error: ${e.toString()}'),
                    backgroundColor: AppColors.error,
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
