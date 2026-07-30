import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';

// ============================================================================
// CLICKED PROFILES PROVIDER (With 24-Hour Grace Period)
// ============================================================================
// Tracks profile IDs that the premium user has clicked to view
// Persisted in local device storage (SharedPreferences)
//
// Grace Period: First 24 hours after click (user can change mind)
// Permanent: After 24 hours (stays hidden indefinitely)
//
// Purpose:
// - Reduce scroll fatigue by hiding viewed profiles
// - Give users 24h grace in case of accidental click or reconsideration
// - Permanently hide after 24h (assumed user is not interested)

/// Model for storing clicked profile with timestamp
class ClickedProfileRecord {
  final String profileId;
  final DateTime clickedAt;

  ClickedProfileRecord({required this.profileId, required this.clickedAt});

  /// Check if this click is within 24-hour grace period
  bool isWithinGracePeriod() {
    final now = DateTime.now();
    final timeDiff = now.difference(clickedAt);
    return timeDiff.inHours < 24;
  }

  /// Check if click is old enough to be considered permanent dismissal
  bool isPermanent() {
    return !isWithinGracePeriod();
  }

  factory ClickedProfileRecord.fromMap(Map<String, dynamic> map) {
    return ClickedProfileRecord(
      profileId: map['profileId'] as String,
      clickedAt: DateTime.parse(map['clickedAt'] as String),
    );
  }

  Map<String, dynamic> toMap() {
    return {'profileId': profileId, 'clickedAt': clickedAt.toIso8601String()};
  }
}

/// Notifier managing clicked profiles with 24h grace period
class ClickedProfilesNotifier extends StateNotifier<Map<String, DateTime>> {
  final SharedPreferences? _prefs;

  ClickedProfilesNotifier(this._prefs) : super({});

  /// Initialize from persistent storage
  Future<void> initialize(String userId) async {
    if (_prefs == null) return;
    try {
      final storedJson = _prefs.getString(_storageKey(userId));
      if (storedJson != null && storedJson.isNotEmpty) {
        final map = <String, DateTime>{};
        // Parse simple format: profileId:timestamp||profileId:timestamp
        final json = storedJson.split('||');
        for (final entry in json) {
          if (entry.isEmpty) continue;
          try {
            final parts = entry.split(':');
            if (parts.length == 2) {
              map[parts[0]] = DateTime.parse(parts[1]);
            }
          } catch (_) {}
        }
        state = map;
      }
      if (kDebugMode) {
        print(
          '[ClickedProfiles] Loaded ${state.length} clicked profiles for $userId',
        );
      }
    } catch (e) {
      print('[ClickedProfiles] Error loading from storage: $e');
      state = {};
    }
  }

  /// Add a profile ID to clicked list (premium user viewed it)
  /// Stores current timestamp for 24-hour grace period tracking
  Future<void> addClickedProfile(String userId, String profileId) async {
    if (_prefs == null || state.containsKey(profileId)) return;

    try {
      final updated = {...state, profileId: DateTime.now()};
      state = updated;

      // Persist to device storage (simple format: profileId:timestamp||profileId:timestamp)
      final serialized = updated.entries
          .map((e) => '${e.key}:${e.value.toIso8601String()}')
          .join('||');

      await _prefs.setString(_storageKey(userId), serialized);

      if (kDebugMode) {
        print(
          '[ClickedProfiles] ✓ Added profile $profileId | Total: ${state.length}',
        );
      }
    } catch (e) {
      print('[ClickedProfiles] Error adding profile: $e');
    }
  }

  /// Get all clicked profile IDs that should be hidden
  /// Includes both temporary (within 24h) and permanent (>= 24h)
  Set<String> getHiddenProfiles() => state.keys.toSet();

  /// Get profiles still within 24-hour grace period (user can reconsider)
  Set<String> getGracePeriodProfiles() {
    final now = DateTime.now();
    return state.entries
        .where((e) => now.difference(e.value).inHours < 24)
        .map((e) => e.key)
        .toSet();
  }

  /// Get profiles past 24-hour grace period (permanently dismissed)
  Set<String> getPermanentProfiles() {
    final now = DateTime.now();
    return state.entries
        .where((e) => now.difference(e.value).inHours >= 24)
        .map((e) => e.key)
        .toSet();
  }

  /// Check if a profile was clicked
  bool wasClicked(String profileId) => state.containsKey(profileId);

  /// Clear all clicked profiles (user can call this manually)
  Future<void> clearAll(String userId) async {
    if (_prefs == null) return;
    try {
      state = {};
      await _prefs.remove(_storageKey(userId));
      if (kDebugMode) {
        print('[ClickedProfiles] Cleared all clicked profiles for $userId');
      }
    } catch (e) {
      print('[ClickedProfiles] Error clearing: $e');
    }
  }

  /// Auto-cleanup: Remove permanent profiles older than 30 days
  /// (Prevents map from growing indefinitely)
  Future<void> autoCleanupOldProfiles(String userId) async {
    if (_prefs == null) return;
    try {
      final now = DateTime.now();
      final cutoff = now.subtract(Duration(days: 30));

      final cleaned = <String, DateTime>{};
      for (final entry in state.entries) {
        if (entry.value.isAfter(cutoff)) {
          cleaned[entry.key] = entry.value;
        }
      }

      if (cleaned.length != state.length) {
        state = cleaned;
        final serialized = cleaned.entries
            .map((e) => '${e.key}:${e.value.toIso8601String()}')
            .join('||');
        await _prefs.setString(_storageKey(userId), serialized);

        if (kDebugMode) {
          final removed = state.length - cleaned.length;
          print(
            '[ClickedProfiles] Auto-cleanup: Removed $removed profiles older than 30 days',
          );
        }
      }
    } catch (e) {
      print('[ClickedProfiles] Error during cleanup: $e');
    }
  }

  static String _storageKey(String userId) => 'dating_clicked_profiles_$userId';

  // ========================================================================
  // DEBUG SECTION - TESTING ONLY
  // REMOVAL INSTRUCTIONS:
  // 1. Set DEBUG_CLICKED_PROFILES_TESTING = false at top of file
  // 2. Or delete the entire section between:
  //    "// ======== DEBUG SECTION START ========"
  //    "// ======== DEBUG SECTION END ========"
  // ========================================================================

  /// DEBUG ONLY: Simulate a click from N hours ago (for grace period testing)
  /// Usage: await ref.read(clickedProfilesProvider.notifier)
  ///            .debugAddOldClickedProfile(userId, "profileId", 25);
  Future<void> debugAddOldClickedProfile(
    String userId,
    String profileId,
    int hoursAgo,
  ) async {
    if (_prefs == null) return;
    if (!DEBUG_CLICKED_PROFILES_TESTING)
      return; // Gate: Only runs if flag enabled

    try {
      final oldDateTime = DateTime.now().subtract(Duration(hours: hoursAgo));
      final updated = {...state, profileId: oldDateTime};
      state = updated;

      final serialized = updated.entries
          .map((e) => '${e.key}:${e.value.toIso8601String()}')
          .join('||');

      await _prefs.setString(_storageKey(userId), serialized);

      print(
        '[DEBUG-CLICKED] ✓ Added $profileId (simulated $hoursAgo hours ago)',
      );
      print('[DEBUG-CLICKED] Timestamp: ${oldDateTime.toIso8601String()}');
      print('[DEBUG-CLICKED] Total in state: ${state.length}');
    } catch (e) {
      print('[DEBUG-CLICKED] ✗ Error: $e');
    }
  }

  /// DEBUG ONLY: Print all stored clicked profiles with timestamps
  /// Usage: await ref.read(clickedProfilesProvider.notifier)
  ///            .debugPrintAllClicked(userId);
  Future<void> debugPrintAllClicked(String userId) async {
    if (_prefs == null) return;
    if (!DEBUG_CLICKED_PROFILES_TESTING)
      return; // Gate: Only runs if flag enabled

    try {
      print('[DEBUG-CLICKED] ========== CLICKED PROFILES DUMP ==========');
      print('[DEBUG-CLICKED] Total profiles: ${state.length}');

      final now = DateTime.now();
      for (final entry in state.entries) {
        final profileId = entry.key;
        final clickedAt = entry.value;
        final hoursAgo = now.difference(clickedAt).inHours;
        final isGrace = now.difference(clickedAt).inHours < 24;

        print(
          '[DEBUG-CLICKED] - $profileId | '
          '${hoursAgo}h ago | '
          '${isGrace ? 'GRACE' : 'PERMANENT'}',
        );
      }

      print('[DEBUG-CLICKED] =============================================');
    } catch (e) {
      print('[DEBUG-CLICKED] ✗ Error: $e');
    }
  }

  /// DEBUG ONLY: Simulate clearing clicked profiles for testing
  /// Usage: await ref.read(clickedProfilesProvider.notifier)
  ///            .debugClearAll(userId);
  Future<void> debugClearAllClicked(String userId) async {
    if (_prefs == null) return;
    if (!DEBUG_CLICKED_PROFILES_TESTING)
      return; // Gate: Only runs if flag enabled

    try {
      final clearedCount = state.length;
      state = {};
      await _prefs.remove(_storageKey(userId));
      print('[DEBUG-CLICKED] ✓ Cleared all $clearedCount profiles');
    } catch (e) {
      print('[DEBUG-CLICKED] ✗ Error clearing: $e');
    }
  }
}

// ============================================================================
// DEBUG FLAG - CONTROLS ALL DEBUG OUTPUT
// ============================================================================
// Set to true when testing grace period behavior
// Set to false for normal operation (recommended for production)
// All debug methods are gated by this flag - they do nothing if false
// ============================================================================
const bool DEBUG_CLICKED_PROFILES_TESTING = true; // ✅ ENABLED FOR TESTING

// ============================================================================
// PROVIDER SETUP
// ============================================================================

/// FutureProvider to initialize SharedPreferences
final _sharedPreferencesProvider = FutureProvider<SharedPreferences>((
  ref,
) async {
  return await SharedPreferences.getInstance();
});

/// StateNotifierProvider for managing clicked profiles
final clickedProfilesProvider =
    StateNotifierProvider<ClickedProfilesNotifier, Map<String, DateTime>>((
      ref,
    ) {
      final prefsAsync = ref.watch(_sharedPreferencesProvider);
      final authAsync = ref.watch(authStateProvider);

      final prefs = prefsAsync.valueOrNull;
      final user = authAsync.valueOrNull;

      final notifier = ClickedProfilesNotifier(prefs);

      // Initialize on first build/user change
      if (user != null) {
        Future.microtask(() => notifier.initialize(user.uid));
        // Auto-cleanup old records daily
        Future.microtask(() => notifier.autoCleanupOldProfiles(user.uid));
      }

      return notifier;
    });

/// Helper provider to get hidden profile IDs
final hiddenProfileIdsProvider = Provider<Set<String>>((ref) {
  final clicked = ref.watch(clickedProfilesProvider);
  return clicked.keys.toSet();
});

/// Helper provider to check if a specific profile was clicked
final wasProfileClickedProvider = Provider.family<bool, String>((
  ref,
  profileId,
) {
  final hidden = ref.watch(hiddenProfileIdsProvider);
  return hidden.contains(profileId);
});

/// Helper provider to get photos still in grace period
final gracePeriodProfilesProvider = Provider<Set<String>>((ref) {
  return ref.watch(clickedProfilesProvider.notifier).getGracePeriodProfiles();
});

/// Helper provider to get permanently dismissed profiles
final permanentlyDismissedProvider = Provider<Set<String>>((ref) {
  return ref.watch(clickedProfilesProvider.notifier).getPermanentProfiles();
});

/// Consume this in UI to add clicked profile
extension ClickedProfilesActions on WidgetRef {
  Future<void> trackProfileClick(String profileId) async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await read(
      clickedProfilesProvider.notifier,
    ).addClickedProfile(userId, profileId);
  }

  Set<String> getHiddenProfiles() => read(clickedProfilesProvider).keys.toSet();

  Future<void> clearClickedProfiles() async {
    final userId = FirebaseAuth.instance.currentUser?.uid;
    if (userId == null) return;

    await read(clickedProfilesProvider.notifier).clearAll(userId);
  }
}
