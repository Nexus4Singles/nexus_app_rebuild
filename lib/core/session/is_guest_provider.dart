import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Canonical guest definition for the entire app.
///
/// A user is considered a guest if:
/// - force_guest == true (explicit guest mode)
/// - Firebase user is null
/// - Firebase user is anonymous
final isGuestProvider = FutureProvider<bool>((ref) async {
  final prefs = await SharedPreferences.getInstance();
  final forceGuest = prefs.getBool('force_guest') ?? false;

  // Canonical guest rules:
  // 1) force_guest wins (explicit guest mode)
  // 2) no Firebase user => guest
  // 3) anonymous Firebase user => guest
  if (forceGuest) return true;

  final user = FirebaseAuth.instance.currentUser;
  if (user == null) return true;
  if (user.isAnonymous) return true;

  return false;
});
