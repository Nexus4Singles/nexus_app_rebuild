import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

import '../bootstrap/firebase_ready_provider.dart';
import 'auth_state.dart';

final firebaseAuthProvider = Provider<FirebaseAuth?>((ref) {
  final ready = ref.watch(firebaseReadyProvider);
  if (!ready) return null;
  return FirebaseAuth.instance;
});

final authStateProvider = StreamProvider<AuthState>((ref) {
  final auth = ref.watch(firebaseAuthProvider);
  if (auth == null) {
    return Stream.value(const AuthState(null));
  }

  return auth.authStateChanges().map((u) => AuthState(u));
});
