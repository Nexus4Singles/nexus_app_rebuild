import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_min_test/core/providers/auth_provider.dart';

class AdminReviewItem {
  final String uid;
  final String name;
  final String? gender;
  final String? relationshipStatus;
  final DateTime? queuedAt;
  final List<String> photoUrls;
  final List<String> audioUrls;

  const AdminReviewItem({
    required this.uid,
    required this.name,
    required this.photoUrls,
    required this.audioUrls,
    this.gender,
    this.relationshipStatus,
    this.queuedAt,
  });
}

DateTime? _asDate(dynamic v) {
  if (v == null) return null;
  try {
    final toDate = v.toDate;
    if (toDate is Function) return toDate() as DateTime;
  } catch (_) {}
  if (v is DateTime) return v;
  if (v is int) return DateTime.fromMillisecondsSinceEpoch(v);
  if (v is String) return DateTime.tryParse(v);
  return null;
}

// Real-time stream for pending reviews - updates automatically when other admins approve/reject
// Excludes the current admin user from reviewing their own profile
final pendingReviewUsersProvider = StreamProvider<List<AdminReviewItem>>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  if (!firebaseReady) return Stream.value(const []);

  final fs = ref.watch(firestoreInstanceProvider);
  if (fs == null) return Stream.value(const []);

  // Get current user ID to exclude from review queue
  final currentUserId = ref.watch(currentUserIdProvider);

  // Real-time Firestore snapshots - updates when any admin approves/rejects
  final stream =
      fs
          .collection('users')
          .where('dating.verificationStatus', isEqualTo: 'pending')
          .orderBy('dating.verificationQueuedAt', descending: true)
          .limit(200)
          .snapshots();

  return stream.map((snapshot) {
    return snapshot.docs
        .where(
          (d) => d.id != currentUserId,
        ) // Exclude current admin from reviewing themselves
        .map((d) {
          final data = d.data();
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

          // Stored mirrors
          final gender =
              dating?['gender']?.toString() ?? data['gender']?.toString();
          final rel = dating?['relationshipStatus']?.toString();

          final queuedAt = _asDate(dating?['verificationQueuedAt']);

          return AdminReviewItem(
            uid: d.id,
            name: name,
            gender: gender,
            relationshipStatus: rel,
            queuedAt: queuedAt,
            photoUrls: photos,
            audioUrls: audios,
          );
        })
        .toList();
  });
});
