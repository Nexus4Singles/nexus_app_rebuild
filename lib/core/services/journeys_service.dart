import 'dart:convert';
import 'package:flutter/services.dart' show rootBundle;

import '../constants/app_constants.dart';

/// Loads journeys catalogs from assets.
/// Update the asset paths to match your real filenames in pubspec.yaml.
class JourneysService {
  const JourneysService();

  Future<Map<String, dynamic>> loadCatalogForStatus(
    RelationshipStatus status,
  ) async {
    final assetPath = _assetForStatus(status);
    final raw = await rootBundle.loadString(assetPath);
    return json.decode(raw) as Map<String, dynamic>;
  }

  String _assetForStatus(RelationshipStatus status) {
    switch (status) {
      case RelationshipStatus.married:
        return 'assets/config/journeys/journeys_married.v1.json';
      case RelationshipStatus.divorced:
        return 'assets/config/journeys/journeys_divorced.v1.json';
      case RelationshipStatus.widowed:
        return 'assets/config/journeys/journeys_widowed.v1.json';
      case RelationshipStatus.singleNeverMarried:
        return 'assets/config/journeys/journeys_singles.v1.json';
    }
  }
}
