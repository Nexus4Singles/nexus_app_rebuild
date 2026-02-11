import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import 'package:nexus_app_v2/features/admin_review/application/coach_application_providers.dart';

class CoachReviewDetailScreen extends ConsumerStatefulWidget {
  final String applicationId;

  const CoachReviewDetailScreen({
    Key? key,
    required this.applicationId,
  }) : super(key: key);

  @override
  ConsumerState<CoachReviewDetailScreen> createState() => _CoachReviewDetailScreenState();
}

class _CoachReviewDetailScreenState extends ConsumerState<CoachReviewDetailScreen> {
  bool _isApproving = false;
  bool _isRejecting = false;

  @override
  Widget build(BuildContext context) {
    final applicationAsync = ref.watch(coachApplicationDetailProvider(widget.applicationId));

    return Scaffold(
      appBar: AppBar(
        title: const Text('Coach Application Review'),
        elevation: 0,
      ),
      body: applicationAsync.when(
        data: (application) {
          return SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Profile Photo
                if (application.profilePhotoUrl != null)
                  Container(
                    width: double.infinity,
                    height: 300,
                    decoration: BoxDecoration(
                      image: DecorationImage(
                        image: NetworkImage(application.profilePhotoUrl!),
                        fit: BoxFit.cover,
                      ),
                    ),
                  )
                else
                  Container(
                    width: double.infinity,
                    height: 300,
                    color: Colors.grey[300],
                    child: Icon(
                      Icons.person,
                      size: 100,
                      color: Colors.grey[600],
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.all(16.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Personal Information Section
                      _buildSectionTitle('Personal Information'),
                      _buildInfoRow('Full Name', application.fullName),
                      _buildInfoRow('Email', application.email),
                      _buildInfoRow('Phone', application.phoneNumber),
                      _buildInfoRow('Gender', application.gender),
                      const SizedBox(height: 16),

                      // Professional Information Section
                      _buildSectionTitle('Professional Information'),
                      _buildInfoRow('Title', application.title),
                      _buildInfoRow('Years of Experience', '${application.yearsOfExperience} years'),
                      _buildInfoRow('Nationality', application.nationality),
                      _buildInfoRow('Residence Location', application.residenceLocation),
                      _buildInfoRow('Marital Status', application.maritalStatus),
                      const SizedBox(height: 16),

                      // Qualifications Section
                      _buildSectionTitle('Qualifications'),
                      _buildExpandableText('Credentials', application.credentials),
                      if (application.specializations.isNotEmpty)
                        _buildInfoRow(
                          'Specializations',
                          application.specializations.join(', '),
                        ),
                      _buildExpandableText('Coaching Philosophy', application.coachingPhilosophy),
                      const SizedBox(height: 16),

                      // Social Media Section
                      if (application.instagramHandle != null || application.linkedinProfile != null)
                        ...[
                          _buildSectionTitle('Social Media'),
                          if (application.instagramHandle != null)
                            _buildLinkRow(
                              'Instagram',
                              application.instagramHandle!,
                              () async {
                                final url = 'https://instagram.com/${application.instagramHandle}';
                                if (await canLaunchUrl(Uri.parse(url))) {
                                  await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
                                }
                              },
                            ),
                          if (application.linkedinProfile != null)
                            _buildLinkRow(
                              'LinkedIn',
                              application.linkedinProfile!,
                              () async {
                                if (await canLaunchUrl(Uri.parse(application.linkedinProfile!))) {
                                  await launchUrl(
                                    Uri.parse(application.linkedinProfile!),
                                    mode: LaunchMode.externalApplication,
                                  );
                                }
                              },
                            ),
                          const SizedBox(height: 16),
                        ],

                      // Attachments Section
                      if (application.credentialsPdfUrl != null)
                        ...[
                          _buildSectionTitle('Attachments'),
                          _buildAttachmentButton(
                            'Download Credentials PDF',
                            application.credentialsPdfUrl!,
                          ),
                          const SizedBox(height: 16),
                        ],

                      // Submission Info
                      _buildSectionTitle('Submission Info'),
                      _buildInfoRow(
                        'Submitted',
                        _formatDateTime(application.submittedAt),
                      ),
                      if (application.emailSentAt != null)
                        _buildInfoRow(
                          'Email Sent',
                          _formatDateTime(application.emailSentAt!),
                        ),
                      if (application.reviewedAt != null)
                        _buildInfoRow(
                          'Reviewed',
                          _formatDateTime(application.reviewedAt!),
                        ),
                      if (application.reviewedBy != null)
                        _buildInfoRow('Reviewed By', application.reviewedBy!),
                      const SizedBox(height: 24),

                      // Action Buttons
                      if (application.status == 'pending')
                        Row(
                          children: [
                            Expanded(
                              child: FilledButton.tonal(
                                onPressed: _isRejecting
                                    ? null
                                    : () => _showRejectDialog(context, ref),
                                style: FilledButton.styleFrom(
                                  backgroundColor: Colors.red[100],
                                  foregroundColor: Colors.red[900],
                                ),
                                child: _isRejecting
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(strokeWidth: 2),
                                      )
                                    : const Text('Reject'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _isApproving ? null : () => _approveApplication(ref),
                                child: _isApproving
                                    ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          valueColor: AlwaysStoppedAnimation(Colors.white),
                                        ),
                                      )
                                    : const Text('Approve'),
                              ),
                            ),
                          ],
                        )
                      else
                        Center(
                          child: Chip(
                            label: Text(
                              'Status: ${application.status.toUpperCase()}',
                              style: const TextStyle(fontWeight: FontWeight.bold),
                            ),
                            backgroundColor: application.status == 'approved'
                                ? Colors.green[100]
                                : Colors.red[100],
                          ),
                        ),
                      const SizedBox(height: 24),
                    ],
                  ),
                ),
              ],
            ),
          );
        },
        loading: () => const Center(
          child: CircularProgressIndicator(),
        ),
        error: (error, stack) => Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.error_outline, size: 64, color: Colors.red[300]),
              const SizedBox(height: 16),
              Text('Error loading application: $error'),
            ],
          ),
        ),
      ),
    );
  }

  void _approveApplication(WidgetRef ref) async {
    setState(() => _isApproving = true);
    try {
      await ref.read(
        updateCoachApplicationStatusProvider(
          (widget.applicationId, 'approved', null),
        ).future,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application approved successfully')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error approving: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isApproving = false);
      if (mounted) setState(() => _isApproving = false);
    }
  }

  void _showRejectDialog(BuildContext context, WidgetRef ref) {
    final reasonController = TextEditingController();

    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('Reject Application'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Please provide a reason for rejection:'),
            const SizedBox(height: 16),
            TextField(
              controller: reasonController,
              decoration: InputDecoration(
                hintText: 'Rejection reason...',
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(8),
                ),
                contentPadding: const EdgeInsets.all(12),
              ),
              maxLines: 3,
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: Colors.red,
            ),
            onPressed: () async {
              Navigator.pop(dialogContext);
              await _rejectApplication(ref, reasonController.text);
            },
            child: const Text('Reject'),
          ),
        ],
      ),
    );
  }

  Future<void> _rejectApplication(WidgetRef ref, String reason) async {
    setState(() => _isRejecting = true);
    try {
      await ref.read(
        updateCoachApplicationStatusProvider(
          (widget.applicationId, 'rejected', reason.isNotEmpty ? reason : null),
        ).future,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Application rejected')),
        );
        Navigator.pop(context);
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error rejecting: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isRejecting = false);
    }
  }

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12.0),
      child: Text(
        title,
        style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: Colors.blue[700],
            ),
      ),
    );
  }

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(
            width: 120,
            child: Text(
              label,
              style: const TextStyle(
                fontWeight: FontWeight.w500,
                color: Colors.grey,
              ),
            ),
          ),
          Expanded(
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildExpandableText(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              fontWeight: FontWeight.w500,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 4),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.grey[50],
              border: Border.all(color: Colors.grey[200]!),
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(value),
          ),
        ],
      ),
    );
  }

  Widget _buildLinkRow(String label, String value, VoidCallback onTap) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: InkWell(
        onTap: onTap,
        child: Row(
          children: [
            SizedBox(
              width: 120,
              child: Text(
                label,
                style: const TextStyle(
                  fontWeight: FontWeight.w500,
                  color: Colors.grey,
                ),
              ),
            ),
            Expanded(
              child: Text(
                value,
                style: TextStyle(
                  color: Colors.blue[600],
                  decoration: TextDecoration.underline,
                ),
              ),
            ),
            Icon(Icons.open_in_new, size: 16, color: Colors.blue[600]),
          ],
        ),
      ),
    );
  }

  Widget _buildAttachmentButton(String label, String url) {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.tonal(
        onPressed: () async {
          if (await canLaunchUrl(Uri.parse(url))) {
            await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
          }
        },
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.download),
            const SizedBox(width: 8),
            Text(label),
          ],
        ),
      ),
    );
  }

  String _formatDateTime(DateTime dateTime) {
    return '${dateTime.year}-${dateTime.month.toString().padLeft(2, '0')}-${dateTime.day.toString().padLeft(2, '0')} ${dateTime.hour.toString().padLeft(2, '0')}:${dateTime.minute.toString().padLeft(2, '0')}';
  }
}
