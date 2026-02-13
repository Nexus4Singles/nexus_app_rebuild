import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';

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
  return SavedProfilesNotifier(userId, ref);
});

class SavedProfilesNotifier {
  final String? userId;
  final Ref _ref;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  SavedProfilesNotifier(this.userId, this._ref);

  /// Toggle save/unsave for a profile with optimistic update
  Future<void> toggleSave(String profileId) async {
    if (userId == null) return;

    // OPTIMISTIC UPDATE: Get current saved state
    final currentSaved = _ref.read(savedProfilesProvider).valueOrNull ?? {};
    final willBeSaved = !currentSaved.contains(profileId);

    // Update Firestore in background (no await - fire and forget for instant UX)
    final docRef = _firestore.collection('users').doc(userId);
    
    if (willBeSaved) {
      // Add to saved
      docRef.update({
        'savedProfiles': FieldValue.arrayUnion([profileId]),
      }).catchError((e) {
        print('[SavedProfilesNotifier] Error saving profile: $e');
      });
    } else {
      // Remove from saved
      docRef.update({
        'savedProfiles': FieldValue.arrayRemove([profileId]),
      }).catchError((e) {
        print('[SavedProfilesNotifier] Error unsaving profile: $e');
      });
    }
    
    // UI updates automatically via StreamProvider watching Firestore
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
