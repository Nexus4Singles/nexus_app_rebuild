import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';

class CompatibilityQuizService {
  final FirebaseFirestore? _firestore;
  CompatibilityQuizService(this._firestore);

  FirebaseFirestore get _fs =>
      _firestore ?? (throw StateError('Firestore not ready'));

  Future<void> saveQuiz({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _fs.collection('users').doc(uid).set({
      'compatibility': data,
      'compatibilitySetted': true,
    }, SetOptions(merge: true));
  }

  Future<Map<String, dynamic>?> loadQuiz(String uid) async {
    final doc = await _fs.collection('users').doc(uid).get();
    final m = doc.data();
    if (m == null) return null;
    return m['compatibility'] as Map<String, dynamic>?;
  }

  Future<bool> isQuizComplete(String uid) async {
    final doc = await _fs.collection('users').doc(uid).get();
    final m = doc.data();
    if (m == null) return false;
    return (m['compatibilitySetted'] == true);
  }
}

final compatibilityQuizServiceProvider = Provider<CompatibilityQuizService>((
  ref,
) {
  final ready = ref.watch(firebaseReadyProvider);
  final fs = ready ? ref.watch(firestoreInstanceProvider) : null;
  return CompatibilityQuizService(fs);
});
