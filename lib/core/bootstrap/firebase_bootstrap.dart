import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Canonical bootstrap for auth vs guest state.
/// Runs once at app startup.
Future<void> initFirebaseSafely() async {
  final prefs = await SharedPreferences.getInstance();
  final auth = FirebaseAuth.instance;

  final user = auth.currentUser;

  if (user == null) {
    // No Firebase user → stay unauthenticated and show auth entry.
    // Do NOT force guest by default; guest is opt-in from the welcome screen.
    await prefs.remove('force_guest');
    // ignore: avoid_print
    print('[BOOTSTRAP] No Firebase user → auth entry (guest not forced)');
    return;
  }

  // Firebase user exists → check if the Firestore doc still exists
  try {
    final firestore = FirebaseFirestore.instance;
    final userDoc = await firestore.collection('users').doc(user.uid).get();

    if (!userDoc.exists) {
      // User is signed in but Firestore doc is missing (deleted account)
      // Sign them out and clear local data
      // ignore: avoid_print
      print(
        '[BOOTSTRAP] User signed in but Firestore doc missing → signing out and clearing cache',
      );

      await auth.signOut();
      await prefs.clear();
      await prefs.remove('force_guest');

      return;
    }

    // Firebase user exists AND Firestore doc exists → authenticated mode
    await prefs.remove('force_guest');
    // ignore: avoid_print
    print(
      '[BOOTSTRAP] Firebase user detected → uid=${user.uid}, guest cleared',
    );
  } catch (e) {
    // Firestore error - still allow user to try logging in
    // ignore: avoid_print
    print('[BOOTSTRAP] Error checking Firestore doc: $e');
    await prefs.remove('force_guest');
  }
}
