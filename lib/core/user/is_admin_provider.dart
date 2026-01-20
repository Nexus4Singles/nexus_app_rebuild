import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Admin gate uses Firebase Auth custom claims:
/// - Firestore rules check: request.auth.token.admin == true
/// So the client must also check the same source of truth.
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  // Force refresh so recently granted claims propagate after sign-in.
  final token = await user.getIdTokenResult(true);
  final claims = token.claims ?? const <String, Object?>{};
  return claims['admin'] == true;
});
