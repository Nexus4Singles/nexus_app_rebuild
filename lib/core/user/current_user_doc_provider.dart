import 'dart:async';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:nexus_app_min_test/core/providers/auth_provider.dart';

/// Streams the signed-in user's Firestore document from `users/{uid}`.
///
/// IMPORTANT:
/// We must cancel the previous Firestore subscription when auth user changes
/// (logout -> login), otherwise old listeners can keep running and throw.
final currentUserDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final controller = StreamController<Map<String, dynamic>?>.broadcast();

  StreamSubscription<User?>? authSub;
  StreamSubscription<DocumentSnapshot<Map<String, dynamic>>>? docSub;

  void attachUser(User? user) {
    // Cancel any previous doc listener
    docSub?.cancel();
    docSub = null;

    if (user == null || user.isAnonymous) {
      controller.add(null);
      return;
    }

    docSub = FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .snapshots()
        .listen((doc) {
          if (!doc.exists) {
            controller.add(null);
            return;
          }
          controller.add(doc.data());
        }, onError: controller.addError);
  }

  authSub = ref
      .watch(authStateProvider.stream)
      .listen(attachUser, onError: controller.addError);

  ref.onDispose(() async {
    await docSub?.cancel();
    await authSub?.cancel();
    await controller.close();
  });

  return controller.stream;
});
