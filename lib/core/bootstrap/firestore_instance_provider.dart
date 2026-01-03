import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'firebase_ready_provider.dart';

final firestoreInstanceProvider = Provider<FirebaseFirestore?>((ref) {
  final ready = ref.watch(firebaseReadyProvider);
  if (!ready) return null;
  return FirebaseFirestore.instance;
});
