import 'dart:convert';
import 'package:http/http.dart' as http;
import '../constants/app_constants.dart';
import '../services/cloud_journey_service_storage.dart';

/// Loads journeys catalogs from Cloud Storage via Cloud Functions.
/// Replaces asset-based loading with cloud-served JSONs.
/// No rebuild needed for updates - just upload new JSONs to Storage!
class CloudJourneysService {
  final CloudJourneyServiceStorage _cloudService = CloudJourneyServiceStorage();

  Future<Map<String, dynamic>> loadCatalogForStatus(
    RelationshipStatus status,
  ) async {
    // Map relationship status to cloud category name
    final category = _getCategory(status);
    return await _loadCatalogFromCloud(category, status);
  }

  /// Fetch all journeys for a category from Cloud Storage
  Future<Map<String, dynamic>> _loadCatalogFromCloud(
    String category,
    RelationshipStatus status,
  ) async {
    try {
      print('[CloudJourneysService] Loading journeys from cloud: $category');

      // Get list of journey IDs for this category
      final journeyIds = await _cloudService.listJourneys(category: category);

      if (journeyIds.isEmpty) {
        print(
          '[CloudJourneysService] No journeys found for category=$category',
        );
        return _emptyJourneyCatalog(status);
      }

      final journeys = <Map<String, dynamic>>[];

      // Fetch each journey individually and assemble
      for (final storageJourneyId in journeyIds) {
        try {
          final journeyJson = await _cloudService.getJourney(
            category: category,
            journeyId: storageJourneyId,
          );

          // Normalize to expected format
          final normalized = _normalizeJourneyJson(
            journeyJson,
            storageJourneyId,
          );
          if (normalized != null) {
            journeys.add(normalized);
          }
        } catch (e) {
          print(
            '[CloudJourneysService] Error loading journey $storageJourneyId: $e',
          );
          // Continue with next journey
        }
      }

      print(
        '[CloudJourneysService] Loaded ${journeys.length} journeys from cloud',
      );

      return {'version': '1.0', 'category': category, 'journeys': journeys};
    } catch (e) {
      print('[CloudJourneysService] Error loading catalog from cloud: $e');
      return _emptyJourneyCatalog(status);
    }
  }

  /// Normalize journey JSON to expected format
  Map<String, dynamic>? _normalizeJourneyJson(
    Map<String, dynamic> data,
    String storageJourneyId,
  ) {
    try {
      final canonicalJourneyId =
          (data['journeyId'] ?? data['id'] ?? storageJourneyId).toString();
      final priorityRank = _extractPriorityRank(storageJourneyId);

      print(
        '[CloudJourneysService] Normalize: storageId=$storageJourneyId -> canonicalId=$canonicalJourneyId',
      );

      return {
        'id': canonicalJourneyId,
        'journeyId': canonicalJourneyId,
        'title': data['title'] ?? 'Untitled',
        'subtitle': data['subtitle'] ?? '',
        'summary': data['summary'] ?? '',
        'priorityRank': priorityRank,
        'icon': data['icon'] ?? 'sparkles',
        'missions': data['missions'] ?? data['activities'] ?? [],
        'cover': data['cover'],
        'allowedGenders': data['allowedGenders'] ?? [],
      };
    } catch (e) {
      print('[CloudJourneysService] Error normalizing journey: $e');
      return null;
    }
  }

  /// Extract priority/order from journey ID
  /// Format: married_journey_01_title -> 1
  int _extractPriorityRank(String journeyId) {
    final match = RegExp(r'_(\d+)_').firstMatch(journeyId);
    if (match != null) {
      return int.tryParse(match.group(1) ?? '999') ?? 999;
    }
    return 999;
  }

  /// Map relationship status to cloud category
  String _getCategory(RelationshipStatus status) {
    switch (status) {
      case RelationshipStatus.singleNeverMarried:
        return 'singles';
      case RelationshipStatus.married:
        return 'married';
      case RelationshipStatus.divorced:
        return 'divorced';
      case RelationshipStatus.widowed:
        return 'widowed';
    }
  }

  /// Empty catalog for error cases
  Map<String, dynamic> _emptyJourneyCatalog(RelationshipStatus status) {
    return {'version': '1.0', 'category': _getCategory(status), 'journeys': []};
  }
}
