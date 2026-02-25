import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../providers/auth_provider.dart';

/// Admin gate checks both Firebase Auth custom claims and Firestore isAdmin field in real-time:
/// - Listens to Firestore isAdmin field changes
/// - Falls back to Firebase Auth custom claims if Firestore unavailable
/// - Invalidates immediately when user auth state changes
///
/// ✅ NOW: StreamProvider - watches isAdmin field in real-time
/// ✅ Previously: FutureProvider - checked once, cached old status
final isAdminProvider = StreamProvider<bool>((ref) async* {
  // Watch auth state so stream resets when user changes
  final authAsync = ref.watch(authStateProvider);

  if (!authAsync.hasValue) {
    yield false;
    return;
  }

  final authState = authAsync.value;
  final user = authState;

  if (user == null) {
    print('[isAdminProvider] ✗ No authenticated user');
    yield false;
    return;
  }

  if (user.isAnonymous) {
    print('[isAdminProvider] ✗ User is anonymous');
    yield false;
    return;
  }

  final uid = user.uid;
  print('[isAdminProvider] Checking admin status for uid=$uid');

  // First check: Firebase Auth custom claims (cached token)
  try {
    final token = await user.getIdTokenResult(false); // false = use cached
    final claims = token.claims ?? const <String, Object?>{};
    if (claims['admin'] == true) {
      print('[isAdminProvider] ✅ Admin (from auth claims)');
      yield true;
      return;
    }
  } catch (e) {
    print('[isAdminProvider] ⚠️  Auth claims check failed: $e');
  }

  // Second check: Watch Firestore in real-time for isAdmin field
  try {
    print('[isAdminProvider] Setting up real-time listener for uid=$uid');
    await for (final doc
        in FirebaseFirestore.instance
            .collection('users')
            .doc(uid)
            .snapshots()) {
      try {
        if (!doc.exists) {
          print('[isAdminProvider] ✗ User doc does not exist');
          yield false;
          continue;
        }

        final isAdmin = doc.data()?['isAdmin'] as bool? ?? false;
        print('[isAdminProvider] ✅ Real-time update: isAdmin=$isAdmin');
        yield isAdmin;
      } catch (parseError) {
        print('[isAdminProvider] Error parsing admin status: $parseError');
        yield false;
      }
    }
  } catch (e) {
    print('[isAdminProvider] ✗ Error setting up real-time listener: $e');
    yield false;
  }
});
