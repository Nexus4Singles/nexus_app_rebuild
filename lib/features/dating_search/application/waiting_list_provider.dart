import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';

/// Stats about the UK waiting list - gender distribution and counts
class WaitingListStats {
  final int? maleCount;
  final int? femaleCount;
  final int totalCount;
  final DateTime? lastUpdated;

  WaitingListStats({
    this.maleCount,
    this.femaleCount,
    required this.totalCount,
    this.lastUpdated,
  });
}

/// Provider for UK waiting list stats (real-time)
final ukWaitingListStatsProvider = StreamProvider<WaitingListStats?>((
  ref,
) async* {
  final fs = ref.watch(firestoreInstanceProvider);
  if (fs == null) {
    yield null;
    return;
  }

  try {
    // Stream changes to the waiting list stats document
    await for (final doc
        in fs
            .collection('config')
            .doc('waitingListStats')
            .collection('countries')
            .doc('United Kingdom')
            .snapshots()) {
      if (!doc.exists) {
        yield WaitingListStats(totalCount: 0);
        continue;
      }

      final data = doc.data() ?? {};
      final stats = WaitingListStats(
        maleCount: data['maleCount'] as int?,
        femaleCount: data['femaleCount'] as int?,
        totalCount: (data['totalCount'] as int?) ?? 0,
        lastUpdated:
            data['lastUpdated'] != null
                ? DateTime.parse(data['lastUpdated'] as String)
                : null,
      );

      yield stats;
    }
  } catch (e) {
    print('[WaitingListProvider] Error streaming stats: $e');
    yield null;
  }
});

/// Notifier for managing waiting list operations
class WaitingListNotifier extends StateNotifier<AsyncValue<bool>> {
  final FirebaseFirestore? _fs;

  WaitingListNotifier(this._fs) : super(const AsyncValue.loading());

  /// Join the UK waiting list
  Future<void> joinWaitingList(String uid) async {
    if (_fs == null) {
      throw StateError('Firestore not available');
    }

    try {
      state = const AsyncValue.loading();

      final now = DateTime.now();

      // Get user document to retrieve gender
      final userDoc = await _fs.collection('users').doc(uid).get();
      final gender = userDoc['gender'] as String? ?? 'unknown';

      // Add to waiting list collection
      await _fs
          .collection('waitingList')
          .doc('countries')
          .collection('United Kingdom')
          .doc(uid)
          .set({
            'uid': uid,
            'gender': gender.toLowerCase(),
            'joinedAt': now.toIso8601String(),
            'notificationEnabled': true,
            'referralCode': uid.substring(0, 8).toUpperCase(),
          });

      // Update user's dating profile to mark them in waiting list
      await _fs
          .collection('users')
          .doc(uid)
          .collection('dating')
          .doc('profile')
          .update({
            'inWaitingList': true,
            'waitingListJoinedAt': now.toIso8601String(),
          });

      // Increment the waiting list stats
      await _updateWaitingListStats(gender.toLowerCase());

      state = const AsyncValue.data(true);
    } catch (e) {
      print('[WaitingListNotifier] Error joining waiting list: $e');
      state = AsyncValue.error(e, StackTrace.current);
      rethrow;
    }
  }

  /// Update the gender-segregated stats for waiting list
  Future<void> _updateWaitingListStats(String gender) async {
    if (_fs == null) return;

    try {
      final statsDoc = _fs
          .collection('config')
          .doc('waitingListStats')
          .collection('countries')
          .doc('United Kingdom');

      // Use transaction to ensure consistency
      await _fs.runTransaction((transaction) async {
        final currentDoc = await transaction.get(statsDoc);
        int maleCount = 0;
        int femaleCount = 0;
        int totalCount = 0;

        if (currentDoc.exists) {
          final data = currentDoc.data() ?? {};
          maleCount = data['maleCount'] as int? ?? 0;
          femaleCount = data['femaleCount'] as int? ?? 0;
          totalCount = data['totalCount'] as int? ?? 0;
        }

        // Increment appropriate counter
        if (gender == 'male') {
          maleCount++;
        } else if (gender == 'female') {
          femaleCount++;
        }
        totalCount = maleCount + femaleCount;

        transaction.set(statsDoc, {
          'maleCount': maleCount,
          'femaleCount': femaleCount,
          'totalCount': totalCount,
          'lastUpdated': DateTime.now().toIso8601String(),
          'country': 'United Kingdom',
        });
      });
    } catch (e) {
      print('[WaitingListNotifier] Error updating stats: $e');
    }
  }

  /// Check if a user has already joined the waiting list
  Future<bool> isUserInWaitingList(String uid) async {
    if (_fs == null) return false;

    try {
      final doc =
          await _fs
              .collection('waitingList')
              .doc('countries')
              .collection('United Kingdom')
              .doc(uid)
              .get();

      return doc.exists;
    } catch (e) {
      print('[WaitingListNotifier] Error checking waiting list status: $e');
      return false;
    }
  }
}

/// Provider for waiting list notifier
final waitingListNotifierProvider =
    StateNotifierProvider<WaitingListNotifier, AsyncValue<bool>>((ref) {
      final fs = ref.watch(firestoreInstanceProvider);
      return WaitingListNotifier(fs);
    });

/// Provider to check if current user is in waiting list
final isUserInWaitingListProvider = FutureProvider.family<bool, String>((
  ref,
  uid,
) async {
  return ref
      .read(waitingListNotifierProvider.notifier)
      .isUserInWaitingList(uid);
});
