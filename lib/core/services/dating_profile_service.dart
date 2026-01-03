import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:nexus_app_min_test/core/bootstrap/firestore_instance_provider.dart';
import 'package:flutter/foundation.dart';

import '../models/user_model.dart';

/// Service for managing dating profile data in Firestore
/// Handles all profile creation, updates, and compatibility quiz operations
class DatingProfileService {
  FirebaseFirestore? _firestore;

  FirebaseFirestore get _fs =>
      _firestore ?? (throw StateError('Firestore not ready'));
  DatingProfileService({FirebaseFirestore? firestore}) : _firestore = firestore;

  /// Get user document reference
  DocumentReference<Map<String, dynamic>> _userDocRef(String uid) {
    return _fs.collection('users').doc(uid);
  }

  // ============================================================================
  // STEP-BY-STEP PROFILE UPDATES
  // ============================================================================

  /// Step 1: Save age
  Future<void> saveAge(String uid, int age) async {
    try {
      await _userDocRef(
        uid,
      ).update({'age': age, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw DatingProfileException('Failed to save age: $e');
    }
  }

  /// Step 2: Save extra information (nationality, location, education, profession, church)
  Future<void> saveExtraInfo(
    String uid, {
    required String nationality,
    required String cityCountry,
    required String country,
    required String educationLevel,
    required String profession,
    String? church,
  }) async {
    try {
      await _userDocRef(uid).update({
        'nationality': nationality,
        'location': cityCountry,
        'country': country,
        'educationLevel': educationLevel,
        'profession': profession,
        'church': church,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw DatingProfileException('Failed to save extra info: $e');
    }
  }

  /// Step 3: Save hobbies/interests
  Future<void> saveHobbies(String uid, List<String> hobbies) async {
    try {
      await _userDocRef(
        uid,
      ).update({'hobbies': hobbies, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw DatingProfileException('Failed to save hobbies: $e');
    }
  }

  /// Step 4: Save desired qualities
  Future<void> saveDesiredQualities(String uid, List<String> qualities) async {
    try {
      await _userDocRef(uid).update({
        'desiredQualities': qualities,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw DatingProfileException('Failed to save desired qualities: $e');
    }
  }

  /// Step 5: Save photos (URLs)
  Future<void> savePhotos(String uid, List<String> photoUrls) async {
    try {
      final updateData = <String, dynamic>{
        'profileUrl': photoUrls.isNotEmpty ? photoUrls.first : null,
        'photos': photoUrls,
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Also update individual photo fields for Nexus 1.0 compatibility
      for (int i = 0; i < 4; i++) {
        updateData['profileUrl${i + 1}'] =
            i < photoUrls.length ? photoUrls[i] : null;
      }

      await _userDocRef(uid).update(updateData);
    } catch (e) {
      throw DatingProfileException('Failed to save photos: $e');
    }
  }

  /// Step 5 (single): Add a single photo
  Future<void> addPhoto(String uid, String photoUrl, int index) async {
    try {
      final doc = await _userDocRef(uid).get();
      final data = doc.data() ?? {};

      List<String> photos = List<String>.from(data['photos'] ?? []);

      if (index < photos.length) {
        photos[index] = photoUrl;
      } else {
        photos.add(photoUrl);
      }

      await savePhotos(uid, photos);
    } catch (e) {
      throw DatingProfileException('Failed to add photo: $e');
    }
  }

  /// Step 5 (single): Remove a photo
  Future<void> removePhoto(String uid, int index) async {
    try {
      final doc = await _userDocRef(uid).get();
      final data = doc.data() ?? {};

      List<String> photos = List<String>.from(data['photos'] ?? []);

      if (index < photos.length) {
        photos.removeAt(index);
      }

      await savePhotos(uid, photos);
    } catch (e) {
      throw DatingProfileException('Failed to remove photo: $e');
    }
  }

  /// Step 6: Save audio recordings
  Future<void> saveAudioRecordings(
    String uid, {
    String? audio1Url,
    String? audio2Url,
    String? audio3Url,
  }) async {
    try {
      final audioData = <String, dynamic>{};

      if (audio1Url != null) audioData['audio1Url'] = audio1Url;
      if (audio2Url != null) audioData['audio2Url'] = audio2Url;
      if (audio3Url != null) audioData['audio3Url'] = audio3Url;

      // Check if all 3 are complete
      final doc = await _userDocRef(uid).get();
      final existingData = doc.data() ?? {};
      final existingAudio =
          existingData['audio'] as Map<String, dynamic>? ?? {};

      final mergedAudio = {...existingAudio, ...audioData};
      mergedAudio['completed'] =
          mergedAudio['audio1Url'] != null &&
          mergedAudio['audio2Url'] != null &&
          mergedAudio['audio3Url'] != null;

      await _userDocRef(uid).update({
        'audio': mergedAudio,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw DatingProfileException('Failed to save audio recordings: $e');
    }
  }

  /// Step 6 (single): Save one audio recording
  Future<void> saveSingleAudio(
    String uid,
    int questionIndex,
    String audioUrl,
  ) async {
    try {
      final fieldName = 'audio${questionIndex}Url';
      await _userDocRef(uid).update({
        'audio.$fieldName': audioUrl,
        'updatedAt': FieldValue.serverTimestamp(),
      });

      // Check completion
      final doc = await _userDocRef(uid).get();
      final data = doc.data() ?? {};
      final audio = data['audio'] as Map<String, dynamic>? ?? {};

      if (audio['audio1Url'] != null &&
          audio['audio2Url'] != null &&
          audio['audio3Url'] != null) {
        await _userDocRef(uid).update({'audio.completed': true});
      }
    } catch (e) {
      throw DatingProfileException('Failed to save audio: $e');
    }
  }

  /// Step 7: Save contact information
  Future<void> saveContactInfo(
    String uid, {
    String? instagramUsername,
    String? twitterUsername,
    String? whatsappNumber,
    String? facebookUsername,
    String? telegramUsername,
    String? snapchatUsername,
  }) async {
    try {
      await _userDocRef(uid).update({
        'instagramUsername': instagramUsername,
        'twitterUsername': twitterUsername,
        'whatsappNumber': whatsappNumber,
        'facebookUsername': facebookUsername,
        'telegramUsername': telegramUsername,
        'snapchatUsername': snapchatUsername,
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw DatingProfileException('Failed to save contact info: $e');
    }
  }

  // ============================================================================
  // COMPLETE PROFILE SAVE
  // ============================================================================

  /// Save complete dating profile (all steps at once)
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
    try {
      final updateData = <String, dynamic>{
        // Step 1: Age
        'age': age,

        // Step 2: Extra info
        'nationality': nationality,
        'location': cityCountry,
        'country': country,
        'educationLevel': educationLevel,
        'profession': profession,
        'church': church,

        // Step 3: Hobbies
        'hobbies': hobbies,

        // Step 4: Desired qualities
        'desiredQualities': desiredQualities,

        // Step 5: Photos
        'profileUrl': photoUrls.isNotEmpty ? photoUrls.first : null,
        'photos': photoUrls,

        // Step 6: Audio
        'audio': {
          'audio1Url': audio1Url,
          'audio2Url': audio2Url,
          'audio3Url': audio3Url,
          'completed':
              audio1Url != null && audio2Url != null && audio3Url != null,
        },

        // Step 7: Contact info
        'instagramUsername': instagramUsername,
        'twitterUsername': twitterUsername,
        'whatsappNumber': whatsappNumber,
        'facebookUsername': facebookUsername,
        'telegramUsername': telegramUsername,
        'snapchatUsername': snapchatUsername,

        // Profile completion flags
        'datingProfileCompleted': true,
        'datingProfileCompletedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      };

      // Add individual photo fields for Nexus 1.0 compatibility
      for (int i = 0; i < 4; i++) {
        updateData['profileUrl${i + 1}'] =
            i < photoUrls.length ? photoUrls[i] : null;
      }

      await _userDocRef(uid).update(updateData);
    } catch (e) {
      throw DatingProfileException('Failed to save complete profile: $e');
    }
  }

  // ============================================================================
  // COMPATIBILITY QUIZ
  // ============================================================================

  /// Save compatibility quiz responses
  Future<void> saveCompatibilityQuiz(
    String uid, {
    required String maritalStatus,
    required String haveKids,
    required String genotype,
    required String personalityType,
    required String regularSourceOfIncome,
    required String marrySomeoneNotFS,
    required String longDistance,
    required String believeInCohabiting,
    required String shouldChristianSpeakInTongue,
    required String believeInTithing,
  }) async {
    try {
      await _userDocRef(uid).update({
        'compatibility': {
          'maritalStatus': maritalStatus,
          'haveKids': haveKids,
          'genotype': genotype,
          'personalityType': personalityType,
          'regularSourceOfIncome': regularSourceOfIncome,
          'marrySomeoneNotFS': marrySomeoneNotFS,
          'longDistance': longDistance,
          'believeInCohiabiting':
              believeInCohabiting, // Note: Nexus 1.0 typo preserved
          'shouldChristianSpeakInTongue': shouldChristianSpeakInTongue,
          'believeInTithing': believeInTithing,
        },
        'compatibilitySetted': true,
        'compatibilitySettedAt': FieldValue.serverTimestamp(),
        'updatedAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw DatingProfileException('Failed to save compatibility quiz: $e');
    }
  }

  /// Save compatibility quiz from a map (convenience method)
  Future<void> saveCompatibilityQuizFromMap(
    String uid,
    Map<String, String> answers,
  ) async {
    await saveCompatibilityQuiz(
      uid,
      maritalStatus: answers['maritalStatus'] ?? '',
      haveKids: answers['haveKids'] ?? '',
      genotype: answers['genotype'] ?? '',
      personalityType: answers['personalityType'] ?? '',
      regularSourceOfIncome: answers['regularSourceOfIncome'] ?? '',
      marrySomeoneNotFS: answers['marrySomeoneNotFS'] ?? '',
      longDistance: answers['longDistance'] ?? '',
      believeInCohabiting: answers['believeInCohabiting'] ?? '',
      shouldChristianSpeakInTongue:
          answers['shouldChristianSpeakInTongue'] ?? '',
      believeInTithing: answers['believeInTithing'] ?? '',
    );
  }

  // ============================================================================
  // PROFILE COMPLETION CHECK
  // ============================================================================

  /// Check if dating profile is complete
  Future<bool> isDatingProfileComplete(String uid) async {
    try {
      final doc = await _userDocRef(uid).get();
      final data = doc.data();
      if (data == null) return false;

      // Check all required fields
      final age = data['age'] as int?;
      final photos = data['photos'] as List? ?? [];
      final hobbies = data['hobbies'] as List? ?? [];
      final desiredQualities = data['desiredQualities'] as List? ?? [];
      final audio = data['audio'] as Map<String, dynamic>? ?? {};

      // Social media - at least one
      final hasSocialMedia =
          (data['instagramUsername'] as String?)?.isNotEmpty == true ||
          (data['twitterUsername'] as String?)?.isNotEmpty == true ||
          (data['whatsappNumber'] as String?)?.isNotEmpty == true ||
          (data['facebookUsername'] as String?)?.isNotEmpty == true ||
          (data['telegramUsername'] as String?)?.isNotEmpty == true ||
          (data['snapchatUsername'] as String?)?.isNotEmpty == true;

      return age != null &&
          age >= 21 &&
          photos.length >= 2 &&
          hobbies.isNotEmpty &&
          desiredQualities.isNotEmpty &&
          audio['completed'] == true &&
          hasSocialMedia;
    } catch (e) {
      debugPrint('Error checking profile completion: $e');
      return false;
    }
  }

  /// Check if compatibility quiz is complete
  Future<bool> isCompatibilityQuizComplete(String uid) async {
    try {
      final doc = await _userDocRef(uid).get();
      return doc.data()?['compatibilitySetted'] == true;
    } catch (e) {
      return false;
    }
  }

  /// Get profile completion percentage (0-100)
  Future<int> getProfileCompletionPercentage(String uid) async {
    try {
      final doc = await _userDocRef(uid).get();
      final data = doc.data();
      if (data == null) return 0;

      int completed = 0;
      const total = 7;

      // Step 1: Age
      if ((data['age'] as int?) != null && data['age'] >= 21) completed++;

      // Step 2: Extra info
      if ((data['nationality'] as String?)?.isNotEmpty == true &&
          (data['location'] as String?)?.isNotEmpty == true &&
          (data['educationLevel'] as String?)?.isNotEmpty == true &&
          (data['profession'] as String?)?.isNotEmpty == true) {
        completed++;
      }

      // Step 3: Hobbies
      final hobbies = data['hobbies'] as List? ?? [];
      if (hobbies.isNotEmpty) completed++;

      // Step 4: Desired qualities
      final qualities = data['desiredQualities'] as List? ?? [];
      if (qualities.isNotEmpty) completed++;

      // Step 5: Photos
      final photos = data['photos'] as List? ?? [];
      if (photos.length >= 2) completed++;

      // Step 6: Audio
      final audio = data['audio'] as Map<String, dynamic>? ?? {};
      if (audio['completed'] == true) completed++;

      // Step 7: Contact info
      final hasSocialMedia =
          (data['instagramUsername'] as String?)?.isNotEmpty == true ||
          (data['twitterUsername'] as String?)?.isNotEmpty == true ||
          (data['whatsappNumber'] as String?)?.isNotEmpty == true ||
          (data['facebookUsername'] as String?)?.isNotEmpty == true ||
          (data['telegramUsername'] as String?)?.isNotEmpty == true ||
          (data['snapchatUsername'] as String?)?.isNotEmpty == true;
      if (hasSocialMedia) completed++;

      return ((completed / total) * 100).round();
    } catch (e) {
      return 0;
    }
  }

  // ============================================================================
  // PROFILE EDITS
  // ============================================================================

  /// Update individual profile fields
  Future<void> updateProfileField(
    String uid,
    String field,
    dynamic value,
  ) async {
    try {
      await _userDocRef(
        uid,
      ).update({field: value, 'updatedAt': FieldValue.serverTimestamp()});
    } catch (e) {
      throw DatingProfileException('Failed to update $field: $e');
    }
  }

  /// Update multiple profile fields
  Future<void> updateProfileFields(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    try {
      fields['updatedAt'] = FieldValue.serverTimestamp();
      await _userDocRef(uid).update(fields);
    } catch (e) {
      throw DatingProfileException('Failed to update profile fields: $e');
    }
  }
}

/// Exception for dating profile operations
class DatingProfileException implements Exception {
  final String message;
  DatingProfileException(this.message);

  @override
  String toString() => 'DatingProfileException: $message';
}
