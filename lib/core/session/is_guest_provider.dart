import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_app_min_test/core/providers/auth_provider.dart';

/// Guest rules (v2):
/// - If FirebaseAuth has a real signed-in user (non-anonymous), you are NOT a guest,
///   regardless of any old `force_guest` flag.
/// - Otherwise (no user, anonymous user, or force_guest flag), you ARE a guest.
///
/// This provider now watches authStateProvider so it automatically updates
/// when auth state changes (login/logout).
final isGuestProvider = FutureProvider<bool>((ref) async {
  // Watch auth state to invalidate when it changes
  final authAsync = ref.watch(authStateProvider);

  final user = authAsync.valueOrNull;

  // Real authenticated user = not a guest
  if (user != null && !user.isAnonymous) return false;

  // No user or anonymous user = guest
  // Also respect explicit force_guest flag for testing
  if (user == null || user.isAnonymous) return true;

  final prefs = await SharedPreferences.getInstance();
  final forceGuest = prefs.getBool('force_guest') ?? false;
  return forceGuest;
});
