import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import 'auth_provider.dart';

// ============================================================================
// STREAK DATA MODEL
// ============================================================================

class StreakData {
  final int currentStreak;
  final int longestStreak;
  final DateTime? lastActiveDate;
  final List<DateTime> recentActivity;

  const StreakData({
    this.currentStreak = 0,
    this.longestStreak = 0,
    this.lastActiveDate,
    this.recentActivity = const [],
  });

  factory StreakData.fromMap(Map<String, dynamic>? map) {
    if (map == null) return const StreakData();
    
    DateTime? lastActive;
    if (map['lastActiveDate'] != null) {
      if (map['lastActiveDate'] is Timestamp) {
        lastActive = (map['lastActiveDate'] as Timestamp).toDate();
      }
    }

    List<DateTime> recent = [];
    if (map['recentActivity'] != null) {
      recent = (map['recentActivity'] as List)
          .map((e) => e is Timestamp ? e.toDate() : DateTime.now())
          .toList();
    }

    return StreakData(
      currentStreak: map['currentStreak'] as int? ?? 0,
      longestStreak: map['longestStreak'] as int? ?? 0,
      lastActiveDate: lastActive,
      recentActivity: recent,
    );
  }

  Map<String, dynamic> toMap() => {
    'currentStreak': currentStreak,
    'longestStreak': longestStreak,
    'lastActiveDate': lastActiveDate != null ? Timestamp.fromDate(lastActiveDate!) : null,
    'recentActivity': recentActivity.map((d) => Timestamp.fromDate(d)).toList(),
  };

  /// Get motivational message based on streak
  String get motivationalMessage {
    if (currentStreak == 0) {
      return 'Start your journey today!';
    } else if (currentStreak == 1) {
      return 'Great start! Keep it up tomorrow.';
    } else if (currentStreak < 7) {
      return 'You\'re building great habits!';
    } else if (currentStreak < 14) {
      return 'One week strong! Amazing progress.';
    } else if (currentStreak < 30) {
      return 'You\'re on fire! Keep the momentum.';
    } else if (currentStreak < 60) {
      return 'A month of dedication! Incredible.';
    } else {
      return 'You\'re a streak champion! 🏆';
    }
  }

  /// Check if streak is at risk (no activity today)
  bool get isAtRisk {
    if (lastActiveDate == null) return false;
    final now = DateTime.now();
    final lastDate = DateTime(lastActiveDate!.year, lastActiveDate!.month, lastActiveDate!.day);
    final today = DateTime(now.year, now.month, now.day);
    return lastDate.isBefore(today);
  }
}

// ============================================================================
// STREAK PROVIDER
// ============================================================================

/// Provider for user's streak data
final streakProvider = StreamProvider<StreakData>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  if (userId == null) {
    return Stream.value(const StreakData());
  }

  return FirebaseFirestore.instance
      .collection('users')
      .doc(userId)
      .snapshots()
      .map((doc) {
        final data = doc.data();
        if (data == null) return const StreakData();
        return StreakData.fromMap(data['streak'] as Map<String, dynamic>?);
      });
});

/// Provider to record activity and update streak
final streakServiceProvider = Provider<StreakService>((ref) {
  final userId = ref.watch(currentUserIdProvider);
  return StreakService(userId);
});

class StreakService {
  final String? userId;
  final FirebaseFirestore _firestore = FirebaseFirestore.instance;

  StreakService(this.userId);

  /// Record user activity for today - call this when user completes a session or logs in
  Future<void> recordActivity() async {
    if (userId == null) return;

    try {
      final userRef = _firestore.collection('users').doc(userId);
      final doc = await userRef.get();
      final data = doc.data();
      
      final now = DateTime.now();
      final today = DateTime(now.year, now.month, now.day);
      
      // Get current streak data
      final currentStreak = StreakData.fromMap(data?['streak'] as Map<String, dynamic>?);
      
      // Check if already recorded today
      if (currentStreak.lastActiveDate != null) {
        final lastDate = DateTime(
          currentStreak.lastActiveDate!.year,
          currentStreak.lastActiveDate!.month,
          currentStreak.lastActiveDate!.day,
        );
        if (lastDate == today) {
          // Already recorded today, no update needed
          return;
        }
      }

      // Calculate new streak
      int newStreak = 1;
      if (currentStreak.lastActiveDate != null) {
        final lastDate = DateTime(
          currentStreak.lastActiveDate!.year,
          currentStreak.lastActiveDate!.month,
          currentStreak.lastActiveDate!.day,
        );
        final yesterday = today.subtract(const Duration(days: 1));
        
        if (lastDate == yesterday) {
          // Consecutive day - increment streak
          newStreak = currentStreak.currentStreak + 1;
        }
        // Otherwise, streak resets to 1
      }

      // Update longest streak if needed
      final newLongest = newStreak > currentStreak.longestStreak 
          ? newStreak 
          : currentStreak.longestStreak;

      // Keep last 7 days of activity
      final recentActivity = [...currentStreak.recentActivity, today];
      final last7Days = recentActivity.length > 7 
          ? recentActivity.sublist(recentActivity.length - 7) 
          : recentActivity;

      // Update Firestore
      await userRef.update({
        'streak': {
          'currentStreak': newStreak,
          'longestStreak': newLongest,
          'lastActiveDate': Timestamp.fromDate(today),
          'recentActivity': last7Days.map((d) => Timestamp.fromDate(d)).toList(),
        },
      });

      debugPrint('🔥 Streak updated: $newStreak days (best: $newLongest)');
    } catch (e) {
      debugPrint('Error recording activity: $e');
    }
  }

  /// Reset streak (for testing or manual reset)
  Future<void> resetStreak() async {
    if (userId == null) return;

    try {
      await _firestore.collection('users').doc(userId).update({
        'streak': {
          'currentStreak': 0,
          'longestStreak': 0,
          'lastActiveDate': null,
          'recentActivity': [],
        },
      });
    } catch (e) {
      debugPrint('Error resetting streak: $e');
    }
  }
}

/// Provider for streak milestone badges
final streakMilestonesProvider = Provider<List<StreakMilestone>>((ref) {
  final streakAsync = ref.watch(streakProvider);
  final currentStreak = streakAsync.valueOrNull?.currentStreak ?? 0;

  return [
    StreakMilestone(days: 3, name: 'Getting Started', achieved: currentStreak >= 3),
    StreakMilestone(days: 7, name: 'Week Warrior', achieved: currentStreak >= 7),
    StreakMilestone(days: 14, name: 'Two Week Champion', achieved: currentStreak >= 14),
    StreakMilestone(days: 30, name: 'Monthly Master', achieved: currentStreak >= 30),
    StreakMilestone(days: 60, name: 'Dedication Hero', achieved: currentStreak >= 60),
    StreakMilestone(days: 100, name: 'Century Legend', achieved: currentStreak >= 100),
  ];
});

class StreakMilestone {
  final int days;
  final String name;
  final bool achieved;

  const StreakMilestone({
    required this.days,
    required this.name,
    required this.achieved,
  });
}
