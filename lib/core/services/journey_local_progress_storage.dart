import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class JourneyLocalProgressStorage {
  static String _key(String journeyId) => 'journey_progress::$journeyId';

  Future<Map<String, dynamic>> _loadRaw(String journeyId) async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key(journeyId));
    if (raw == null || raw.trim().isEmpty) return {};
    try {
      return json.decode(raw) as Map<String, dynamic>;
    } catch (_) {
      return {};
    }
  }

  Future<void> _saveRaw(String journeyId, Map<String, dynamic> data) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key(journeyId), json.encode(data));
  }

  Future<Set<int>> loadCompleted(String journeyId) async {
    final raw = await _loadRaw(journeyId);
    final list = (raw['completedSessions'] as List<dynamic>? ?? []);
    return list.map((e) => e as int).toSet();
  }

  Future<void> markCompleted(String journeyId, int sessionNumber) async {
    final raw = await _loadRaw(journeyId);
    final set = ((raw['completedSessions'] as List<dynamic>? ?? [])
        .map((e) => e as int)
        .toSet());
    set.add(sessionNumber);
    raw['completedSessions'] = set.toList()..sort();
    raw['updatedAt'] = DateTime.now().toIso8601String();
    await _saveRaw(journeyId, raw);
  }

  Future<void> saveSessionAnswer(
    String journeyId,
    int sessionNumber,
    Map<String, dynamic> answer,
  ) async {
    final raw = await _loadRaw(journeyId);
    final answers = (raw['answers'] as Map<String, dynamic>? ?? {});
    answers[sessionNumber.toString()] = answer;
    raw['answers'] = answers;
    raw['updatedAt'] = DateTime.now().toIso8601String();
    await _saveRaw(journeyId, raw);
  }

  Future<Map<String, dynamic>> loadSessionAnswer(
    String journeyId,
    int sessionNumber,
  ) async {
    final raw = await _loadRaw(journeyId);
    final answers = (raw['answers'] as Map<String, dynamic>? ?? {});
    final v = answers[sessionNumber.toString()];
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return Map<String, dynamic>.from(v);
    return {};
  }

  Future<void> clear(String journeyId) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_key(journeyId));
  }
}
