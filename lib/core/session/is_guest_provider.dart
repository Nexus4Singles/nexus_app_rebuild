import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Guest rules (v2):
/// - If FirebaseAuth has a real signed-in user (non-anonymous), you are NOT a guest,
///   regardless of any old `force_guest` flag.
/// - Otherwise, fall back to `force_guest` for explicit guest mode.
final isGuestProvider = FutureProvider<bool>((ref) async {
  final user = FirebaseAuth.instance.currentUser;
  if (user != null && !user.isAnonymous) return false;

  final prefs = await SharedPreferences.getInstance();
  final forceGuest = prefs.getBool('force_guest') ?? false;
  return forceGuest;
});
