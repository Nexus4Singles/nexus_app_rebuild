import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../bootstrap/firebase_ready_provider.dart';

final userProfileServiceProvider = Provider<UserProfileService>((ref) {
  final ready = ref.watch(firebaseReadyProvider);
  final fs = ready ? FirebaseFirestore.instance : null;
  final auth = ready ? FirebaseAuth.instance : null;
  return UserProfileService(fs, auth);
});

class UserProfileService {
  final FirebaseFirestore? _firestore;
  final FirebaseAuth? _auth;

  UserProfileService(this._firestore, this._auth);

  FirebaseFirestore get _fs =>
      _firestore ?? (throw StateError('Firestore not ready'));
  FirebaseAuth get _a => _auth ?? (throw StateError('Auth not ready'));

  Future<void> ensureUserDoc({required Map<String, dynamic> data}) async {
    final uid = _a.currentUser?.uid;
    if (uid == null) throw StateError('No user');

    final ref = _fs.collection('users').doc(uid);

    await _fs.runTransaction((tx) async {
      final snap = await tx.get(ref);
      if (!snap.exists) {
        tx.set(ref, {...data, 'createdAt': FieldValue.serverTimestamp()});
      } else {
        tx.update(ref, {...data, 'updatedAt': FieldValue.serverTimestamp()});
      }
    });
  }
}
