import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../auth/auth_providers.dart';
import '../bootstrap/firebase_ready_provider.dart';
import '../constants/app_constants.dart';
import '../session/effective_relationship_status_provider.dart';
import '../user/current_user_doc_provider.dart';

enum DatingProfileStatus { none, incomplete, complete }

final datingProfileStatusProvider = StreamProvider<DatingProfileStatus>((ref) {
  final ready = ref.watch(firebaseReadyProvider);
  final authAsync = ref.watch(authStateProvider);
  final rel = ref.watch(effectiveRelationshipStatusProvider);

  // Married users do NOT have dating profiles.
  if (rel == RelationshipStatus.married) {
    return Stream.value(DatingProfileStatus.complete);
  }

  final uid = authAsync.maybeWhen(data: (a) => a.user?.uid, orElse: () => null);

  if (!ready || uid == null) {
    return Stream.value(DatingProfileStatus.none);
  }

  final fs = FirebaseFirestore.instance;

  // Legacy compatibility:
  // If the signed-in user's /users/{uid} doc is legacy (schemaVersion missing or < 2),
  // treat their dating profile as complete so they can use chats/search immediately.
  return ref.watch(currentUserDocProvider.stream).asyncExpand((userDoc) {
    final sv = userDoc?['schemaVersion'];
    final svInt = (sv is int) ? sv : int.tryParse(sv?.toString() ?? '');
    final isLegacy = (svInt == null || svInt < 2);

    if (isLegacy) {
      return Stream.value(DatingProfileStatus.complete);
    }

    // v2 path: check datingProfiles/{uid} completeness.
    return fs.collection('datingProfiles').doc(uid).snapshots().map((doc) {
      final data = doc.data();
      if (data == null) return DatingProfileStatus.none;

      final name = (data['name'] as String?)?.trim() ?? '';
      final age = data['age'];
      final gender = (data['gender'] as String?)?.trim() ?? '';
      final photos = data['photos'];

      final ageOk = (age is num) && age >= 18;
      final photosOk = (photos is List) && photos.isNotEmpty;

      final complete =
          name.isNotEmpty && ageOk && gender.isNotEmpty && photosOk;

      return complete
          ? DatingProfileStatus.complete
          : DatingProfileStatus.incomplete;
    });
  });
});
