import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';

class CompatibilityQuizService {
  final FirebaseFirestore? _firestore;
  CompatibilityQuizService(this._firestore);

  FirebaseFirestore get _fs => _firestore ?? FirebaseFirestore.instance;

  Future<void> saveQuiz({
    required String uid,
    required Map<String, dynamic> data,
  }) async {
    await _fs.collection('users').doc(uid).set({
      'compatibility': data,
      'compatibilitySetted': true,
      'compatibility_setted': true,
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

    // v2 flag
    if (m['compatibilitySetted'] == true) return true;

    // v1 legacy compatibility stored as a map
    final compat = m['compatibility'];
    if (compat is Map && compat.isNotEmpty) return true;

    // v1 legacy answers (common shapes)
    final answers = m['compatibilityAnswers'];
    if (answers is List && answers.isNotEmpty) return true;

    final answersMap = m['answers'];
    if (answersMap is Map && answersMap.isNotEmpty) return true;

    return false;
  }
}

final compatibilityQuizServiceProvider = Provider<CompatibilityQuizService>((
  ref,
) {
  final ready = ref.watch(firebaseReadyProvider);
  final fs = ready ? ref.watch(firestoreInstanceProvider) : null;
  return CompatibilityQuizService(fs);
});
