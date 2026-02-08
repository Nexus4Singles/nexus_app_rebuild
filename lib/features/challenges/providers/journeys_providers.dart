import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';

import '../../../core/constants/app_constants.dart';
import '../../../core/services/journeys_service.dart';
import '../../../core/services/journey_entitlements_service.dart';
import '../../../core/services/journey_progress_service.dart';
import '../../../core/services/journey_mission_response_service.dart';
import '../../../core/services/firestore_service.dart';
import '../../../core/session/effective_relationship_status_provider.dart';
import '../../../core/user/current_user_gender_provider.dart';
import '../../../core/providers/firestore_service_provider.dart';
import '../../../core/providers/user_provider.dart';
import '../domain/journey_v1_models.dart';

final journeysServiceProvider = Provider((ref) => const JourneysService());
final journeyProgressServiceProvider = Provider((ref) {
  final firestore = ref.watch(firestoreServiceProvider);
  return JourneyProgressService(firestore);
});
final journeyEntitlementsServiceProvider = Provider(
  (ref) => JourneyEntitlementsService(),
);
final journeyMissionResponseServiceProvider = Provider(
  (ref) => JourneyMissionResponseService(),
);

final journeyCatalogProvider = FutureProvider<JourneyCatalogV1>((ref) async {
  final status = ref.watch(effectiveRelationshipStatusProvider);

  final service = ref.watch(journeysServiceProvider);
  final json = await service.loadCatalogForStatus(status);
  var catalog = JourneyCatalogV1.fromJson(json);

  // Gender-specific filtering for Singles: total per gender = 20, with 2 gender-specific.
  if (status == RelationshipStatus.singleNeverMarried) {
    String? gender;
    try {
      // Wait for gender with 3-second timeout to avoid hanging
      // If gender determination takes too long, proceed without filtering
      final genderFuture = ref.watch(currentUserGenderProvider.future);
      gender = await genderFuture.timeout(
        const Duration(seconds: 3),
        onTimeout: () {
          return null; // Proceed without gender filtering
        },
      );
      
      if (gender != null) {
        gender = gender.trim().toLowerCase();
      } else {
      }
    } catch (e) {
      gender = null;
    }

    // Only filter if gender was successfully determined
    if (gender == 'male' || gender == 'female') {
      final filtered =
          catalog.journeys.where((j) => _includeForGender(j, gender!)).toList();
      catalog = JourneyCatalogV1(
        version: catalog.version,
        category: catalog.category,
        journeys: filtered,
      );
    }
  }

  return catalog;
});

final journeyByIdProvider = Provider.family<JourneyV1?, String>((ref, id) {
  final catalogAsync = ref.watch(journeyCatalogProvider);
  return catalogAsync.maybeWhen(
    data: (catalog) => catalog.findById(id),
    orElse: () => null,
  );
});

/// Returns a tuple of (JourneyV1, category) for purchase navigation
final journeyWithCategoryProvider =
    Provider.family<(JourneyV1, String)?, String>((ref, id) {
      final catalogAsync = ref.watch(journeyCatalogProvider);
      return catalogAsync.maybeWhen(
        data: (catalog) {
          final journey = catalog.findById(id);
          return journey != null ? (journey, catalog.category) : null;
        },
        orElse: () => null,
      );
    });

final completedMissionIdsProvider = FutureProvider.family<Set<String>, String>((
  ref,
  journeyId,
) async {
  final currentUserAsync = ref.watch(currentUserProvider);
  final uid = currentUserAsync.maybeWhen(
    data: (user) => user?.id ?? '',
    orElse: () => '',
  );

  if (uid.isEmpty) return <String>{};

  final svc = ref.watch(journeyProgressServiceProvider);
  return svc.loadCompletedMissionIds(journeyId, uid);
});

final journeyStreakProvider = FutureProvider.family<int, String>((
  ref,
  journeyId,
) async {
  final currentUserAsync = ref.watch(currentUserProvider);
  final uid = currentUserAsync.maybeWhen(
    data: (user) => user?.id ?? '',
    orElse: () => '',
  );

  if (uid.isEmpty) return 0;

  final svc = ref.watch(journeyProgressServiceProvider);
  return svc.loadStreak(journeyId, uid);
});

final purchasedJourneyIdsProvider = FutureProvider<Set<String>>((ref) async {
  final svc = ref.watch(journeyEntitlementsServiceProvider);
  return svc.loadPurchasedJourneyIds();
});

final isJourneyPurchasedProvider = FutureProvider.family<bool, String>((
  ref,
  journeyId,
) async {
  // Get current user ID from user provider
  final userAsync = ref.watch(currentUserProvider);
  final userId = userAsync.maybeWhen(
    data: (user) => user?.id,
    orElse: () => null,
  );

  if (userId == null) return false;

  try {
    // Check if journey is in user's purchases collection
    final doc =
        await FirebaseFirestore.instance
            .collection('users')
            .doc(userId)
            .collection('purchases')
            .doc(journeyId)
            .get();
    return doc.exists;
  } catch (e) {
    // Fall back to shared preferences as backup
    final svc = ref.watch(journeyEntitlementsServiceProvider);
    return svc.isPurchased(journeyId);
  }
});

final bestJourneysStreakProvider = FutureProvider<int>((ref) async {
  final currentUserAsync = ref.watch(currentUserProvider);
  final uid = currentUserAsync.maybeWhen(
    data: (user) => user?.id ?? '',
    orElse: () => '',
  );

  if (uid.isEmpty) return 0;

  final catalog = await ref.watch(journeyCatalogProvider.future);
  final svc = ref.watch(journeyProgressServiceProvider);

  var best = 0;
  for (final j in catalog.journeys) {
    final s = await svc.loadStreak(j.id, uid);
    if (s > best) best = s;
  }
  return best;
});

bool _includeForGender(JourneyV1 j, String gender) {
  // Prefer explicit allowedGenders from v2 schema.
  if (j.allowedGenders.isNotEmpty) {
    return j.allowedGenders.contains(gender.toLowerCase());
  }

  // Fallback heuristics from id/title.
  final id = j.id.toLowerCase();
  final title = j.title.toLowerCase();

  final isFemaleOnly = id.contains('feminin') || title.contains('feminin');
  final isMaleOnly = id.contains('masculin') || title.contains('masculin');

  if (isFemaleOnly) return gender == 'female';
  if (isMaleOnly) return gender == 'male';
  return true;
}
