import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:crypto/crypto.dart';
import 'package:http/http.dart' as http;
import 'dart:typed_data';

/// Service for detecting duplicate photos, audio, and suspicious account patterns
class DuplicateDetectionService {
  final FirebaseFirestore _firestore;

  DuplicateDetectionService({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  /// Compute SHA256 hash of a file from URL
  Future<String> computePhotoHash(String photoUrl) async {
    try {
      final response = await http
          .get(Uri.parse(photoUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to download photo: ${response.statusCode}');
      }

      final bytes = response.bodyBytes;
      return sha256.convert(bytes).toString();
    } catch (e) {
      throw Exception('Error computing photo hash: $e');
    }
  }

  /// Compute MD5 hash of an audio file from URL
  Future<String> computeAudioHash(String audioUrl) async {
    try {
      final response = await http
          .get(Uri.parse(audioUrl))
          .timeout(const Duration(seconds: 30));

      if (response.statusCode != 200) {
        throw Exception('Failed to download audio: ${response.statusCode}');
      }

      final bytes = response.bodyBytes;
      return md5.convert(bytes).toString();
    } catch (e) {
      throw Exception('Error computing audio hash: $e');
    }
  }

  /// Store photo hashes in review pack
  Future<void> storePhotoHashes(String userId, List<String> photoUrls) async {
    try {
      final hashes = <String>[];

      for (final url in photoUrls) {
        final hash = await computePhotoHash(url);
        hashes.add(hash);
      }

      await _firestore.collection('users').doc(userId).update({
        'dating.reviewPack.photoHashes': hashes,
      });
    } catch (e) {
      throw Exception('Failed to store photo hashes: $e');
    }
  }

  /// Store audio hashes in review pack
  Future<void> storeAudioHashes(String userId, List<String> audioUrls) async {
    try {
      final hashes = <String>[];

      for (final url in audioUrls) {
        final hash = await computeAudioHash(url);
        hashes.add(hash);
      }

      await _firestore.collection('users').doc(userId).update({
        'dating.reviewPack.audioHashes': hashes,
      });
    } catch (e) {
      throw Exception('Failed to store audio hashes: $e');
    }
  }

  /// Check for duplicate photos across all profiles
  Future<List<DuplicateMatch>> findDuplicatePhotos(
    String userId,
    List<String> photoHashes,
  ) async {
    try {
      final duplicates = <DuplicateMatch>[];

      for (final hash in photoHashes) {
        final matches =
            await _firestore
                .collection('users')
                .where('dating.reviewPack.photoHashes', arrayContains: hash)
                .where(FieldPath.documentId, isNotEqualTo: userId)
                .limit(10)
                .get();

        for (final doc in matches.docs) {
          final matchData = doc.data();
          final matchName = matchData['name'] as String? ?? 'Unknown';
          final matchUid = doc.id;

          duplicates.add(
            DuplicateMatch(
              userId: matchUid,
              userName: matchName,
              hash: hash,
              type: 'photo',
            ),
          );
        }
      }

      return duplicates;
    } catch (e) {
      throw Exception('Error checking for duplicate photos: $e');
    }
  }

  /// Check for duplicate audio across all profiles
  Future<List<DuplicateMatch>> findDuplicateAudio(
    String userId,
    List<String> audioHashes,
  ) async {
    try {
      final duplicates = <DuplicateMatch>[];

      for (final hash in audioHashes) {
        final matches =
            await _firestore
                .collection('users')
                .where('dating.reviewPack.audioHashes', arrayContains: hash)
                .where(FieldPath.documentId, isNotEqualTo: userId)
                .limit(10)
                .get();

        for (final doc in matches.docs) {
          final matchData = doc.data();
          final matchName = matchData['name'] as String? ?? 'Unknown';
          final matchUid = doc.id;

          duplicates.add(
            DuplicateMatch(
              userId: matchUid,
              userName: matchName,
              hash: hash,
              type: 'audio',
            ),
          );
        }
      }

      return duplicates;
    } catch (e) {
      throw Exception('Error checking for duplicate audio: $e');
    }
  }

  /// Detect suspicious patterns (rapid account creation, email/phone reuse)
  Future<List<SuspiciousPattern>> detectSuspiciousPatterns(
    String userId,
  ) async {
    try {
      final patterns = <SuspiciousPattern>[];
      final userDoc = await _firestore.collection('users').doc(userId).get();

      if (!userDoc.exists) return patterns;

      final userData = userDoc.data() as Map<String, dynamic>;
      final userEmail = userData['email'] as String?;
      final userPhone = userData['phone_number'] as String?;
      final userCreatedAt = userData['profile_completed_on'] as Timestamp?;

      // Check 1: Rapid profile creation (multiple accounts in 1 hour)
      if (userCreatedAt != null) {
        final oneHourAgo = userCreatedAt.toDate().subtract(
          const Duration(hours: 1),
        );

        final recentProfiles =
            await _firestore
                .collection('users')
                .where(
                  'profile_completed_on',
                  isGreaterThan: Timestamp.fromDate(oneHourAgo),
                )
                .limit(50)
                .get();

        if (recentProfiles.docs.length > 3) {
          patterns.add(
            SuspiciousPattern(
              type: 'rapid_creation',
              severity: 'medium',
              description:
                  'Multiple accounts created within 1 hour (${recentProfiles.docs.length} accounts)',
              relatedUserIds:
                  recentProfiles.docs
                      .map((doc) => doc.id)
                      .where((id) => id != userId)
                      .take(5)
                      .toList(),
            ),
          );
        }
      }

      // Check 2: Email reuse across recent accounts
      if (userEmail != null && userEmail.isNotEmpty) {
        final emailMatches =
            await _firestore
                .collection('users')
                .where('email', isEqualTo: userEmail)
                .where(FieldPath.documentId, isNotEqualTo: userId)
                .limit(10)
                .get();

        if (emailMatches.docs.isNotEmpty) {
          patterns.add(
            SuspiciousPattern(
              type: 'email_reuse',
              severity: 'high',
              description:
                  'Same email used in ${emailMatches.docs.length} other account(s)',
              relatedUserIds: emailMatches.docs.map((doc) => doc.id).toList(),
            ),
          );
        }
      }

      // Check 3: Phone reuse across recent accounts
      if (userPhone != null && userPhone.isNotEmpty) {
        final phoneMatches =
            await _firestore
                .collection('users')
                .where('phone_number', isEqualTo: userPhone)
                .where(FieldPath.documentId, isNotEqualTo: userId)
                .limit(10)
                .get();

        if (phoneMatches.docs.isNotEmpty) {
          patterns.add(
            SuspiciousPattern(
              type: 'phone_reuse',
              severity: 'high',
              description:
                  'Same phone used in ${phoneMatches.docs.length} other account(s)',
              relatedUserIds: phoneMatches.docs.map((doc) => doc.id).toList(),
            ),
          );
        }
      }

      return patterns;
    } catch (e) {
      throw Exception('Error detecting suspicious patterns: $e');
    }
  }
}

/// Model for duplicate photo/audio matches
class DuplicateMatch {
  final String userId;
  final String userName;
  final String hash;
  final String type; // 'photo' or 'audio'

  DuplicateMatch({
    required this.userId,
    required this.userName,
    required this.hash,
    required this.type,
  });
}

/// Model for suspicious account patterns
class SuspiciousPattern {
  final String type; // 'rapid_creation', 'email_reuse', 'phone_reuse'
  final String severity; // 'low', 'medium', 'high'
  final String description;
  final List<String> relatedUserIds;

  SuspiciousPattern({
    required this.type,
    required this.severity,
    required this.description,
    required this.relatedUserIds,
  });

  String get icon {
    switch (severity) {
      case 'high':
        return '🔴';
      case 'medium':
        return '🟡';
      default:
        return '🟢';
    }
  }
}
