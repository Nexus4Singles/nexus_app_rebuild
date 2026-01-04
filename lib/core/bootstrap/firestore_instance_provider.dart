import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'firebase_ready_provider.dart';

final firestoreInstanceProvider = Provider<FirebaseFirestore?>((ref) {
  if (kDebugMode) return null;

  final ready = ref.watch(firebaseReadyProvider);
  if (!ready) return null;
  return FirebaseFirestore.instance;
});
