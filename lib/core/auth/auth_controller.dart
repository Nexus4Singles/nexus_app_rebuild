import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../bootstrap/firebase_ready_provider.dart';

final authControllerProvider = Provider<AuthController>((ref) {
  final ready = ref.watch(firebaseReadyProvider);
  final auth = ready ? FirebaseAuth.instance : null;
  return AuthController(auth);
});

class AuthController {
  final FirebaseAuth? _auth;

  AuthController(this._auth);

  FirebaseAuth get _a => _auth ?? (throw StateError('FirebaseAuth not ready'));

  Future<void> signUp({required String email, required String password}) async {
    await _a.createUserWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signIn({required String email, required String password}) async {
    await _a.signInWithEmailAndPassword(
      email: email.trim(),
      password: password,
    );
  }

  Future<void> signOut() async {
    await _a.signOut();
  }
}
