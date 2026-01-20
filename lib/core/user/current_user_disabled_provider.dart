import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_min_test/core/providers/auth_provider.dart';

/// Firestore-authoritative disabled flag for the CURRENT user.
///
/// We intentionally read raw Firestore data (not UserModel) to avoid coupling
/// disable enforcement to model migrations.
final currentUserDisabledProvider = StreamProvider<bool>((ref) {
  final ready = ref.watch(firebaseReadyProvider);
  final fs = ref.watch(firestoreInstanceProvider);
  final uid = ref.watch(currentUserIdProvider);

  if (!ready || fs == null || uid == null) {
    return Stream<bool>.value(false);
  }

  bool isDisabledFromMap(Map<String, dynamic>? data) {
    if (data == null) return false;

    // Preferred v2 shape (recommended): account.disabled == true
    final account = data['account'];
    if (account is Map<String, dynamic>) {
      final disabled = account['disabled'];
      if (disabled == true) return true;
      final status = account['status']?.toString().toLowerCase();
      if (status == 'disabled') return true;
    }

    // Legacy / fallback heuristics seen during migration
    final accountStatus = data['accountStatus']?.toString().toLowerCase();
    if (accountStatus == 'disabled') return true;

    final status = data['status']?.toString().toLowerCase();
    if (status == 'disabled') return true;

    final disabled = data['disabled'];
    if (disabled == true) return true;

    return false;
  }

  return fs.collection('users').doc(uid).snapshots().map((snap) {
    return isDisabledFromMap(snap.data());
  });
});
