import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../bootstrap/firebase_ready_provider.dart';
import '../constants/app_constants.dart';

final userRelationshipStatusProvider = StreamProvider<RelationshipStatus?>((
  ref,
) {
  final authAsync = ref.watch(authStateProvider);
  final ready = ref.watch(firebaseReadyProvider);

  final uid = authAsync.maybeWhen(data: (a) => a.user?.uid, orElse: () => null);

  if (!ready || uid == null) {
    return Stream.value(null);
  }

  final fs = FirebaseFirestore.instance;

  return fs.collection('users').doc(uid).snapshots().map((doc) {
    final data = doc.data();
    if (data == null) return null;

    final nexus = (data['nexus'] as Map?)?.cast<String, dynamic>();
    final nexus2 = (data['nexus2'] as Map?)?.cast<String, dynamic>();

    // v2 canonical field (merge-safe, namespaced). nexus2 is temporary fallback.
    final raw =
        (nexus?['relationshipStatus'] ??
            nexus2?['relationshipStatus'] ??
            data['relationshipStatus']);

    if (raw is String && raw.trim().isNotEmpty) {
      final v = raw.trim();

      // Prefer v2 stored keys
      if (v == 'single_never_married')
        return RelationshipStatus.singleNeverMarried;
      if (v == 'married') return RelationshipStatus.married;
      if (v == 'divorced') return RelationshipStatus.divorced;
      if (v == 'widowed') return RelationshipStatus.widowed;

      // Backward compatibility: if someone stored enum names
      try {
        return RelationshipStatus.values.byName(v);
      } catch (_) {
        return null;
      }
    }
    return null;
  });
});
