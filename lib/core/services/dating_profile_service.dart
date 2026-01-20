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

    final updates = <String, dynamic>{
      'dating.reviewPack': _buildReviewPack(
        photoUrls: photoUrls,
        audioUrls: audioUrls,
      ),
    };

    if (bumpToPendingIfVerified && currentStatus == 'verified') {
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
    int done = 0;
    const int total = 6;

    if ((data['age'] is int) && (data['age'] as int) > 0) done += 1;
    if ((data['nationality']?.toString().trim().isNotEmpty ?? false)) done += 1;
    if ((data['educationLevel']?.toString().trim().isNotEmpty ?? false))
      done += 1;
    if (_stringList(data['hobbies']).isNotEmpty) done += 1;
    if (_stringList(data['desiredQualities']).isNotEmpty) done += 1;
    if (_stringList(data['photos']).isNotEmpty) done += 1;

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

    final updateData = <String, dynamic>{
      'age': age,
      'nationality': nationality,
      'location': cityCountry,
      'country': country,
      'educationLevel': educationLevel,
      'profession': profession,
      'church': church,
      'hobbies': hobbies,
      'desiredQualities': desiredQualities,
      'profileUrl': photoUrls.isNotEmpty ? photoUrls.first : null,
      'photos': photoUrls,
      // legacy photo fields
      for (int i = 0; i < 4; i++)
        'profileUrl${i + 1}': i < photoUrls.length ? photoUrls[i] : null,
      // legacy audio fields
      'audio1Url': audio1Url,
      'audio2Url': audio2Url,
      'audio3Url': audio3Url,
      // contact
      'instagramUsername': instagramUsername,
      'twitterUsername': twitterUsername,
      'phoneNumber':
          whatsappNumber, // WhatsApp stored as phoneNumber in some UIs
      'facebookUsername': facebookUsername,
      'telegramUsername': telegramUsername,
      'snapchatUsername': snapchatUsername,
      // v2 completion flag
      'dating.profileCompleted': true,
      'dating.profileCompletedAt': FieldValue.serverTimestamp(),
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // moderation bumps when evidence changes
    updateData.addAll(
      _datingModerationUpdates(
        existingUserDoc: existing,
        photoUrls: photoUrls,
        audioUrls: audioUrls,
        bumpToPendingIfVerified: true,
      ),
    );

    await userRef.set(updateData, SetOptions(merge: true));
  }

  Future<void> saveAge(String uid, int age) async {
    await _userDocRef(
      uid,
    ).update({'age': age, 'updatedAt': FieldValue.serverTimestamp()});
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
      'nationality': nationality,
      'location': cityCountry,
      'country': country,
      'educationLevel': educationLevel,
      'profession': profession,
      'church': church,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> saveHobbies(String uid, List<String> hobbies) async {
    await _userDocRef(
      uid,
    ).update({'hobbies': hobbies, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> saveDesiredQualities(String uid, List<String> qualities) async {
    await _userDocRef(uid).update({
      'desiredQualities': qualities,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> savePhotos(String uid, List<String> photoUrls) async {
    final userRef = _userDocRef(uid);

    final doc = await userRef.get();
    final existing = doc.data() ?? <String, dynamic>{};

    final updateData = <String, dynamic>{
      'profileUrl': photoUrls.isNotEmpty ? photoUrls.first : null,
      'photos': photoUrls,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    // Nexus 1.x compatibility fields profileUrl1..4
    for (int i = 0; i < 4; i++) {
      updateData['profileUrl${i + 1}'] =
          i < photoUrls.length ? photoUrls[i] : null;
    }

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
      'audio1Url': audio1Url,
      'audio2Url': audio2Url,
      'audio3Url': audio3Url,
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
      'instagramUsername': instagramUsername,
      'twitterUsername': twitterUsername,
      'phoneNumber': whatsappNumber,
      'facebookUsername': facebookUsername,
      'telegramUsername': telegramUsername,
      'snapchatUsername': snapchatUsername,
      'updatedAt': FieldValue.serverTimestamp(),
    });
  }

  Future<void> updateProfileField(
    String uid,
    String field,
    dynamic value,
  ) async {
    await _userDocRef(
      uid,
    ).update({field: value, 'updatedAt': FieldValue.serverTimestamp()});
  }

  Future<void> updateProfileFields(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    fields['updatedAt'] = FieldValue.serverTimestamp();
    await _userDocRef(uid).update(fields);
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
}

class DatingProfileException implements Exception {
  final String message;
  DatingProfileException(this.message);

  @override
  String toString() => 'DatingProfileException: $message';
}
