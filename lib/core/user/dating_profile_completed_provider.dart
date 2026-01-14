import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'current_user_doc_provider.dart';

/// Returns whether the signed-in user has completed dating profile onboarding.
/// Firestore flag (v2): users/{uid}.dating.profileCompleted == true
///
/// - If Firebase isn't ready / user doc missing -> returns false.
/// - Missing field -> returns false.
final datingProfileCompletedProvider = StreamProvider<bool>((ref) {
  return ref.watch(currentUserDocProvider.stream).map((doc) {
    final dating = (doc?['dating'] as Map?)?.cast<String, dynamic>();
    final completed = dating?['profileCompleted'];
    return completed == true;
  });
});
