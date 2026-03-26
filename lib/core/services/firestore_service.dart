import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/foundation.dart';
import '../models/user_model.dart';
import '../models/assessment_model.dart';
import '../models/journey_model.dart';
import '../models/story_model.dart';
import '../constants/app_constants.dart';
import 'dart:developer' as dev;

/// Service for Firestore database operations.
class FirestoreService {
  void _requireDb() {
    if (_db == null) {
      throw Exception(
        "Firestore unavailable in dev mode (Firebase not initialized)",
      );
    }
  }

  final FirebaseFirestore? _db;

  bool get isAvailable => _db != null;

  FirestoreService({FirebaseFirestore? firestore}) : _db = firestore;

  // ==================== DOCUMENT REFERENCES ====================

  DocumentReference<Map<String, dynamic>> _userDocRef(String uid) {
    _requireDb();
    return _db!.collection(AppConfig.usersCollection).doc(uid);
  }

  CollectionReference<Map<String, dynamic>> _assessmentResultsRef(String uid) {
    _requireDb();
    return _db!.collection('assessmentResults').doc(uid).collection('results');
  }

  // ✅ Nexus v2 assessment storage:
  // users/{uid}/assessments/{assessmentId} -> latest
  // users/{uid}/assessments/{assessmentId}/history/{docId} -> history
  CollectionReference<Map<String, dynamic>> _userAssessmentsRef(String uid) {
    return _userDocRef(uid).collection('assessments');
  }

  DocumentReference<Map<String, dynamic>> _latestAssessmentRef(
    String uid,
    String assessmentId,
  ) {
    return _userAssessmentsRef(uid).doc(assessmentId);
  }

  CollectionReference<Map<String, dynamic>> _assessmentHistoryRef(
    String uid,
    String assessmentId,
  ) {
    return _latestAssessmentRef(uid, assessmentId).collection('history');
  }

  CollectionReference<Map<String, dynamic>> _journeyProgressRef(String uid) {
    _requireDb();
    return _userDocRef(uid).collection('journeys');
  }

  CollectionReference<Map<String, dynamic>> _sessionResponsesRef(
    String uid,
    String productId,
  ) {
    return _journeyProgressRef(uid).doc(productId).collection('responses');
  }

  CollectionReference<Map<String, dynamic>> _storyProgressRef(String uid) {
    _requireDb();
    return _db!.collection('storyProgress').doc(uid).collection('stories');
  }

  CollectionReference<Map<String, dynamic>> _pollVotesRef(String pollId) {
    _requireDb();
    return _db!.collection('pollVotes').doc(pollId).collection('votes');
  }

  DocumentReference<Map<String, dynamic>> _pollAggregateRef(String pollId) {
    _requireDb();
    return _db!.collection('pollAggregates').doc(pollId);
  }

  // ==================== USER OPERATIONS ====================

  Future<UserModel?> getUser(String uid) async {
    try {
      final doc = await _userDocRef(uid).get();
      final data = doc.data();
      if (!doc.exists || data == null) return null;

      print(
        '[USER DOC] rel_with_god=${data['relationship_with_god']} role_of_husband=${data['role_of_husband']} best_qualities=${data['best_qualities_or_traits']}',
      );
      print(
        '[USER DOC] username=${data['username']} user_name=${data['user_name']} name=${data['name']} full_name=${data['full_name']} nationality=${data['nationality']}',
      );
      return UserModel.fromDocument(doc);
    } catch (e) {
      throw FirestoreException('Failed to get user: $e');
    }
  }

  Stream<UserModel?> streamUser(String uid) {
    return _userDocRef(uid).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return UserModel.fromDocument(doc);
    });
  }

  Future<bool> userExists(String uid) async {
    final doc = await _userDocRef(uid).get();
    return doc.exists;
  }

  /// Get the username for a user, with fallback to displayName if not found
  Future<String?> getUserUsername(String uid) async {
    try {
      final doc = await _userDocRef(uid).get();
      final data = doc.data();
      if (data == null) return null;

      final username = data['username'] as String?;
      if (username != null && username.trim().isNotEmpty) {
        return username.trim();
      }
      return null;
    } catch (e) {
      return null;
    }
  }

  Future<void> createUser(UserModel user) async {
    if (_db == null) return;

    try {
      final ref = _userDocRef(user.id);
      final existing = await ref.get();

      // 🔒 Critical: never overwrite existing v1 user docs.
      if (existing.exists) return;

      await ref.set(user.toMap(), SetOptions(merge: true));
    } catch (e) {
      throw FirestoreException('Failed to create user: $e');
    }
  }

  Future<void> updateNexus2Data(String uid, Nexus2Data nexus2Data) async {
    if (_db == null) return;

    try {
      await _userDocRef(
        uid,
      ).set({'nexus2': nexus2Data.toMap()}, SetOptions(merge: true));
    } catch (e) {
      throw FirestoreException('Failed to update nexus2 data: $e');
    }
  }

  Future<void> updateNexus2Fields(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    if (_db == null) return;

    try {
      final prefixedFields = <String, dynamic>{};
      fields.forEach((key, value) {
        prefixedFields['nexus2.$key'] = value;
      });
      await _userDocRef(uid).update(prefixedFields);
    } catch (e) {
      throw FirestoreException('Failed to update nexus2 fields: $e');
    }
  }

  Future<void> updateLastActive(String uid) async {
    if (_db == null) return;

    try {
      await _userDocRef(
        uid,
      ).update({'nexus2.lastActiveAt': FieldValue.serverTimestamp()});
    } catch (_) {
      // Silently fail - not critical
    }
  }

  Future<void> updateUserFields(String uid, Map<String, dynamic> fields) async {
    if (_db == null) return;

    try {
      await _userDocRef(uid).update(fields);
    } catch (e) {
      throw FirestoreException('Failed to update user fields: $e');
    }
  }

  /// Update user PROFILE fields to dating.profile (consolidated location)
  /// Profile fields: age, gender, name, city, country, photos, etc.
  /// This is the NEW recommended method for profile updates
  Future<void> updateUserProfileFields(
    String uid,
    Map<String, dynamic> fields,
  ) async {
    if (_db == null) return;

    try {
      final prefixedFields = <String, dynamic>{};
      fields.forEach((key, value) {
        prefixedFields['dating.profile.$key'] = value;
      });
      prefixedFields['updatedAt'] = FieldValue.serverTimestamp();
      await _userDocRef(uid).update(prefixedFields);
    } catch (e) {
      throw FirestoreException('Failed to update user profile fields: $e');
    }
  }

  /// Delete user document from Firestore
  /// This triggers Cloud Function to delete Firebase Auth user
  Future<void> deleteUser(String uid) async {
    if (_db == null) return;

    try {
      await _userDocRef(uid).delete();
    } catch (e) {
      throw FirestoreException('Failed to delete user: $e');
    }
  }

  Future<void> completeOnboarding(
    String uid, {
    required String relationshipStatus,
    required String gender,
    required List<String> primaryGoals,
  }) async {
    if (_db == null) return;

    try {
      // IMPORTANT: Cannot use .set(merge:true) with dot-notation keys
      // because Firestore's set() treats them as literal field names, not
      // nested paths. Only .update() interprets dots as nested paths.
      // The nexus2 map is safe as a proper nested object.
      await _userDocRef(uid).set({
        // Dual-write gender to root for search queries
        'gender': gender,
        // Nexus 2.0 metadata (non-profile fields only)
        'nexus2': {
          'relationshipStatus': relationshipStatus,
          'primaryGoals': primaryGoals,
          'onboardingCompleted': true,
          'onboardedAt': FieldValue.serverTimestamp(),
          'schemaVersion': AppConfig.nexus2SchemaVersion,
        },
      }, SetOptions(merge: true));
      // Write dating.profile.gender via .update() (dot-notation requires update)
      await _userDocRef(uid).update({'dating.profile.gender': gender});
    } catch (e) {
      throw FirestoreException('Failed to complete onboarding: $e');
    }
  }

  // ==================== ASSESSMENT OPERATIONS ====================

  Future<void> saveAssessmentResult(String uid, AssessmentResult result) async {
    if (_db == null) return;

    try {
      final now = DateTime.now();
      final historyId = '${now.millisecondsSinceEpoch}';

      // ✅ New Nexus v2 storage (latest + history)
      await _latestAssessmentRef(
        uid,
        result.assessmentId,
      ).set({...result.toJson(), 'updatedAt': now.toIso8601String()});

      await _assessmentHistoryRef(uid, result.assessmentId).doc(historyId).set({
        ...result.toJson(),
        'createdAt': now.toIso8601String(),
      });

      // ✅ Legacy storage (keep for backward compatibility / migration)
      final legacyDocId =
          '${result.assessmentId}_${now.millisecondsSinceEpoch}';
      await _assessmentResultsRef(uid).doc(legacyDocId).set(result.toJson());
    } catch (e) {
      throw FirestoreException('Failed to save assessment result: $e');
    }
  }

  Future<AssessmentResult?> getLatestAssessmentResult(
    String uid,
    String assessmentId,
  ) async {
    try {
      print(
        '[FirestoreService] getLatestAssessmentResult: uid=$uid, assessmentId=$assessmentId',
      );

      // ✅ New Nexus v2 storage first - filtering out archived assessments
      final latestSnap = await _latestAssessmentRef(uid, assessmentId).get();
      if (latestSnap.exists && latestSnap.data() != null) {
        final result = AssessmentResult.fromJson(latestSnap.data()!);
        // Only return if NOT archived
        if (!result.archived) {
          print(
            '[FirestoreService] ✓ Found v2 result: ${result.assessmentId}, dimensionScores=${result.dimensionScores.length}',
          );
          return result;
        }
      }

      print(
        '[FirestoreService] No v2 result found, checking legacy storage...',
      );

      // ✅ Fallback to legacy storage - fetch all and filter on client
      // (Firestore where filter excludes documents without the archived field)
      final query =
          await _assessmentResultsRef(uid)
              .where('assessmentId', isEqualTo: assessmentId)
              .orderBy('completedAt', descending: true)
              .limit(100)
              .get();

      if (query.docs.isEmpty) {
        print('[FirestoreService] ✓ No results found in legacy storage');
        return null;
      }

      print('[FirestoreService] Found ${query.docs.length} legacy results');

      // Filter on client side to include documents without archived field
      final filtered =
          query.docs
              .map((doc) => AssessmentResult.fromJson(doc.data()))
              .where((result) => !result.archived)
              .toList();

      if (filtered.isEmpty) {
        print('[FirestoreService] ✓ All legacy results were archived');
        return null;
      }

      final first = filtered.first;
      print(
        '[FirestoreService] ✓ Returning first legacy result: ${first.assessmentId}, dimensionScores=${first.dimensionScores.length}',
      );
      return first;
    } catch (e) {
      throw FirestoreException('Failed to get assessment result: $e');
    }
  }

  Future<List<AssessmentResult>> getAllAssessmentResults(String uid) async {
    try {
      // ✅ Prefer latest-per-assessment documents
      // Filter on client side instead of Firestore where() to include old documents
      // without the archived field (they default to false in the model)
      final snap =
          await _userAssessmentsRef(
            uid,
          ).orderBy('updatedAt', descending: true).get();

      final results =
          snap.docs
              .map((doc) => AssessmentResult.fromJson(doc.data()))
              .where((result) => !result.archived) // Filter on client side
              .toList();

      return results;
    } catch (e) {
      // ✅ Fallback to legacy storage
      try {
        final query =
            await _assessmentResultsRef(
              uid,
            ).orderBy('completedAt', descending: true).get();
        return query.docs
            .map((doc) => AssessmentResult.fromJson(doc.data()))
            .where((result) => !result.archived) // Filter on client side
            .toList();
      } catch (e2) {
        throw FirestoreException('Failed to get assessment results: $e2');
      }
    }
  }

  Stream<List<AssessmentResult>> watchAssessmentResults(String uid) {
    return _userAssessmentsRef(uid)
        .orderBy('updatedAt', descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs
                  .map((doc) => AssessmentResult.fromJson(doc.data()))
                  .where((result) => !result.archived)
                  .toList(),
        );
  }

  // ==================== JOURNEY OPERATIONS ====================

  Future<JourneyProgress?> getJourneyProgress(
    String uid,
    String productId,
  ) async {
    try {
      final doc = await _journeyProgressRef(uid).doc(productId).get();
      if (!doc.exists || doc.data() == null) return null;
      return JourneyProgress.fromJson(doc.data()!);
    } catch (e) {
      throw FirestoreException('Failed to get journey progress: $e');
    }
  }

  Future<List<JourneyProgress>> getAllJourneyProgress(String uid) async {
    try {
      final query = await _journeyProgressRef(uid).get();
      return query.docs
          .map((doc) => JourneyProgress.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw FirestoreException('Failed to get all journey progress: $e');
    }
  }

  Future<void> createJourneyProgress(
    String uid,
    JourneyProgress progress,
  ) async {
    if (_db == null) return;

    try {
      await _journeyProgressRef(
        uid,
      ).doc(progress.productId).set(progress.toJson());
    } catch (e) {
      throw FirestoreException('Failed to create journey progress: $e');
    }
  }

  Future<void> updateJourneyProgress(
    String uid,
    String productId,
    int completedSessionNumber,
  ) async {
    if (_db == null) return;

    try {
      // Get current progress to update
      final doc = await _journeyProgressRef(uid).doc(productId).get();
      final currentProgress =
          doc.exists && doc.data() != null
              ? JourneyProgress.fromJson(doc.data()!)
              : null;

      final completedSessions = currentProgress?.completedSessionIdsList ?? [];
      final sessionId = 'session_$completedSessionNumber';

      if (!completedSessions.contains(sessionId)) {
        completedSessions.add(sessionId);
      }

      await _journeyProgressRef(uid).doc(productId).set({
        'visitorId': uid,
        'visitorUid': uid,
        'productId': productId,
        'completedSessionCount': completedSessions.length,
        'completedSessionIdsList': completedSessions,
        'lastSessionAt': FieldValue.serverTimestamp(),
        if (currentProgress == null) 'startedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      throw FirestoreException('Failed to update journey progress: $e');
    }
  }

  Future<void> deleteJourneyProgress(String uid, String journeyId) async {
    if (_db == null) return;
    try {
      await _journeyProgressRef(uid).doc(journeyId).delete();
    } catch (e) {
      throw FirestoreException('Failed to delete journey progress: $e');
    }
  }

  Future<void> updateJourneyProgressFields(
    String uid,
    String productId,
    Map<String, dynamic> updates,
  ) async {
    if (_db == null) return;

    try {
      await _journeyProgressRef(uid).doc(productId).update(updates);
    } catch (e) {
      throw FirestoreException('Failed to update journey progress: $e');
    }
  }

  Future<void> saveSessionResponse(String uid, SessionResponse response) async {
    if (_db == null) return;

    try {
      final docId = '${response.sessionId}_${response.stepId}';
      await _sessionResponsesRef(
        uid,
        response.productId,
      ).doc(docId).set(response.toJson());
    } catch (e) {
      throw FirestoreException('Failed to save session response: $e');
    }
  }

  Stream<JourneyProgress?> watchJourneyProgress(String uid, String productId) {
    return _journeyProgressRef(uid).doc(productId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return JourneyProgress.fromJson(doc.data()!);
    });
  }

  Stream<Map<String, JourneyProgress>> watchAllJourneyProgress(String uid) {
    return _journeyProgressRef(uid).snapshots().map((snapshot) {
      final map = <String, JourneyProgress>{};
      for (final doc in snapshot.docs) {
        final progress = JourneyProgress.fromJson(doc.data());
        map[progress.productId] = progress;
      }
      return map;
    });
  }

  Future<SessionResponse?> getSessionResponse(
    String uid,
    String productId,
    String sessionId,
    String stepId,
  ) async {
    try {
      final docId = '${sessionId}_$stepId';
      final doc = await _sessionResponsesRef(uid, productId).doc(docId).get();
      if (!doc.exists || doc.data() == null) return null;
      return SessionResponse.fromJson(doc.data()!);
    } catch (e) {
      throw FirestoreException('Failed to get session response: $e');
    }
  }

  Future<List<SessionResponse>> getSessionResponses(
    String uid,
    String productId,
  ) async {
    try {
      final query =
          await _sessionResponsesRef(
            uid,
            productId,
          ).orderBy('createdAt', descending: false).get();

      return query.docs
          .map((doc) => SessionResponse.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw FirestoreException('Failed to get session responses: ');
    }
  }

  // ==================== STORY OPERATIONS ====================

  Future<StoryProgress?> getStoryProgress(String uid, String storyId) async {
    try {
      final doc = await _storyProgressRef(uid).doc(storyId).get();
      if (!doc.exists || doc.data() == null) return null;
      return StoryProgress.fromJson(doc.data()!);
    } catch (e) {
      throw FirestoreException('Failed to get story progress: $e');
    }
  }

  Future<List<StoryProgress>> getAllStoryProgress(String uid) async {
    try {
      final query = await _storyProgressRef(uid).get();
      return query.docs
          .map((doc) => StoryProgress.fromJson(doc.data()))
          .toList();
    } catch (e) {
      throw FirestoreException('Failed to get all story progress: $e');
    }
  }

  Future<void> updateStoryProgress(String uid, StoryProgress progress) async {
    if (_db == null) return;

    try {
      await _storyProgressRef(
        uid,
      ).doc(progress.storyId).set(progress.toJson(), SetOptions(merge: true));
    } catch (e) {
      throw FirestoreException('Failed to update story progress: $e');
    }
  }

  Stream<StoryProgress?> watchStoryProgress(String uid, String storyId) {
    return _storyProgressRef(uid).doc(storyId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) return null;
      return StoryProgress.fromJson(doc.data()!);
    });
  }

  Stream<Map<String, StoryProgress>> watchAllStoryProgress(String uid) {
    return _storyProgressRef(uid).snapshots().map((snapshot) {
      final map = <String, StoryProgress>{};
      for (final doc in snapshot.docs) {
        final progress = StoryProgress.fromJson(doc.data());
        map[progress.storyId] = progress;
      }
      return map;
    });
  }

  // ==================== POLL OPERATIONS ====================

  Future<PollVote?> getUserPollVote(String uid, String pollId) async {
    try {
      final doc = await _pollVotesRef(pollId).doc(uid).get();
      if (!doc.exists || doc.data() == null) return null;
      return PollVote.fromJson(doc.data()!);
    } catch (e) {
      throw FirestoreException('Failed to get poll vote: $e');
    }
  }

  Future<void> savePollVote(PollVote vote) async {
    final db = _db;
    if (db == null) return;

    try {
      // Use transaction to atomically save vote and update aggregate
      await db.runTransaction((transaction) async {
        final voteRef = _pollVotesRef(vote.pollId).doc(vote.userId);
        final aggregateRef = _pollAggregateRef(vote.pollId);

        // Get current aggregate
        final aggregateDoc = await transaction.get(aggregateRef);
        final currentAggregate =
            aggregateDoc.exists
                ? PollAggregate.fromJson(aggregateDoc.data()!)
                : PollAggregate(
                  pollId: vote.pollId,
                  totalVotes: 0,
                  optionCounts: {},
                  updatedAt: DateTime.now(),
                );

        // Calculate new optionCounts
        final newOptionCounts = Map<String, int>.from(
          currentAggregate.optionCounts,
        );
        newOptionCounts[vote.selectedOptionId] =
            (newOptionCounts[vote.selectedOptionId] ?? 0) + 1;

        // Save vote
        transaction.set(voteRef, vote.toJson());

        // Update aggregate with calculated values (not increment)
        transaction.set(aggregateRef, {
          'pollId': vote.pollId,
          'totalVotes': currentAggregate.totalVotes + 1,
          'optionCounts': newOptionCounts,
          'updatedAt': FieldValue.serverTimestamp(),
        }, SetOptions(merge: true));
      });
    } catch (e) {
      throw FirestoreException('Failed to save poll vote: $e');
    }
  }

  Future<PollAggregate> getPollAggregate(String pollId) async {
    try {
      final doc = await _pollAggregateRef(pollId).get();
      if (!doc.exists || doc.data() == null) {
        return PollAggregate(
          pollId: pollId,
          totalVotes: 0,
          optionCounts: {},
          updatedAt: DateTime.now(),
        );
      }
      return PollAggregate.fromJson(doc.data()!);
    } catch (e) {
      throw FirestoreException('Failed to get poll aggregate: $e');
    }
  }

  Stream<PollAggregate> streamPollAggregate(String pollId) {
    return _pollAggregateRef(pollId).snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return PollAggregate(
          pollId: pollId,
          totalVotes: 0,
          optionCounts: {},
          updatedAt: DateTime.now(),
        );
      }
      return PollAggregate.fromJson(doc.data()!);
    });
  }

  // ==================== BLOCK & REPORT ====================

  Future<void> blockUser(String currentUserId, String blockedUserId) async {
    if (_db == null) return;

    try {
      await _userDocRef(currentUserId).update({
        'blocked': FieldValue.arrayUnion([blockedUserId]),
      });
    } catch (e) {
      throw FirestoreException('Failed to block user: $e');
    }
  }

  Future<void> unblockUser(String currentUserId, String blockedUserId) async {
    if (_db == null) return;

    try {
      await _userDocRef(currentUserId).update({
        'blocked': FieldValue.arrayRemove([blockedUserId]),
      });
    } catch (e) {
      throw FirestoreException('Failed to unblock user: $e');
    }
  }

  Future<List<String>> getBlockedUsers(String userId) async {
    try {
      final doc = await _userDocRef(userId).get();
      final data = doc.data();
      if (data == null) return [];
      final blocked = data['blocked'] as List<dynamic>?;
      return blocked?.map((e) => e.toString()).toList() ?? [];
    } catch (e) {
      throw FirestoreException('Failed to get blocked users: $e');
    }
  }

  Future<List<UserModel>> getBlockedUsersModels(String userId) async {
    try {
      final blockedIds = await getBlockedUsers(userId);
      if (blockedIds.isEmpty) return [];

      final users = <UserModel>[];
      for (final id in blockedIds) {
        final user = await getUser(id);
        if (user != null) users.add(user);
      }
      return users;
    } catch (e) {
      throw FirestoreException('Failed to get blocked users: $e');
    }
  }

  // ==================== SUPPORT ====================

  Future<void> submitSupportRequest({
    required String userId,
    required String userEmail,
    required String username,
    required String category,
    required String subject,
    required String message,
    required String platform,
    required String appVersion,
  }) async {
    final db = _db;
    if (db == null) return;

    try {
      await db.collection('supportRequests').add({
        'userId': userId,
        'userEmail': userEmail,
        'username': username,
        'category': category,
        'subject': subject,
        'message': message,
        'platform': platform,
        'appVersion': appVersion,
        'status': 'new',
        'createdAt': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      throw FirestoreException('Failed to submit support request: $e');
    }
  }

  /// Exception thrown when Firestore operation fails

  // ==================== STORY (STREAMS + ENGAGEMENT) ====================
  DocumentReference<Map<String, dynamic>> _pollAggregateDoc(String pollId) =>
      _db!.collection("pollAggregates").doc(pollId);

  DocumentReference<Map<String, dynamic>> _storyEngagementDoc(String storyId) =>
      _db!.collection("storyEngagement").doc(storyId);

  CollectionReference<Map<String, dynamic>> _storyCommentsRef(String storyId) =>
      _db!.collection("storyComments").doc(storyId).collection("comments");

  DocumentReference<Map<String, dynamic>> _storyCommentLikesDoc(
    String storyId,
    String commentId,
    String userId,
  ) => _db!
      .collection("storyCommentLikes")
      .doc(storyId)
      .collection("likes")
      .doc("$commentId:$userId");

  DocumentReference<Map<String, dynamic>> _storyLikesDoc(
    String storyId,
    String userId,
  ) => _db!
      .collection("storyLikes")
      .doc(storyId)
      .collection("likes")
      .doc(userId);

  Stream<PollVote?> watchPollVote(String pollId, String userId) {
    return _pollVotesRef(pollId).doc(userId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return PollVote.fromFirestore(data);
    });
  }

  Stream<PollAggregate?> watchPollAggregate(String pollId) {
    return _pollAggregateDoc(pollId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return PollAggregate.fromFirestore(data);
    });
  }

  Stream<StoryEngagement?> watchStoryEngagement(String storyId) {
    return _storyEngagementDoc(storyId).snapshots().map((doc) {
      final data = doc.data();
      if (!doc.exists || data == null) return null;
      return StoryEngagement.fromJson(data);
    });
  }

  Stream<bool> watchUserLikedStory(String storyId, String userId) {
    return _storyLikesDoc(storyId, userId).snapshots().map((doc) => doc.exists);
  }

  /// Stream of all comment IDs liked by the user in a given story.
  /// Returns a Set<String> of commentIds that the user has liked.
  Stream<Set<String>> watchUserLikedComments(String storyId, String userId) {
    return _db!
        .collection("storyCommentLikes")
        .doc(storyId)
        .collection("likes")
        .where("userId", isEqualTo: userId)
        .snapshots()
        .map((snap) {
          final likedSet = <String>{};
          for (final doc in snap.docs) {
            final data = doc.data();
            final commentId = data['commentId'] as String?;
            if (commentId != null && commentId.isNotEmpty) {
              likedSet.add(commentId);
            }
          }
          return likedSet;
        });
  }

  Stream<List<StoryComment>> watchStoryComments(String storyId) {
    return _storyCommentsRef(storyId)
        .orderBy("likeCount", descending: true)
        .orderBy("createdAt", descending: true)
        .snapshots()
        .map(
          (snap) =>
              snap.docs.map((d) => StoryComment.fromJson(d.data())).toList(),
        );
  }

  Future<void> likeStory({
    required String storyId,
    required String userId,
    String? userName,
  }) async {
    if (_db == null) return;

    await _storyLikesDoc(storyId, userId).set({
      "visitorId": userId,
      "storyId": storyId,
      "userId": userId,
      if (userName != null) "userName": userName,
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _storyEngagementDoc(storyId).set({
      "storyId": storyId,
      "likeCount": FieldValue.increment(1),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unlikeStory({
    required String storyId,
    required String userId,
  }) async {
    if (_db == null) return;

    await _storyLikesDoc(storyId, userId).delete();

    await _storyEngagementDoc(storyId).set({
      "storyId": storyId,
      "likeCount": FieldValue.increment(-1),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> hasUserLikedStory(String storyId, String userId) async {
    final doc = await _storyLikesDoc(storyId, userId).get();
    return doc.exists;
  }

  Future<StoryComment> addStoryComment({
    required String storyId,
    required String userId,
    required String userName,
    String? userPhotoUrl,
    String? parentId,
    required String text,
  }) async {
    final ref = _storyCommentsRef(storyId).doc();
    final payload = {
      "visitorId": ref.id,
      "storyId": storyId,
      "userId": userId,
      "userName": userName,
      if (userPhotoUrl != null) "userPhotoUrl": userPhotoUrl,
      if (parentId != null) "parentId": parentId,
      "likeCount": 0,
      "replyCount": 0,
      "text": text,
      "createdAt": FieldValue.serverTimestamp(),
    };

    await ref.set(payload);

    await _storyEngagementDoc(storyId).set({
      "storyId": storyId,
      "commentCount": FieldValue.increment(1),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (parentId != null && parentId.isNotEmpty) {
      await _storyCommentsRef(storyId).doc(parentId).update({
        "replyCount": FieldValue.increment(1),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }

    // Local return (server timestamp will resolve later)
    return StoryComment.fromJson({
      ...payload,
      "createdAt": Timestamp.fromDate(DateTime.now()),
      "replyCount": 0,
      "likeCount": 0,
    });
  }

  Future<void> deleteStoryComment({
    required String storyId,
    required String commentId,
  }) async {
    if (_db == null) return;

    final snapshot = await _storyCommentsRef(storyId).doc(commentId).get();
    final parentId = snapshot.data()?['parentId'] as String?;

    await _storyCommentsRef(storyId).doc(commentId).delete();

    await _storyEngagementDoc(storyId).set({
      "storyId": storyId,
      "commentCount": FieldValue.increment(-1),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    if (parentId != null && parentId.isNotEmpty) {
      await _storyCommentsRef(storyId).doc(parentId).update({
        "replyCount": FieldValue.increment(-1),
        "updatedAt": FieldValue.serverTimestamp(),
      });
    }
  }

  Future<void> likeComment({
    required String storyId,
    required String commentId,
    required String userId,
  }) async {
    if (_db == null) return;

    // Check if already liked to prevent duplicate increments
    final likeDoc =
        await _storyCommentLikesDoc(storyId, commentId, userId).get();
    if (likeDoc.exists) {
      // Already liked, skip to prevent double-increment
      return;
    }

    // Get actual like count before incrementing
    final actualCount = await getActualCommentLikeCount(
      storyId: storyId,
      commentId: commentId,
    );

    await _storyCommentLikesDoc(storyId, commentId, userId).set({
      "storyId": storyId,
      "commentId": commentId,
      "userId": userId,
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    // Set the likeCount to the actual count + 1 (safer than increment)
    // This prevents inconsistencies from previous operations
    await _storyCommentsRef(storyId).doc(commentId).set({
      "likeCount": actualCount + 1,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unlikeComment({
    required String storyId,
    required String commentId,
    required String userId,
  }) async {
    if (_db == null) return;

    // First, verify the like actually exists before deleting
    final likeDoc =
        await _storyCommentLikesDoc(storyId, commentId, userId).get();
    if (!likeDoc.exists) {
      // Like doesn't exist, skip operation to prevent negative counts
      return;
    }

    // Get actual like count before decrementing
    final actualCount = await getActualCommentLikeCount(
      storyId: storyId,
      commentId: commentId,
    );

    await _storyCommentLikesDoc(storyId, commentId, userId).delete();

    // Set the likeCount to max(0, actualCount - 1) to prevent going negative
    // This fixes inconsistencies from old data
    final newCount = (actualCount - 1) < 0 ? 0 : (actualCount - 1);
    await _storyCommentsRef(storyId).doc(commentId).set({
      "likeCount": newCount,
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<bool> hasUserLikedComment({
    required String storyId,
    required String commentId,
    required String userId,
  }) async {
    final doc = await _storyCommentLikesDoc(storyId, commentId, userId).get();
    return doc.exists;
  }

  /// Get actual comment like count from the database
  /// This queries the actual likes collection (source of truth)
  /// and compares with stored likeCount field to detect inconsistencies
  Future<int> getActualCommentLikeCount({
    required String storyId,
    required String commentId,
  }) async {
    if (_db == null) return 0;

    try {
      // Query the actual likes from storyCommentLikes
      final likesSnapshot =
          await _db
              .collection("storyCommentLikes")
              .doc(storyId)
              .collection("likes")
              .where("commentId", isEqualTo: commentId)
              .count()
              .get();

      return likesSnapshot.count ?? 0;
    } catch (e) {
      // If count query fails, fall back to fetching all docs
      try {
        final likesSnapshot =
            await _db
                .collection("storyCommentLikes")
                .doc(storyId)
                .collection("likes")
                .where("commentId", isEqualTo: commentId)
                .get();
        return likesSnapshot.docs.length;
      } catch (e) {
        // If query fails, return 0 as safe default
        return 0;
      }
    }
  }

  Future<void> incrementShareCount(String storyId) async {
    if (_db == null) return;

    await _storyEngagementDoc(storyId).set({
      "storyId": storyId,
      "shareCount": FieldValue.increment(1),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  // ==================== REPORTS ====================

  Future<void> submitUserReport({
    required String reporterKey,
    required String reportedUid,
    required String reason,
    String? notes,
  }) async {
    if (_db == null) return;

    try {
      await _db.collection('reports').add({
        'reporterKey': reporterKey,
        'reportedUid': reportedUid,
        'reason': reason,
        'notes': notes,
        'createdAt': FieldValue.serverTimestamp(),
        'status': 'pending',
      });
    } catch (e) {
      throw FirestoreException('Failed to submit report: $e');
    }
  }
}

class FirestoreException implements Exception {
  final String message;
  FirestoreException(this.message);

  String toString() => message;
}
