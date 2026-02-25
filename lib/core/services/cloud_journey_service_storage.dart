import 'package:http/http.dart' as http;
import 'dart:convert';

/// Simple service to fetch journeys from Firebase Storage via Cloud Functions
///
/// No Firestore needed - journeys are plain JSON files in Storage at:
/// gs://nexus-visibility-app.appspot.com/journeys/{category}/{journeyId}.json
///
/// To update: just upload new JSON file to Storage, no app rebuild needed!
class CloudJourneyServiceStorage {
  static const String baseUrl =
      'https://us-central1-nexus-visibility-app.cloudfunctions.net';

  // Simple in-memory cache
  final Map<String, dynamic> _cache = {};
  final Map<String, DateTime> _cacheTime = {};
  final Duration cacheDuration = const Duration(minutes: 60);

  /// Fetch a single journey JSON from Storage
  ///
  /// Example:
  /// ```dart
  /// final journey = await service.getJourney(
  ///   category: 'married',
  ///   journeyId: 'married_journey_01_communication_conflict',
  /// );
  /// ```
  Future<Map<String, dynamic>> getJourney({
    required String category,
    required String journeyId,
    bool forceRefresh = false,
  }) async {
    final cacheKey = '$category/$journeyId';

    // Check cache
    if (!forceRefresh &&
        _cache.containsKey(cacheKey) &&
        _cacheTime[cacheKey]?.add(cacheDuration).isAfter(DateTime.now()) ==
            true) {
      return _cache[cacheKey];
    }

    try {
      final url = '$baseUrl/getJourney?category=$category&journeyId=$journeyId';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        _cache[cacheKey] = data;
        _cacheTime[cacheKey] = DateTime.now();
        return data;
      } else {
        throw Exception(
          'Failed to fetch journey: ${response.statusCode} - ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('Error fetching journey: $e');
    }
  }

  /// List all journey IDs in a category
  ///
  /// Example:
  /// ```dart
  /// final journeys = await service.listJourneys(category: 'married');
  /// // Returns: ['married_journey_01_communication_conflict', 'married_journey_02_..', ...]
  /// ```
  Future<List<String>> listJourneys({required String category}) async {
    try {
      final url = '$baseUrl/listJourneys?category=$category';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body);
        final journeys = List<String>.from(data['journeys'] ?? []);
        return journeys;
      } else {
        throw Exception('Failed to list journeys: ${response.statusCode}');
      }
    } catch (e) {
      throw Exception('Error listing journeys: $e');
    }
  }

  /// Clear local cache (useful after manually uploading to Storage)
  void clearCache() {
    _cache.clear();
    _cacheTime.clear();
  }
}
