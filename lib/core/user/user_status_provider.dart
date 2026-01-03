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

    final raw = data['relationshipStatus'];
    if (raw is String && raw.isNotEmpty) {
      try {
        return RelationshipStatus.values.byName(raw);
      } catch (_) {
        return null;
      }
    }
    return null;
  });
});
