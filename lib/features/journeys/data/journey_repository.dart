import 'package:flutter/services.dart';
import 'package:nexus_app_min_test/features/journeys/domain/journey_models.dart';

class JourneyRepository {
  const JourneyRepository();

  Future<List<Journey>> loadJourneysForCategory(String category) async {
    final normalized = category.toLowerCase();

    // Default mapping (divorced falls back to singles for now).
    final assetPath = switch (normalized) {
      'married' => 'assets/config/journeys/journeys_married.v1.json',
      'widowed' => 'assets/config/journeys/journeys_widowed.v1.json',
      'divorced' => 'assets/config/journeys/journeys_singles.v1.json',
      'single' => 'assets/config/journeys/journeys_singles.v1.json',
      'singles' => 'assets/config/journeys/journeys_singles.v1.json',
      _ => 'assets/config/journeys/journeys_singles.v1.json',
    };

    final raw = await rootBundle.loadString(assetPath);
    final payload = JourneysPayload.fromJsonString(raw);

    final list = [...payload.journeys];
    list.sort((a, b) => a.priorityRank.compareTo(b.priorityRank));
    return list;
  }
}
