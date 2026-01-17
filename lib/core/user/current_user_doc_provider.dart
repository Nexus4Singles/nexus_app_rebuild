import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/providers/auth_provider.dart';

/// Streams the signed-in user's Firestore document from `users/{uid}`.
/// - If signed out (or anonymous), yields null.
/// - Avoids transient nulls caused by bootstrap "ready" providers.
final currentUserDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  return ref.watch(authStateProvider.stream).asyncExpand((user) {
    if (user == null || user.isAnonymous) return Stream.value(null);

    return FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .map((doc) {
      if (!doc.exists) return null;
      return doc.data();
    });
  });
});
