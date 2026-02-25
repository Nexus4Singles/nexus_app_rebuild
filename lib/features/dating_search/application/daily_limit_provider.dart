import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:nexus_app_v2/core/providers/user_provider.dart';

/// Manages daily profile viewing limit for FREE users (10 profiles/day)
/// Premium users are NOT affected - they have unlimited access
///
/// Data persisted in Firestore:
/// - `users/{uid}/dating.dailyLimitFirstHit` → DateTime when 10 profiles first shown
/// - `users/{uid}/dating.shownProfileIds` → List<String> of profile IDs shown today

class DailyLimitManager {
  final FirebaseFirestore _fs;

  const DailyLimitManager(this._fs);

  /// Get the timestamp when today's daily limit was first hit
  /// Returns null if limit hasn't been hit yet or 24+ hours have passed
  Future<DateTime?> getDailyLimitFirstHit(String uid) async {
    try {
      final doc = await _fs.collection('users').doc(uid).get();
      if (!doc.exists) return null;

      final datetime = doc['dating.dailyLimitFirstHit'] as Timestamp?;
      if (datetime == null) {
        print(
          '[DailyLimitManager] 📝 getDailyLimitFirstHit: No timestamp found (first search)',
        );
        return null;
      }

      final dt = datetime.toDate();
      final now = DateTime.now();
      final hoursSince = now.difference(dt).inHours;
      print(
        '[DailyLimitManager] 📝 getDailyLimitFirstHit: timestamp=$dt, hours_since=$hoursSince',
      );

      // If 24+ hours have passed, limit has expired - return null to reset
      if (hoursSince >= 24) {
        print('[DailyLimitManager] ⏰ 24+ hours passed - clearing daily limit');
        await clearDailyLimit(uid);
        return null;
      }

      return dt;
    } catch (e) {
      print('[DailyLimitManager] Error getting dailyLimitFirstHit: $e');
      return null;
    }
  }

  /// Get the list of profile IDs already shown to this free user today
  Future<List<String>> getShownProfileIds(String uid) async {
    try {
      final doc = await _fs.collection('users').doc(uid).get();
      if (!doc.exists) return [];

      final ids = doc['dating.shownProfileIds'] as List?;
      if (ids == null) {
        print(
          '[DailyLimitManager] 📝 getShownProfileIds: None found (fresh start)',
        );
        return [];
      }

      final listIds = List<String>.from(ids.map((e) => e.toString()));
      print(
        '[DailyLimitManager] 📝 getShownProfileIds: ${listIds.length} IDs found | Sample: ${listIds.take(2).join(", ")}',
      );
      return listIds;
    } catch (e) {
      print('[DailyLimitManager] Error getting shownProfileIds: $e');
      return [];
    }
  }

  /// Store the timestamp when today's daily limit was first hit (first time showing 10 profiles)
  /// Only call once per day when limit first triggered
  Future<void> setDailyLimitFirstHit(String uid) async {
    try {
      await _fs.collection('users').doc(uid).update({
        'dating.dailyLimitFirstHit': FieldValue.serverTimestamp(),
      });
      print('[DailyLimitManager] ✅ Set dailyLimitFirstHit for $uid');
    } catch (e) {
      print('[DailyLimitManager] ❌ Error setting dailyLimitFirstHit: $e');
      rethrow;
    }
  }

  /// Store the profile IDs we're showing to the free user today (for deduplication)
  /// Call this when we first show 10 profiles to track which ones we've shown
  Future<void> setShownProfileIds(String uid, List<String> profileIds) async {
    try {
      await _fs.collection('users').doc(uid).update({
        'dating.shownProfileIds': profileIds,
      });
      print(
        '[DailyLimitManager] ✅ Stored ${profileIds.length} shown profile IDs for $uid',
      );
    } catch (e) {
      print('[DailyLimitManager] ❌ Error setting shownProfileIds: $e');
      rethrow;
    }
  }

  /// Clear the daily limit when 24 hours have passed
  /// Resets both timestamp and shown profiles list
  ///
  /// DUAL-GUARANTEE SYSTEM:
  /// - Primary: CloudFunction resets daily at midnight UTC (sets lastResetAt)
  /// - Backup: This method runs on client when user searches after 24h
  /// This ensures resets always happen, even if CloudFunction fails
  Future<void> clearDailyLimit(String uid) async {
    try {
      await _fs.collection('users').doc(uid).update({
        'dating.dailyLimitFirstHit': FieldValue.delete(),
        'dating.shownProfileIds': FieldValue.delete(),
        'dating.clientClearedAt':
            FieldValue.serverTimestamp(), // Track client-side reset
      });
      print(
        '[DailyLimitManager] ✅ Cleared daily limit for $uid (24 hours passed) via client-side lazy reset',
      );
    } catch (e) {
      print('[DailyLimitManager] ❌ Error clearing daily limit: $e');
      // Silently fail - not critical
    }
  }

  /// Check when the limit was last reset (CloudFunction or client)
  /// Returns null if no reset has happened
  /// Helps verify consistency of reset system
  Future<DateTime?> getLastResetTime(String uid) async {
    try {
      final doc = await _fs.collection('users').doc(uid).get();
      if (!doc.exists) return null;

      // Check CloudFunction reset first (primary mechanism)
      final cfReset = doc['dating.lastResetAt'] as Timestamp?;
      if (cfReset != null) {
        print(
          '[DailyLimitManager] ℹ️ Found CloudFunction reset at ${cfReset.toDate()}',
        );
        return cfReset.toDate();
      }

      // Check client-side reset (backup mechanism)
      final clientReset = doc['dating.clientClearedAt'] as Timestamp?;
      if (clientReset != null) {
        print(
          '[DailyLimitManager] ℹ️ Found client-side reset at ${clientReset.toDate()}',
        );
        return clientReset.toDate();
      }

      return null;
    } catch (e) {
      print('[DailyLimitManager] Error getting last reset time: $e');
      return null;
    }
  }
}

/// Provider for DailyLimitManager instance
final dailyLimitManagerProvider = Provider<DailyLimitManager>((ref) {
  return DailyLimitManager(FirebaseFirestore.instance);
});

/// Provider to check if current user's daily limit is still active
/// Returns null if user is premium or limit has expired
/// Returns DateTime if limit is active (when it was hit)
final currentUserDailyLimitProvider = FutureProvider<DateTime?>((ref) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return null;

  // Check if user is premium - if so, no limit applies
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.valueOrNull;
  if (user?.onPremium == true) {
    print('[currentUserDailyLimitProvider] User is premium, no daily limit');
    return null;
  }

  // Get persistent daily limit timestamp for free user
  final manager = ref.watch(dailyLimitManagerProvider);
  return await manager.getDailyLimitFirstHit(userId);
});

/// Provider to get profile IDs shown to free user today
final currentUserShownProfileIdsProvider = FutureProvider<List<String>>((
  ref,
) async {
  final userId = FirebaseAuth.instance.currentUser?.uid;
  if (userId == null) return [];

  // Check if user is premium
  final userAsync = ref.watch(currentUserProvider);
  final user = userAsync.valueOrNull;
  if (user?.onPremium == true) {
    return []; // Premium users not tracked
  }

  final manager = ref.watch(dailyLimitManagerProvider);
  return await manager.getShownProfileIds(userId);
});
