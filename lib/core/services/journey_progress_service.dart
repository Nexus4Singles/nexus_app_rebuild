import 'package:shared_preferences/shared_preferences.dart';

class JourneyProgressService {
  static const _kCompletedPrefix = 'journey_completed_missions:'; // + journeyId
  static const _kLastCompletePrefix =
      'journey_last_complete:'; // + journeyId (yyyy-mm-dd)
  static const _kStreakPrefix = 'journey_streak:'; // + journeyId (int)

  Future<Set<String>> loadCompletedMissionIds(String journeyId) async {
    final prefs = await SharedPreferences.getInstance();
    final list =
        prefs.getStringList('$_kCompletedPrefix$journeyId') ?? <String>[];
    return list.toSet();
  }

  Future<void> markMissionCompleted(String journeyId, String missionId) async {
    final prefs = await SharedPreferences.getInstance();

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

    if (last == today) return; // already counted today

    final yesterday = _yesterdayKey();
    final newStreak = (last == yesterday) ? (currentStreak + 1) : 1;

    await prefs.setInt(streakKey, newStreak);
    await prefs.setString(lastKey, today);
  }

  Future<int> loadStreak(String journeyId) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getInt('$_kStreakPrefix$journeyId') ?? 0;
  }

  Future<void> resetMission(String journeyId, String missionId) async {
    // Placeholder: if later you store mission inputs (text/choices), clear them here.
    // We do NOT un-complete missions here; completion only happens on "I did it".
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
