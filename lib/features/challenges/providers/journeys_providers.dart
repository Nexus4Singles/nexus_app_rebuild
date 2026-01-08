import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/journeys_service.dart';
import '../../../core/services/journey_entitlements_service.dart';
import '../../../core/services/journey_progress_service.dart';
import '../../../core/services/journey_mission_response_service.dart';
import '../../../core/session/effective_relationship_status_provider.dart';
import '../domain/journey_v1_models.dart';

final journeysServiceProvider = Provider((ref) => const JourneysService());
final journeyProgressServiceProvider = Provider(
  (ref) => JourneyProgressService(),
);
final journeyEntitlementsServiceProvider = Provider(
  (ref) => JourneyEntitlementsService(),
);
final journeyMissionResponseServiceProvider = Provider(
  (ref) => JourneyMissionResponseService(),
);

final journeyCatalogProvider = FutureProvider<JourneyCatalogV1>((ref) async {
  final status =
      ref.watch(effectiveRelationshipStatusProvider) ??
      RelationshipStatus.singleNeverMarried;

  final service = ref.watch(journeysServiceProvider);
  final json = await service.loadCatalogForStatus(status);
  return JourneyCatalogV1.fromJson(json);
});

final journeyByIdProvider = Provider.family<JourneyV1?, String>((ref, id) {
  final catalogAsync = ref.watch(journeyCatalogProvider);
  return catalogAsync.maybeWhen(
    data: (catalog) => catalog.findById(id),
    orElse: () => null,
  );
});

final completedMissionIdsProvider = FutureProvider.family<Set<String>, String>((
  ref,
  journeyId,
) async {
  final svc = ref.watch(journeyProgressServiceProvider);
  return svc.loadCompletedMissionIds(journeyId);
});

final journeyStreakProvider = FutureProvider.family<int, String>((
  ref,
  journeyId,
) async {
  final svc = ref.watch(journeyProgressServiceProvider);
  return svc.loadStreak(journeyId);
});

final purchasedJourneyIdsProvider = FutureProvider<Set<String>>((ref) async {
  final svc = ref.watch(journeyEntitlementsServiceProvider);
  return svc.loadPurchasedJourneyIds();
});

final isJourneyPurchasedProvider = FutureProvider.family<bool, String>((
  ref,
  journeyId,
) async {
  final svc = ref.watch(journeyEntitlementsServiceProvider);
  return svc.isPurchased(journeyId);
});

final bestJourneysStreakProvider = FutureProvider<int>((ref) async {
  final catalog = await ref.watch(journeyCatalogProvider.future);
  final svc = ref.watch(journeyProgressServiceProvider);

  var best = 0;
  for (final j in catalog.journeys) {
    final s = await svc.loadStreak(j.id);
    if (s > best) best = s;
  }
  return best;
});
