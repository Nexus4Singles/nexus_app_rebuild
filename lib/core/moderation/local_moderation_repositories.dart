import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';

import 'moderation_models.dart';

/// SharedPreferences keys (v1)
String _blocksKey(String viewerKey) => 'nexus_blocks_v1_' + viewerKey;
String _reportsKey(String reporterKey) => 'nexus_reports_v1_' + reporterKey;

class LocalBlockRepository {
  const LocalBlockRepository();

  Future<Set<String>> loadBlockedUids(String viewerKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_blocksKey(viewerKey));
      if (raw == null || raw.isEmpty) return <String>{};

      final decoded = jsonDecode(raw);
      if (decoded is! Map<String, dynamic>) return <String>{};

      final blocked = decoded['blocked'];
      if (blocked is! List) return <String>{};

      final out = <String>{};
      for (final e in blocked) {
        if (e is Map<String, dynamic>) {
          final uid = (e['uid'] ?? '').toString().trim();
          if (uid.isNotEmpty) out.add(uid);
        } else {
          // tolerate older formats: list of strings
          final uid = (e ?? '').toString().trim();
          if (uid.isNotEmpty) out.add(uid);
        }
      }
      return out;
    } catch (_) {
      return <String>{};
    }
  }

  Future<void> block(String viewerKey, String blockedUid) async {
    final uid = blockedUid.trim();
    if (uid.isEmpty) return;

    final current = await loadBlockedUids(viewerKey);
    if (current.contains(uid)) return;

    final next = {...current, uid};
    await _save(viewerKey, next);
  }

  Future<void> unblock(String viewerKey, String blockedUid) async {
    final uid = blockedUid.trim();
    if (uid.isEmpty) return;

    final current = await loadBlockedUids(viewerKey);
    if (!current.contains(uid)) return;

    final next = {...current}..remove(uid);
    await _save(viewerKey, next);
  }

  Future<void> _save(String viewerKey, Set<String> blockedUids) async {
    final prefs = await SharedPreferences.getInstance();

    final payload = <String, dynamic>{
      'version': 1,
      'blocked':
          blockedUids
              .map(
                (u) => {
                  'uid': u,
                  'createdAtMs': DateTime.now().millisecondsSinceEpoch,
                },
              )
              .toList(),
    };

    await prefs.setString(_blocksKey(viewerKey), jsonEncode(payload));
  }
}

class LocalReportRepository {
  const LocalReportRepository();

  Future<void> submitReport(UserReportRecord record) async {
    final prefs = await SharedPreferences.getInstance();
    final key = _reportsKey(record.reporterKey);

    List<dynamic> list = <dynamic>[];
    try {
      final raw = prefs.getString(key);
      if (raw != null && raw.isNotEmpty) {
        final decoded = jsonDecode(raw);
        if (decoded is List) list = decoded;
      }
    } catch (_) {
      list = <dynamic>[];
    }

    list.add(record.toJson());

    // Keep local store bounded (Phase 1 only)
    const maxItems = 100;
    if (list.length > maxItems) {
      list = list.sublist(list.length - maxItems);
    }

    await prefs.setString(key, jsonEncode(list));
  }

  Future<List<UserReportRecord>> loadReports(String reporterKey) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final raw = prefs.getString(_reportsKey(reporterKey));
      if (raw == null || raw.isEmpty) return const [];

      final decoded = jsonDecode(raw);
      if (decoded is! List) return const [];

      final out = <UserReportRecord>[];
      for (final e in decoded) {
        final rec = UserReportRecord.fromJson(e);
        if (rec != null) out.add(rec);
      }
      return out;
    } catch (_) {
      return const [];
    }
  }
}
