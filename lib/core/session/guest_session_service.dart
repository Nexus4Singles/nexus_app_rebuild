import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import '../constants/app_constants.dart';
import 'guest_session.dart';

class GuestSessionService {
  static const _key = 'guest_session_v1';

  final SharedPreferences _prefs;

  GuestSessionService(this._prefs);

  GuestSession? load() {
    final raw = _prefs.getString(_key);
    if (raw == null || raw.isEmpty) return null;

    try {
      final data = jsonDecode(raw) as Map<String, dynamic>;
      final rsName = data['relationshipStatus'] as String?;
      if (rsName == null) return null;

      final rs = RelationshipStatus.values.byName(rsName);

      return GuestSession(
        relationshipStatus: rs,
        gender: data['gender'] as String?,
        goals: (data['goals'] as List?)?.cast<String>() ?? const [],
      );
    } catch (_) {
      return null;
    }
  }

  Future<void> save(GuestSession session) async {
    final data = <String, dynamic>{
      'relationshipStatus': session.relationshipStatus.name,
      'gender': session.gender,
      'goals': session.goals,
    };
    await _prefs.setString(_key, jsonEncode(data));
  }

  Future<void> clear() async {
    await _prefs.remove(_key);
  }
}
