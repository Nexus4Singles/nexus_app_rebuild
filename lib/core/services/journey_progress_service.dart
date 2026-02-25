import 'package:shared_preferences/shared_preferences.dart';
import 'firestore_service.dart';

class JourneyProgressService {
  static const _kCompletedPrefix = 'journey_completed_missions:'; // + journeyId
  static const _kLastCompletePrefix =
      'journey_last_complete:'; // + journeyId (yyyy-mm-dd)
  static const _kStreakPrefix = 'journey_streak:'; // + journeyId (int)
  static const _kInProgressPrefix = 'journey_in_progress:'; // + journeyId

  final FirestoreService _firestore;

  JourneyProgressService(this._firestore);

  Future<Set<String>> loadCompletedMissionIds(
    String journeyId,
    String uid,
  ) async {
    try {
      // Try to load from Firestore first (source of truth)
      if (_firestore.isAvailable) {
        final progress = await _firestore.getJourneyProgress(uid, journeyId);
        if (progress != null) {
          final completed = Set<String>.from(progress.completedSessionIds);
          // Cache to SharedPreferences
          final prefs = await SharedPreferences.getInstance();
          await prefs.setStringList(
            '$_kCompletedPrefix$journeyId',
            completed.toList(),
          );
          return completed;
        }
      }
    } catch (e) {
      print('Error loading from Firestore: $e');
    }

    // Fallback to SharedPreferences cache
    final prefs = await SharedPreferences.getInstance();
    final list =
        prefs.getStringList('$_kCompletedPrefix$journeyId') ?? <String>[];
    return list.toSet();
  }

  Future<void> markMissionCompleted(
    String journeyId,
    String missionId,
    String uid,
  ) async {
    final prefs = await SharedPreferences.getInstance();

    // Update local cache first
    final completedKey = '$_kCompletedPrefix$journeyId';
    final current = (prefs.getStringList(completedKey) ?? <String>[]).toSet();
    current.add(missionId);
    await prefs.setStringList(completedKey, current.toList());

    // --- streak update ---
    final today = _todayKey();
    final lastKey = '$_kLastCompletePrefix$journeyId';
    final streakKey = '$_kStreakPrefix$journeyId';

    final last = prefs.getString(lastKey);
    final currentStreak = prefs.getInt(streakKey) ?? 0;

    if (last != today) {
      final yesterday = _yesterdayKey();
      final newStreak = (last == yesterday) ? (currentStreak + 1) : 1;
      await prefs.setInt(streakKey, newStreak);
      await prefs.setString(lastKey, today);
    }

    // Sync to Firestore (non-blocking)
    _syncToFirestore(
      journeyId,
      uid,
      current.toList(),
      lastKey,
      streakKey,
      prefs,
    );
  }

  Future<int> loadStreak(String journeyId, String uid) async {
    try {
      if (_firestore.isAvailable) {
        final progress = await _firestore.getJourneyProgress(uid, journeyId);
        if (progress != null) {
          final streak = progress.currentStreak;
          // Cache it
          final prefs = await SharedPreferences.getInstance();
          await prefs.setInt('$_kStreakPrefix$journeyId', streak);
          return streak;
        }
      }
    } catch (e) {
      print('Error loading streak from Firestore: $e');
    }

    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_kStreakPrefix$journeyId') ?? 0;
  }

  Future<void> resetMission(
    String journeyId,
    String missionId,
    String uid,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final completedKey = '$_kCompletedPrefix$journeyId';
    final current = (prefs.getStringList(completedKey) ?? <String>[]).toSet();
    current.remove(missionId);
    await prefs.setStringList(completedKey, current.toList());

    // Sync removal to Firestore
    _syncToFirestore(journeyId, uid, current.toList(), null, null, prefs);
  }

  /// Mark a mission as in-progress (user started but hasn't completed)
  Future<void> markMissionInProgress(
    String journeyId,
    String missionId,
    String uid,
  ) async {
    final prefs = await SharedPreferences.getInstance();
    final key = '$_kInProgressPrefix$journeyId';
    await prefs.setString(key, missionId);
  }

  /// Get the in-progress mission ID for a journey (if any)
  Future<String?> getInProgressMissionId(String journeyId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_kInProgressPrefix$journeyId');
  }

  /// Clear in-progress when mission is completed
  Future<void> clearInProgress(String journeyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('$_kInProgressPrefix$journeyId');
  }

  /// Non-blocking sync to Firestore
  void _syncToFirestore(
    String journeyId,
    String uid,
    List<String> completedMissions,
    String? lastKey,
    String? streakKey,
    SharedPreferences prefs,
  ) {
    if (!_firestore.isAvailable) return;

    // Fire and forget - don't block the UI
    _firestore
        .updateJourneyProgressFields(uid, journeyId, {
          'completedSessionIdsList': completedMissions,
          'lastSessionAt': lastKey,
          'currentStreak': streakKey != null ? prefs.getInt(streakKey) : 0,
          'updatedAt': DateTime.now().toIso8601String(),
        })
        .catchError((e) => print('Firestore sync error: $e'));
  }

  String _todayKey() {
    final now = DateTime.now();
    return '${now.year.toString().padLeft(4, '0')}-'
        '${now.month.toString().padLeft(2, '0')}-'
        '${now.day.toString().padLeft(2, '0')}';
  }

  String _yesterdayKey() {
    final y = DateTime.now().subtract(const Duration(days: 1));
    return '${y.year.toString().padLeft(4, '0')}-'
        '${y.month.toString().padLeft(2, '0')}-'
        '${y.day.toString().padLeft(2, '0')}';
  }
}
