import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:nexus_app_min_test/core/user/is_admin_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_min_test/core/services/media_service.dart';

class AdminReviewDetailScreen extends ConsumerWidget {
  final String userId;
  const AdminReviewDetailScreen({super.key, required this.userId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final isAdmin = ref
        .watch(isAdminProvider)
        .maybeWhen(data: (v) => v, orElse: () => false);
    if (!isAdmin) {
      return const Scaffold(body: Center(child: Text('Admin access required')));
    }

    final fs = ref.watch(firestoreInstanceProvider);
    if (fs == null) {
      return const Scaffold(body: Center(child: Text('Firestore not ready')));
    }

    final docStream = fs.collection('users').doc(userId).snapshots();

    return StreamBuilder<DocumentSnapshot<Map<String, dynamic>>>(
      stream: docStream,
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          );
        }
        final doc = snap.data!;
        final data = doc.data() ?? {};
        final dating = (data['dating'] is Map) ? data['dating'] as Map : null;
        final rp =
            (dating?['reviewPack'] is Map)
                ? dating!['reviewPack'] as Map
                : null;

        final photos =
            (rp?['photoUrls'] is List)
                ? (rp!['photoUrls'] as List)
                    .map((e) => e.toString())
                    .take(2)
                    .toList()
                : <String>[];

        final audios =
            (rp?['audioUrls'] is List)
                ? (rp!['audioUrls'] as List)
                    .map((e) => e.toString())
                    .take(2)
                    .toList()
                : <String>[];

        final name = (data['name'] ?? data['username'] ?? 'User').toString();
        final status = dating?['verificationStatus']?.toString();

        Future<void> setStatus(String newStatus, {String? reason}) async {
          final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
          final payload = <String, dynamic>{
            'dating.verificationStatus': newStatus,

            // Keep existing field name for backwards compatibility (already used elsewhere)
            'dating.verifiedBy': adminId,

            // Audit trail (new)
            'dating.reviewedBy': adminId,
            'dating.reviewedAt': FieldValue.serverTimestamp(),
          };
          if (newStatus == 'verified') {
            payload['dating.verifiedAt'] = FieldValue.serverTimestamp();
          }
          if (newStatus == 'rejected') {
            payload['dating.rejectedAt'] = FieldValue.serverTimestamp();
            if (reason != null && reason.trim().isNotEmpty) {
              payload['dating.rejectionReason'] = reason.trim();
            }
          }
          await fs.collection('users').doc(userId).update(payload);
        }

        Future<String?> askRejectionReason() async {
          final controller = TextEditingController();
          return showDialog<String?>(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: const Text('Rejection reason'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  decoration: const InputDecoration(
                    hintText:
                        'Tell the user what to fix (e.g. blurry photos, no clear face, audio missing)…',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed:
                        () => Navigator.of(ctx).pop(controller.text.trim()),
                    child: const Text('Reject'),
                  ),
                ],
              );
            },
          );
        }

        Future<String?> askDisableReason({required bool enabling}) async {
          final controller = TextEditingController();
          return showDialog<String?>(
            context: context,
            builder: (ctx) {
              return AlertDialog(
                title: Text(enabling ? 'Enable account' : 'Disable account'),
                content: TextField(
                  controller: controller,
                  autofocus: true,
                  maxLines: 3,
                  decoration: InputDecoration(
                    hintText:
                        enabling
                            ? 'Optional note (will be cleared on enable)…'
                            : 'Optional reason (e.g. policy violation, spam, abuse)…',
                  ),
                ),
                actions: [
                  TextButton(
                    onPressed: () => Navigator.of(ctx).pop(null),
                    child: const Text('Cancel'),
                  ),
                  ElevatedButton(
                    onPressed:
                        () => Navigator.of(ctx).pop(controller.text.trim()),
                    child: Text(enabling ? 'Enable' : 'Disable'),
                  ),
                ],
              );
            },
          );
        }

        Future<void> setAccountDisabled(bool disabled, {String? reason}) async {
          final adminId = FirebaseAuth.instance.currentUser?.uid ?? 'admin';
          final payload = <String, dynamic>{
            'account.disabled': disabled,
            'account.disabledBy': adminId,
            'account.disabledAt': FieldValue.serverTimestamp(),
          };

          if (!disabled) {
            // Clear reason when enabling.
            payload['account.disabledReason'] = FieldValue.delete();
          } else {
            if (reason != null && reason.trim().isNotEmpty) {
              payload['account.disabledReason'] = reason.trim();
            } else {
              payload['account.disabledReason'] = FieldValue.delete();
            }
          }

          await fs.collection('users').doc(userId).update(payload);
        }

        return Scaffold(
          appBar: AppBar(title: Text('Review: $name')),
          body: Padding(
            padding: const EdgeInsets.all(16),
            child: ListView(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Status: ${status ?? "unknown"}'),
                    const SizedBox(height: 6),

                    // Account disable status (moderation)
                    Builder(
                      builder: (_) {
                        final account =
                            (data['account'] is Map)
                                ? data['account'] as Map
                                : null;
                        final disabled =
                            (account?['disabled'] == true) ||
                            (account?['isDisabled'] == true);
                        final disabledBy = account?['disabledBy']?.toString();
                        final disabledReason =
                            account?['disabledReason']?.toString();

                        final lines = <String>[];
                        lines.add(
                          'Account disabled: ${disabled ? "YES" : "NO"}',
                        );
                        if (disabledBy != null && disabledBy.isNotEmpty) {
                          lines.add('Disabled by: $disabledBy');
                        }
                        if (disabledReason != null &&
                            disabledReason.trim().isNotEmpty) {
                          lines.add('Reason: ${disabledReason.trim()}');
                        }
                        return Text(
                          lines.join('\n'),
                          style: const TextStyle(fontSize: 12, height: 1.25),
                        );
                      },
                    ),

                    const SizedBox(height: 10),

                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final reason = await askDisableReason(
                                enabling: false,
                              );
                              if (reason == null) return;
                              await setAccountDisabled(true, reason: reason);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.block_rounded),
                            label: const Text('Disable account'),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: ElevatedButton.icon(
                            onPressed: () async {
                              final note = await askDisableReason(
                                enabling: true,
                              );
                              if (note == null) return;
                              await setAccountDisabled(false);
                              if (context.mounted) Navigator.of(context).pop();
                            },
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('Enable account'),
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 14),

                    Builder(
                      builder: (_) {
                        DateTime? asDate(dynamic v) {
                          if (v == null) return null;
                          try {
                            final toDate = v.toDate;
                            if (toDate is Function) return toDate() as DateTime;
                          } catch (_) {}
                          return null;
                        }

                        final verifiedAt = asDate(dating?['verifiedAt']);
                        final rejectedAt = asDate(dating?['rejectedAt']);
                        final reviewedAt = asDate(dating?['reviewedAt']);
                        final reviewedBy = dating?['reviewedBy']?.toString();
                        final verifiedBy = dating?['verifiedBy']?.toString();
                        final rejectionReason =
                            dating?['rejectionReason']?.toString();

                        final lines = <String>[];
                        if (reviewedAt != null)
                          lines.add('Reviewed: ${reviewedAt.toLocal()}');
                        if (reviewedBy != null && reviewedBy.isNotEmpty)
                          lines.add('Reviewed by: $reviewedBy');
                        if (verifiedAt != null)
                          lines.add('Verified: ${verifiedAt.toLocal()}');
                        if (verifiedBy != null && verifiedBy.isNotEmpty)
                          lines.add('Verified by: $verifiedBy');
                        if (rejectedAt != null)
                          lines.add('Rejected: ${rejectedAt.toLocal()}');
                        if (rejectionReason != null &&
                            rejectionReason.trim().isNotEmpty) {
                          lines.add('Reason: ${rejectionReason.trim()}');
                        }

                        if (lines.isEmpty) return const SizedBox.shrink();
                        return Text(
                          lines.join('\n'),
                          style: const TextStyle(fontSize: 12, height: 1.25),
                        );
                      },
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                const Text(
                  'Photos (review pack)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (photos.isEmpty)
                  const Text('No photos in review pack.')
                else
                  Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final url in photos)
                        ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Image.network(
                            url,
                            width: 150,
                            height: 150,
                            fit: BoxFit.cover,
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 20),
                const Text(
                  'Audio (review pack)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 8),
                if (audios.isEmpty)
                  const Text('No audio in review pack.')
                else
                  Column(
                    children: [
                      for (final url in audios)
                        ListTile(
                          contentPadding: EdgeInsets.zero,
                          leading: const Icon(Icons.mic_rounded),
                          title: Text(
                            url,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.play_arrow_rounded),
                            onPressed: () async {
                              try {
                                await MediaService().playAudioFromUrl(url);
                              } catch (_) {}
                            },
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 24),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          await setStatus('verified');
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.verified_rounded),
                        label: const Text('Approve'),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () async {
                          final reason = await askRejectionReason();
                          if (reason == null) return; // cancelled
                          await setStatus('rejected', reason: reason);
                          if (context.mounted) Navigator.of(context).pop();
                        },
                        icon: const Icon(Icons.block_rounded),
                        label: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
