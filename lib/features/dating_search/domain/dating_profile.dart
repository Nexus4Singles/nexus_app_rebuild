import 'package:flutter/foundation.dart';

class DatingProfile {
  // Debug probe limiter (avoid spamming console)
  static int _nameProbeCount = 0;

  final String uid;
  final String name;
  final int age;
  final String gender;

  final String? city;
  final String? country;
  final String? educationLevel;
  final String? profession;

  final List<String> photos;

  final DateTime createdAt;

  /// Normalized to lowercase. 'legacy' if missing.
  final String verificationStatus;

  final String? maritalStatus;
  final String? haveKids;
  final String? genotype;
  final String? regularSourceOfIncome;
  final String? longDistance;

  const DatingProfile({
    required this.uid,
    required this.name,
    required this.age,
    required this.gender,
    this.city,
    this.country,
    this.educationLevel,
    this.profession,
    required this.photos,
    required this.createdAt,
    required this.verificationStatus,
    this.maritalStatus,
    this.haveKids,
    this.genotype,
    this.regularSourceOfIncome,
    this.longDistance,
  });

  bool get isVerified => verificationStatus == 'verified';

  String get displayLocation {
    final c = (city ?? '').trim();
    final k = (country ?? '').trim();
    if (c.isEmpty && k.isEmpty) return '';
    if (c.isEmpty) return k;
    if (k.isEmpty) return c;
    return '$c • $k';
  }

  static DateTime _asDate(dynamic v) {
    if (v == null) return DateTime.fromMillisecondsSinceEpoch(0);
    if (v is DateTime) return v;
    try {
      // Firestore Timestamp has toDate()
      final toDate = v.toDate;
      if (toDate is Function) return toDate() as DateTime;
    } catch (_) {}
    return DateTime.fromMillisecondsSinceEpoch(0);
  }


  static String _pick(Map<String, dynamic> json, List<String> keys) {
    for (final k in keys) {
      final v = json[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return '';
  }

  static String? _pickNullable(Map<String, dynamic> json, List<String> keys) {
    final v = _pick(json, keys);
    return v.isEmpty ? null : v;
  }


  factory DatingProfile.fromFirestore(String uid, Map<String, dynamic> json) {
    String _resolveName(Map<String, dynamic> j) {
      String? pick(dynamic v) {
        if (v == null) return null;
        final s = v.toString().trim();
        return s.isEmpty ? null : s;
      }

      // v1/v2 common keys (and common naming variants)
      final candidates = <dynamic>[
        j['username'],
        j['name'],
        j['displayName'],
        j['display_name'],
        j['fullName'],
        j['full_name'],
      ];

      for (final c in candidates) {
        final v = pick(c);
        if (v != null) return v;
      }

      return 'User';
    }

    String? _pickStringFromMap(Map<String, dynamic>? m, List<String> keys) {
      if (m == null) return null;
      for (final key in keys) {
        final v = m[key];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    String? _pickStringCaseInsensitive(
      Map<String, dynamic>? m,
      List<String> keysLower,
    ) {
      if (m == null) return null;
      final lowerToActual = <String, String>{};
      for (final k in m.keys) {
        lowerToActual[k.toLowerCase()] = k;
      }
      for (final wantedLower in keysLower) {
        final actual = lowerToActual[wantedLower];
        if (actual == null) continue;
        final v = m[actual];
        if (v == null) continue;
        final s = v.toString().trim();
        if (s.isNotEmpty) return s;
      }
      return null;
    }

    Map<String, dynamic>? _asMap(dynamic v) {
      if (v is Map<String, dynamic>) return v;
      if (v is Map) return v.cast<String, dynamic>();
      return null;
    }

    String _resolveDisplayName() {
      final root = json;
      final dating = _asMap(root['dating']);
      final profile = _asMap(root['profile']);
      final public = _asMap(root['public']);
      final user = _asMap(root['user']);
      final datingProfile = _asMap(root['datingProfile']);

      final direct =
          _pickStringFromMap(root, [
            'name',
            'username',
            'displayName',
            'fullName',
          ]) ??
          _pickStringCaseInsensitive(root, [
            'name',
            'username',
            'displayname',
            'fullname',
          ]) ??
          _pickStringFromMap(public, [
            'name',
            'username',
            'displayName',
            'fullName',
          ]) ??
          _pickStringCaseInsensitive(public, [
            'name',
            'username',
            'displayname',
            'fullname',
          ]) ??
          _pickStringFromMap(profile, [
            'name',
            'username',
            'displayName',
            'fullName',
          ]) ??
          _pickStringCaseInsensitive(profile, [
            'name',
            'username',
            'displayname',
            'fullname',
          ]) ??
          _pickStringFromMap(user, [
            'name',
            'username',
            'displayName',
            'fullName',
          ]) ??
          _pickStringCaseInsensitive(user, [
            'name',
            'username',
            'displayname',
            'fullname',
          ]) ??
          _pickStringFromMap(dating, [
            'name',
            'username',
            'displayName',
            'fullName',
          ]) ??
          _pickStringCaseInsensitive(dating, [
            'name',
            'username',
            'displayname',
            'fullname',
          ]) ??
          _pickStringFromMap(datingProfile, [
            'name',
            'username',
            'displayName',
            'fullName',
          ]) ??
          _pickStringCaseInsensitive(datingProfile, [
            'name',
            'username',
            'displayname',
            'fullname',
          ]);

      if (direct != null && direct.trim().isNotEmpty) return direct.trim();

      String? first =
          _pickStringFromMap(root, ['firstName', 'first_name']) ??
          _pickStringCaseInsensitive(root, ['firstname', 'first_name']) ??
          _pickStringFromMap(profile, ['firstName', 'first_name']) ??
          _pickStringCaseInsensitive(profile, ['firstname', 'first_name']) ??
          _pickStringFromMap(user, ['firstName', 'first_name']) ??
          _pickStringCaseInsensitive(user, ['firstname', 'first_name']) ??
          _pickStringFromMap(public, ['firstName', 'first_name']) ??
          _pickStringCaseInsensitive(public, ['firstname', 'first_name']);

      String? last =
          _pickStringFromMap(root, ['lastName', 'last_name']) ??
          _pickStringCaseInsensitive(root, ['lastname', 'last_name']) ??
          _pickStringFromMap(profile, ['lastName', 'last_name']) ??
          _pickStringCaseInsensitive(profile, ['lastname', 'last_name']) ??
          _pickStringFromMap(user, ['lastName', 'last_name']) ??
          _pickStringCaseInsensitive(user, ['lastname', 'last_name']) ??
          _pickStringFromMap(public, ['lastName', 'last_name']) ??
          _pickStringCaseInsensitive(public, ['lastname', 'last_name']);

      final combined = ('${first ?? ''} ${last ?? ''}').trim();
      if (combined.isNotEmpty) return combined;

      return '';
    }

    final photosRaw = json['photos'];
    final photos =
        (photosRaw is List)
            ? photosRaw.map((e) => e.toString()).toList()
            : <String>[];

    final dating = json['dating'];
    final status =
        (dating is Map) ? (dating['verificationStatus'] ?? '').toString() : '';
    final normalizedVerificationStatus =
        status.toLowerCase().trim().isNotEmpty
            ? status.toLowerCase().trim()
            : 'legacy';

    final resolvedName = _resolveDisplayName();
    if (kDebugMode && _nameProbeCount < 3) {
      _nameProbeCount++;
      // ignore: avoid_print
      print('[NameProbe] users/$uid -> resolvedName="$resolvedName"');
      // ignore: avoid_print
      print('[NameProbe] root keys=${json.keys.toList()}');
      // ignore: avoid_print
      print(
        '[NameProbe] root.name=${json['name']} root.username=${json['username']} root.displayName=${json['displayName']} root.fullName=${json['fullName']}',
      );
      final datingMap = json['dating'];
      // ignore: avoid_print
      print(
        '[NameProbe] dating=${datingMap is Map ? datingMap.keys.toList() : datingMap}',
      );
    }

    final compat = (json['compatibility'] is Map)
        ? (json['compatibility'] as Map).cast<String, dynamic>()
        : null;

    return DatingProfile(
      uid: uid,
      // v1 uses username/name interchangeably; prefer name, then username.
      name: _resolveName(json),

      age:
          (json['age'] is int)
              ? json['age'] as int
              : int.tryParse('${json['age']}') ?? 0,

      // v1 key is usually 'gender' already; keep as-is but normalize.
      gender: (json['gender'] ?? '').toString().toLowerCase(),

      // v1 stores these as snake_case; v2 may store camelCase.
      city: _pickNullable(json, ['city']),
      country: _pickNullable(json, [
        'country',
        'countryOfResidence',
        'country_of_residence',
        'countryOfResidenceFilters',
        'country_of_resident',
      ]),

      // profession often exists already in v1
      profession: _pickNullable(json, ['profession']),

      photos: photos,
      createdAt: _asDate(json['createdAt']),

      verificationStatus: normalizedVerificationStatus,

            // Filters (IMPORTANT): hydrate from v1 + v2 keys (root first, then compatibility map)
      educationLevel: _pickNullable(json, [
        'educationLevel',
        'education_level',
      ]) ??
          _pickStringFromMap(compat, [
            'educationLevel',
            'education_level',
            'education',
          ]),
      maritalStatus: _pickNullable(json, [
        'maritalStatus',
        'marital_status',
      ]) ??
          _pickStringFromMap(compat, [
            'maritalStatus',
            'marital_status',
          ]),
      haveKids: _pickNullable(json, [
        'haveKids',
        'hasKids',
        'have_kids',
        'has_kids',
      ]) ??
          _pickStringFromMap(compat, [
            'haveKids',
            'hasKids',
            'have_kids',
            'has_kids',
            'kids',
          ]),
      genotype: _pickNullable(json, [
        'genotype',
      ]) ??
          _pickStringFromMap(compat, [
            'genotype',
          ]),
      regularSourceOfIncome: _pickNullable(json, [
        'regularSourceOfIncome',
        'regular_source_of_income',
        'source_of_income',
        'incomeSource',
        'income_source',
        'income',
      ]) ??
          _pickStringFromMap(compat, [
            'regularSourceOfIncome',
            'regular_source_of_income',
            'source_of_income',
            'incomeSource',
            'income_source',
            'income',
          ]),
      longDistance: _pickNullable(json, [
        'longDistance',
        'long_distance',
        'relationshipDistance',
        'relationship_distance',
      ]) ??
          _pickStringFromMap(compat, [
            'longDistance',
            'long_distance',
            'relationshipDistance',
            'relationship_distance',
            'distance',
          ]),
    );
}
}
