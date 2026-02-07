import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/models/user_model.dart';
import 'package:nexus_app_min_test/core/providers/user_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';

/// Provider for updating relationship status and handling profile archiving
final relationshipStatusUpdaterProvider =
    Provider<RelationshipStatusUpdater>((ref) {
  final fs = ref.watch(firestoreInstanceProvider);
  return RelationshipStatusUpdater(fs);
});

class RelationshipStatusUpdater {
  final FirebaseFirestore? _firestore;

  RelationshipStatusUpdater(this._firestore);

  /// Update user's relationship status and archive dating profile if transitioning to married
  Future<void> updateRelationshipStatus(
    String uid,
    String newStatus,
  ) async {
    if (_firestore == null) {
      throw Exception('Firestore not initialized');
    }

    final userRef = _firestore.collection('users').doc(uid);
    final batch = _firestore.batch();

    // Update user's relationship status in Nexus2Data
    batch.update(userRef, {
      'nexus2.relationshipStatus': newStatus,
    });

    // If transitioning to married, archive the dating profile
    if (newStatus.toLowerCase() == 'married') {
      final datingProfileRef = userRef.collection('dating').doc('profile');
      batch.update(datingProfileRef, {
        'isActive': false,
      });
    }

    // NOTE: Do NOT auto-reactivate dating profiles when switching from married.
    // User will be prompted to explicitly opt-in via showRelationshipStatusDialog().
    // This maintains consistency with the dating opt-in flow (not automatic).

    await batch.commit();
  }

  /// Check if user has an archived dating profile
  Future<bool> hasArchivedDatingProfile(String uid) async {
    if (_firestore == null) return false;

    try {
      final snapshot = await _firestore
          .collection('users')
          .doc(uid)
          .collection('dating')
          .doc('profile')
          .get();

      if (!snapshot.exists) return false;

      final isActive = snapshot.get('isActive') as bool? ?? true;
      return !isActive; // Return true if archived (isActive = false)
    } catch (e) {
      return false;
    }
  }
}
