import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_min_test/core/bootstrap/firebase_ready_provider.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import '../domain/compatibility_quiz_answers.dart';

class CompatibilityQuizService {
  final Ref ref;
  CompatibilityQuizService(this.ref);

  Future<void> saveAnswers(CompatibilityQuizAnswers answers) async {
    final ready = ref.read(firebaseReadyProvider);
    if (!ready) {
      throw StateError('Firebase not ready');
    }

    final fs = ref.read(firestoreInstanceProvider);
    if (fs == null) {
      throw StateError('Firestore not available');
    }

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) {
      throw StateError('Not signed in');
    }

    await fs.collection('users').doc(uid).set({
      'compatibility': answers.toMap(),
      'compatibilitySetted': true,
    }, SetOptions(merge: true));
  }
}
