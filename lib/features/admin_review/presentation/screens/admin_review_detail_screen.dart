import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:nexus_app_min_test/core/user/is_admin_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_min_test/core/services/media_service.dart';
import 'package:nexus_app_min_test/core/providers/service_providers.dart';
import 'package:nexus_app_min_test/core/services/duplicate_detection_service.dart';

class AdminReviewDetailScreen extends ConsumerStatefulWidget {
  final String userId;
  const AdminReviewDetailScreen({super.key, required this.userId});

  @override
  ConsumerState<AdminReviewDetailScreen> createState() =>
      _AdminReviewDetailScreenState();
}

class _AdminReviewDetailScreenState
    extends ConsumerState<AdminReviewDetailScreen> {
  String? _currentlyPlayingUrl;
  bool _isPlaying = false;

  MediaService get _media => ref.read(mediaServiceProvider);

  Future<void> _togglePlay(String url) async {
    try {
      if (_currentlyPlayingUrl == url && _isPlaying) {
        await _media.pauseAudio();
        setState(() => _isPlaying = false);
        return;
      }

      // If switching tracks, stop then play the new one
      await _media.stopAudio();
      await _media.playAudioFromUrl(url);
      setState(() {
        _currentlyPlayingUrl = url;
        _isPlaying = true;
      });
    } catch (_) {}
  }

  Future<void> _stopAll() async {
    try {
      await _media.stopAudio();
    } catch (_) {}
    if (mounted) setState(() => _isPlaying = false);
  }

  @override
  void dispose() {
    _stopAll();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final ref = this.ref;
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

    final docStream = fs.collection('users').doc(widget.userId).snapshots();

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
            // After approval: delete review pack (no longer needed)
            payload['dating.reviewPack'] = FieldValue.delete();
          }

          if (newStatus == 'rejected') {
            payload['dating.rejectedAt'] = FieldValue.serverTimestamp();
            if (reason != null && reason.trim().isNotEmpty) {
              payload['dating.rejectionReason'] = reason.trim();
            }
            // After rejection: delete review pack AND auto-disable account
            payload['dating.reviewPack'] = FieldValue.delete();
            payload['account.disabled'] = true;
            payload['account.disabledBy'] = adminId;
            payload['account.disabledAt'] = FieldValue.serverTimestamp();
            payload['account.disabledReason'] =
                'Profile rejected: ${reason?.trim() ?? 'Failed verification'}';
          }

          await fs.collection('users').doc(widget.userId).update(payload);
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

          await fs.collection('users').doc(widget.userId).update(payload);
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
                        GestureDetector(
                          onTap: () => _showImageViewer(context, url),
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(12),
                            child: Image.network(
                              url,
                              width: 150,
                              height: 150,
                              fit: BoxFit.cover,
                            ),
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
                      for (int i = 0; i < audios.length; i++)
                        _AudioItem(
                          index: i,
                          url: audios[i],
                          isPlaying:
                              _isPlaying && _currentlyPlayingUrl == audios[i],
                          onToggle: () => _togglePlay(audios[i]),
                        ),
                    ],
                  ),

                const SizedBox(height: 24),

                // Duplicate Detection Section
                _DuplicateDetectionWidget(
                  userId: widget.userId,
                  photoHashes:
                      (rp?['photoHashes'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [],
                  audioHashes:
                      (rp?['audioHashes'] as List?)
                          ?.map((e) => e.toString())
                          .toList() ??
                      [],
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

  void _showImageViewer(BuildContext context, String url) {
    showDialog(
      context: context,
      barrierDismissible: true,
      builder: (_) {
        return GestureDetector(
          onTap: () => Navigator.of(context).pop(),
          child: Container(
            color: Colors.black.withOpacity(0.9),
            child: Stack(
              children: [
                Center(
                  child: InteractiveViewer(
                    minScale: 0.5,
                    maxScale: 4,
                    child: Image.network(url, fit: BoxFit.contain),
                  ),
                ),
                Positioned(
                  top: 40,
                  right: 20,
                  child: CircleAvatar(
                    backgroundColor: Colors.black54,
                    child: IconButton(
                      icon: const Icon(
                        Icons.close_rounded,
                        color: Colors.white,
                      ),
                      onPressed: () => Navigator.of(context).pop(),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _AudioItem extends StatelessWidget {
  final int index;
  final String url;
  final bool isPlaying;
  final VoidCallback onToggle;

  const _AudioItem({
    required this.index,
    required this.url,
    required this.isPlaying,
    required this.onToggle,
  });

  String get _title {
    // Map known questions by index (0-based corresponding to Q1..Q3)
    switch (index) {
      case 0:
        return 'Q1: Relationship with God';
      case 1:
        return 'Q2: Roles in Marriage';
      case 2:
        return 'Q3: Favorite Qualities';
      default:
        return 'Audio ${index + 1}';
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.mic_rounded),
      title: Text(_title),
      subtitle: Text(
        url,
        maxLines: 1,
        overflow: TextOverflow.ellipsis,
        style: Theme.of(context).textTheme.bodySmall,
      ),
      trailing: IconButton(
        icon: Icon(isPlaying ? Icons.pause_rounded : Icons.play_arrow_rounded),
        onPressed: onToggle,
      ),
    );
  }
}

// ============================================================================
// Duplicate Detection Widget
// ============================================================================

class _DuplicateDetectionWidget extends ConsumerStatefulWidget {
  final String userId;
  final List<String> photoHashes;
  final List<String> audioHashes;

  const _DuplicateDetectionWidget({
    required this.userId,
    required this.photoHashes,
    required this.audioHashes,
  });

  @override
  ConsumerState<_DuplicateDetectionWidget> createState() =>
      _DuplicateDetectionWidgetState();
}

class _DuplicateDetectionWidgetState
    extends ConsumerState<_DuplicateDetectionWidget> {
  late Future<_DuplicateCheckResult> _duplicateCheckFuture;

  @override
  void initState() {
    super.initState();
    _duplicateCheckFuture = _checkDuplicates();
  }

  Future<_DuplicateCheckResult> _checkDuplicates() async {
    final service = ref.read(duplicateDetectionServiceProvider);

    try {
      final duplicatePhotos =
          widget.photoHashes.isNotEmpty
              ? await service.findDuplicatePhotos(
                widget.userId,
                widget.photoHashes,
              )
              : <DuplicateMatch>[];

      final duplicateAudio =
          widget.audioHashes.isNotEmpty
              ? await service.findDuplicateAudio(
                widget.userId,
                widget.audioHashes,
              )
              : <DuplicateMatch>[];

      final suspiciousPatterns = await service.detectSuspiciousPatterns(
        widget.userId,
      );

      return _DuplicateCheckResult(
        photoMatches: duplicatePhotos,
        audioMatches: duplicateAudio,
        suspiciousPatterns: suspiciousPatterns,
      );
    } catch (e) {
      debugPrint('Error checking duplicates: $e');
      return _DuplicateCheckResult(
        photoMatches: [],
        audioMatches: [],
        suspiciousPatterns: [],
        error: e.toString(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_DuplicateCheckResult>(
      future: _duplicateCheckFuture,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return const Padding(
            padding: EdgeInsets.all(8.0),
            child: SizedBox(height: 40, child: CircularProgressIndicator()),
          );
        }

        if (snapshot.hasError || snapshot.data == null) {
          return Padding(
            padding: const EdgeInsets.all(12.0),
            child: Text(
              'Error checking duplicates: ${snapshot.error}',
              style: const TextStyle(color: Colors.red, fontSize: 12),
            ),
          );
        }

        final result = snapshot.data!;

        // If no duplicates or suspicious patterns found, show nothing
        if (result.photoMatches.isEmpty &&
            result.audioMatches.isEmpty &&
            result.suspiciousPatterns.isEmpty) {
          return const Padding(
            padding: EdgeInsets.all(12.0),
            child: Text(
              '✅ No duplicates or suspicious patterns detected',
              style: TextStyle(color: Colors.green, fontSize: 12),
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Security Check',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 8),

            // Photo duplicates
            if (result.photoMatches.isNotEmpty)
              _buildDuplicateWarning(
                icon: '📸',
                title:
                    '⚠️ Duplicate Photos Detected (${result.photoMatches.length})',
                matches: result.photoMatches,
              ),

            // Audio duplicates
            if (result.audioMatches.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: _buildDuplicateWarning(
                  icon: '🎤',
                  title:
                      '⚠️ Duplicate Audio Detected (${result.audioMatches.length})',
                  matches: result.audioMatches,
                ),
              ),

            // Suspicious patterns
            if (result.suspiciousPatterns.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(top: 8.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    for (final pattern in result.suspiciousPatterns)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0),
                        child: Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color:
                                pattern.severity == 'high'
                                    ? Colors.red.shade50
                                    : Colors.orange.shade50,
                            border: Border.all(
                              color:
                                  pattern.severity == 'high'
                                      ? Colors.red
                                      : Colors.orange,
                            ),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                '${pattern.icon} ${pattern.description}',
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 12,
                                ),
                              ),
                              if (pattern.relatedUserIds.isNotEmpty)
                                Padding(
                                  padding: const EdgeInsets.only(top: 6.0),
                                  child: Text(
                                    'Related users: ${pattern.relatedUserIds.take(3).join(", ")}',
                                    style: const TextStyle(fontSize: 11),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                            ],
                          ),
                        ),
                      ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildDuplicateWarning({
    required String icon,
    required String title,
    required List<DuplicateMatch> matches,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.red.shade50,
        border: Border.all(color: Colors.red),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 12,
              color: Colors.red,
            ),
          ),
          const SizedBox(height: 6),
          ...matches.take(3).map((match) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 4.0),
              child: Text(
                '• ${match.userName} (ID: ${match.userId.substring(0, 6)}...)',
                style: const TextStyle(fontSize: 11),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            );
          }),
          if (matches.length > 3)
            Text(
              '• +${matches.length - 3} more',
              style: const TextStyle(fontSize: 11, fontStyle: FontStyle.italic),
            ),
        ],
      ),
    );
  }
}

class _DuplicateCheckResult {
  final List<DuplicateMatch> photoMatches;
  final List<DuplicateMatch> audioMatches;
  final List<SuspiciousPattern> suspiciousPatterns;
  final String? error;

  _DuplicateCheckResult({
    required this.photoMatches,
    required this.audioMatches,
    required this.suspiciousPatterns,
    this.error,
  });
}
