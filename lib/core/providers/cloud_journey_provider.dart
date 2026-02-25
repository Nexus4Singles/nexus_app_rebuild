import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../services/cloud_journeys_service.dart';
import '../services/cloud_journey_service_storage.dart';

/// Provider for CloudJourneysService (fetches catalog using HTTP)
final cloudJourneysServiceProvider = Provider<CloudJourneysService>((ref) {
  return CloudJourneysService();
});

/// Provider for CloudJourneyServiceStorage (low-level HTTP wrapper)
final cloudJourneyServiceStorageProvider = Provider<CloudJourneyServiceStorage>(
  (ref) {
    return CloudJourneyServiceStorage();
  },
);
