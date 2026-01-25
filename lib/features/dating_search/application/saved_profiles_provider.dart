import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/providers/auth_provider.dart';

/// Provider for saved/bookmarked profiles
final savedProfilesProvider = StreamProvider<Set<String>>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) return Stream.value({});

  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
        if (!doc.exists) return <String>{};
        final data = doc.data();
        if (data == null) return <String>{};

        final savedList = data['savedProfiles'] as List?;
        if (savedList == null) return <String>{};

        return Set<String>.from(savedList.map((e) => e.toString()));
      });
});

/// Check if a specific profile is saved
final isProfileSavedProvider = Provider.family<bool, String>((ref, profileId) {
  final savedProfiles = ref.watch(savedProfilesProvider).valueOrNull ?? {};
  return savedProfiles.contains(profileId);
});

/// Notifier for managing saved profiles
final savedProfilesNotifierProvider = Provider<SavedProfilesNotifier>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return SavedProfilesNotifier(userId);
});

class SavedProfilesNotifier {
  final String? userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SavedProfilesNotifier(this.userId);

  /// Toggle save/unsave for a profile
  Future<void> toggleSave(String profileId) async {
    if (userId == null) return;

    final docRef = _firestore.collection('users').doc(userId);
    final doc = await docRef.get();

    if (!doc.exists) return;

    final data = doc.data();
    final savedList =
        (data?['savedProfiles'] as List?)?.map((e) => e.toString()).toList() ??
        [];

    if (savedList.contains(profileId)) {
      // Remove from saved
      savedList.remove(profileId);
    } else {
      // Add to saved
      savedList.add(profileId);
    }

    await docRef.update({'savedProfiles': savedList});
  }

  /// Save a profile
  Future<void> save(String profileId) async {
    if (userId == null) return;

    await _firestore.collection('users').doc(userId).update({
      'savedProfiles': FieldValue.arrayUnion([profileId]),
    });
  }

  /// Unsave a profile
  Future<void> unsave(String profileId) async {
    if (userId == null) return;

    await _firestore.collection('users').doc(userId).update({
      'savedProfiles': FieldValue.arrayRemove([profileId]),
    });
  }

  /// Remove a saved profile (alias for unsave)
  Future<void> removeSaved(String profileId) async {
    await unsave(profileId);
  }
}
