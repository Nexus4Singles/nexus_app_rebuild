import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'firebase_ready_provider.dart';

final firestoreInstanceProvider = Provider<FirebaseFirestore?>((ref) {
  // In debug we still want Firestore reads for search/compatibility, otherwise
  // downstream providers resolve as "unknown" and features appear broken.
  if (kDebugMode) return FirebaseFirestore.instance;

  final ready = ref.watch(firebaseReadyProvider);
  if (!ready) return null;
  return FirebaseFirestore.instance;
});
