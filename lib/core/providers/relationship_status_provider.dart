import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/models/user_model.dart';
import 'package:nexus_app_v2/core/providers/user_provider.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';

/// Provider for updating relationship status and handling profile archiving
final relationshipStatusUpdaterProvider = Provider<RelationshipStatusUpdater>((
  ref,
) {
  final fs = ref.watch(firestoreInstanceProvider);
  return RelationshipStatusUpdater(fs);
});

class RelationshipStatusUpdater {
  final FirebaseFirestore? _firestore;

  RelationshipStatusUpdater(this._firestore);

  /// Update user's relationship status and handle dating profile archiving/restoration + assessment archiving
  /// If transitioning from married to another status, sets dating profile to pending admin review
  Future<void> updateRelationshipStatus(
    String uid,
    String newStatus, {
    String? oldStatus,
  }) async {
    if (_firestore == null) {
      throw Exception('Firestore not initialized');
    }

    // ignore: avoid_print
    print(
      '[RelationshipStatusUpdater] UPDATING: uid=$uid, oldStatus=$oldStatus, newStatus=$newStatus',
    );

    final userRef = _firestore.collection('users').doc(uid);
    final batch = _firestore.batch();

    // DIAGNOSTIC: Log admin status BEFORE update
    try {
      final preUpdateDoc = await userRef.get();
      final preIsAdmin = preUpdateDoc.data()?['isAdmin'] as bool? ?? false;
      // ignore: avoid_print
      print('[RelationshipStatusUpdater] 📋 BEFORE UPDATE: isAdmin=$preIsAdmin');
    } catch (e) {
      // ignore: avoid_print
      print('[RelationshipStatusUpdater] Could not read isAdmin before update: $e');
    }

    // Update user's relationship status in BOTH v1 (nexus) and v2 (nexus2) fields
    // This ensures the change is read immediately, even for v1 accounts
    batch.update(userRef, {
      'nexus.relationshipStatus': newStatus,
      'nexus2.relationshipStatus': newStatus,
    });

    // ignore: avoid_print
    print(
      '[RelationshipStatusUpdater] Batch includes nexus=$newStatus, nexus2=$newStatus',
    );

    // Archive all existing assessment results in BOTH storage locations
    // This ensures they start fresh with assessments tailored to their new status

    // ⚠️  TEMPORARILY DISABLED TO DIAGNOSE DATA REVERSION
    // If archiving was causing the revert, disabling it should fix the issue

    // 1. Archive in legacy storage (assessmentResults/{uid}/results)
    // try {
    //   final resultsRef = userRef
    //       .collection('assessmentResults')
    //       .doc(uid)
    //       .collection('results');
    //   final snapshot =
    //       await resultsRef.where('archived', isEqualTo: false).get();

    //   // ignore: avoid_print
    //   print('[RelationshipStatusUpdater] Found ${snapshot.docs.length} unarchived legacy assessments to archive');

    //   for (final doc in snapshot.docs) {
    //     batch.update(doc.reference, {
    //       'archived': true,
    //       'archivedAt': FieldValue.serverTimestamp(),
    //       'archivedDueToStatusChange': true,
    //     });
    //   }
    // } catch (e) {
    //   // ignore: avoid_print
    //   print('[RelationshipStatusUpdater] ⚠️  Could not archive legacy assessments: $e');
    // }

    // 2. Archive in v2 storage (users/{uid}/assessments/{assessmentType})
    // try {
    //   final assessmentsRef = userRef.collection('assessments');
    //   final v2Snapshot =
    //       await assessmentsRef.where('archived', isEqualTo: false).get();

    //   // ignore: avoid_print
    //   print('[RelationshipStatusUpdater] Found ${v2Snapshot.docs.length} unarchived v2 assessments to archive');

    //   for (final doc in v2Snapshot.docs) {
    //     batch.update(doc.reference, {
    //       'archived': true,
    //       'archivedAt': FieldValue.serverTimestamp(),
    //       'archivedDueToStatusChange': true,
    //     });
    //   }
    // } catch (e) {
    //   // ignore: avoid_print
    //   print('[RelationshipStatusUpdater] ⚠️  Could not archive v2 assessments: $e');
    // }

    // If transitioning to married, archive the dating profile
    if (newStatus.toLowerCase() == 'married') {
      // ignore: avoid_print
      print(
        '[RelationshipStatusUpdater] Transitioning TO MARRIED: setting dating.optIn=false, isActive=false',
      );
      // Use set with merge instead of update, in case dating/profile doesn't exist yet
      final datingProfileRef = userRef.collection('dating').doc('profile');
      batch.set(datingProfileRef, {'isActive': false}, SetOptions(merge: true));

      // Also ensure dating opt-in is turned off for married users
      batch.update(userRef, {'dating.optIn': false});
    } else if (newStatus.toLowerCase() == 'never_married' ||
        newStatus.toLowerCase() == 'divorced' ||
        newStatus.toLowerCase() == 'widowed' ||
        newStatus.toLowerCase() == 'single') {
      // If transitioning FROM married to eligible status,
      // set dating profile to pending admin review AND reactivate if it was archived
      final isTransitioningFromMarried = oldStatus?.toLowerCase() == 'married';

      if (isTransitioningFromMarried) {
        // ignore: avoid_print
        print(
          '[RelationshipStatusUpdater] Transitioning FROM MARRIED to $newStatus: setting verification status to pending for admin review',
        );
        
        // Log what we're about to preserve before the update
        try {
          final currentDoc = await userRef.get();
          final currentData = currentDoc.data();
          final currentDating = currentData?['dating'] as Map?;
          final currentPhotos = currentData?['photos'] as List?;
          final currentAudio = currentData?['audioPrompts'] as List?;
          final datingPhotos = currentDating?['reviewPack']?['photoUrls'] as List?;
          final datingAudio = currentDating?['audioPrompts'] as List?;
          // ignore: avoid_print
          print(
            '[RelationshipStatusUpdater] 📸 BEFORE UPDATE - Root Photos: ${currentPhotos?.length ?? 0}, Root Audio: ${currentAudio?.length ?? 0}, Dating Photos: ${datingPhotos?.length ?? 0}, Dating Audio: ${datingAudio?.length ?? 0}',
          );
        } catch (e) {
          // ignore: avoid_print
          print('[RelationshipStatusUpdater] Could not log current state: $e');
        }
        
        // Reactivate archived dating profile (restore it)
        batch.update(userRef, {
          'dating.isActive': true,  // Reactivate archived profile
          'dating.optIn': true,
          'dating.verificationStatus': 'pending',
          'dating.verificationQueuedAt': FieldValue.serverTimestamp(),
        });
      } else {
        // If not transitioning from married, just restore dating opt-in
        // ignore: avoid_print
        print(
          '[RelationshipStatusUpdater] Transitioning TO SINGLE STATUS (not from married): setting dating.optIn=true',
        );
        batch.update(userRef, {'dating.optIn': true});
      }
    }

    // ignore: avoid_print
    print('[RelationshipStatusUpdater] About to call batch.commit()...');

    await batch.commit();

    // ignore: avoid_print
    print(
      '[RelationshipStatusUpdater] ✅ BATCH COMMIT COMPLETE - code is executing after commit',
    );

    // Read immediately after commit to verify
    try {
      // ignore: avoid_print
      print(
        '[RelationshipStatusUpdater] Starting immediate verification read...',
      );
      final verify0 = await userRef.get();
      final data0 = verify0.data();
      final nexus0 = (data0?['nexus'] as Map?)?.cast<String, dynamic>();
      final nexus20 = (data0?['nexus2'] as Map?)?.cast<String, dynamic>();
      final optIn0 = (data0?['dating'] as Map?)?.cast<String, dynamic>();
      final photos0 = (data0?['photos'] as List?);
      final audio0 = (data0?['audioPrompts'] as List?);
      // ignore: avoid_print
      print(
        '[RelationshipStatusUpdater] 🔍 IMMEDIATE (0ms): nexus=${nexus0?['relationshipStatus']}, nexus2=${nexus20?['relationshipStatus']}, optIn=${optIn0?['optIn']}',
      );
      // ignore: avoid_print
      print(
        '[RelationshipStatusUpdater] 📸 IMMEDIATE (0ms): Photos: ${photos0?.length ?? 0}, AudioPrompts: ${audio0?.length ?? 0}',
      );
    } catch (e) {
      // ignore: avoid_print
      print('[RelationshipStatusUpdater] ❌ Error on immediate read: $e');
    }

    // Wait 500ms and check
    await Future.delayed(const Duration(milliseconds: 500));
    try {
      final verify500 = await userRef.get();
      final data500 = verify500.data();
      final nexus500 = (data500?['nexus'] as Map?)?.cast<String, dynamic>();
      final nexus2500 = (data500?['nexus2'] as Map?)?.cast<String, dynamic>();
      final optIn500 = (data500?['dating'] as Map?)?.cast<String, dynamic>();
      final photos500 = (data500?['photos'] as List?);
      final audio500 = (data500?['audioPrompts'] as List?);
      // ignore: avoid_print
      print(
        '[RelationshipStatusUpdater] 🔍 AT 500ms: nexus=${nexus500?['relationshipStatus']}, nexus2=${nexus2500?['relationshipStatus']}, optIn=${optIn500?['optIn']}',
      );
      // ignore: avoid_print
      print(
        '[RelationshipStatusUpdater] 📸 AT 500ms: Photos: ${photos500?.length ?? 0}, AudioPrompts: ${audio500?.length ?? 0}',
      );
    } catch (e) {
      // ignore: avoid_print
      print('[RelationshipStatusUpdater] ❌ Error on 500ms read: $e');
    }

    // Wait another 1.5 seconds (total 2s) and check
    await Future.delayed(const Duration(milliseconds: 1500));
    try {
      final verify2s = await userRef.get();
      final data2s = verify2s.data();
      final nexus2s = (data2s?['nexus'] as Map?)?.cast<String, dynamic>();
      final nexus22s = (data2s?['nexus2'] as Map?)?.cast<String, dynamic>();
      final optIn2s = (data2s?['dating'] as Map?)?.cast<String, dynamic>();
      final photos2s = (data2s?['photos'] as List?);
      final audio2s = (data2s?['audioPrompts'] as List?);
      // ignore: avoid_print
      print(
        '[RelationshipStatusUpdater] 🔍 AT 2s: nexus=${nexus2s?['relationshipStatus']}, nexus2=${nexus22s?['relationshipStatus']}, optIn=${optIn2s?['optIn']}',
      );
      // ignore: avoid_print
      print(
        '[RelationshipStatusUpdater] 📸 AT 2s: Photos: ${photos2s?.length ?? 0}, AudioPrompts: ${audio2s?.length ?? 0}',
      );

      if (nexus2s?['relationshipStatus'] != newStatus) {
        // ignore: avoid_print
        print(
          '[RelationshipStatusUpdater] 🚨 CRITICAL: Data reverted! Expected $newStatus, got ${nexus2s?['relationshipStatus']}',
        );
      } else {
        // ignore: avoid_print
        print('[RelationshipStatusUpdater] ✅ Data persisted correctly');
      }
    } catch (e) {
      // ignore: avoid_print
      print('[RelationshipStatusUpdater] ❌ Error on 2s read: $e');
    }
  }

  /// Check if user has an archived dating profile
  Future<bool> hasArchivedDatingProfile(String uid) async {
    if (_firestore == null) return false;

    try {
      final snapshot =
          await _firestore
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
