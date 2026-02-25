import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';

/// Firestore-backed service for Dating Profile operations.
///
/// Notes:
/// - We keep updates narrowly-scoped (only fields we intend to change).
/// - We maintain a small set of Nexus 1.x compatibility fields (profileUrl1..4 etc).
/// - "Moderation bump" logic is conservative: when media changes and user was
///   previously verified, we can bump status back to pending.
class DatingProfileService {
  final FirebaseFirestore _fs;

  DatingProfileService({required FirebaseFirestore firestore})
    : _fs = firestore;

  DocumentReference<Map<String, dynamic>> _userDocRef(String uid) =>
      _fs.collection('users').doc(uid);

  // --------------------------------------------------------------------------
  // Read helpers
  // --------------------------------------------------------------------------

  static List<String> _stringList(dynamic v) {
    if (v is List) return v.map((e) => e.toString()).toList();
    return const <String>[];
  }

  static List<String> _audioUrlsFromExisting(Map<String, dynamic> existing) {
    // Prefer v2 shape: dating.reviewPack.audioUrls
    final dating =
        (existing['dating'] is Map)
            ? (existing['dating'] as Map).cast<String, dynamic>()
            : null;
    final reviewPack =
        (dating?['reviewPack'] is Map)
            ? (dating!['reviewPack'] as Map).cast<String, dynamic>()
            : null;

    final fromReviewPack = _stringList(reviewPack?['audioUrls']);
    if (fromReviewPack.isNotEmpty) return fromReviewPack;

    // Fallback to legacy / flat fields if present
    final a1 = existing['audio1Url']?.toString();
    final a2 = existing['audio2Url']?.toString();
    final a3 = existing['audio3Url']?.toString();
    final out = <String>[
      if (a1 != null && a1.trim().isNotEmpty) a1.trim(),
      if (a2 != null && a2.trim().isNotEmpty) a2.trim(),
      if (a3 != null && a3.trim().isNotEmpty) a3.trim(),
    ];
    return out;
  }

  static Map<String, dynamic> _buildReviewPack({
    required List<String> photoUrls,
    required List<String> audioUrls,
  }) {
    return <String, dynamic>{
      'photoUrls': photoUrls,
      'audioUrls': audioUrls,
      'updatedAt': FieldValue.serverTimestamp(),
    };
  }

  static Map<String, dynamic> _datingModerationUpdates({
    required Map<String, dynamic> existingUserDoc,
    required List<String> photoUrls,
    required List<String> audioUrls,
    required bool bumpToPendingIfVerified,
  }) {
    // Read current status from user doc: users/{uid}.dating.verificationStatus
    final dating =
        (existingUserDoc['dating'] is Map)
            ? (existingUserDoc['dating'] as Map).cast<String, dynamic>()
            : null;

    final currentStatus = dating?['verificationStatus']?.toString();
    final isLockedByAdmin = dating?['verificationLockedByAdmin'] == true;

    final updates = <String, dynamic>{
      'dating.reviewPack': _buildReviewPack(
        photoUrls: photoUrls,
        audioUrls: audioUrls,
      ),
    };

    // Only bump to pending if not locked by admin
    if (bumpToPendingIfVerified &&
        currentStatus == 'verified' &&
        !isLockedByAdmin) {
      // Bump back to pending when user changes evidence content (photos/audio).
      updates['dating.verificationStatus'] = 'pending';
      updates['dating.pendingAt'] = FieldValue.serverTimestamp();
      // Clear prior decisions (optional but reduces confusion).
      updates['dating.verifiedAt'] = null;
      updates['dating.verifiedBy'] = null;
      updates['dating.rejectedAt'] = null;
      updates['dating.rejectedBy'] = null;
      updates['dating.rejectionReason'] = null;
    }

    return updates;
  }

  // --------------------------------------------------------------------------
  // Completion / progress
  // --------------------------------------------------------------------------

  Future<bool> isDatingProfileComplete(String uid) async {
    final doc = await _userDocRef(uid).get();
    if (!doc.exists || doc.data() == null) return false;
    final data = doc.data()!;

    // Primary v2 flag:
    final dating =
        (data['dating'] is Map)
            ? (data['dating'] as Map).cast<String, dynamic>()
            : null;
    final completed = dating?['profileCompleted'];
    if (completed == true) return true;

    // Heuristic fallback: require a few basics.
    final age = data['age'];
    final photos = _stringList(data['photos']);
    final hobbies = _stringList(data['hobbies']);
    return (age is int && age > 0) && photos.isNotEmpty && hobbies.isNotEmpty;
  }

  Future<bool> isCompatibilityQuizComplete(String uid) async {
    final doc = await _userDocRef(uid).get();
    if (!doc.exists || doc.data() == null) return false;
    final data = doc.data()!;
    // This is intentionally conservative: expects a boolean flag.
    final v = data['compatibilityQuizCompleted'];
    return v == true;
  }

  Future<int> getProfileCompletionPercentage(String uid) async {
    final doc = await _userDocRef(uid).get();
    if (!doc.exists || doc.data() == null) return 0;
    final data = doc.data()!;

    // Simple weighted heuristic: 6 core buckets.
    // Check dating.profile first (v2), then fallback to root (v1 compat)
    final dating =
        (data['dating'] is Map)
            ? (data['dating'] as Map).cast<String, dynamic>()
            : null;
    final profile =
        (dating?['profile'] is Map)
            ? (dating!['profile'] as Map).cast<String, dynamic>()
            : null;

    int done = 0;
    const int total = 6;

    final age = (profile?['age'] ?? data['age']) as int?;
    if ((age is int) && age > 0) done += 1;

    final nationality =
        (profile?['nationality'] ?? data['nationality'])?.toString().trim() ??
        '';
    if (nationality.isNotEmpty) done += 1;

    final educationLevel =
        (profile?['educationLevel'] ?? data['educationLevel'])
            ?.toString()
            .trim() ??
        '';
    if (educationLevel.isNotEmpty) done += 1;

    final hobbies = _stringList(profile?['hobbies'] ?? data['hobbies']);
    if (hobbies.isNotEmpty) done += 1;

    final qualities = _stringList(
      profile?['desiredQualities'] ?? data['desiredQualities'],
    );
    if (qualities.isNotEmpty) done += 1;

    final photos = _stringList(profile?['photos'] ?? data['photos']);
    if (photos.isNotEmpty) done += 1;

    final pct = ((done / total) * 100.0).round();
    return pct.clamp(0, 100);
  }

  // --------------------------------------------------------------------------
  // Write operations (called by service_providers.dart)
  // --------------------------------------------------------------------------

  Future<void> saveCompleteDatingProfile(
    String uid, {
    required int age,
    required String nationality,
    required String cityCountry,
    required String country,
    required String educationLevel,
    required String profession,
    String? church,
    required List<String> hobbies,
    required List<String> desiredQualities,
    required List<String> photoUrls,
    String? audio1Url,
    String? audio2Url,
    String? audio3Url,
    String? instagramUsername,
    String? twitterUsername,
    String? whatsappNumber,
    String? facebookUsername,
    String? telegramUsername,
    String? snapchatUsername,
  }) async {
    final userRef = _userDocRef(uid);

    final doc = await userRef.get();
    final existing = doc.data() ?? <String, dynamic>{};

    final audioUrls = <String>[
      if (audio1Url != null && audio1Url.trim().isNotEmpty) audio1Url.trim(),
      if (audio2Url != null && audio2Url.trim().isNotEmpty) audio2Url.trim(),
      if (audio3Url != null && audio3Url.trim().isNotEmpty) audio3Url.trim(),
    ];

    // Build the new dating sub-map (overwrite whole `dating` map)
    final datingMap = <String, dynamic>{
      'profileCompleted': true,
      'profileCompletedAt': FieldValue.serverTimestamp(),
      // Store a compact review pack used by moderation + search
      'reviewPack': _buildReviewPack(
        photoUrls: photoUrls,
        audioUrls: audioUrls,
      ),
      // Nest all profile fields under 'profile' (consolidated location)
      'profile': <String, dynamic>{
        'age': age,
        'nationality': nationality,
        'country': country,
        'educationLevel': educationLevel,
        'profession': profession,
        'church': church,
        'hobbies': hobbies,
        'desiredQualities': desiredQualities,
        'profileUrl': photoUrls.isNotEmpty ? photoUrls.first : null,
        'photos': photoUrls,
        'audio1Url': audio1Url,
        'audio2Url': audio2Url,
        'audio3Url': audio3Url,
        'instagramUsername': instagramUsername,
        'twitterUsername': twitterUsername,
        'phoneNumber': whatsappNumber,
        'facebookUsername': facebookUsername,
        'telegramUsername': telegramUsername,
        'snapchatUsername': snapchatUsername,
      },
    };

    // If the user was previously verified and we changed evidence, bump to pending
    final previousDating =
        (existing['dating'] is Map)
            ? (existing['dating'] as Map).cast<String, dynamic>()
            : <String, dynamic>{};
    final currentStatus = previousDating['verificationStatus']?.toString();
    final isLockedByAdmin = previousDating['verificationLockedByAdmin'] == true;

    if (currentStatus == 'verified' && !isLockedByAdmin) {
      datingMap['verificationStatus'] = 'pending';
      datingMap['pendingAt'] = FieldValue.serverTimestamp();
      // Clear prior decisions
      datingMap['verifiedAt'] = null;
      datingMap['verifiedBy'] = null;
      datingMap['rejectedAt'] = null;
      datingMap['rejectedBy'] = null;
      datingMap['rejectionReason'] = null;
    }

    // Top-level fields: non-profile metadata + search-critical fields (dual-write)
    // Profile data is now consolidated in dating.profile (see above)
    // BUT we dual-write gender & country for search queries (6-9 month compat)
    final topLevel = <String, dynamic>{
      // Dual-write country for search compatibility
      'country': country.isNotEmpty ? country : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Prepare the final write: if the document exists, update specific fields
    // and overwrite the `dating` map. If it does not exist, create a new doc
    // with the full payload (safe for new users).
    if (!doc.exists) {
      final full =
          <String, dynamic>{}
            ..addAll(topLevel)
            ..addAll({'dating': datingMap});
      await userRef.set(full);
    } else {
      // Use update to overwrite the `dating` map and set top-level fields.
      final updatePayload =
          <String, dynamic>{}
            ..addAll(topLevel)
            ..addAll({'dating': datingMap});

      // Perform the update
      await userRef.update(updatePayload);
    }

    // Track unique nationality and country
    await trackNationalityAndCountry(nationality, country);
  }

  Future<void> saveAge(String uid, int age) async {
    await _userDocRef(uid).update({
      'dating.profile.age': age,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveExtraInfo(
    String uid, {
    required String nationality,
    required String cityCountry,
    required String country,
    required String educationLevel,
    required String profession,
    String? church,
  }) async {
    await _userDocRef(uid).update({
      'dating.profile.nationality': nationality,
      'dating.profile.country': country,
      'dating.profile.educationLevel': educationLevel,
      'dating.profile.profession': profession,
      'dating.profile.church': church,
      // Dual-write country to root for search queries (6-9 month backward compat)
      'country': country,
      'updatedAt': FieldValue.serverTimestamp(),
    });

    // Track unique nationality and country
    await trackNationalityAndCountry(nationality, country);
  }

  Future<void> saveHobbies(String uid, List<String> hobbies) async {
    await _userDocRef(uid).update({
      'dating.profile.hobbies': hobbies,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveDesiredQualities(String uid, List<String> qualities) async {
    await _userDocRef(uid).update({
      'dating.profile.desiredQualities': qualities,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> savePhotos(String uid, List<String> photoUrls) async {
    final userRef = _userDocRef(uid);

    final doc = await userRef.get();
    final existing = doc.data() ?? <String, dynamic>{};

    final updateData = <String, dynamic>{
      'dating.profile.photos': photoUrls,
      'dating.profile.profileUrl':
          photoUrls.isNotEmpty ? photoUrls.first : null,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    final audioUrls = _audioUrlsFromExisting(existing);

    updateData.addAll(
      _datingModerationUpdates(
        existingUserDoc: existing,
        photoUrls: photoUrls,
        audioUrls: audioUrls,
        bumpToPendingIfVerified: true,
      ),
    );

    await userRef.update(updateData);
  }

  Future<void> saveAudioRecordings(
    String uid, {
    String? audio1Url,
    String? audio2Url,
    String? audio3Url,
  }) async {
    final userRef = _userDocRef(uid);

    final doc = await userRef.get();
    final existing = doc.data() ?? <String, dynamic>{};

    final audioUrls = <String>[
      if (audio1Url != null && audio1Url.trim().isNotEmpty) audio1Url.trim(),
      if (audio2Url != null && audio2Url.trim().isNotEmpty) audio2Url.trim(),
      if (audio3Url != null && audio3Url.trim().isNotEmpty) audio3Url.trim(),
    ];

    final photoUrls = _stringList(existing['photos']);

    final updates = <String, dynamic>{
      'dating.profile.audio1Url': audio1Url,
      'dating.profile.audio2Url': audio2Url,
      'dating.profile.audio3Url': audio3Url,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    updates.addAll(
      _datingModerationUpdates(
        existingUserDoc: existing,
        photoUrls: photoUrls,
        audioUrls: audioUrls,
        bumpToPendingIfVerified: true,
      ),
    );

    await userRef.update(updates);
  }

  Future<void> saveContactInfo(
    String uid, {
    String? instagramUsername,
    String? twitterUsername,
    String? whatsappNumber,
    String? facebookUsername,
    String? telegramUsername,
    String? snapchatUsername,
  }) async {
    await _userDocRef(uid).update({
      'dating.profile.instagramUsername': instagramUsername,
      'dating.profile.twitterUsername': twitterUsername,
      'dating.profile.phoneNumber': whatsappNumber,
      'dating.profile.facebookUsername': facebookUsername,
      'dating.profile.telegramUsername': telegramUsername,
      'dating.profile.snapchatUsername': snapchatUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfileField(
    String uid,
    String field,
    dynamic value,
  ) async {
    await _userDocRef(uid).update({
      'dating.profile.$field': value,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfileFields(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    final prefixedFields = <String, dynamic>{};
    fields.forEach((key, value) {
      prefixedFields['dating.profile.$key'] = value;
    });
    prefixedFields['updatedAt'] = FieldValue.serverTimestamp();
    await _userDocRef(uid).update(prefixedFields);
  }

  /// Best-effort migration for legacy verification flags into v2 structure.
  /// Safe behavior:
  /// - If v2 field already exists: do nothing.
  /// - If legacy 'isVerified' == true and v2 missing: set dating.verificationStatus='verified'
  /// - If legacy 'isVerified' != true and v2 missing: do nothing.
  Future<void> migrateLegacyV1VerificationIfNeeded(String uid) async {
    final ref = _userDocRef(uid);
    final snap = await ref.get();
    if (!snap.exists || snap.data() == null) return;

    final data = snap.data()!;
    final dating =
        (data['dating'] is Map)
            ? (data['dating'] as Map).cast<String, dynamic>()
            : null;

    final currentStatus = dating?['verificationStatus'];
    if (currentStatus != null) return;

    final legacyVerified = data['isVerified'] == true;
    if (!legacyVerified) return;

    await ref.update({
      'dating.verificationStatus': 'verified',
      'dating.verifiedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  // ============================================================================
  // TRACK UNIQUE NATIONALITIES AND COUNTRIES OF RESIDENCE
  // ============================================================================

  /// Add a nationality to the unique nationalities collection
  Future<void> trackNationality(String nationality) async {
    if (nationality.trim().isEmpty) return;

    try {
      final normalized = nationality.trim();
      print('[DatingProfileService] Tracking nationality: $normalized');
      await _fs.collection('nationalities').doc(normalized).set({
        'name': normalized,
        'count': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print(
        '[DatingProfileService] ✅ Successfully tracked nationality: $normalized',
      );
    } catch (e) {
      print('[DatingProfileService] ❌ Error tracking nationality: $e');
      rethrow;
    }
  }

  /// Add a country of residence to the unique countries collection
  Future<void> trackCountryOfResidence(String country) async {
    if (country.trim().isEmpty) return;

    try {
      final normalized = country.trim();
      print(
        '[DatingProfileService] Tracking country of residence: $normalized',
      );
      await _fs.collection('countriesOfResidence').doc(normalized).set({
        'name': normalized,
        'count': FieldValue.increment(1),
        'lastUpdatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
      print(
        '[DatingProfileService] ✅ Successfully tracked country: $normalized',
      );
    } catch (e) {
      print('[DatingProfileService] ❌ Error tracking country: $e');
      rethrow;
    }
  }

  /// Track both nationality and country when user completes profile
  Future<void> trackNationalityAndCountry(
    String nationality,
    String country,
  ) async {
    try {
      await Future.wait([
        trackNationality(nationality),
        trackCountryOfResidence(country),
      ]);
    } catch (e) {}
  }
}

class DatingProfileException implements Exception {
  final String message;
  DatingProfileException(this.message);

  @override
  String toString() => 'DatingProfileException: $message';
}
