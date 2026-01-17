import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Canonical bootstrap for auth vs guest state.
/// Runs once at app startup.
Future<void> initFirebaseSafely() async {
  final prefs = await SharedPreferences.getInstance();
  final auth = FirebaseAuth.instance;

  final user = auth.currentUser;

  if (user == null) {
    // No Firebase user → force guest mode
    await prefs.setBool('force_guest', true);
    // ignore: avoid_print
    print('[BOOTSTRAP] No Firebase user → guest mode');
    return;
  }

  // Firebase user exists → authenticated mode
  await prefs.remove('force_guest');

  // ignore: avoid_print
  print('[BOOTSTRAP] Firebase user detected → uid=${user.uid}, guest cleared');
}
