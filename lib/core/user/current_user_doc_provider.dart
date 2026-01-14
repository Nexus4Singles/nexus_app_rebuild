import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';

import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';

final currentUserDocProvider = StreamProvider<Map<String, dynamic>?>((ref) {
  final firebaseReady = ref.watch(firebaseReadyProvider);
  if (!firebaseReady) return Stream.value(null);

  final uid = FirebaseAuth.instance.currentUser?.uid;
  if (uid == null) return Stream.value(null);

  final fs = ref.watch(firestoreInstanceProvider);
  if (fs == null) return Stream.value(null);

  return fs.collection('users').doc(uid).snapshots().map((doc) {
    if (!doc.exists) return null;
    return doc.data();
  });
});
