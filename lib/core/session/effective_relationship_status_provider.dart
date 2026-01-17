import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../constants/app_constants.dart';
import '../providers/auth_provider.dart';
import '../user/current_user_doc_provider.dart';
import 'guest_session_provider.dart';

RelationshipStatus? _parseRelationshipStatusKey(String? key) {
  final k = (key ?? '').trim().toLowerCase();
  switch (k) {
    case 'single_never_married':
    case 'single':
    case 'never_married':
      return RelationshipStatus.singleNeverMarried;
    case 'married':
      return RelationshipStatus.married;
    case 'divorced':
      return RelationshipStatus.divorced;
    case 'widowed':
      return RelationshipStatus.widowed;
    default:
      return null;
  }
}

/// Source of truth:
/// - Signed-in users: Firestore `users/{uid}` doc (nexus.relationshipStatus; nexus2 mirror)
/// - Guests: guestSessionProvider
///
/// If signed in but missing relationshipStatus (v1 user pre-presurvey), returns null.
/// NavConfig already treats null as singles (so tabs don't disappear).
final effectiveRelationshipStatusProvider = Provider<RelationshipStatus?>((ref) {
  final authAsync = ref.watch(authStateProvider);
  final user = authAsync.maybeWhen(data: (u) => u, orElse: () => null);

  // Signed out / anonymous -> guest session status
  if (user == null || user.isAnonymous) {
    final guest = ref.watch(guestSessionProvider);
    return guest?.relationshipStatus;
  }

  // Signed in -> Firestore-backed status
  final docAsync = ref.watch(currentUserDocProvider);
  final doc = docAsync.maybeWhen(data: (d) => d, orElse: () => null);
  if (doc == null) return null;

  final nexus = (doc['nexus'] as Map?)?.cast<String, dynamic>();
  final nexus2 = (doc['nexus2'] as Map?)?.cast<String, dynamic>();

  final key =
      (nexus?['relationshipStatus'] ?? nexus2?['relationshipStatus'])?.toString();

  return _parseRelationshipStatusKey(key);
});
