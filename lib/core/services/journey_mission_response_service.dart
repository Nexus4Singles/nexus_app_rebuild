import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

class JourneyMissionResponseService {
  static const _key = 'journeys.mission_responses.v1';

  Future<Map<String, dynamic>> _loadAll() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_key);
    if (raw == null || raw.trim().isEmpty) return <String, dynamic>{};
    final decoded = jsonDecode(raw);
    if (decoded is Map<String, dynamic>) return decoded;
    return <String, dynamic>{};
  }

  Future<void> _saveAll(Map<String, dynamic> map) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_key, jsonEncode(map));
  }

  String _makeKey({
    required String journeyId,
    required String missionId,
    required String cardKey,
  }) {
    return '$journeyId::$missionId::$cardKey';
  }

  Future<String?> loadChoice({
    required String journeyId,
    required String missionId,
    required String cardKey,
  }) async {
    final map = await _loadAll();
    final k = _makeKey(
      journeyId: journeyId,
      missionId: missionId,
      cardKey: cardKey,
    );
    final v = map[k];
    return v is String ? v : null;
  }

  Future<void> saveChoice({
    required String journeyId,
    required String missionId,
    required String cardKey,
    required String selectedOption,
  }) async {
    final map = await _loadAll();
    final k = _makeKey(
      journeyId: journeyId,
      missionId: missionId,
      cardKey: cardKey,
    );
    map[k] = selectedOption;
    await _saveAll(map);
  }

  Future<void> clearMission({
    required String journeyId,
    required String missionId,
  }) async {
    final map = await _loadAll();
    final prefix = '$journeyId::$missionId::';
    map.removeWhere((k, _) => k.startsWith(prefix));
    await _saveAll(map);
  }
}
