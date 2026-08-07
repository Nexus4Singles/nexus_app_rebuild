import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_v2/core/bootstrap/firestore_instance_provider.dart';
import 'package:nexus_app_v2/core/providers/auth_provider.dart';
import '../domain/dating_profile.dart';
import 'dating_preferences_provider.dart';

/// Daily profiles state - tracks which profiles have been shown today
class DailyProfilesState {
  final List<DatingProfile> profiles; // Max 5 per day
  final int viewedCount; // How many user has viewed
  final DateTime resetTime; // When the daily allowance resets
  final bool isDailyLimitReached; // If user viewed all 5

  DailyProfilesState({
    required this.profiles,
    required this.viewedCount,
    required this.resetTime,
    required this.isDailyLimitReached,
  });

  DailyProfilesState copyWith({
    List<DatingProfile>? profiles,
    int? viewedCount,
    DateTime? resetTime,
    bool? isDailyLimitReached,
  }) {
    return DailyProfilesState(
      profiles: profiles ?? this.profiles,
      viewedCount: viewedCount ?? this.viewedCount,
      resetTime: resetTime ?? this.resetTime,
      isDailyLimitReached: isDailyLimitReached ?? this.isDailyLimitReached,
    );
  }
}

/// Provider for daily profiles - fetches from Cloud Function daily calculation
/// Data structure: dailyProfiles/{date}/users/{uid} contains pre-calculated scores
/// Resets at midnight UTC
final dailyProfilesProvider = FutureProvider.autoDispose<DailyProfilesState?>((
  ref,
) async {
  try {
    final authAsync = ref.watch(authStateProvider);
    final preferencesAsync = await ref.watch(datingPreferencesProvider.future);
    final country = preferencesAsync?.countryOfResidence;

    if (country == null || authAsync.value?.uid == null) {
      return null;
    }

    // Don't show daily profiles for Nigeria - they use grid
    if (country == 'Nigeria') {
      return null;
    }

    final fs = ref.watch(firestoreInstanceProvider);
    if (fs == null) return null;

    final uid = authAsync.value!.uid;

    // Get today's date in YYYY-MM-DD format
    final now = DateTime.now().toUtc();
    final today = now.toIso8601String().split('T')[0]; // YYYY-MM-DD
    final tomorrow = now.add(const Duration(days: 1));

    Future<DocumentSnapshot<Map<String, dynamic>>> _loadDailyProfilesDoc(
      FirebaseFirestore fs,
      String userId,
      String targetDate,
    ) async {
      final todayDoc =
          await fs
              .collection('dailyProfiles')
              .doc(targetDate)
              .collection('users')
              .doc(userId)
              .get();

      if (todayDoc.exists) {
        return todayDoc;
      }

      final now = DateTime.parse('${targetDate}T00:00:00Z');
      final maxLookbackDays = 14;

      for (var offset = 1; offset <= maxLookbackDays; offset++) {
        final previousDate = now.subtract(Duration(days: offset));
        final previousDateKey = previousDate.toIso8601String().split('T')[0];
        final previousDoc =
            await fs
                .collection('dailyProfiles')
                .doc(previousDateKey)
                .collection('users')
                .doc(userId)
                .get();

        if (previousDoc.exists) {
          print(
            '[DailyProfilesProvider] Falling back to last available batch $previousDateKey for $userId',
          );
          return previousDoc;
        }
      }

      print(
        '[DailyProfilesProvider] No daily profiles found for $targetDate or the previous $maxLookbackDays days',
      );
      return todayDoc;
    }

    try {
      // Fetch from Cloud Function output
      final dailyProfilesDoc = await _loadDailyProfilesDoc(fs, uid, today);

      final viewedSnapshot = await fs
          .collection('users')
          .doc(uid)
          .collection('dailyProfilesViewed')
          .get();
      final viewedProfileIds = viewedSnapshot.docs.map((doc) => doc.id).toSet();
      final viewedCount = viewedSnapshot.docs.where((doc) {
        final viewedAt = doc.data()['viewedAt'];
        if (viewedAt is Timestamp) {
          return !viewedAt.toDate().toUtc().isBefore(
            DateTime.utc(now.year, now.month, now.day),
          );
        }
        return false;
      }).length;
      final remainingSlots = (5 - viewedCount).clamp(0, 5);

      if (!dailyProfilesDoc.exists) {
        return DailyProfilesState(
          profiles: [],
          viewedCount: viewedCount,
          resetTime: DateTime.utc(tomorrow.year, tomorrow.month, tomorrow.day),
          isDailyLimitReached: remainingSlots == 0,
        );
      }

      final data = dailyProfilesDoc.data();
      final profilesData = data?['profiles'] as List<dynamic>? ?? [];

      final profiles = <DatingProfile>[];

      // Get current user's gender for filtering
      final currentUserDoc = await fs.collection('users').doc(uid).get();
      final currentUserData = currentUserDoc.data();
      final currentUserGender = currentUserData?['gender'] as String?;

      for (final profileData in profilesData) {
        try {
          final profileId = profileData['profileId'] as String?;
          final score = profileData['compatibilityScore'] as int?;

          if (profileId == null ||
              viewedProfileIds.contains(profileId) ||
              profiles.length >= remainingSlots) {
            continue;
          }

          // Fetch full profile document
          final userDoc = await fs.collection('users').doc(profileId).get();
          if (!userDoc.exists) continue;

          final userData = userDoc.data() as Map<String, dynamic>;

            final profileCountry = (userData['dating'] is Map
                ? (userData['dating'] as Map)['profile']
                : null)
              is Map
              ? (((userData['dating'] as Map)['profile'] as Map)['country']
                ?.toString()
                .trim()
                .toLowerCase())
              : null;
            final verificationStatus = userData['dating'] is Map
              ? ((userData['dating'] as Map)['verificationStatus']
                ?.toString()
                .trim()
                .toLowerCase())
              : null;
            if (profileCountry != 'united kingdom' ||
              verificationStatus != 'verified' ||
              userData['status'] == 'disabled') {
            continue;
            }

          // Gender filtering: show only opposite gender
          final profileGender = userData['gender'] as String?;
          if (currentUserGender != null && profileGender != null) {
            // Only show opposite gender
            // Normalize to lowercase for comparison
            final currentGenderNorm = currentUserGender.toLowerCase();
            final profileGenderNorm = profileGender.toLowerCase();

            if (currentGenderNorm == profileGenderNorm) {
              // Skip profiles with same gender
              print(
                '[DailyProfilesProvider] Skipping same-gender profile: $profileId ($profileGenderNorm)',
              );
              continue;
            }
          }

          // Build profile using fromFirestore
          final datingProfile = DatingProfile.fromFirestore(
            profileId,
            userData,
          );

          // Add compatibility score if available
          if (score != null) {
            profiles.add(datingProfile.copyWith(compatibilityScore: score));
          } else {
            profiles.add(datingProfile);
          }
        } catch (e) {
          print('[DailyProfilesProvider] Error loading profile: $e');
          continue;
        }
      }

      return DailyProfilesState(
        profiles: profiles,
        viewedCount: viewedCount,
        resetTime: DateTime.utc(tomorrow.year, tomorrow.month, tomorrow.day),
        isDailyLimitReached: remainingSlots == 0,
      );
    } catch (e) {
      print('[DailyProfilesProvider] Error fetching daily profiles: $e');
      // Fall back to empty state instead of crashing
      return DailyProfilesState(
        profiles: [],
        viewedCount: 0,
        resetTime: DateTime.utc(tomorrow.year, tomorrow.month, tomorrow.day),
        isDailyLimitReached: false,
      );
    }
  } catch (e) {
    print('[DailyProfilesProvider] Fatal error: $e');
    rethrow;
  }
});

/// Notifier to track user's daily profile interactions
class DailyProfilesNotifier
    extends StateNotifier<AsyncValue<DailyProfilesState?>> {
  final FirebaseFirestore? _fs;

  DailyProfilesNotifier(this._fs) : super(const AsyncValue.loading());

  /// Record that user viewed a profile (increment counter)
  Future<void> recordProfileView(
    String uid,
    String profileUid,
    bool wasLiked,
  ) async {
    if (_fs == null) return;

    try {
      final now = DateTime.now().toUtc();

      final profileViewDocRef = _fs
          .collection('users')
          .doc(uid)
          .collection('dailyProfilesViewed')
          .doc(profileUid);

      final profileViewDoc = await profileViewDocRef.get();
      if (profileViewDoc.exists) {
        return; // already recorded before
      }

      // Add to persistent viewed-profile history
      await profileViewDocRef.set({
        'viewedAt': Timestamp.fromDate(now),
        'liked': wasLiked,
      });
    } catch (e) {
      print('[DailyProfilesNotifier] Error recording profile view: $e');
    }
  }

  /// Get count of profiles viewed today
  Future<int> getViewedCountToday(String uid) async {
    if (_fs == null) return 0;

    try {
      final now = DateTime.now().toUtc();
      final todayStart = DateTime.utc(now.year, now.month, now.day);

      final query =
          await _fs
              .collection('users')
              .doc(uid)
              .collection('dailyProfilesViewed')
              .where(
                'viewedAt',
                isGreaterThanOrEqualTo: Timestamp.fromDate(todayStart),
              )
              .count()
              .get();

      return query.count ?? 0;
    } catch (e) {
      print('[DailyProfilesNotifier] Error getting viewed count: $e');
      return 0;
    }
  }

  /// Check if daily limit reached (5 profiles viewed today)
  Future<bool> isDailyLimitReached(String uid) async {
    final count = await getViewedCountToday(uid);
    return count >= 5;
  }
}

/// Provider for daily profiles notifier
final dailyProfilesNotifierProvider = StateNotifierProvider<
  DailyProfilesNotifier,
  AsyncValue<DailyProfilesState?>
>((ref) {
  final fs = ref.watch(firestoreInstanceProvider);
  return DailyProfilesNotifier(fs);
});

/// Provider to check if daily limit has been reached
final isDailyLimitReachedProvider = FutureProvider.family<bool, String>((
  ref,
  uid,
) async {
  return ref
      .read(dailyProfilesNotifierProvider.notifier)
      .isDailyLimitReached(uid);
});

/// Provider to get today's viewed count
final dailyViewedCountProvider = FutureProvider.family<int, String>((
  ref,
  uid,
) async {
  return ref
      .read(dailyProfilesNotifierProvider.notifier)
      .getViewedCountToday(uid);
});
