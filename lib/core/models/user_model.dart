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

    return Nexus2Data(
      relationshipStatus: map['relationshipStatus'] as String? ?? '',
      gender: map['gender'] as String? ?? '',
      primaryGoals:
          (map['primaryGoals'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      onboardingCompleted: map['onboardingCompleted'] as bool? ?? false,
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
  final String? bestQualitiesOrTraits;
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
    this.bestQualitiesOrTraits,
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
    return UserModel(
      id: id,
      name: data['name'] as String?,
      username: data['username'] as String?,
      email: data['email'] as String?,
      profileUrl: data['profileUrl'] as String?,
      age: data['age'] as int?,
      gender: data['gender'] as String?,
      bestQualitiesOrTraits:
          data['bestQualotiesOrTraits'] as String?, // Note: typo in original
      city: data['city'] as String?,
      countLike: data['countLike'] as int?,
      desiredQualities: data['desiredQualities'] as String?,
      hobbies: _parseStringList(data['hobbies']),
      photos: _parseStringList(data['photos']),
      audioPrompts: _parseStringList(data['audioPrompts']),
      likeMe: _parseStringList(data['likeMe']),
      myLikes: _parseStringList(data['myLikes']),
      mySaves: _parseStringList(data['mySaves']),
      blocked: _parseStringList(data['blocked']),
      usersChatWarning: _parseStringList(data['usersChatWarning']),
      matchedUsers: _parseStringList(data['matchedUsers']),
      unRecommendUsers: _parseStringList(data['unRecommendUsers']),
      educationLevel: data['educationLevel'] as String?,
      profession: data['profession'] as String?,
      relationshipWithGod: data['relationshipWithGod'] as String?,
      roleOfHusband: data['roleOfHusband'] as String?,
      stateOfOrigin: data['stateOfOrigin'] as String?,
      isVerified: data['isVerified'] as bool?,
      notificationToken: data['notificationToken'] as String?,
      phoneNumber: data['phoneNumber'] as String?,
      registrationProgress: data['registrationProgress'] as String?,
      country: data['country'] as String?,
      countryCode: data['countryCode'] as String?,
      nationality: data['nationality'] as String?,
      nationalityCode: data['nationalityCode'] as String?,
      facebookUsername: data['facebookUsername'] as String?,
      instagramUsername: data['instagramUsername'] as String?,
      twitterUsername: data['twitterUsername'] as String?,
      telegramUsername: data['telegramUsername'] as String?,
      snapchatUsername: data['snapchatUsername'] as String?,
      churchName: data['churchName'] as String?,
      compatibility: data['compatibility'] as Map<String, dynamic>?,
      compatibilitySetted: data['compatibilitySetted'] as bool?,
      location: data['location'] as Map<String, dynamic>?,
      fcmToken: data['fcmToken'] as String?,
      onPremium: data['onPremium'] as bool?,
      prevSubscribed: data['prevSubscribed'] as bool?,
      subExpDate: _parseTimestamp(data['subExpDate']),
      usedOneFreeText: data['usedOneFreeText'] as bool?,
      entitledUser: data['entitledUser'] as bool?,
      subscriberId: data['subscriberId'] as String?,
      recommendedTime: _parseTimestamp(data['recommendedTime']),
      hasExternalSubscriptionFlow: data['hasExternalSubscriptionFlow'] as bool?,
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
      'bestQualotiesOrTraits': bestQualitiesOrTraits,
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
    String? bestQualitiesOrTraits,
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
      bestQualitiesOrTraits:
          bestQualitiesOrTraits ?? this.bestQualitiesOrTraits,
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
