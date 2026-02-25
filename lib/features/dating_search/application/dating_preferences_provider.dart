import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import '../domain/dating_preferences.dart';

/// Provider to STREAM dating preferences for current user in real-time.
///
/// ✅ NOW: StreamProvider - listens to Firestore document changes
/// ✅ Previously: FutureProvider - read-once, cached stale data
///
/// This ensures preferences updates are reflected immediately in search results
/// without waiting for manual refresh or app restart.
final datingPreferencesProvider = StreamProvider<DatingPreferences?>((
  ref,
) async* {
  // Watch auth state to invalidate on user changes
  final authAsync = ref.watch(authStateProvider);

  if (!authAsync.hasValue) {
    yield null;
    return;
  }

  final authState = authAsync.value;
  final uid = authState?.uid;

  if (uid == null || authState == null) {
    yield null;
    return;
  }

  final fs = ref.watch(firestoreInstanceProvider);
  if (fs == null) {
    yield null;
    return;
  }

  try {
    print(
      '[DatingPreferencesProvider] Setting up real-time listener for uid=$uid',
    );

    // Listen to real-time changes from Firestore
    await for (final doc
        in fs
            .collection('users')
            .doc(uid)
            .collection('dating')
            .doc('preferences')
            .snapshots()) {
      if (!doc.exists) {
        print('[DatingPreferencesProvider] ✗ No prefs doc found for uid=$uid');
        yield null;
        continue;
      }

      try {
        final prefs = DatingPreferences.fromFirestore(doc.data() ?? {});
        print(
          '[DatingPreferencesProvider] ✓ Real-time update: minAge=${prefs.minAge}, maxAge=${prefs.maxAge}, country=${prefs.countryOfResidence}',
        );
        yield prefs;
      } catch (parseError) {
        print('[DatingPreferencesProvider] Error parsing prefs: $parseError');
        yield null;
      }
    }
  } catch (e) {
    print('[DatingPreferencesProvider] ✗ Error setting up listener: $e');
    yield null;
  }
});

/// Notifier to manage dating preferences
class DatingPreferencesNotifier
    extends StateNotifier<AsyncValue<DatingPreferences?>> {
  final FirebaseFirestore? _fs;

  DatingPreferencesNotifier(this._fs) : super(const AsyncValue.loading());

  /// Save preferences to Firestore
  Future<void> savePreferences(DatingPreferences prefs) async {
    if (_fs == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      state = const AsyncValue.loading();

      final now = DateTime.now();
      final updatedPrefs = prefs.copyWith(
        createdAt: prefs.createdAt ?? now,
        lastRefreshedAt: now,
      );

      final firestoreData = updatedPrefs.toFirestore();

      print('[DatingPreferencesNotifier] Saving prefs: $firestoreData');

      await _fs
          .collection('users')
          .doc(uid)
          .collection('dating')
          .doc('preferences')
          .set(firestoreData, SetOptions(merge: true));

      print('[DatingPreferencesNotifier] Saved successfully to Firestore');

      state = AsyncValue.data(updatedPrefs);
    } catch (e, st) {
      print('[DatingPreferencesNotifier] Save error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Load preferences from Firestore
  Future<void> loadPreferences() async {
    if (_fs == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      state = const AsyncValue.loading();

      final doc =
          await _fs
              .collection('users')
              .doc(uid)
              .collection('dating')
              .doc('preferences')
              .get();

      print('[DatingPreferencesNotifier] Loaded doc: ${doc.data()}');

      if (!doc.exists) {
        print('[DatingPreferencesNotifier] No prefs doc found');
        state = const AsyncValue.data(null);
        return;
      }

      final prefs = DatingPreferences.fromFirestore(doc.data() ?? {});
      print(
        '[DatingPreferencesNotifier] Parsed prefs: country=${prefs.countryOfResidence}',
      );
      state = AsyncValue.data(prefs);
    } catch (e, st) {
      print('[DatingPreferencesNotifier] Load error: $e');
      state = AsyncValue.error(e, st);
    }
  }

  /// Update last refresh timestamp (for 24-hr cycle)
  Future<void> updateLastRefresh() async {
    if (_fs == null) return;

    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) return;

    try {
      await _fs
          .collection('users')
          .doc(uid)
          .collection('dating')
          .doc('preferences')
          .update({'lastRefreshedAt': DateTime.now().toIso8601String()});

      final current = state.valueOrNull;
      if (current != null) {
        state = AsyncValue.data(
          current.copyWith(lastRefreshedAt: DateTime.now()),
        );
      }
    } catch (_) {
      // Silently fail - not critical
    }
  }
}

/// StateNotifier provider for dating preferences
final datingPreferencesNotifierProvider = StateNotifierProvider<
  DatingPreferencesNotifier,
  AsyncValue<DatingPreferences?>
>((ref) {
  final fs = ref.watch(firestoreInstanceProvider);
  return DatingPreferencesNotifier(fs);
});
