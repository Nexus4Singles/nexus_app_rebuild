import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Admin gate checks both Firebase Auth custom claims and Firestore isAdmin field:
/// - First checks Firebase Auth custom claims (server-side admin claims)
/// - Then checks Firestore users collection for isAdmin field
final isAdminProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return false;

  // First check: Firebase Auth custom claims
  try {
    final token = await user.getIdTokenResult(true);
    final claims = token.claims ?? const <String, Object?>{};
    if (claims['admin'] == true) return true;
  } catch (e) {
    // Continue to Firestore check if Auth claims fail
  }

  // Second check: Firestore isAdmin field
  try {
    final doc = await FirebaseFirestore.instance
        .collection('users')
        .doc(user.uid)
        .get();
    
    if (doc.exists) {
      final isAdmin = doc.data()?['isAdmin'] as bool? ?? false;
      return isAdmin;
    }
  } catch (e) {
    // Continue to return false if Firestore check fails
  }

  return false;
});
