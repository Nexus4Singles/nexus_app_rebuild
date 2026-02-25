import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';

/// Guest rules (v2):
/// - If FirebaseAuth has a real signed-in user (non-anonymous), you are NOT a guest,
///   regardless of any old `force_guest` flag.
/// - Otherwise (no user, anonymous user, or force_guest flag), you ARE a guest.
///
/// This provider STREAMS auth state changes so it automatically updates
/// when user logs in/out, ensuring real-time accuracy.
///
/// ✅ NOW: StreamProvider - watches auth state in real-time
/// ✅ Previously: FutureProvider - checked once, cached stale guest status
final isGuestProvider = StreamProvider<bool>((ref) async* {
  // Watch auth state stream to invalidate when it changes
  final authAsync = ref.watch(authStateProvider);

  if (!authAsync.hasValue) {
    yield true; // Assume guest if auth not ready
    return;
  }

  final user = authAsync.value;

  // Real authenticated user = not a guest
  if (user != null && !user.isAnonymous) {
    print('[isGuestProvider] ✓ Authenticated user: NOT a guest');
    yield false;
    return;
  }

  // Check for explicit force_guest flag
  try {
    final prefs = await SharedPreferences.getInstance();
    final forceGuest = prefs.getBool('force_guest') ?? false;

    if (user == null || user.isAnonymous || forceGuest) {
      print(
        '[isGuestProvider] ✓ IS a guest (user=$user, anon=${user?.isAnonymous}, forceGuest=$forceGuest)',
      );
      yield true;
    } else {
      yield false;
    }
  } catch (e) {
    print('[isGuestProvider] Error checking guest status: $e');
    // If error checking prefs, default to guest
    yield true;
  }
});
