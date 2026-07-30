import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';

/// Model for a dismissed profile entry
class DismissedProfileEntry {
  final String profileId;
  final DateTime dismissedAt;

  DismissedProfileEntry({required this.profileId, required this.dismissedAt});

  factory DismissedProfileEntry.fromMap(Map<String, dynamic> map) {
    return DismissedProfileEntry(
      profileId: map['profileId'] as String,
      dismissedAt: DateTime.parse(map['dismissedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'profileId': profileId,
      'dismissedAt': dismissedAt.toIso8601String(),
    };
  }

  /// Check if this dismissal has expired (7 days)
  bool isExpired() {
    final now = DateTime.now();
    final difference = now.difference(dismissedAt);
    return difference.inDays >= 7;
  }
}

/// Provider to STREAM list of active dismissed profiles (not expired) in real-time
///
/// ✅ NOW: StreamProvider - listens to Firestore document changes
/// ✅ Previously: FutureProvider - read-once, could show stale data
///
/// Real-time updates ensure that recent dismissals are immediately reflected
/// and don't appear in next search results
final dismissedProfilesProvider = StreamProvider<List<String>>((ref) async* {
  // Watch auth state to invalidate on user changes
  final authAsync = ref.watch(authStateProvider);

  if (!authAsync.hasValue) {
    yield [];
    return;
  }

  final authState = authAsync.value;
  final uid = authState?.uid;

  if (uid == null || authState == null) {
    yield [];
    return;
  }

  final fs = ref.watch(firestoreInstanceProvider);
  if (fs == null) {
    yield [];
    return;
  }

  try {
    print(
      '[dismissedProfilesProvider] Setting up real-time listener for uid=$uid',
    );

    // Listen to real-time changes from Firestore
    await for (final doc
        in fs
            .collection('users')
            .doc(uid)
            .collection('dating')
            .doc('dismissedProfiles')
            .snapshots()) {
      try {
        if (!doc.exists) {
          print('[dismissedProfilesProvider] ✓ No dismissed profiles yet');
          yield [];
          continue;
        }

        final data = doc.data() ?? {};
        final entries =
            (data['entries'] as List<dynamic>?)
                ?.map(
                  (e) =>
                      DismissedProfileEntry.fromMap(e as Map<String, dynamic>),
                )
                .toList() ??
            [];

        // Filter out expired dismissals and return only active profile IDs
        final activeDismissed =
            entries
                .where((e) => !e.isExpired())
                .map((e) => e.profileId)
                .toList();

        print(
          '[dismissedProfilesProvider] ✓ Real-time update: ${activeDismissed.length} active dismissed profiles',
        );
        yield activeDismissed;
      } catch (parseError) {
        print(
          '[dismissedProfilesProvider] Error parsing dismissed profiles: $parseError',
        );
        yield [];
      }
    }
  } catch (e) {
    print('[dismissedProfilesProvider] ✗ Error setting up listener: $e');
    yield [];
  }
});

/// Notifier to manage dismissed profiles
class DismissedProfilesNotifier
    extends StateNotifier<AsyncValue<List<String>>> {
  final FirebaseFirestore? _fs;

  DismissedProfilesNotifier(this._fs) : super(const AsyncValue.loading());

  /// Add a profile to dismissed list
  Future<void> dismissProfile(String profileId) async {
    if (_fs == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final docRef = _fs
          .collection('users')
          .doc(uid)
          .collection('dating')
          .doc('dismissedProfiles');

      final doc = await docRef.get();
      final entries =
          (doc.data()?['entries'] as List<dynamic>?)
              ?.map(
                (e) => DismissedProfileEntry.fromMap(e as Map<String, dynamic>),
              )
              .toList() ??
          [];

      // Add new entry
      entries.add(
        DismissedProfileEntry(
          profileId: profileId,
          dismissedAt: DateTime.now(),
        ),
      );

      // Save back to Firestore
      await docRef.set({
        'entries': entries.map((e) => e.toMap()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      // Update state
      final activeIds =
          entries.where((e) => !e.isExpired()).map((e) => e.profileId).toList();
      state = AsyncValue.data(activeIds);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Remove a profile from dismissed list (clear history)
  Future<void> undismissProfile(String profileId) async {
    if (_fs == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      final docRef = _fs
          .collection('users')
          .doc(uid)
          .collection('dating')
          .doc('dismissedProfiles');

      final doc = await docRef.get();
      var entries =
          (doc.data()?['entries'] as List<dynamic>?)
              ?.map(
                (e) => DismissedProfileEntry.fromMap(e as Map<String, dynamic>),
              )
              .toList() ??
          [];

      // Remove the entry
      entries.removeWhere((e) => e.profileId == profileId);

      // Save back to Firestore
      await docRef.set({
        'entries': entries.map((e) => e.toMap()).toList(),
        'lastUpdated': DateTime.now().toIso8601String(),
      });

      // Update state
      final activeIds =
          entries.where((e) => !e.isExpired()).map((e) => e.profileId).toList();
      state = AsyncValue.data(activeIds);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }

  /// Clear all dismissed profiles history
  Future<void> clearHistory() async {
    if (_fs == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await _fs
          .collection('users')
          .doc(uid)
          .collection('dating')
          .doc('dismissedProfiles')
          .delete();

      state = const AsyncValue.data([]);
    } catch (e, st) {
      state = AsyncValue.error(e, st);
    }
  }
}

/// StateNotifier provider for managing dismissed profiles
final dismissedProfilesNotifierProvider =
    StateNotifierProvider<DismissedProfilesNotifier, AsyncValue<List<String>>>((
      ref,
    ) {
      final fs = ref.watch(firestoreInstanceProvider);
      return DismissedProfilesNotifier(fs);
    });
