import 'package:cloud_firestore/cloud_firestore.dart';
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
    return _db!.collection('journeyProgress').doc(uid).collection('progress');
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
      await _userDocRef(uid).set(prefixedFields, SetOptions(merge: true));
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
      await _userDocRef(uid).set(fields, SetOptions(merge: true));
    } catch (e) {
      throw FirestoreException('Failed to update user fields: $e');
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
      await _userDocRef(uid).set({
        'nexus': {
          'relationshipStatus': relationshipStatus,
          'gender': gender,
          'primaryGoals': primaryGoals,
          'onboardingCompleted': true,
          'onboardedAt': FieldValue.serverTimestamp(),
          'schemaVersion': AppConfig.nexus2SchemaVersion,
        },
        // Temporary mirror for backwards compatibility while migrating codepaths.
        'nexus2': {
          'relationshipStatus': relationshipStatus,
          'gender': gender,
          'primaryGoals': primaryGoals,
          'onboardingCompleted': true,
          'onboardedAt': FieldValue.serverTimestamp(),
          'schemaVersion': AppConfig.nexus2SchemaVersion,
        },
      }, SetOptions(merge: true));
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
      // ✅ New Nexus v2 storage first
      final latestSnap = await _latestAssessmentRef(uid, assessmentId).get();
      if (latestSnap.exists && latestSnap.data() != null) {
        return AssessmentResult.fromJson(latestSnap.data()!);
      }

      // ✅ Fallback to legacy storage
      final query =
          await _assessmentResultsRef(uid)
              .where('assessmentId', isEqualTo: assessmentId)
              .orderBy('completedAt', descending: true)
              .limit(1)
              .get();

      if (query.docs.isEmpty) return null;
      return AssessmentResult.fromJson(query.docs.first.data());
    } catch (e) {
      throw FirestoreException('Failed to get assessment result: $e');
    }
  }

  Future<List<AssessmentResult>> getAllAssessmentResults(String uid) async {
    try {
      // ✅ Prefer latest-per-assessment documents
      final snap =
          await _userAssessmentsRef(
            uid,
          ).orderBy('updatedAt', descending: true).get();

      return snap.docs
          .map((doc) => AssessmentResult.fromJson(doc.data()))
          .toList();
    } catch (e) {
      // ✅ Fallback to legacy storage
      try {
        final query =
            await _assessmentResultsRef(
              uid,
            ).orderBy('completedAt', descending: true).get();
        return query.docs
            .map((doc) => AssessmentResult.fromJson(doc.data()))
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
      final batch = db.batch();

      // Save the vote
      batch.set(_pollVotesRef(vote.pollId).doc(vote.userId), vote.toJson());

      // Update aggregate
      batch.set(_pollAggregateRef(vote.pollId), {
        'pollId': vote.pollId,
        'totalVotes': FieldValue.increment(1),
        'optionCounts.${vote.selectedOptionId}': FieldValue.increment(1),
        'updatedAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));

      await batch.commit();
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
      await _storyCommentsRef(storyId).doc(parentId).set({
        "replyCount": FieldValue.increment(1),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
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
      await _storyCommentsRef(storyId).doc(parentId).set({
        "replyCount": FieldValue.increment(-1),
        "updatedAt": FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    }
  }

  Future<void> likeComment({
    required String storyId,
    required String commentId,
    required String userId,
  }) async {
    if (_db == null) return;

    await _storyCommentLikesDoc(storyId, commentId, userId).set({
      "storyId": storyId,
      "commentId": commentId,
      "userId": userId,
      "createdAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));

    await _storyCommentsRef(storyId).doc(commentId).set({
      "likeCount": FieldValue.increment(1),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }

  Future<void> unlikeComment({
    required String storyId,
    required String commentId,
    required String userId,
  }) async {
    if (_db == null) return;

    await _storyCommentLikesDoc(storyId, commentId, userId).delete();

    await _storyCommentsRef(storyId).doc(commentId).set({
      "likeCount": FieldValue.increment(-1),
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

  Future<void> incrementShareCount(String storyId) async {
    if (_db == null) return;

    await _storyEngagementDoc(storyId).set({
      "storyId": storyId,
      "shareCount": FieldValue.increment(1),
      "updatedAt": FieldValue.serverTimestamp(),
    }, SetOptions(merge: true));
  }
}

class FirestoreException implements Exception {
  final String message;
  FirestoreException(this.message);

  String toString() => message;
}
