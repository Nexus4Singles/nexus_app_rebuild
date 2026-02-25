import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

/// Service to fetch journey JSON files from cloud without app rebuild needed
///
/// Architecture:
/// - Journey JSONs are stored in Firestore under: journeys/{category}/files/{journeyId}
/// - Cloud Function endpoints serve these files without local bundling
/// - Updates happen in real-time without requiring new app builds
class CloudJourneyService {
  static const String functionsBaseUrl =
      'https://us-central1-nexus-app-v2.cloudfunctions.net';

  final FirebaseFirestore _firestore;
  final FirebaseAuth _auth;

  // Local cache to avoid repeated network calls
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTimestamps = {};
  static const int _cacheExpiryMinutes = 60;

  CloudJourneyService({FirebaseFirestore? firestore, FirebaseAuth? auth})
    : _firestore = firestore ?? FirebaseFirestore.instance,
      _auth = auth ?? FirebaseAuth.instance;

  /// Fetch a single journey file by ID
  ///
  /// Returns the journey JSON content or null if not found
  /// Logs to Firestore for analytics
  Future<Map<String, dynamic>?> getJourney({
    required String category,
    required String journeyId,
    bool forceRefresh = false,
  }) async {
    try {
      final cacheKey = '$category/$journeyId';

      // Check local cache first
      if (!forceRefresh && _isCacheValid(cacheKey)) {
        return _cache[cacheKey] as Map<String, dynamic>?;
      }

      // Fetch from Firestore directly (most reliable)
      final doc =
          await _firestore
              .collection('journeys')
              .doc(category)
              .collection('files')
              .doc(journeyId)
              .get();

      if (!doc.exists) {
        debugLog('Journey not found: $category/$journeyId');
        return null;
      }

      final data = doc.data();
      if (data == null) return null;

      final content = data['content'] as Map<String, dynamic>?;

      // Cache the result
      _cache[cacheKey] = content;
      _cacheTimestamps[cacheKey] = DateTime.now();

      // Log access for analytics
      _logJourneyAccess(journeyId, category);

      return content;
    } catch (e) {
      debugLog('Error fetching journey: $e');
      return null;
    }
  }

  /// Fetch all journey summaries for a category
  /// Returns list of { id, title, version, updatedAt }
  Future<List<Map<String, dynamic>>> listJourneys(String category) async {
    try {
      final snapshot =
          await _firestore
              .collection('journeys')
              .doc(category)
              .collection('files')
              .orderBy('journeyNumber', descending: false)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'id': doc.id,
          'title': data['title'] ?? 'Untitled',
          'version': data['version'] ?? 1,
          'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate(),
        };
      }).toList();
    } catch (e) {
      debugLog('Error listing journeys: $e');
      return [];
    }
  }

  /// Update a journey file (admin only)
  ///
  /// Requires Firebase auth token with admin=true custom claim
  /// Automatically versions and backs up previous version
  Future<bool> updateJourney({
    required String category,
    required String journeyId,
    required Map<String, dynamic> content,
    String? title,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) {
        debugLog('User not authenticated');
        return false;
      }

      // Get ID token
      final idToken = await user.getIdToken();

      // Verify admin claims before sending
      final claims = await user.getIdTokenResult();
      if (claims.claims?['admin'] != true) {
        debugLog('User does not have admin claim');
        return false;
      }

      final response = await http.post(
        Uri.parse('$functionsBaseUrl/updateJourney'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({
          'category': category,
          'journeyId': journeyId,
          'content': content,
          'title': title,
        }),
      );

      if (response.statusCode == 200) {
        // Invalidate cache
        _cache.remove('$category/$journeyId');
        _cacheTimestamps.remove('$category/$journeyId');
        debugLog('Journey updated successfully: $category/$journeyId');
        return true;
      } else {
        debugLog('Update failed: ${response.body}');
        return false;
      }
    } catch (e) {
      debugLog('Error updating journey: $e');
      return false;
    }
  }

  /// Batch upload multiple journeys (admin only)
  /// Useful for initial seeding or migration from local assets
  Future<int> batchUploadJourneys({
    required String category,
    required List<Map<String, dynamic>> journeys,
  }) async {
    try {
      final user = _auth.currentUser;
      if (user == null) return 0;

      final idToken = await user.getIdToken();
      final claims = await user.getIdTokenResult();
      if (claims.claims?['admin'] != true) return 0;

      final response = await http.post(
        Uri.parse('$functionsBaseUrl/batchUploadJourneys'),
        headers: {
          'Content-Type': 'application/json',
          'Authorization': 'Bearer $idToken',
        },
        body: jsonEncode({'category': category, 'journeys': journeys}),
      );

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        final uploadedCount = data['uploaded'] as int? ?? 0;
        debugLog('Batch uploaded $uploadedCount journeys to $category');
        return uploadedCount;
      }
      return 0;
    } catch (e) {
      debugLog('Error batch uploading: $e');
      return 0;
    }
  }

  /// Fetch version history for a journey
  Future<List<Map<String, dynamic>>> getJourneyHistory({
    required String category,
    required String journeyId,
  }) async {
    try {
      final snapshot =
          await _firestore
              .collection('journeys')
              .doc(category)
              .collection('history')
              .where('journeyId', isEqualTo: journeyId)
              .orderBy('version', descending: true)
              .get();

      return snapshot.docs.map((doc) {
        final data = doc.data();
        return {
          'version': data['version'],
          'updatedAt': (data['updatedAt'] as Timestamp?)?.toDate(),
          'updatedBy': data['updatedBy'],
          'contentHash': data['contentHash'],
        };
      }).toList();
    } catch (e) {
      debugLog('Error fetching history: $e');
      return [];
    }
  }

  /// Clear local cache to force refresh from cloud
  void clearCache() {
    _cache.clear();
    _cacheTimestamps.clear();
    debugLog('Journey cache cleared');
  }

  /// Private helpers

  bool _isCacheValid(String key) {
    final timestamp = _cacheTimestamps[key];
    if (timestamp == null) return false;

    final elapsed = DateTime.now().difference(timestamp);
    return elapsed.inMinutes < _cacheExpiryMinutes;
  }

  void _logJourneyAccess(String journeyId, String category) {
    try {
      final userId = _auth.currentUser?.uid;
      if (userId == null) return;

      _firestore
          .collection('analytics')
          .doc('journeyAccess')
          .collection('logs')
          .add({
            'userId': userId,
            'journeyId': journeyId,
            'category': category,
            'timestamp': FieldValue.serverTimestamp(),
            'platform': 'mobile',
          })
          .then((_) {}, onError: (_, __) {}); // Silently fail on logging
    } catch (_) {
      // Ignore logging errors
    }
  }
}

void debugLog(String message) {
  print('[CloudJourneyService] $message');
}
