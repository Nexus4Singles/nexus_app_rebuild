import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:just_audio/just_audio.dart' as ja;

import 'package:nexus_app_v2/core/user/is_admin_provider.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_v2/core/services/media_service.dart';
import 'package:nexus_app_v2/core/providers/service_providers.dart';
import 'package:nexus_app_v2/core/services/duplicate_detection_service.dart';
import 'package:nexus_app_v2/core/theme/app_colors.dart';
import 'package:nexus_app_v2/core/notifications/notification_service.dart';
import 'package:nexus_app_v2/features/admin_review/application/admin_review_audio_url_utils.dart';

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
  bool _isPaused = false; // distinguishes paused vs stopped
  StreamSubscription<ja.PlayerState>? _playerStateSub;

  MediaService get _media => ref.read(mediaServiceProvider);

  @override
  void initState() {
    super.initState();
    // Listen for playback completion so icon resets when track ends naturally
    _playerStateSub = _media.onPlayerStateChanged.listen((state) {
      if (!mounted) return;
      if (state.processingState == ja.ProcessingState.completed) {
        setState(() {
          _isPlaying = false;
          _isPaused = false;
          _currentlyPlayingUrl = null;
        });
      }
    });
  }

  Future<void> _togglePlay(String url) async {
    try {
      // Tap the same track that is currently playing → pause it
      if (_currentlyPlayingUrl == url && _isPlaying) {
        await _media.pauseAudio();
        setState(() {
          _isPlaying = false;
          _isPaused = true;
        });
        return;
      }

      // Tap the same track that was paused → resume it
      if (_currentlyPlayingUrl == url && _isPaused) {
        await _media.resumeAudio();
        setState(() {
          _isPlaying = true;
          _isPaused = false;
        });
        return;
      }

      // Different track (or first play) → stop current, start new
      await _media.stopAudio();
      setState(() {
        _currentlyPlayingUrl = url;
        _isPlaying = true;
        _isPaused = false;
      });
      await _media.playAudioFromUrl(url);
    } catch (e) {
      print('[ADMIN_REVIEW] Audio playback error for $url: $e');
      setState(() {
        _currentlyPlayingUrl = null;
        _isPlaying = false;
        _isPaused = false;
      });
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Audio playback failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  void deactivate() {
    // Stop audio and reset UI state when screen is deactivated (navigating away)
    try {
      _media.stopAudio(); // Fire and forget, don't await in deactivate
    } catch (_) {}
    _currentlyPlayingUrl = null;
    _isPlaying = false;
    _isPaused = false;
    super.deactivate();
  }

  @override
  void dispose() {
    _playerStateSub?.cancel();
    // Extra safety: stop audio again in dispose
    try {
      _media.stopAudio(); // Fire and forget
    } catch (_) {}
    _currentlyPlayingUrl = null;
    _isPlaying = false;
    _isPaused = false;
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

        final audios = extractAdminReviewAudioUrls(data).take(3).toList();

        // Debug logging for admin troubleshooting
        print('[ADMIN_REVIEW] ====== AdminReviewDetailScreen LOADED ======');
        print('[ADMIN_REVIEW] reviewPack present: ${rp != null}');
        print('[ADMIN_REVIEW] photoUrls (${photos.length}): $photos');
        print('[ADMIN_REVIEW] audioUrls (${audios.length}): $audios');

        final name = (data['name'] ?? data['username'] ?? 'User').toString();
        // Age: try multiple sources in priority order:
        // 1. Root-level age (most reliable, always written by dating onboarding)
        // 2. dating.profile.age (nested, if profile exists)
        // 3. dating-level age (if it was written at dating root)
        // 4. Default to ? if none found
        final profile =
            (dating?['profile'] is Map) ? dating!['profile'] as Map : null;

        // Try to extract age from multiple sources
        String age;
        if (data['age'] != null) {
          // Try root-level first
          age =
              (data['age'] is int
                  ? data['age'].toString()
                  : int.tryParse(data['age'].toString())?.toString()) ??
              '?';
        } else if (profile != null && profile['age'] != null) {
          // Try dating.profile.age
          age =
              (profile['age'] is int
                  ? profile['age'].toString()
                  : int.tryParse(profile['age'].toString())?.toString()) ??
              '?';
        } else if (dating != null && dating['age'] != null) {
          // Try dating-level age (if it was written at dating root)
          age =
              (dating['age'] is int
                  ? dating['age'].toString()
                  : int.tryParse(dating['age'].toString())?.toString()) ??
              '?';
        } else {
          // Fallback to ?
          age = '?';
        }
        final email = (data['email'] ?? '').toString();

        Future<void> setStatus(String newStatus, {String? reason}) async {
          print(
            '[DEBUG] setStatus called: newStatus=$newStatus, userId=${widget.userId}, reason=$reason',
          );

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
            print(
              '[DEBUG] Approval flow triggered: newStatus==verified is TRUE, attempting to send notification',
            );
            payload['dating.verifiedAt'] = FieldValue.serverTimestamp();
            // After approval: delete review pack (no longer needed)
            payload['dating.reviewPack'] = FieldValue.delete();
            // Send notification to user
            try {
              print(
                '[DEBUG] About to call NotificationHelpers.sendProfileVerifiedNotification for userId=${widget.userId}',
              );
              await NotificationHelpers.sendProfileVerifiedNotification(
                userId: widget.userId,
              );
              print(
                '[DEBUG] NotificationHelpers.sendProfileVerifiedNotification completed successfully',
              );
            } catch (e, st) {
              print(
                '[DEBUG] CAUGHT EXCEPTION in sendProfileVerifiedNotification: $e',
              );
              print('[DEBUG] Stack trace: $st');
              print(
                '[ADMIN_REVIEW] Failed to send verification notification: $e',
              );
            }
          } else {
            print(
              '[DEBUG] Approval flow NOT triggered: newStatus=$newStatus (expected: verified)',
            );
          }

          if (newStatus == 'rejected') {
            print(
              '[DEBUG] Rejection flow triggered: newStatus==rejected is TRUE, attempting to send notification',
            );
            payload['dating.rejectedAt'] = FieldValue.serverTimestamp();
            if (reason != null && reason.trim().isNotEmpty) {
              payload['dating.rejectionReason'] = reason.trim();
            }
            // After rejection: delete review pack and clear profile data
            // (Account remains active so user can recreate profile)
            payload['dating.reviewPack'] = FieldValue.delete();
            payload['dating.profile'] = FieldValue.delete();
            // Clear root-level profile fields (used by search & display)
            payload['photos'] = FieldValue.delete();
            payload['audioPrompts'] = FieldValue.delete();
            payload['audioDurations'] = FieldValue.delete();
            payload['profileUrl'] = FieldValue.delete();
            // Clear dating-level audio fields
            payload['dating.audioPrompts'] = FieldValue.delete();
            // Reset completion flag so profile screen shows "Create Dating Profile" CTA
            payload['dating.profileCompleted'] = false;
            // Send notification to user
            try {
              print(
                '[DEBUG] About to call NotificationHelpers.sendProfileRejectedNotification for userId=${widget.userId}',
              );
              await NotificationHelpers.sendProfileRejectedNotification(
                userId: widget.userId,
                rejectionReason: reason,
              );
              print(
                '[DEBUG] NotificationHelpers.sendProfileRejectedNotification completed successfully',
              );
            } catch (e, st) {
              print(
                '[DEBUG] CAUGHT EXCEPTION in sendProfileRejectedNotification: $e',
              );
              print('[DEBUG] Stack trace: $st');
              print('[ADMIN_REVIEW] Failed to send rejection notification: $e');
            }
          }

          print('[DEBUG] About to update Firestore user document with payload');
          print('[DEBUG] Payload keys: ${payload.keys.toList()}');
          print('[DEBUG] widget.userId: ${widget.userId}');

          try {
            await fs.collection('users').doc(widget.userId).update(payload);
            print(
              '[DEBUG] Firestore update completed successfully for user ${widget.userId}',
            );
          } catch (e, st) {
            print(
              '[ERROR] FIRESTORE UPDATE FAILED for user ${widget.userId}: $e',
            );
            print('[ERROR] Stack trace: $st');
            print('[ERROR] Payload was: $payload');

            // Re-throw so the caller can handle the error
            rethrow;
          }

          // If rejecting, also clear the v2 datingProfiles/{uid} doc to force profile recreation
          if (newStatus == 'rejected') {
            try {
              print(
                '[DEBUG] Clearing v2 profile: datingProfiles/${widget.userId}',
              );
              await fs.collection('datingProfiles').doc(widget.userId).delete();
              print('[DEBUG] v2 profile cleared successfully');
            } catch (e) {
              print(
                '[DEBUG] Note: v2 profile clear failed (may not exist for v1 users): $e',
              );
              // Don't fail the rejection if v2 profile doesn't exist
            }
          }
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

        return Scaffold(
          appBar: AppBar(title: Text('Review: $name, $age')),
          body: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            child: ListView(
              children: [
                Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Email display
                    if (email.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Row(
                          children: [
                            const Text(
                              'Email: ',
                              style: TextStyle(
                                fontWeight: FontWeight.w600,
                                fontSize: 14,
                              ),
                            ),
                            Expanded(
                              child: Text(
                                email,
                                style: const TextStyle(fontSize: 14),
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                      ),
                    const SizedBox(height: 8),

                    // User Details Section
                    Builder(
                      builder: (_) {
                        final profileData =
                            (dating?['profile'] is Map)
                                ? dating!['profile'] as Map
                                : null;
                        final city = profileData?['city']?.toString() ?? 'N/A';
                        final countryOfResidence =
                            dating?['countryOfResidence']?.toString() ?? 'N/A';
                        final nationality =
                            profileData?['nationality']?.toString() ?? 'N/A';
                        final profession =
                            profileData?['profession']?.toString() ?? 'N/A';
                        final churchName =
                            profileData?['churchName']?.toString() ?? 'N/A';

                        return Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Text(
                                  'City: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    city,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Country of Residence: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    countryOfResidence,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Nationality: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    nationality,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Profession: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    profession,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Row(
                              children: [
                                const Text(
                                  'Church Name: ',
                                  style: TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14,
                                  ),
                                ),
                                Expanded(
                                  child: Text(
                                    churchName,
                                    style: const TextStyle(fontSize: 14),
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                          ],
                        );
                      },
                    ),
                    const SizedBox(height: 4),
                    // Account disable status (only if disabled)
                    Builder(
                      builder: (_) {
                        final account =
                            (data['account'] is Map)
                                ? data['account'] as Map
                                : null;
                        final disabled =
                            (account?['disabled'] == true) ||
                            (account?['isDisabled'] == true);

                        // Only show if account is actually disabled
                        if (!disabled) return const SizedBox.shrink();

                        final disabledBy = account?['disabledBy']?.toString();
                        final disabledReason =
                            account?['disabledReason']?.toString();

                        final lines = <String>['⛔ Account Disabled'];
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

                    const SizedBox(height: 4),

                    // NOTE: Disable and Enable account buttons have been commented out
                    // and replaced with user details display above
                    /*
                    Row(
                      children: [
                        Expanded(
                          child: OutlinedButton.icon(
                            onPressed: () async {
                              final reason = await askDisableReason(
                                enabling: false,
                              );
                              if (reason == null) return;
                              try {
                                await setAccountDisabled(true, reason: reason);
                                if (context.mounted)
                                  Navigator.of(context).pop();
                              } catch (e) {
                                print('[ERROR] Account disable failed: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Disable failed: $e'),
                                      duration: const Duration(seconds: 5),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
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
                              try {
                                await setAccountDisabled(false);
                                if (context.mounted)
                                  Navigator.of(context).pop();
                              } catch (e) {
                                print('[ERROR] Account enable failed: $e');
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                    SnackBar(
                                      content: Text('Enable failed: $e'),
                                      duration: const Duration(seconds: 5),
                                      backgroundColor: Colors.red,
                                    ),
                                  );
                                }
                              }
                            },
                            icon: const Icon(Icons.check_circle_rounded),
                            label: const Text('Enable account'),
                          ),
                        ),
                      ],
                    ),
                    */
                    const SizedBox(height: 8),

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
                const SizedBox(height: 10),

                const Text(
                  'Photos (review pack)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
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
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return SizedBox(
                                  width: 150,
                                  height: 150,
                                  child: Center(
                                    child: CircularProgressIndicator(
                                      value:
                                          progress.expectedTotalBytes != null
                                              ? progress.cumulativeBytesLoaded /
                                                  progress.expectedTotalBytes!
                                              : null,
                                    ),
                                  ),
                                );
                              },
                              errorBuilder: (_, error, __) {
                                print(
                                  '[ADMIN_REVIEW] Photo load error for $url: $error',
                                );
                                return Container(
                                  width: 150,
                                  height: 150,
                                  decoration: BoxDecoration(
                                    color: Colors.grey[200],
                                    borderRadius: BorderRadius.circular(12),
                                    border: Border.all(
                                      color: AppColors.error.withOpacity(0.5),
                                    ),
                                  ),
                                  child: const Column(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.broken_image_rounded,
                                        color: AppColors.error,
                                        size: 32,
                                      ),
                                      SizedBox(height: 4),
                                      Text(
                                        'Load failed',
                                        style: TextStyle(
                                          fontSize: 11,
                                          color: AppColors.error,
                                        ),
                                      ),
                                    ],
                                  ),
                                );
                              },
                            ),
                          ),
                        ),
                    ],
                  ),

                const SizedBox(height: 12),
                const Text(
                  'Audio (review pack)',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
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

                const SizedBox(height: 12),
                Row(
                  children: [
                    Expanded(
                      child: ElevatedButton.icon(
                        onPressed: () async {
                          print('[ROOT] Approve button onPressed triggered');
                          print('[ROOT] About to call setStatus(verified)');
                          try {
                            await setStatus('verified');
                            print('[ROOT] setStatus completed, about to pop');
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            print('[ERROR] Approval failed: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Approval failed: $e'),
                                  duration: const Duration(seconds: 5),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
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
                          try {
                            await setStatus('rejected', reason: reason);
                            if (context.mounted) Navigator.of(context).pop();
                          } catch (e) {
                            print('[ERROR] Rejection failed: $e');
                            if (context.mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                SnackBar(
                                  content: Text('Rejection failed: $e'),
                                  duration: const Duration(seconds: 5),
                                  backgroundColor: Colors.red,
                                ),
                              );
                            }
                          }
                        },
                        icon: const Icon(Icons.block_rounded),
                        label: const Text('Reject'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),

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
                const SizedBox(height: 8),
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
