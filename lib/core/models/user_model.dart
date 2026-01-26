import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:equatable/equatable.dart';
import '../constants/app_constants.dart';

/// Nexus 2.0 extension data stored in users/{uid}/nexus2
/// This keeps Nexus 1.0 fields untouched and adds new fields safely
class Nexus2Data extends Equatable {
  final String relationshipStatus;
  final String gender;
  final List<String> primaryGoals;
  final bool onboardingCompleted;
  final DateTime? onboardedAt;
  final int schemaVersion;
  final DateTime? lastActiveAt;
  final Map<String, dynamic>? experiments;

  const Nexus2Data({
    required this.relationshipStatus,
    required this.gender,
    this.primaryGoals = const [],
    this.onboardingCompleted = false,
    this.onboardedAt,
    this.schemaVersion = AppConfig.nexus2SchemaVersion,
    this.lastActiveAt,
    this.experiments,
  });

  /// Create from Firestore document
  factory Nexus2Data.fromMap(Map<String, dynamic>? map) {
    if (map == null) {
      return const Nexus2Data(relationshipStatus: '', gender: '');
    }

    // Normalize gender for v1/v2 compatibility
    final rawGender = map['gender'] as String? ?? '';
    final normalizedGender =
        rawGender.isNotEmpty
            ? (UserModel._normalizeGender(rawGender) ?? rawGender)
            : '';

    return Nexus2Data(
      relationshipStatus: map['relationshipStatus'] as String? ?? '',
      gender: normalizedGender,
      primaryGoals:
          (map['primaryGoals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      onboardingCompleted:
          UserModel._boolFrom(map['onboardingCompleted']) ?? false,
      onboardedAt: (map['onboardedAt'] as Timestamp?)?.toDate(),
      schemaVersion:
          map['schemaVersion'] as int? ?? AppConfig.nexus2SchemaVersion,
      lastActiveAt: (map['lastActiveAt'] as Timestamp?)?.toDate(),
      experiments: map['experiments'] as Map<String, dynamic>?,
    );
  }

  /// Convert to map for Firestore
  Map<String, dynamic> toMap() {
    return {
      'relationshipStatus': relationshipStatus,
      'gender': gender,
      'primaryGoals': primaryGoals,
      'onboardingCompleted': onboardingCompleted,
      'onboardedAt':
          onboardedAt != null ? Timestamp.fromDate(onboardedAt!) : null,
      'schemaVersion': schemaVersion,
      'lastActiveAt':
          lastActiveAt != null ? Timestamp.fromDate(lastActiveAt!) : null,
      if (experiments != null) 'experiments': experiments,
    };
  }

  /// Convert to update map for Firestore (prefixed with nexus2.)
  Map<String, dynamic> toNexus2UpdateMap() {
    return {'nexus2': toMap()};
  }

  /// Create a copy with updated fields
  Nexus2Data copyWith({
    String? relationshipStatus,
    String? gender,
    List<String>? primaryGoals,
    bool? onboardingCompleted,
    DateTime? onboardedAt,
    int? schemaVersion,
    DateTime? lastActiveAt,
    Map<String, dynamic>? experiments,
  }) {
    return Nexus2Data(
      relationshipStatus: relationshipStatus ?? this.relationshipStatus,
      gender: gender ?? this.gender,
      primaryGoals: primaryGoals ?? this.primaryGoals,
      onboardingCompleted: onboardingCompleted ?? this.onboardingCompleted,
      onboardedAt: onboardedAt ?? this.onboardedAt,
      schemaVersion: schemaVersion ?? this.schemaVersion,
      lastActiveAt: lastActiveAt ?? this.lastActiveAt,
      experiments: experiments ?? this.experiments,
    );
  }

  /// Helper getters
  RelationshipStatus get relationshipStatusEnum =>
      RelationshipStatus.fromValue(relationshipStatus);

  Gender get genderEnum => Gender.fromValue(gender);

  List<UserGoal> get primaryGoalsEnum =>
      primaryGoals.map((g) => UserGoal.fromValue(g)).toList();

  bool get isValid =>
      relationshipStatus.isNotEmpty && gender.isNotEmpty && onboardingCompleted;

  bool get isSingle =>
      relationshipStatusEnum == RelationshipStatus.singleNeverMarried ||
      relationshipStatusEnum == RelationshipStatus.divorced;

  bool get isMarried => relationshipStatusEnum == RelationshipStatus.married;

  @override
  List<Object?> get props => [
    relationshipStatus,
    gender,
    primaryGoals,
    onboardingCompleted,
    onboardedAt,
    schemaVersion,
    lastActiveAt,
    experiments,
  ];
}

/// Complete User model that extends Nexus 1.0 schema
/// Maintains backward compatibility with existing users/{uid} documents
class UserModel extends Equatable {
  /// Accepts bools from Firestore that may be stored as bool, string ("true"/"false"),
  /// or num (1/0). Returns null if not parseable.
  static bool? _boolFrom(dynamic v) {
    if (v == null) return null;
    if (v is bool) return v;
    if (v is num) return v != 0;
    if (v is String) {
      final t = v.trim().toLowerCase();
      if (t == 'true' || t == '1' || t == 'yes') return true;
      if (t == 'false' || t == '0' || t == 'no') return false;
    }
    return null;
  }

  // ignore: unused_element
  static String? _pickString(Map<String, dynamic> data, List<String> keys) {
    for (final k in keys) {
      final v = data[k];
      if (v == null) continue;
      final s = v.toString().trim();
      if (s.isNotEmpty) return s;
    }
    return null;
  }

  static Map<String, dynamic>? _map(dynamic v) {
    if (v == null) return null;
    if (v is Map<String, dynamic>) return v;
    if (v is Map) return v.cast<String, dynamic>();
    return null;
  }

  static dynamic _getPath(Map<String, dynamic> root, List<String> path) {
    dynamic cur = root;
    for (final key in path) {
      if (cur is Map) {
        cur = cur[key];
      } else {
        return null;
      }
    }
    return cur;
  }

  static String? _stringFrom(dynamic v) {
    if (v == null) return null;
    final s = v.toString().trim();
    return s.isEmpty ? null : s;
  }

  /// Normalize gender for v1/v2 compatibility
  /// V1 stored "Male"/"Female", v2 uses "male"/"female"
  static String? _normalizeGender(String? gender) {
    if (gender == null) return null;
    final normalized = gender.trim().toLowerCase();
    if (normalized == 'male' || normalized == 'female') return normalized;
    return gender; // Return as-is if not recognized
  }

  static int? _intFrom(dynamic v) {
    if (v == null) return null;
    if (v is int) return v;
    if (v is num) return v.toInt();
    return int.tryParse(v.toString());
  }

  static String? _firstString(
    Map<String, dynamic> root,
    List<List<String>> paths,
  ) {
    for (final p in paths) {
      final v = _getPath(root, p);
      final s = _stringFrom(v);
      if (s != null) return s;
    }
    return null;
  }

  static List<String> _firstStringList(
    Map<String, dynamic> root,
    List<List<String>> paths,
  ) {
    for (final p in paths) {
      final v = _getPath(root, p);
      final list = _parseStringList(v) ?? const <String>[];
      if (list.isNotEmpty) return list;
    }
    return const <String>[];
  }

  // ========================
  // NEXUS 1.0 FIELDS (DO NOT MODIFY)
  // ========================
  final String id;
  final String? name;
  final String? username;
  final String? email;
  final String? profileUrl;
  final int? age;
  final String? gender;
  final String? bestQualotiesOrTraits;

  // Backward/forward compatibility: UI expects the correctly-spelled name.
  String? get bestQualitiesOrTraits => bestQualotiesOrTraits;

  final String? city;
  final int? countLike;
  final String? desiredQualities;
  final List<String>? hobbies;
  final List<String>? photos;
  final List<String>? audioPrompts;
  final List<String>? likeMe;
  final List<String>? myLikes;
  final List<String>? mySaves;
  final List<String>? blocked;
  final List<String>? usersChatWarning;
  final List<String>? matchedUsers;
  final List<String>? unRecommendUsers;
  final String? educationLevel;
  final String? profession;
  final String? relationshipWithGod;
  final String? roleOfHusband;
  final String? stateOfOrigin;
  final bool? isVerified;
  final String? notificationToken;
  final String? phoneNumber;
  final String? registrationProgress;
  final String? country;
  final String? countryCode; // ISO-2 country code for country of residence
  final String? nationality;
  final String? nationalityCode; // ISO-2 country code for nationality
  final String? facebookUsername;
  final String? instagramUsername;
  final String? twitterUsername;
  final String? telegramUsername;
  final String? snapchatUsername;
  final String? churchName;
  final Map<String, dynamic>? compatibility;
  final bool? compatibilitySetted;
  final Map<String, dynamic>? location;
  final String? fcmToken;
  final bool? onPremium;
  final bool? prevSubscribed;
  final DateTime? subExpDate;
  final bool? usedOneFreeText;
  final bool? entitledUser;
  final String? subscriberId;
  final DateTime? recommendedTime;
  final bool? hasExternalSubscriptionFlow;
  final DateTime? profileCompletionDate;

  // ========================
  // NEXUS 2.0 EXTENSION
  // ========================
  final Nexus2Data? nexus2;

  const UserModel({
    required this.id,
    this.name,
    this.username,
    this.email,
    this.profileUrl,
    this.age,
    this.gender,
    this.bestQualotiesOrTraits,
    this.city,
    this.countLike,
    this.desiredQualities,
    this.hobbies,
    this.photos,
    this.audioPrompts,
    this.likeMe,
    this.myLikes,
    this.mySaves,
    this.blocked,
    this.usersChatWarning,
    this.matchedUsers,
    this.unRecommendUsers,
    this.educationLevel,
    this.profession,
    this.relationshipWithGod,
    this.roleOfHusband,
    this.stateOfOrigin,
    this.isVerified,
    this.notificationToken,
    this.phoneNumber,
    this.registrationProgress,
    this.country,
    this.countryCode,
    this.nationality,
    this.nationalityCode,
    this.facebookUsername,
    this.instagramUsername,
    this.twitterUsername,
    this.telegramUsername,
    this.snapchatUsername,
    this.churchName,
    this.compatibility,
    this.compatibilitySetted,
    this.location,
    this.fcmToken,
    this.onPremium,
    this.prevSubscribed,
    this.subExpDate,
    this.usedOneFreeText,
    this.entitledUser,
    this.subscriberId,
    this.recommendedTime,
    this.hasExternalSubscriptionFlow,
    this.profileCompletionDate,
    this.nexus2,
  });

  /// Create from Firestore document
  factory UserModel.fromDocument(DocumentSnapshot<Map<String, dynamic>> doc) {
    final data = doc.data();
    if (data == null) {
      return UserModel(id: doc.id);
    }
    return UserModel.fromMap(doc.id, data);
  }

  /// Create from Firestore query document
  factory UserModel.fromQueryDocument(
    QueryDocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    final data = doc.data();
    return UserModel.fromMap(doc.id, data);
  }

  /// Create from Firestore data with id
  factory UserModel.fromFirestore(Map<String, dynamic> data, String id) {
    return UserModel.fromMap(id, data);
  }

  factory UserModel.fromMap(String id, Map<String, dynamic> data) {
    // v2 commonly nests values under nexus2 / dating. We read v1 first, then v2 paths.
    final dating = _map(data['dating']);
    final nexus2 = _map(data['nexus2']);
    final reviewPack =
        _map(dating?['reviewPack']) ?? _map(nexus2?['reviewPack']);

    // Audio prompts:
    // - v2 preferred: dating.reviewPack.audioUrls
    // - v2 new onboarding: dating.audioPrompts
    // - v1 fallback: audioPrompts
    // - legacy fallback: audio1Url/audio2Url/audio3Url
    final audioUrls = <String>[
      ...(_parseStringList(reviewPack?['audioUrls']) ?? const <String>[]),
      ...(_parseStringList(dating?['audioPrompts']) ?? const <String>[]),
      ...(_parseStringList(data['audioPrompts']) ?? const <String>[]),
    ];

    bool _looksLikeUrl(String s) {
      final t = s.trim().toLowerCase();
      return t.startsWith('http://') ||
          t.startsWith('https://') ||
          t.startsWith('gs://');
    }

    // v1 audio fields were stored under the 3 question keys (snake_case / camelCase).
    final v1AudioCandidates = <String?>[
      _stringFrom(data['relationship_with_god'] ?? data['relationshipWithGod']),
      _stringFrom(data['role_of_husband'] ?? data['roleOfHusband']),
      _stringFrom(
        data['best_qualities_or_traits'] ??
            data['bestQualitiesOrTraits'] ??
            data['bestQualotiesOrTraits'],
      ),
    ];

    for (final a in v1AudioCandidates) {
      if (a == null) continue;
      if (!_looksLikeUrl(a)) continue;
      if (!audioUrls.contains(a)) audioUrls.add(a);
    }

    return UserModel(
      id: id,
      name: _firstString(data, [
        ['name'],
        ['displayName'],
        ['nexus2', 'profile', 'name'],
        ['dating', 'profile', 'name'],
      ]),
      username: _firstString(data, [
        ['username'],
        ['userName'],
        ['handle'], // v1 legacy
        ['user_name'], // v1 snake_case
        ['displayName'], // some v1 users
        ['nexus2', 'profile', 'username'],
        ['dating', 'profile', 'username'],
      ]),

      email: _firstString(data, [
        ['email'],
        ['nexus2', 'profile', 'email'],
      ]),
      profileUrl: _firstString(data, [
        ['profileUrl'],
        ['photoUrl'],
        ['avatarUrl'],
        ['nexus2', 'profile', 'profileUrl'],
        ['dating', 'profile', 'profileUrl'],
      ]),
      age:
          _intFrom(_getPath(data, ['age'])) ??
          _intFrom(_getPath(data, ['nexus2', 'profile', 'age'])) ??
          _intFrom(_getPath(data, ['dating', 'profile', 'age'])),
      gender: _normalizeGender(
        _firstString(data, [
          ['gender'],
          ['nexus2', 'profile', 'gender'],
          ['dating', 'profile', 'gender'],
        ]),
      ),
      // Note: typo in original v1 key: bestQualotiesOrTraits
      bestQualotiesOrTraits: _firstString(data, [
        ['bestQualitiesOrTraits'],
        ['best_qualities_or_traits'], // v1 snake_case
        ['nexus2', 'profile', 'bestQualitiesOrTraits'],
        ['dating', 'profile', 'bestQualitiesOrTraits'],
      ]),
      city: _firstString(data, [
        ['city'],
        ['location', 'city'], // v1 nested
        ['nexus2', 'profile', 'city'],
        ['dating', 'profile', 'city'],
      ]),

      countLike: _intFrom(_getPath(data, ['countLike'])),
      desiredQualities: _firstString(data, [
        ['desiredQualities'],
        ['desired_qualities'], // v1 snake_case
        ['partnerQualities'], // legacy wording
        ['nexus2', 'profile', 'desiredQualities'],
        ['dating', 'profile', 'desiredQualities'],
      ]),

      hobbies: _firstStringList(data, [
        ['hobbies'],
        ['nexus2', 'profile', 'hobbies'],
        ['dating', 'profile', 'hobbies'],
      ]),
      photos: _firstStringList(data, [
        ['photos'],
        ['nexus2', 'profile', 'photos'],
        ['dating', 'profile', 'photos'],
        ['dating', 'photos'],
      ]),
      audioPrompts: audioUrls,
      likeMe: _parseStringList(data['likeMe']),
      myLikes: _parseStringList(data['myLikes']),
      mySaves: _parseStringList(data['mySaves']),
      blocked: _parseStringList(data['blocked']),
      usersChatWarning: _parseStringList(data['usersChatWarning']),
      matchedUsers: _parseStringList(data['matchedUsers']),
      unRecommendUsers: _parseStringList(data['unRecommendUsers']),
      educationLevel: _firstString(data, [
        ['educationLevel'],
        ['education_level'], // ← ADD
        ['education'], // ← ADD
        ['nexus2', 'profile', 'educationLevel'],
        ['dating', 'profile', 'educationLevel'],
      ]),

      profession: _firstString(data, [
        ['profession'],
        ['nexus2', 'profile', 'profession'],
        ['dating', 'profile', 'profession'],
      ]),
      relationshipWithGod: _firstString(data, [
        ['relationshipWithGod'],
        ['relationship_with_god'],
        ['nexus2', 'profile', 'relationshipWithGod'],
      ]),

      roleOfHusband: _firstString(data, [
        ['roleOfHusband'],
        ['role_of_husband'],
        ['nexus2', 'profile', 'roleOfHusband'],
      ]),

      stateOfOrigin: _firstString(data, [
        ['stateOfOrigin'],
        ['nexus2', 'profile', 'stateOfOrigin'],
      ]),
      isVerified: UserModel._boolFrom(data['isVerified']),
      notificationToken: _stringFrom(data['notificationToken']),
      phoneNumber: _firstString(data, [
        ['phoneNumber'],
        ['phone'],
        ['nexus2', 'profile', 'phoneNumber'],
        ['dating', 'profile', 'phoneNumber'],
      ]),
      registrationProgress: _stringFrom(data['registrationProgress']),
      country: _firstString(data, [
        // v1: residence display sometimes stored as location.place ("Lagos, Nigeria")
        ['location', 'place'],
        ['country'],
        ['countryOfResidence'], // v1 search schema
        ['country_name'],
        ['nexus2', 'profile', 'country'],
        ['dating', 'profile', 'country'],
      ]),

      countryCode: _firstString(data, [
        ['countryCode'],
        ['country_code'],
        ['countryIso'],
        ['nexus2', 'profile', 'countryCode'],
        ['dating', 'profile', 'countryCode'],
      ]),

      nationality: _firstString(data, [
        ['nationality'],
        ['nationalityName'],
        ['nationality_name'], // v1 variant
        ['citizenship'], // legacy
        ['countryOfOrigin'], // v1 variant
        ['country_of_origin'], // v1 snake_case
        ['country'], // v1: top-level country often stored as nationality
        ['location', 'country'], // v1: nationality wrongly nested here
        ['nexus2', 'profile', 'nationality'],
        ['dating', 'profile', 'nationality'],
      ]),

      nationalityCode: _firstString(data, [
        ['nationalityCode'],
        ['nationality_code'],
        ['countryOfOriginCode'], // v1 variant
        ['country_of_origin_code'], // v1 snake_case
        ['nexus2', 'profile', 'nationalityCode'],
        ['dating', 'profile', 'nationalityCode'],
      ]),

      facebookUsername: _firstString(data, [
        ['facebookUsername'],
        ['nexus2', 'profile', 'facebookUsername'],
      ]),
      instagramUsername: _firstString(data, [
        ['instagramUsername'],
        ['nexus2', 'profile', 'instagramUsername'],
      ]),
      twitterUsername: _firstString(data, [
        ['twitterUsername'],
        ['nexus2', 'profile', 'twitterUsername'],
      ]),
      telegramUsername: _firstString(data, [
        ['telegramUsername'],
        ['nexus2', 'profile', 'telegramUsername'],
      ]),
      snapchatUsername: _firstString(data, [
        ['snapchatUsername'],
        ['nexus2', 'profile', 'snapchatUsername'],
      ]),
      churchName: _firstString(data, [
        ['churchName'],
        ['church_name'], // v1 snake_case
        ['church'], // legacy
        ['nexus2', 'profile', 'churchName'],
        ['dating', 'profile', 'churchName'],
      ]),

      compatibility: data['compatibility'] as Map<String, dynamic>?,
      compatibilitySetted:
          UserModel._boolFrom(data['compatibilitySetted']) ??
          UserModel._boolFrom(data['compatibility_setted']) ??
          UserModel._boolFrom(data['compatibilitysetted']),
      location:
          _getPath(data, ['location']) as Map<String, dynamic>? ??
          _getPath(data, ['nexus2', 'profile', 'location'])
              as Map<String, dynamic>? ??
          _getPath(data, ['dating', 'profile', 'location'])
              as Map<String, dynamic>?,

      fcmToken: _stringFrom(data['fcmToken']),
      onPremium: UserModel._boolFrom(data['onPremium']),
      prevSubscribed: UserModel._boolFrom(data['prevSubscribed']),
      subExpDate: _parseTimestamp(data['subExpDate']),
      usedOneFreeText: UserModel._boolFrom(data['usedOneFreeText']),
      entitledUser: UserModel._boolFrom(data['entitledUser']),
      subscriberId: _stringFrom(data['subscriberId']),
      recommendedTime: _parseTimestamp(data['recommendedTime']),
      hasExternalSubscriptionFlow: UserModel._boolFrom(
        data['hasExternalSubscriptionFlow'],
      ),
      profileCompletionDate: _parseTimestamp(data['profileCompletionDate']),
      nexus2: Nexus2Data.fromMap(data['nexus2'] as Map<String, dynamic>?),
    );
  }

  /// Convert to map - ONLY includes Nexus 2.0 fields for update
  /// Use this when updating only Nexus 2.0 data
  Map<String, dynamic> toNexus2UpdateMap() {
    return {'nexus2': nexus2?.toMap()};
  }

  /// Convert full model to map (for reference only - use with caution)
  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'username': username,
      'email': email,
      'profileUrl': profileUrl,
      'age': age,
      'gender': gender,
      'bestQualotiesOrTraits': bestQualotiesOrTraits,

      'city': city,
      'countLike': countLike,
      'desiredQualities': desiredQualities,
      'hobbies': hobbies,
      'photos': photos,
      'audioPrompts': audioPrompts,
      'likeMe': likeMe,
      'myLikes': myLikes,
      'mySaves': mySaves,
      'blocked': blocked,
      'usersChatWarning': usersChatWarning,
      'matchedUsers': matchedUsers,
      'unRecommendUsers': unRecommendUsers,
      'educationLevel': educationLevel,
      'profession': profession,
      'relationshipWithGod': relationshipWithGod,
      'roleOfHusband': roleOfHusband,
      'stateOfOrigin': stateOfOrigin,
      'isVerified': isVerified,
      'notificationToken': notificationToken,
      'phoneNumber': phoneNumber,
      'registrationProgress': registrationProgress,
      'country': country,
      'countryCode': countryCode,
      'nationality': nationality,
      'nationalityCode': nationalityCode,
      'facebookUsername': facebookUsername,
      'instagramUsername': instagramUsername,
      'twitterUsername': twitterUsername,
      'telegramUsername': telegramUsername,
      'snapchatUsername': snapchatUsername,
      'churchName': churchName,
      'compatibility': compatibility,
      'compatibilitySetted': compatibilitySetted,
      'location': location,
      'fcmToken': fcmToken,
      'onPremium': onPremium,
      'prevSubscribed': prevSubscribed,
      'subExpDate': subExpDate != null ? Timestamp.fromDate(subExpDate!) : null,
      'usedOneFreeText': usedOneFreeText,
      'entitledUser': entitledUser,
      'subscriberId': subscriberId,
      'recommendedTime':
          recommendedTime != null ? Timestamp.fromDate(recommendedTime!) : null,
      'hasExternalSubscriptionFlow': hasExternalSubscriptionFlow,
      'profileCompletionDate':
          profileCompletionDate != null
              ? Timestamp.fromDate(profileCompletionDate!)
              : null,
      'nexus2': nexus2?.toMap(),
    };
  }

  UserModel copyWith({
    String? id,
    String? name,
    String? username,
    String? email,
    String? profileUrl,
    int? age,
    String? gender,
    String? bestQualotiesOrTraits,
    String? city,
    int? countLike,
    String? desiredQualities,
    List<String>? hobbies,
    List<String>? photos,
    List<String>? audioPrompts,
    List<String>? likeMe,
    List<String>? myLikes,
    List<String>? mySaves,
    List<String>? blocked,
    List<String>? usersChatWarning,
    List<String>? matchedUsers,
    List<String>? unRecommendUsers,
    String? educationLevel,
    String? profession,
    String? relationshipWithGod,
    String? roleOfHusband,
    String? stateOfOrigin,
    bool? isVerified,
    String? notificationToken,
    String? phoneNumber,
    String? registrationProgress,
    String? country,
    String? nationality,
    String? facebookUsername,
    String? instagramUsername,
    String? twitterUsername,
    String? telegramUsername,
    String? snapchatUsername,
    String? churchName,
    Map<String, dynamic>? compatibility,
    bool? compatibilitySetted,
    Map<String, dynamic>? location,
    String? fcmToken,
    bool? onPremium,
    bool? prevSubscribed,
    DateTime? subExpDate,
    bool? usedOneFreeText,
    bool? entitledUser,
    String? subscriberId,
    DateTime? recommendedTime,
    bool? hasExternalSubscriptionFlow,
    DateTime? profileCompletionDate,
    Nexus2Data? nexus2,
  }) {
    return UserModel(
      id: id ?? this.id,
      name: name ?? this.name,
      username: username ?? this.username,
      email: email ?? this.email,
      profileUrl: profileUrl ?? this.profileUrl,
      age: age ?? this.age,
      gender: gender ?? this.gender,
      bestQualotiesOrTraits:
          bestQualotiesOrTraits ?? this.bestQualotiesOrTraits,
      city: city ?? this.city,
      countLike: countLike ?? this.countLike,
      desiredQualities: desiredQualities ?? this.desiredQualities,
      hobbies: hobbies ?? this.hobbies,
      photos: photos ?? this.photos,
      audioPrompts: audioPrompts ?? this.audioPrompts,
      likeMe: likeMe ?? this.likeMe,
      myLikes: myLikes ?? this.myLikes,
      mySaves: mySaves ?? this.mySaves,
      blocked: blocked ?? this.blocked,
      usersChatWarning: usersChatWarning ?? this.usersChatWarning,
      matchedUsers: matchedUsers ?? this.matchedUsers,
      unRecommendUsers: unRecommendUsers ?? this.unRecommendUsers,
      educationLevel: educationLevel ?? this.educationLevel,
      profession: profession ?? this.profession,
      relationshipWithGod: relationshipWithGod ?? this.relationshipWithGod,
      roleOfHusband: roleOfHusband ?? this.roleOfHusband,
      stateOfOrigin: stateOfOrigin ?? this.stateOfOrigin,
      isVerified: isVerified ?? this.isVerified,
      notificationToken: notificationToken ?? this.notificationToken,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      registrationProgress: registrationProgress ?? this.registrationProgress,
      country: country ?? this.country,
      nationality: nationality ?? this.nationality,
      facebookUsername: facebookUsername ?? this.facebookUsername,
      instagramUsername: instagramUsername ?? this.instagramUsername,
      twitterUsername: twitterUsername ?? this.twitterUsername,
      telegramUsername: telegramUsername ?? this.telegramUsername,
      snapchatUsername: snapchatUsername ?? this.snapchatUsername,
      churchName: churchName ?? this.churchName,
      compatibility: compatibility ?? this.compatibility,
      compatibilitySetted: compatibilitySetted ?? this.compatibilitySetted,
      location: location ?? this.location,
      fcmToken: fcmToken ?? this.fcmToken,
      onPremium: onPremium ?? this.onPremium,
      prevSubscribed: prevSubscribed ?? this.prevSubscribed,
      subExpDate: subExpDate ?? this.subExpDate,
      usedOneFreeText: usedOneFreeText ?? this.usedOneFreeText,
      entitledUser: entitledUser ?? this.entitledUser,
      subscriberId: subscriberId ?? this.subscriberId,
      recommendedTime: recommendedTime ?? this.recommendedTime,
      hasExternalSubscriptionFlow:
          hasExternalSubscriptionFlow ?? this.hasExternalSubscriptionFlow,
      profileCompletionDate:
          profileCompletionDate ?? this.profileCompletionDate,
      nexus2: nexus2 ?? this.nexus2,
    );
  }

  // ========================
  // HELPER METHODS
  // ========================

  /// Alias for id (UI compatibility)
  String get uid => id;

  /// Get full name (alias for name)
  String? get fullName => name;

  /// Check if user is online (placeholder - would need real-time presence)
  bool get isOnline => false;

  /// Convert to Firestore map
  Map<String, dynamic> toFirestore() => toMap();

  /// Check if user needs Nexus 2.0 onboarding
  bool get needsNexus2Onboarding =>
      nexus2 == null || !nexus2!.onboardingCompleted;

  /// Check if profile is complete enough for dating features
  bool get isProfileCompleteForDating =>
      name != null &&
      name!.isNotEmpty &&
      age != null &&
      age! >= 18 &&
      gender != null &&
      gender!.isNotEmpty &&
      photos != null &&
      photos!.isNotEmpty;

  /// Get display name
  String get displayName => name ?? username ?? 'User';

  /// Get profile photo URL
  String? get profilePhoto =>
      profileUrl ?? (photos?.isNotEmpty == true ? photos!.first : null);

  /// Check if user is premium
  bool get isPremium => onPremium == true;

  /// Check if user is single (for navigation)
  bool get isSingle => nexus2?.isSingle ?? true;

  /// Check if user is married (for navigation)
  bool get isMarried => nexus2?.isMarried ?? false;

  static List<String>? _parseStringList(dynamic value) {
    if (value == null) return null;
    if (value is List) {
      return value.map((e) => e.toString()).toList();
    }
    return null;
  }

  static DateTime? _parseTimestamp(dynamic value) {
    if (value == null) return null;
    if (value is Timestamp) {
      return value.toDate();
    }
    return null;
  }

  @override
  List<Object?> get props => [id, email, nexus2];
}
