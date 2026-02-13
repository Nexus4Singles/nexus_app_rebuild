import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/models/user_model.dart';
import 'package:nexus_app_v2/core/providers/user_provider.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';

/// Provider for updating relationship status and handling profile archiving
final relationshipStatusUpdaterProvider =
    Provider<RelationshipStatusUpdater>((ref) {
  final fs = ref.watch(firestoreInstanceProvider);
  return RelationshipStatusUpdater(fs);
});

class RelationshipStatusUpdater {
  final FirebaseFirestore? _firestore;

  RelationshipStatusUpdater(this._firestore);

  /// Update user's relationship status and handle dating profile archiving/restoration + assessment archiving
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

    // Archive all existing assessment results in BOTH storage locations
    // This ensures they start fresh with assessments tailored to their new status
    
    // 1. Archive in legacy storage (assessmentResults/{uid}/results)
    try {
      final resultsRef = userRef.collection('assessmentResults').doc(uid).collection('results');
      final snapshot = await resultsRef.where('archived', isEqualTo: false).get();
      
      for (final doc in snapshot.docs) {
        batch.update(doc.reference, {
          'archived': true,
          'archivedAt': FieldValue.serverTimestamp(),
          'archivedDueToStatusChange': true,
        });
      }
    } catch (e) {
      // Collection might not exist yet - continue
    }

    // 2. Archive in v2 storage (users/{uid}/assessments/{assessmentType})
    try {
      final assessmentsRef = userRef.collection('assessments');
      final v2Snapshot = await assessmentsRef.where('archived', isEqualTo: false).get();
      
      for (final doc in v2Snapshot.docs) {
        batch.update(doc.reference, {
          'archived': true,
          'archivedAt': FieldValue.serverTimestamp(),
          'archivedDueToStatusChange': true,
        });
      }
    } catch (e) {
      // Collection might not exist yet - continue
    }

    // If transitioning to married, archive the dating profile
    if (newStatus.toLowerCase() == 'married') {
      final datingProfileRef = userRef.collection('dating').doc('profile');
      batch.update(datingProfileRef, {
        'isActive': false,
      });
      
      // Also ensure dating opt-in is turned off for married users
      batch.update(userRef, {
        'dating.optIn': false,
      });
    }

    // If transitioning FROM married to eligible status (never_married, divorced, widowed),
    // ensure dating opt-in is restored but keep profile archived until user explicitly reactivates
    final eligibleStatuses = ['never_married', 'divorced', 'widowed', 'single'];
    if (eligibleStatuses.contains(newStatus.toLowerCase())) {
      batch.update(userRef, {
        'dating.optIn': true,
      });
      // NOTE: Keep dating profile archived (isActive: false) 
      // User will see "create dating profile" card and can choose to reactivate
    }

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
